import 'dart:math';
import 'mesh_packet.dart';

/// Bluetooth Mesh 1.1 Segmentation (SAR) Fragmenter.
/// Splits large payloads into MTU-compliant fragments.
class MeshPacketFragmenter {
  static final _rand = Random();

  static List<BluetoothMeshPacket> fragmentPayload({
    required String messageId,
    required String senderFingerprint,
    required String senderName,
    required int nid,
    required int ttl,
    required int seq,
    required int src,
    required int dst,
    required String payload,
    String opcode = 'GENERIC_TEXT',
    int maxMtuPayloadSize = 180,
  }) {
    if (payload.length <= maxMtuPayloadSize) {
      return [
        BluetoothMeshPacket(
          nid: nid,
          ttl: ttl,
          seq: seq,
          src: src,
          dst: dst,
          messageId: messageId,
          senderFingerprint: senderFingerprint,
          senderName: senderName,
          payload: payload,
          opcode: opcode,
          segmentId: 0,
          fragmentIndex: 0,
          totalFragments: 1,
        ),
      ];
    }

    final int segmentId = _rand.nextInt(65535);
    final int totalFragments = (payload.length / maxMtuPayloadSize).ceil();
    final List<BluetoothMeshPacket> fragments = [];

    for (int i = 0; i < totalFragments; i++) {
      final start = i * maxMtuPayloadSize;
      final end = (start + maxMtuPayloadSize < payload.length) ? start + maxMtuPayloadSize : payload.length;
      final part = payload.substring(start, end);

      fragments.add(BluetoothMeshPacket(
        nid: nid,
        ttl: ttl,
        seq: seq + i,
        src: src,
        dst: dst,
        messageId: messageId,
        senderFingerprint: senderFingerprint,
        senderName: senderName,
        payload: part,
        opcode: opcode,
        segmentId: segmentId,
        fragmentIndex: i,
        totalFragments: totalFragments,
      ));
    }
    return fragments;
  }
}
