import 'dart:async';
import '../data/database_helper.dart';
import '../data/models.dart';

/// Bluetooth Mesh 1.1 Store-and-Forward Engine.
/// Buffers offline pending messages in SQLite and flushes them when destinations return.
class StoreAndForwardEngine {
  final DatabaseHelper dbHelper;

  StoreAndForwardEngine({required this.dbHelper});

  Future<void> queuePendingMessage(Message msg) async {
    msg.status = DeliveryStatus.pending;
    await dbHelper.saveMessage(msg);
  }

  Future<List<Message>> getPendingMessagesForDestination(String destinationId) async {
    final unsent = dbHelper.getUnsentQueue();
    return unsent.where((m) => m.recipientId == destinationId || m.channelId != null).toList();
  }

  Future<void> markDelivered(String messageId) async {
    await dbHelper.updateMessageStatus(messageId, DeliveryStatus.delivered);
  }
}
