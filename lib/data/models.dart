import 'dart:convert';
import 'dart:typed_data';

enum MessageType { text, voice, sos, control, ack, keyExchange }
enum DeliveryStatus { pending, sent, relayed, delivered, read }
enum ControlType { mutePeer, kickPeer, updateTopology }

class Peer {
  final String id;
  final String name;
  final String fingerprint;
  final String publicKeyHex;
  final int rssi;
  final int batteryLevel; // 0 to 100
  final DateTime lastSeen;
  final bool isDirect;
  final int hops;
  final double latencyMs;
  final double deliverySuccessRate;
  bool isMuted;
  bool isKicked;

  Peer({
    required this.id,
    required this.name,
    required this.fingerprint,
    required this.publicKeyHex,
    required this.rssi,
    required this.batteryLevel,
    required this.lastSeen,
    this.isDirect = true,
    this.hops = 1,
    this.latencyMs = 25.0,
    this.deliverySuccessRate = 0.98,
    this.isMuted = false,
    this.isKicked = false,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'fingerprint': fingerprint,
    'publicKeyHex': publicKeyHex,
    'rssi': rssi,
    'batteryLevel': batteryLevel,
    'lastSeen': lastSeen.toIso8601String(),
    'isDirect': isDirect,
    'hops': hops,
    'latencyMs': latencyMs,
    'deliverySuccessRate': deliverySuccessRate,
    'isMuted': isMuted,
    'isKicked': isKicked,
  };

  factory Peer.fromJson(Map<String, dynamic> json) => Peer(
    id: json['id'],
    name: json['name'],
    fingerprint: json['fingerprint'],
    publicKeyHex: json['publicKeyHex'],
    rssi: json['rssi'] ?? -65,
    batteryLevel: json['batteryLevel'] ?? 80,
    lastSeen: DateTime.parse(json['lastSeen']),
    isDirect: json['isDirect'] ?? true,
    hops: json['hops'] ?? 1,
    latencyMs: (json['latencyMs'] as num?)?.toDouble() ?? 25.0,
    deliverySuccessRate: (json['deliverySuccessRate'] as num?)?.toDouble() ?? 0.98,
    isMuted: json['isMuted'] ?? false,
    isKicked: json['isKicked'] ?? false,
  );
}

class Channel {
  final String id;
  final String name;
  final String description;
  final bool isProtected;
  final String? passwordHash;
  final String creatorFingerprint;
  final DateTime createdTime;
  bool isMuted;

  Channel({
    required this.id,
    required this.name,
    required this.description,
    this.isProtected = false,
    this.passwordHash,
    required this.creatorFingerprint,
    required this.createdTime,
    this.isMuted = false,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'description': description,
    'isProtected': isProtected,
    'passwordHash': passwordHash,
    'creatorFingerprint': creatorFingerprint,
    'createdTime': createdTime.toIso8601String(),
    'isMuted': isMuted,
  };

  factory Channel.fromJson(Map<String, dynamic> json) => Channel(
    id: json['id'],
    name: json['name'],
    description: json['description'],
    isProtected: json['isProtected'] ?? false,
    passwordHash: json['passwordHash'],
    creatorFingerprint: json['creatorFingerprint'],
    createdTime: DateTime.parse(json['createdTime']),
    isMuted: json['isMuted'] ?? false,
  );
}

class Message {
  final String id;
  final String senderId;
  final String senderFingerprint;
  final String senderName;
  final String? recipientId; // null if broadcast/channel
  final String? channelId;   // null if 1:1 direct
  final String content;
  final DateTime timestamp;
  final MessageType type;
  DeliveryStatus status;
  final int ttl;
  int hopCount;
  final bool isEncrypted;
  final List<String> relayPath; // node IDs visited
  final Uint8List? voiceBytes;
  final int? voiceDurationMs;
  String? translatedContent;

  Message({
    required this.id,
    required this.senderId,
    required this.senderFingerprint,
    required this.senderName,
    this.recipientId,
    this.channelId,
    required this.content,
    required this.timestamp,
    this.type = MessageType.text,
    this.status = DeliveryStatus.pending,
    this.ttl = 7,
    this.hopCount = 0,
    this.isEncrypted = false,
    List<String>? relayPath,
    this.voiceBytes,
    this.voiceDurationMs,
    this.translatedContent,
  }) : relayPath = relayPath ?? [senderId];

  Map<String, dynamic> toJson() => {
    'id': id,
    'senderId': senderId,
    'senderFingerprint': senderFingerprint,
    'senderName': senderName,
    'recipientId': recipientId,
    'channelId': channelId,
    'content': content,
    'timestamp': timestamp.toIso8601String(),
    'type': type.name,
    'status': status.name,
    'ttl': ttl,
    'hopCount': hopCount,
    'isEncrypted': isEncrypted,
    'relayPath': relayPath,
    'voiceBytes': voiceBytes != null ? base64Encode(voiceBytes!) : null,
    'voiceDurationMs': voiceDurationMs,
    'translatedContent': translatedContent,
  };

  /// SQLite compatible Map conversion (booleans -> 1/0, List<String> -> JSON string)
  Map<String, dynamic> toDbMap() => {
    'id': id,
    'senderId': senderId,
    'senderFingerprint': senderFingerprint,
    'senderName': senderName,
    'recipientId': recipientId,
    'channelId': channelId,
    'content': content,
    'timestamp': timestamp.toIso8601String(),
    'type': type.name,
    'status': status.name,
    'ttl': ttl,
    'hopCount': hopCount,
    'isEncrypted': isEncrypted ? 1 : 0,
    'relayPath': jsonEncode(relayPath),
    'voiceBytes': voiceBytes != null ? base64Encode(voiceBytes!) : null,
    'voiceDurationMs': voiceDurationMs,
    'translatedContent': translatedContent,
  };

  factory Message.fromJson(Map<String, dynamic> json) {
    dynamic rawRelay = json['relayPath'];
    List<String> pathList = [];
    if (rawRelay is String) {
      try {
        pathList = List<String>.from(jsonDecode(rawRelay));
      } catch (e) {
        pathList = [json['senderId'] ?? ''];
      }
    } else if (rawRelay is List) {
      pathList = List<String>.from(rawRelay);
    }

    dynamic rawEncrypted = json['isEncrypted'];
    bool encryptedBool = false;
    if (rawEncrypted is bool) {
      encryptedBool = rawEncrypted;
    } else if (rawEncrypted is int) {
      encryptedBool = rawEncrypted == 1;
    }

    return Message(
      id: json['id'],
      senderId: json['senderId'],
      senderFingerprint: json['senderFingerprint'],
      senderName: json['senderName'],
      recipientId: json['recipientId'],
      channelId: json['channelId'],
      content: json['content'],
      timestamp: DateTime.parse(json['timestamp']),
      type: MessageType.values.firstWhere((e) => e.name == json['type'], orElse: () => MessageType.text),
      status: DeliveryStatus.values.firstWhere((e) => e.name == json['status'], orElse: () => DeliveryStatus.sent),
      ttl: json['ttl'] ?? 7,
      hopCount: json['hopCount'] ?? 0,
      isEncrypted: encryptedBool,
      relayPath: pathList,
      voiceBytes: json['voiceBytes'] != null ? base64Decode(json['voiceBytes']) : null,
      voiceDurationMs: json['voiceDurationMs'],
      translatedContent: json['translatedContent'],
    );
  }

  Message copyWith({DeliveryStatus? status, int? hopCount, List<String>? relayPath, String? translatedContent}) {
    return Message(
      id: id,
      senderId: senderId,
      senderFingerprint: senderFingerprint,
      senderName: senderName,
      recipientId: recipientId,
      channelId: channelId,
      content: content,
      timestamp: timestamp,
      type: type,
      status: status ?? this.status,
      ttl: ttl,
      hopCount: hopCount ?? this.hopCount,
      isEncrypted: isEncrypted,
      relayPath: relayPath ?? this.relayPath,
      voiceBytes: voiceBytes,
      voiceDurationMs: voiceDurationMs,
      translatedContent: translatedContent ?? this.translatedContent,
    );
  }
}

class ControlPacket {
  final ControlType type;
  final String targetFingerprint;
  final String channelId;
  final String issuerFingerprint;
  final String signature;

  ControlPacket({
    required this.type,
    required this.targetFingerprint,
    required this.channelId,
    required this.issuerFingerprint,
    required this.signature,
  });

  Map<String, dynamic> toJson() => {
    'type': type.name,
    'targetFingerprint': targetFingerprint,
    'channelId': channelId,
    'issuerFingerprint': issuerFingerprint,
    'signature': signature,
  };

  factory ControlPacket.fromJson(Map<String, dynamic> json) => ControlPacket(
    type: ControlType.values.firstWhere((e) => e.name == json['type']),
    targetFingerprint: json['targetFingerprint'],
    channelId: json['channelId'],
    issuerFingerprint: json['issuerFingerprint'],
    signature: json['signature'],
  );
}
