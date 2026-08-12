import 'dart:async';
import '../data/models.dart';

enum PartitionState { connected, partitioned, synchronizing }

/// Network Partition & Reconnection Synchronization Manager.
/// Handles network splits, state detection, and message inventory synchronization.
class NetworkPartitionManager {
  PartitionState _state = PartitionState.connected;
  final List<String> _partitionedPeerIds = [];

  final _stateController = StreamController<PartitionState>.broadcast();
  Stream<PartitionState> get onStateChanged => _stateController.stream;

  PartitionState get state => _state;

  void detectPeerDisappearance(String peerId) {
    if (!_partitionedPeerIds.contains(peerId)) {
      _partitionedPeerIds.add(peerId);
      _state = PartitionState.partitioned;
      _stateController.add(_state);
    }
  }

  void detectPeerReappearance(String peerId, Function(String peerId) onSynchronizeInventory) {
    if (_partitionedPeerIds.contains(peerId)) {
      _partitionedPeerIds.remove(peerId);
      _state = PartitionState.synchronizing;
      _stateController.add(_state);

      // Perform Inventory Exchange Synchronization
      onSynchronizeInventory(peerId);

      _state = PartitionState.connected;
      _stateController.add(_state);
    }
  }
}
