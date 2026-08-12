import 'dart:convert';
import '../data/models.dart';

class AckManager {
  /// Create an ACK control message packet for receipt tracking
  static Message createAckMessage({
    required String originalMessageId,
    required String senderId,
    required String senderFingerprint,
    required String senderName,
    required String recipientId,
    required DeliveryStatus ackStatus,
  }) {
    final payload = {
      'ackMsgId': originalMessageId,
      'ackStatus': ackStatus.name,
    };

    return Message(
      id: 'ack_${DateTime.now().microsecondsSinceEpoch}',
      senderId: senderId,
      senderFingerprint: senderFingerprint,
      senderName: senderName,
      recipientId: recipientId,
      content: jsonEncode(payload),
      timestamp: DateTime.now(),
      type: MessageType.ack,
      status: DeliveryStatus.sent,
      ttl: 5,
    );
  }

  /// Process incoming ACK packet and update local message status
  static bool processAckPacket(Message ackMsg, Function(String msgId, DeliveryStatus status) onUpdate) {
    try {
      final Map<String, dynamic> data = jsonDecode(ackMsg.content);
      final targetMsgId = data['ackMsgId'] as String;
      final statusStr = data['ackStatus'] as String;

      final status = DeliveryStatus.values.firstWhere(
        (e) => e.name == statusStr,
        orElse: () => DeliveryStatus.delivered,
      );

      onUpdate(targetMsgId, status);
      return true;
    } catch (e) {
      return false;
    }
  }
}
