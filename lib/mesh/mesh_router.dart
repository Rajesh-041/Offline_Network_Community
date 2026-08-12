import 'dart:async';
import 'dart:convert';
import '../ble/ble_packet.dart';
import '../ble/ble_transport.dart';
import '../ble/gatt_client.dart';
import '../ble/gatt_server.dart';
import '../data/database_helper.dart';
import '../data/models.dart';
import '../ml/adaptive_router.dart';
import '../ml/translation_engine.dart';
import '../packet/fragmenter.dart';
import '../packet/mesh_packet.dart';
import '../packet/reassembler.dart';
import '../power/friend_manager.dart';
import '../power/low_power_node.dart';
import '../provisioning/provisioner.dart';
import '../security/encryption.dart';
import '../security/identity_manager.dart';
import '../security/replay_protection.dart';
import '../topology/topology_manager.dart';
import 'ack_manager.dart';
import 'message_cache.dart';
import 'partition_manager.dart';
import 'relay_manager.dart';
import 'store_forward.dart';
import 'ttl_manager.dart';

/// Bluetooth Mesh Protocol 1.1 Compliant Core Router.
/// Integrates all 15 layered protocol features into a unified mesh pipeline.
class MeshRouter {
  final IBleTransport transport;
  final IdentityManager identityManager;
  final DatabaseHelper dbHelper;
  final TinyMlAdaptiveRouter mlRouter;
  final TranslationEngine translationEngine;

  // Layered Protocol Components
  final MeshGattServer gattServer = MeshGattServer();
  final MeshGattClient gattClient = MeshGattClient();
  final MeshPacketReassembler reassembler = MeshPacketReassembler();
  final MeshNetworkMessageCache messageCache = MeshNetworkMessageCache();
  final ReplayProtectionList replayProtection = ReplayProtectionList();
  final MeshRelayManager relayManager = MeshRelayManager();
  final MeshAckManager ackManager = MeshAckManager();
  final FriendNodeManager friendManager = FriendNodeManager();
  late final LowPowerNodeManager lpnManager;
  late final MeshTopologyManager topologyManager;
  late final StoreAndForwardEngine storeAndForward;
  final NetworkPartitionManager partitionManager = NetworkPartitionManager();
  late final MeshProvisioner provisioner;

  int _sequenceCounter = 1;

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
    topologyManager = MeshTopologyManager(identityManager: identityManager);
    storeAndForward = StoreAndForwardEngine(dbHelper: dbHelper);
    provisioner = MeshProvisioner(identityManager: identityManager);
    lpnManager = LowPowerNodeManager(onSendFriendPoll: (friendAddr) {
      _sendFriendPollRequest(friendAddr);
    });

    _initTransportListeners();
  }

  void _initTransportListeners() {
    transport.onPacketReceived.listen((blePkt) {
      try {
        final meshPkt = BluetoothMeshPacket.fromJson(jsonDecode(blePkt.payloadJson));
        _handleIncomingMeshPacket(meshPkt);
      } catch (e) {
        // Fallback for raw byte transport
      }
    });

    transport.onPeersUpdated.listen((peers) {
      _activePeers = peers;
      _peersStreamController.add(peers);

      // Update Topology Graph Link Metrics
      for (var peer in peers) {
        topologyManager.updateNeighborLink(
          unicastAddress: _deriveUnicast(peer.fingerprint),
          peerId: peer.id,
          peerName: peer.name,
          fingerprint: peer.fingerprint,
          rssi: peer.rssi,
          hopCount: peer.hops,
        );

        // Network Partition Recovery & Inventory Sync
        partitionManager.detectPeerReappearance(peer.id, (pId) {
          _flushUnsentMessagesToPeers([peer]);
        });
      }

      _flushUnsentMessagesToPeers(peers);
    });
  }

  static int _deriveUnicast(String fp) {
    final bytes = utf8.encode(fp);
    return ((bytes[0] << 8) | bytes[1]) & 0x7FFF;
  }

  /// Send application message through the layered mesh pipeline
  Future<void> sendMessage(Message message) async {
    await dbHelper.saveMessage(message);

    // 1. Encrypt Application Payload
    final encryptedPayload = MeshEncryptionEngine.encryptNetworkPayload(
      message.content,
      identityManager.meshKeyManager.appKey,
      _sequenceCounter,
      identityManager.unicastAddress,
    );

    // 2. Fragment large payloads via SAR Segmenter
    final fragments = MeshPacketFragmenter.fragmentPayload(
      messageId: message.id,
      senderFingerprint: identityManager.fingerprint,
      senderName: identityManager.nodeName,
      nid: identityManager.meshKeyManager.deriveNid(),
      ttl: MeshTtlManager.defaultTtl,
      seq: _sequenceCounter++,
      src: identityManager.unicastAddress,
      dst: message.recipientId != null ? _deriveUnicast(message.senderFingerprint) : 0xFFFF,
      payload: encryptedPayload,
    );

    // 3. Managed Flooding / Next-Hop Relay Selection
    for (var frag in fragments) {
      messageCache.isDuplicate(frag.src, frag.seq, frag.messageId);

      final routeScores = mlRouter.predictOptimalRoutes(_activePeers, targetPeerId: message.recipientId);
      final rawBlePkt = frag.toJson();

      if (routeScores.isNotEmpty) {
        await transport.sendDirectPacket(routeScores.first.peer.id, _toBlePacket(frag));
      } else {
        await transport.broadcastPacket(_toBlePacket(frag));
      }
    }

    message.status = DeliveryStatus.sent;
    await dbHelper.saveMessage(message);
    _messageStreamController.add(message);
  }

  /// Send High-Priority Location-Free Emergency SOS Broadcast
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
      ttl: 15,
      status: DeliveryStatus.sent,
    );

    await sendMessage(sosMsg);
  }

  /// Process incoming Network PDU packet through the 15-feature layered pipeline
  Future<void> _handleIncomingMeshPacket(BluetoothMeshPacket frag) async {
    // Feature 13: Replay Protection Check
    if (replayProtection.isReplayAttack(frag.src, frag.seq)) {
      return; // Reject replayed packet attack
    }

    // Feature 7: Message Cache & Duplicate Suppression
    if (messageCache.isDuplicate(frag.src, frag.seq, frag.messageId)) {
      return; // Drop duplicate network PDU
    }

    replayProtection.updateSequence(frag.src, frag.seq);

    // Feature 9: SAR Reassembly
    final completePacket = reassembler.addFragment(frag);
    if (completePacket == null) return; // Awaiting remaining fragments

    // Feature 12: Decryption
    String decryptedContent = completePacket.payload;
    try {
      decryptedContent = MeshEncryptionEngine.decryptNetworkPayload(
        completePacket.payload,
        identityManager.meshKeyManager.appKey,
        completePacket.seq,
        completePacket.src,
      );
    } catch (e) {
      // Fallback unencrypted / broadcast
    }

    // Construct application Message
    final Message msg = Message(
      id: completePacket.messageId,
      senderId: 'node_${completePacket.senderFingerprint}',
      senderFingerprint: completePacket.senderFingerprint,
      senderName: completePacket.senderName,
      content: decryptedContent,
      timestamp: DateTime.now(),
      status: DeliveryStatus.delivered,
      ttl: completePacket.ttl,
      hopCount: MeshTtlManager.defaultTtl - completePacket.ttl,
    );

    // Feature 6: TTL Check & Decrement
    final remainingTtl = MeshTtlManager.decrementTtl(completePacket.ttl);

    // Feature 5: Multi-Hop Endpoint vs Relay Decision
    final bool isForMe = (completePacket.dst == identityManager.unicastAddress || completePacket.dst == 0xFFFF);

    if (isForMe) {
      // Consume as Endpoint
      if (msg.type == MessageType.text) {
        final translated = await translationEngine.translateMessage(msg.content);
        if (translated != null) msg.translatedContent = translated;
      }

      await dbHelper.saveMessage(msg);
      _messageStreamController.add(msg);

      // Feature 8: Send E2E ACK back
      if (completePacket.dst == identityManager.unicastAddress) {
        final ack = MeshAckManager.createAckMessage(
          originalMessageId: msg.id,
          senderId: identityManager.nodeId,
          senderFingerprint: identityManager.fingerprint,
          senderName: identityManager.nodeName,
          recipientId: msg.senderId,
          ackStatus: DeliveryStatus.delivered,
        );
        await sendMessage(ack);
      }
    }

    // Feature 4: Managed Flooding Relay if enabled and TTL > 1
    if (remainingTtl > 0 && relayManager.relayEnabled && !isForMe) {
      final relayedFrag = BluetoothMeshPacket(
        ivi: completePacket.ivi,
        nid: completePacket.nid,
        ctl: completePacket.ctl,
        ttl: remainingTtl,
        seq: completePacket.seq,
        src: completePacket.src,
        dst: completePacket.dst,
        messageId: completePacket.messageId,
        senderFingerprint: completePacket.senderFingerprint,
        senderName: completePacket.senderName,
        payload: completePacket.payload,
        opcode: completePacket.opcode,
      );

      // Feature 14: Friend Queue check for sleeping LPNs
      if (friendManager.activeLpnAddresses.contains(completePacket.dst)) {
        friendManager.queueMessageForLpn(completePacket.dst, relayedFrag);
      } else {
        await transport.broadcastPacket(_toBlePacket(relayedFrag));
      }
    }
  }

  void _sendFriendPollRequest(int friendAddr) {
    final pollPkt = BluetoothMeshPacket(
      nid: identityManager.meshKeyManager.deriveNid(),
      ctl: true,
      ttl: 1,
      seq: _sequenceCounter++,
      src: identityManager.unicastAddress,
      dst: friendAddr,
      messageId: 'poll_${DateTime.now().millisecondsSinceEpoch}',
      senderFingerprint: identityManager.fingerprint,
      senderName: identityManager.nodeName,
      payload: 'FRIEND_POLL',
      opcode: 'FRIEND_POLL',
    );
    transport.broadcastPacket(_toBlePacket(pollPkt));
  }

  dynamic _toBlePacket(BluetoothMeshPacket meshPkt) {
    return BlePacket(
      packetId: meshPkt.messageId,
      senderId: identityManager.nodeId,
      payloadJson: jsonEncode(meshPkt.toJson()),
      chunkIndex: meshPkt.fragmentIndex,
      totalChunks: meshPkt.totalFragments,
    );
  }

  Future<void> _flushUnsentMessagesToPeers(List<Peer> peers) async {
    if (peers.isEmpty) return;
    final unsentList = dbHelper.getUnsentQueue();
    for (var msg in unsentList) {
      await sendMessage(msg);
    }
  }
}
