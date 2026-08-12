import 'neighbor_table.dart';

class TopologyNode {
  final int unicastAddress;
  final String nodeName;
  final String fingerprint;
  final bool isLocal;
  final bool isRelay;
  final bool isFriend;
  final bool isLpn;
  final int batteryLevel;

  TopologyNode({
    required this.unicastAddress,
    required this.nodeName,
    required this.fingerprint,
    this.isLocal = false,
    this.isRelay = true,
    this.isFriend = false,
    this.isLpn = false,
    this.batteryLevel = 85,
  });
}

class TopologyEdge {
  final int sourceAddress;
  final int targetAddress;
  final int rssi;
  final int hopCount;

  TopologyEdge({
    required this.sourceAddress,
    required this.targetAddress,
    required this.rssi,
    required this.hopCount,
  });
}

/// Mesh Topology Graph G = (V, E) representation.
class TopologyGraph {
  final List<TopologyNode> nodes;
  final List<TopologyEdge> edges;

  TopologyGraph({required this.nodes, required this.edges});
}
