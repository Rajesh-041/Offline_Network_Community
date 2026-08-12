import 'dart:convert';
import '../data/models.dart';

enum AckLevel { hopAck, endToEndAck }

class PendingAckTracker {
  final String originalMessageId;
  final AckLevel level;
  final int sequenceNumber;
  final DateTime sentTime;
  int retryCount;

  PendingAckTracker({
    required this.originalMessageId,
    required this.level,
    required this.sequenceNumber,
    required this.sentTime,
    this.retryCount = 0,
  });
}

/// Bluetooth Mesh 1.1 Dual-Level ACK & Retransmission Manager.
class MeshAckManager {
  final Map<String, PendingAckTracker> _pendingAcks = {};
  final int retryLimit;
  final Duration ackTimeout;

  MeshAckManager({
    this.retryLimit = 3,
    this.ackTimeout = const Duration(milliseconds: 1500),
  });

  void trackPendingAck({
    required String originalMessageId,
    required AckLevel level,
    required int sequenceNumber,
  }) {
    _pendingAcks[originalMessageId] = PendingAckTracker(
      originalMessageId: originalMessageId,
      level: level,
      sequenceNumber: sequenceNumber,
      sentTime: DateTime.now(),
    );
  }

  void processAckReceived(String originalMessageId) {
    _pendingAcks.remove(originalMessageId);
  }

  List<PendingAckTracker> getTimedOutAcks() {
    final now = DateTime.now();
    final List<PendingAckTracker> timedOut = [];

    _pendingAcks.forEach((id, tracker) {
      if (now.difference(tracker.sentTime) > ackTimeout) {
        timedOut.add(tracker);
      }
    });

    return timedOut;
  }

  static Message createAckMessage({
    required String originalMessageId,
    required String senderId,
    required String senderFingerprint,
    required String senderName,
    required String recipientId,
    required DeliveryStatus ackStatus,
    AckLevel level = AckLevel.endToEndAck,
  }) {
    final payload = {
      'ackMsgId': originalMessageId,
      'ackStatus': ackStatus.name,
      'ackLevel': level.name,
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
}
