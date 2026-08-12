import 'dart:convert';
import 'dart:typed_data';

class BlePacket {
  final String packetId;
  final String senderId;
  final String payloadJson;
  final int chunkIndex;
  final int totalChunks;

  BlePacket({
    required this.packetId,
    required this.senderId,
    required this.payloadJson,
    this.chunkIndex = 0,
    this.totalChunks = 1,
  });

  Map<String, dynamic> toJson() => {
    'pId': packetId,
    'sId': senderId,
    'p': payloadJson,
    'cIdx': chunkIndex,
    'tChunks': totalChunks,
  };

  factory BlePacket.fromJson(Map<String, dynamic> json) => BlePacket(
    packetId: json['pId'],
    senderId: json['sId'],
    payloadJson: json['p'],
    chunkIndex: json['cIdx'] ?? 0,
    totalChunks: json['tChunks'] ?? 1,
  );

  Uint8List toBytes() {
    return Uint8List.fromList(utf8.encode(jsonEncode(toJson())));
  }

  factory BlePacket.fromBytes(Uint8List bytes) {
    final str = utf8.decode(bytes);
    return BlePacket.fromJson(jsonDecode(str));
  }

  /// Split long payload into smaller BLE MTU chunks (e.g. 128 bytes each)
  static List<BlePacket> chunkPayload(String packetId, String senderId, String payloadJson, {int chunkSize = 256}) {
    if (payloadJson.length <= chunkSize) {
      return [BlePacket(packetId: packetId, senderId: senderId, payloadJson: payloadJson, chunkIndex: 0, totalChunks: 1)];
    }

    final List<BlePacket> chunks = [];
    final int total = (payloadJson.length / chunkSize).ceil();
    for (int i = 0; i < total; i++) {
      final start = i * chunkSize;
      final end = (start + chunkSize < payloadJson.length) ? start + chunkSize : payloadJson.length;
      final part = payloadJson.substring(start, end);
      chunks.add(BlePacket(
        packetId: packetId,
        senderId: senderId,
        payloadJson: part,
        chunkIndex: i,
        totalChunks: total,
      ));
    }
    return chunks;
  }
}

/// Buffer for reassembling multi-chunk BLE packets
class BlePacketReassembler {
  final Map<String, Map<int, String>> _chunks = {};
  final Map<String, int> _totals = {};

  String? addChunk(BlePacket packet) {
    if (packet.totalChunks <= 1) {
      return packet.payloadJson;
    }

    _chunks.putIfAbsent(packet.packetId, () => {});
    _chunks[packet.packetId]![packet.chunkIndex] = packet.payloadJson;
    _totals[packet.packetId] = packet.totalChunks;

    final received = _chunks[packet.packetId]!;
    if (received.length == packet.totalChunks) {
      final buffer = StringBuffer();
      for (int i = 0; i < packet.totalChunks; i++) {
        buffer.write(received[i] ?? '');
      }
      _chunks.remove(packet.packetId);
      _totals.remove(packet.packetId);
      return buffer.toString();
    }
    return null; // incomplete
  }
}
