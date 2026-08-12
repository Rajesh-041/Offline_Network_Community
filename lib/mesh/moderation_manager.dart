import 'dart:convert';
import '../crypto/crypto_engine.dart';
import '../data/database_helper.dart';
import '../data/models.dart';

class ModerationManager {
  final DatabaseHelper dbHelper;

  ModerationManager({required this.dbHelper});

  /// Create a signed moderation control packet (Mute or Kick peer)
  ControlPacket createModerationPacket({
    required ControlType type,
    required String targetFingerprint,
    required String channelId,
    required String issuerFingerprint,
    required Uint8List issuerPrivateKey,
  }) {
    final payloadToSign = '${type.name}:$targetFingerprint:$channelId:$issuerFingerprint';
    final signature = CryptoEngine.signPayload(payloadToSign, issuerPrivateKey);

    return ControlPacket(
      type: type,
      targetFingerprint: targetFingerprint,
      channelId: channelId,
      issuerFingerprint: issuerFingerprint,
      signature: signature,
    );
  }

  /// Process incoming moderation packet from mesh
  bool handleIncomingControlPacket(ControlPacket packet, String issuerPublicKeyHex) {
    final payloadToVerify = '${packet.type.name}:${packet.targetFingerprint}:${packet.channelId}:${packet.issuerFingerprint}';
    final isValid = CryptoEngine.verifySignature(payloadToVerify, packet.signature, issuerPublicKeyHex);

    if (!isValid) {
      return false; // reject fake / forged moderation control packet
    }

    if (packet.type == ControlType.mutePeer) {
      dbHelper.mutePeer(packet.targetFingerprint);
    } else if (packet.type == ControlType.kickPeer) {
      dbHelper.kickPeer(packet.targetFingerprint);
    }

    return true;
  }
}
