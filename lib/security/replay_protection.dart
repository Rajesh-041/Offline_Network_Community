import 'dart:collection';

/// Bluetooth Mesh 1.1 Replay Protection List (RPL) Manager.
/// Tracks sequence numbers per source Unicast Address to reject replayed packets.
class ReplayProtectionList {
  final Map<int, int> _highestSequenceNumber = {};
  final Map<int, DateTime> _lastSeenTimestamp = {};

  /// Check if incoming packet sequence number is a replay attack
  bool isReplayAttack(int srcAddress, int sequenceNumber) {
    if (!_highestSequenceNumber.containsKey(srcAddress)) {
      return false; // New source address
    }

    final highest = _highestSequenceNumber[srcAddress]!;
    if (sequenceNumber <= highest) {
      return true; // Replay attack detected! Sequence number is <= previously seen sequence
    }
    return false;
  }

  /// Update sequence number tracking for verified valid packet
  void updateSequence(int srcAddress, int sequenceNumber) {
    _highestSequenceNumber[srcAddress] = sequenceNumber;
    _lastSeenTimestamp[srcAddress] = DateTime.now();
  }

  int? getHighestSequence(int srcAddress) => _highestSequenceNumber[srcAddress];

  void clearReplayList() {
    _highestSequenceNumber.clear();
    _lastSeenTimestamp.clear();
  }
}
