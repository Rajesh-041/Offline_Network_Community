import 'dart:convert';
import 'dart:typed_data';

/// Bluetooth Mesh 1.1 Network PDU & Application Message Header Specification.
class BluetoothMeshPacket {
  final int ivi;          // 1 bit: IV Index
  final int nid;          // 7 bits: Network ID
  final bool ctl;         // 1 bit: Control PDU flag (true for control/ack, false for access)
  final int ttl;          // 7 bits: Time To Live (max 126)
  final int seq;          // 24 bits: Sequence Number
  final int src;          // 16 bits: Source Unicast Address
  final int dst;          // 16 bits: Destination Address
  final String messageId;
  final String senderFingerprint;
  final String senderName;
  final String payload;
  final String opcode;
  final int segmentId;    // SAR Segment Identifier
  final int fragmentIndex;// 0 to totalFragments - 1
  final int totalFragments;

  BluetoothMeshPacket({
    this.ivi = 0,
    required this.nid,
    this.ctl = false,
    required this.ttl,
    required this.seq,
    required this.src,
    required this.dst,
    required this.messageId,
    required this.senderFingerprint,
    required this.senderName,
    required this.payload,
    this.opcode = 'GENERIC_TEXT',
    this.segmentId = 0,
    this.fragmentIndex = 0,
    this.totalFragments = 1,
  });

  Map<String, dynamic> toJson() => {
    'ivi': ivi,
    'nid': nid,
    'ctl': ctl,
    'ttl': ttl,
    'seq': seq,
    'src': src,
    'dst': dst,
    'msgId': messageId,
    'fp': senderFingerprint,
    'name': senderName,
    'p': payload,
    'op': opcode,
    'segId': segmentId,
    'fIdx': fragmentIndex,
    'tFrags': totalFragments,
  };

  factory BluetoothMeshPacket.fromJson(Map<String, dynamic> json) => BluetoothMeshPacket(
    ivi: json['ivi'] ?? 0,
    nid: json['nid'] ?? 1,
    ctl: json['ctl'] ?? false,
    ttl: json['ttl'] ?? 126,
    seq: json['seq'] ?? 0,
    src: json['src'] ?? 0x0001,
    dst: json['dst'] ?? 0xFFFF,
    messageId: json['msgId'],
    senderFingerprint: json['fp'],
    senderName: json['name'],
    payload: json['p'],
    opcode: json['op'] ?? 'GENERIC_TEXT',
    segmentId: json['segId'] ?? 0,
    fragmentIndex: json['fIdx'] ?? 0,
    totalFragments: json['tFrags'] ?? 1,
  );

  Uint8List toBytes() => Uint8List.fromList(utf8.encode(jsonEncode(toJson())));

  factory BluetoothMeshPacket.fromBytes(Uint8List bytes) {
    final str = utf8.decode(bytes);
    return BluetoothMeshPacket.fromJson(jsonDecode(str));
  }
}
