import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'models.dart';

/// Database Manager handling SQLite / local file state persistence, unsent queue, channels, and Panic Wipe.
class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  factory DatabaseHelper() => _instance;

  final Map<String, Message> _messages = {};
  final Map<String, Channel> _channels = {};
  final Map<String, Peer> _peers = {};
  final Set<String> _mutedPeerFingerprints = {};
  final Set<String> _kickedPeerFingerprints = {};
  final List<Message> _unsentQueue = [];

  DatabaseHelper._internal() {
    _seedDefaultChannels();
  }

  void _seedDefaultChannels() {
    _channels['public'] = Channel(
      id: 'public',
      name: 'Public Mesh',
      description: 'Default broadcast channel for all nearby BLE peers',
      isProtected: false,
      creatorFingerprint: 'SYSTEM',
      createdTime: DateTime.now().subtract(const Duration(days: 30)),
    );

    _channels['emergency'] = Channel(
      id: 'emergency',
      name: 'SOS Emergency Channel',
      description: 'High priority broadcast alerts and disaster response',
      isProtected: false,
      creatorFingerprint: 'SYSTEM',
      createdTime: DateTime.now().subtract(const Duration(days: 30)),
    );
  }

  // --- Messages ---
  Future<void> saveMessage(Message message) async {
    _messages[message.id] = message;
    if (message.status == DeliveryStatus.pending) {
      _unsentQueue.add(message);
    } else {
      _unsentQueue.removeWhere((m) => m.id == message.id);
    }
  }

  List<Message> getMessagesForChannel(String channelId) {
    final list = _messages.values.where((m) => m.channelId == channelId).toList();
    list.sort((a, b) => a.timestamp.compareTo(b.timestamp));
    return list;
  }

  List<Message> getDirectMessages(String peerId) {
    final list = _messages.values
        .where((m) => (m.senderId == peerId || m.recipientId == peerId) && m.channelId == null)
        .toList();
    list.sort((a, b) => a.timestamp.compareTo(b.timestamp));
    return list;
  }

  List<Message> getUnsentQueue() => List.unmodifiable(_unsentQueue);

  void updateMessageStatus(String messageId, DeliveryStatus status) {
    if (_messages.containsKey(messageId)) {
      _messages[messageId]!.status = status;
      if (status != DeliveryStatus.pending) {
        _unsentQueue.removeWhere((m) => m.id == messageId);
      }
    }
  }

  // --- Channels ---
  List<Channel> getAllChannels() => _channels.values.toList();

  Channel? getChannel(String id) => _channels[id];

  void saveChannel(Channel channel) {
    _channels[channel.id] = channel;
  }

  // --- Moderation ---
  void mutePeer(String fingerprint) {
    _mutedPeerFingerprints.add(fingerprint);
  }

  void kickPeer(String fingerprint) {
    _kickedPeerFingerprints.add(fingerprint);
  }

  bool isPeerMuted(String fingerprint) => _mutedPeerFingerprints.contains(fingerprint);
  bool isPeerKicked(String fingerprint) => _kickedPeerFingerprints.contains(fingerprint);

  // --- Panic Wipe Gesture ---
  Future<void> panicWipeAllData() async {
    _messages.clear();
    _channels.clear();
    _peers.clear();
    _mutedPeerFingerprints.clear();
    _kickedPeerFingerprints.clear();
    _unsentQueue.clear();
    _seedDefaultChannels();
  }

  // --- Export / Import JSON snapshot ---
  String exportEncryptedJson() {
    final exportData = {
      'version': 1,
      'exportedAt': DateTime.now().toIso8601String(),
      'messages': _messages.values.map((m) => m.toJson()).toList(),
      'channels': _channels.values.map((c) => c.toJson()).toList(),
      'muted': _mutedPeerFingerprints.toList(),
      'kicked': _kickedPeerFingerprints.toList(),
    };
    return jsonEncode(exportData);
  }

  void importJson(String jsonStr) {
    final Map<String, dynamic> data = jsonDecode(jsonStr);
    if (data.containsKey('messages')) {
      for (var item in data['messages']) {
        final m = Message.fromJson(item);
        _messages[m.id] = m;
      }
    }
    if (data.containsKey('channels')) {
      for (var item in data['channels']) {
        final c = Channel.fromJson(item);
        _channels[c.id] = c;
      }
    }
    if (data.containsKey('muted')) {
      _mutedPeerFingerprints.addAll(List<String>.from(data['muted']));
    }
    if (data.containsKey('kicked')) {
      _kickedPeerFingerprints.addAll(List<String>.from(data['kicked']));
    }
  }
}
