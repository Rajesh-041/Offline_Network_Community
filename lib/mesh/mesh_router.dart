import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import '../ble/ble_packet.dart';
import '../ble/ble_transport.dart';
import '../crypto/identity_manager.dart';
import '../data/database_helper.dart';
import '../data/models.dart';
import '../ml/adaptive_router.dart';
import '../ml/translation_engine.dart';
import 'ack_manager.dart';

class MeshRouter {
  final IBleTransport transport;
  final IdentityManager identityManager;
  final DatabaseHelper dbHelper;
  final TinyMlAdaptiveRouter mlRouter;
  final TranslationEngine translationEngine;

  final _packetReassembler = BlePacketReassembler();

  /// LRU cache of seen message IDs (capacity ~500) to prevent duplicate relay loops
  final LinkedHashMap<String, DateTime> _seenMessageCache = LinkedHashMap();
  static const int _cacheCapacity = 500;

  final _messageStreamController = StreamController<Message>.broadcast();
  final _peersStreamController = StreamController<List<Peer>>.broadcast();

  Stream<Message> get onMessageReceived => _messageStreamController.stream;
  Stream<List<Peer>> get onPeersUpdated => _peersStreamController.stream;

  List<Peer> _activePeers = [];
  List<Peer> get activePeers => List.unmodifiable(_activePeers);

  MeshRouter({
    required this.transport,
    required this.identityManager,
    required this.dbHelper,
    required this.mlRouter,
    required this.translationEngine,
  }) {
    _initTransportListeners();
  }

  void _initTransportListeners() {
    transport.onPacketReceived.listen(_handleIncomingBlePacket);
    transport.onPeersUpdated.listen((peers) {
      _activePeers = peers;
      _peersStreamController.add(peers);
      _flushUnsentMessagesToPeers(peers);
    });
  }

  bool _isDuplicate(String messageId) {
    if (_seenMessageCache.containsKey(messageId)) {
      // Touch key to refresh LRU position
      final val = _seenMessageCache.remove(messageId)!;
      _seenMessageCache[messageId] = val;
      return true;
    }
    _seenMessageCache[messageId] = DateTime.now();
    if (_seenMessageCache.length > _cacheCapacity) {
      _seenMessageCache.remove(_seenMessageCache.keys.first);
    }
    return false;
  }

  /// Send a new message originating from local node
  Future<void> sendMessage(Message message) async {
    _isDuplicate(message.id);
    await dbHelper.saveMessage(message);

    final payloadJson = jsonEncode(message.toJson());
    final packets = BlePacket.chunkPayload(message.id, identityManager.nodeId, payloadJson);

    // Predict optimal relay paths via Tiny ML Adaptive Router
    final routeScores = mlRouter.predictOptimalRoutes(_activePeers, targetPeerId: message.recipientId);

    if (routeScores.isNotEmpty) {
      final bestPeer = routeScores.first.peer;
      for (var pkt in packets) {
        await transport.sendDirectPacket(bestPeer.id, pkt);
      }
    } else {
      // Fallback: broadcast across mesh
      for (var pkt in packets) {
        await transport.broadcastPacket(pkt);
      }
    }

    message.status = DeliveryStatus.sent;
    await dbHelper.saveMessage(message);
    _messageStreamController.add(message);
  }

  /// Send High-Priority Emergency SOS Alert (Always Relayed, Max TTL)
  Future<void> sendEmergencySos(String alertText) async {
    final sosMsg = Message(
      id: 'sos_${DateTime.now().millisecondsSinceEpoch}',
      senderId: identityManager.nodeId,
      senderFingerprint: identityManager.fingerprint,
      senderName: identityManager.nodeName,
      channelId: 'emergency',
      content: '🚨 EMERGENCY SOS ALERT: $alertText',
      timestamp: DateTime.now(),
      type: MessageType.sos,
      ttl: 15, // High TTL for disaster coverage
      status: DeliveryStatus.sent,
    );

    await sendMessage(sosMsg);
  }

  /// Handle incoming low-level BLE packet frame
  Future<void> _handleIncomingBlePacket(BlePacket packet) async {
    final reassembledJson = _packetReassembler.addChunk(packet);
    if (reassembledJson == null) return; // awaiting remaining chunks

    try {
      final Map<String, dynamic> rawMsgMap = jsonDecode(reassembledJson);
      final Message incomingMsg = Message.fromJson(rawMsgMap);

      // 1. LRU Duplicate Check
      if (_isDuplicate(incomingMsg.id)) {
        return; // Drop duplicate
      }

      // Check if sender is muted or kicked locally
      if (dbHelper.isPeerMuted(incomingMsg.senderFingerprint) ||
          dbHelper.isPeerKicked(incomingMsg.senderFingerprint)) {
        return;
      }

      // Record latency & delivery metric in Tiny ML router
      mlRouter.recordDeliveryResult(incomingMsg.senderId, true, 35.0);

      // Increment hop count & add local node to path
      incomingMsg.hopCount += 1;
      if (!incomingMsg.relayPath.contains(identityManager.nodeId)) {
        incomingMsg.relayPath.add(identityManager.nodeId);
      }

      // 2. Handle ACK packet
      if (incomingMsg.type == MessageType.ack) {
        AckManager.processAckPacket(incomingMsg, (msgId, status) {
          dbHelper.updateMessageStatus(msgId, status);
        });
        return;
      }

      // 3. On-Device Translation check if enabled
      if (incomingMsg.type == MessageType.text) {
        final translated = await translationEngine.translateMessage(incomingMsg.content);
        if (translated != null) {
          incomingMsg.translatedContent = translated;
        }
      }

      // 4. Save to local storage
      incomingMsg.status = DeliveryStatus.delivered;
      await dbHelper.saveMessage(incomingMsg);
      _messageStreamController.add(incomingMsg);

      // Send ACK back to sender if recipient match
      if (incomingMsg.recipientId == identityManager.nodeId) {
        final ack = AckManager.createAckMessage(
          originalMessageId: incomingMsg.id,
          senderId: identityManager.nodeId,
          senderFingerprint: identityManager.fingerprint,
          senderName: identityManager.nodeName,
          recipientId: incomingMsg.senderId,
          ackStatus: DeliveryStatus.delivered,
        );
        await sendMessage(ack);
      }

      // 5. Store-and-Forward Relay if TTL > 0 and not final destination
      if (incomingMsg.ttl > incomingMsg.hopCount &&
          incomingMsg.recipientId != identityManager.nodeId) {
        
        final relayedMsg = incomingMsg.copyWith(
          status: DeliveryStatus.relayed,
        );

        final payloadJson = jsonEncode(relayedMsg.toJson());
        final packets = BlePacket.chunkPayload(relayedMsg.id, identityManager.nodeId, payloadJson);

        final routeScores = mlRouter.predictOptimalRoutes(_activePeers);
        if (routeScores.isNotEmpty) {
          for (var pkt in packets) {
            await transport.broadcastPacket(pkt);
          }
        }
      }
    } catch (e) {
      // Ignore corrupted / malformed packet bytes
    }
  }

  /// Automatically flush unsent/buffered messages in SQLite to newly discovered BLE peers
  Future<void> _flushUnsentMessagesToPeers(List<Peer> peers) async {
    if (peers.isEmpty) return;
    final unsentList = dbHelper.getUnsentQueue();
    for (var msg in unsentList) {
      await sendMessage(msg);
    }
  }
}
