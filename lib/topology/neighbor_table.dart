import 'dart:collection';

class NeighborEntry {
  final int unicastAddress;
  final String peerId;
  final String peerName;
  final String fingerprint;
  int rssi;
  DateTime lastSeen;
  int hopCount;
  bool isRelay;
  bool isFriend;
  bool isLpn;

  NeighborEntry({
    required this.unicastAddress,
    required this.peerId,
    required this.peerName,
    required this.fingerprint,
    required this.rssi,
    required this.lastSeen,
    required this.hopCount,
    this.isRelay = true,
    this.isFriend = false,
    this.isLpn = false,
  });
}

class NeighborTable {
  final Map<int, NeighborEntry> _neighbors = {};

  void addOrUpdateNeighbor(NeighborEntry entry) {
    _neighbors[entry.unicastAddress] = entry;
  }

  void removeNeighbor(int unicastAddress) {
    _neighbors.remove(unicastAddress);
  }

  NeighborEntry? getNeighbor(int address) => _neighbors[address];

  List<NeighborEntry> get allNeighbors => _neighbors.values.toList();

  void cleanStaleNeighbors({Duration maxAge = const Duration(seconds: 45)}) {
    final now = DateTime.now();
    _neighbors.removeWhere((_, entry) => now.difference(entry.lastSeen) > maxAge);
  }
}
