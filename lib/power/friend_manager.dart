import 'dart:collection';
import '../packet/mesh_packet.dart';

class FriendshipSession {
  final int lpnAddress;
  final int pollTimeoutMs;
  final DateTime establishedTime;
  final Queue<BluetoothMeshPacket> friendQueue = Queue();

  FriendshipSession({
    required this.lpnAddress,
    required this.pollTimeoutMs,
    required this.establishedTime,
  });
}

/// Bluetooth Mesh 1.1 Friend Feature Manager.
/// Stores network messages in FriendQueue for associated Low Power Nodes (LPNs).
class FriendNodeManager {
  final Map<int, FriendshipSession> _friendships = {};
  bool _isFriendFeatureEnabled = true;

  bool get isFriendFeatureEnabled => _isFriendFeatureEnabled;

  void toggleFriendFeature(bool enabled) {
    _isFriendFeatureEnabled = enabled;
    if (!enabled) _friendships.clear();
  }

  /// Establish Friendship with a Low Power Node (LPN)
  void establishFriendship(int lpnAddress, {int pollTimeoutMs = 30000}) {
    if (!_isFriendFeatureEnabled) return;
    _friendships[lpnAddress] = FriendshipSession(
      lpnAddress: lpnAddress,
      pollTimeoutMs: pollTimeoutMs,
      establishedTime: DateTime.now(),
    );
  }

  /// Store message destined for LPN in FriendQueue
  bool queueMessageForLpn(int lpnAddress, BluetoothMeshPacket packet) {
    if (_friendships.containsKey(lpnAddress)) {
      final session = _friendships[lpnAddress]!;
      session.friendQueue.add(packet);
      if (session.friendQueue.length > 100) {
        session.friendQueue.removeFirst(); // Cap queue size at 100
      }
      return true;
    }
    return false;
  }

  /// Respond to LPN FriendPoll request & flush queued messages
  List<BluetoothMeshPacket> pollFriendQueue(int lpnAddress) {
    if (_friendships.containsKey(lpnAddress)) {
      final session = _friendships[lpnAddress]!;
      final list = session.friendQueue.toList();
      session.friendQueue.clear();
      return list;
    }
    return [];
  }

  List<int> get activeLpnAddresses => _friendships.keys.toList();
}
