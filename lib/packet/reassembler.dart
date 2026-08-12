import 'dart:async';
import 'mesh_packet.dart';

class _ReassemblyBuffer {
  final Map<int, String> fragments = {};
  final int totalFragments;
  final DateTime startTime;

  _ReassemblyBuffer({required this.totalFragments}) : startTime = DateTime.now();
}

/// Bluetooth Mesh 1.1 SAR Reassembly Engine.
/// Reconstructs fragmented network packets and enforces reassembly timeouts.
class MeshPacketReassembler {
  final Map<String, _ReassemblyBuffer> _buffers = {};
  final Duration reassemblyTimeout;
  final int maxFragments;

  MeshPacketReassembler({
    this.reassemblyTimeout = const Duration(seconds: 10),
    this.maxFragments = 64,
  });

  BluetoothMeshPacket? addFragment(BluetoothMeshPacket fragment) {
    if (fragment.totalFragments <= 1) {
      return fragment; // Single unfragmented packet
    }

    if (fragment.totalFragments > maxFragments) {
      return null; // Reject resource abuse / oversized fragment count
    }

    final key = '${fragment.messageId}_${fragment.segmentId}';
    _cleanExpiredBuffers();

    _buffers.putIfAbsent(key, () => _ReassemblyBuffer(totalFragments: fragment.totalFragments));
    final buf = _buffers[key]!;
    buf.fragments[fragment.fragmentIndex] = fragment.payload;

    if (buf.fragments.length == fragment.totalFragments) {
      final buffer = StringBuffer();
      for (int i = 0; i < fragment.totalFragments; i++) {
        buffer.write(buf.fragments[i] ?? '');
      }
      _buffers.remove(key);

      return BluetoothMeshPacket(
        ivi: fragment.ivi,
        nid: fragment.nid,
        ctl: fragment.ctl,
        ttl: fragment.ttl,
        seq: fragment.seq,
        src: fragment.src,
        dst: fragment.dst,
        messageId: fragment.messageId,
        senderFingerprint: fragment.senderFingerprint,
        senderName: fragment.senderName,
        payload: buffer.toString(),
        opcode: fragment.opcode,
        segmentId: fragment.segmentId,
        fragmentIndex: 0,
        totalFragments: 1,
      );
    }

    return null; // Awaiting remaining fragments
  }

  void _cleanExpiredBuffers() {
    final now = DateTime.now();
    _buffers.removeWhere((key, buf) => now.difference(buf.startTime) > reassemblyTimeout);
  }
}
