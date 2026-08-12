import 'dart:async';
import '../security/identity_manager.dart';
import 'neighbor_table.dart';
import 'topology_graph.dart';

class MeshTopologyManager {
  final IdentityManager identityManager;
  final NeighborTable neighborTable = NeighborTable();

  final _graphController = StreamController<TopologyGraph>.broadcast();
  Stream<TopologyGraph> get onTopologyUpdated => _graphController.stream;

  Timer? _pruneTimer;

  MeshTopologyManager({required this.identityManager}) {
    _startTopologyMonitor();
  }

  void _startTopologyMonitor() {
    _pruneTimer?.cancel();
    _pruneTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      neighborTable.cleanStaleNeighbors();
      _graphController.add(buildCurrentGraph());
    });
  }

  void updateNeighborLink({
    required int unicastAddress,
    required String peerId,
    required String peerName,
    required String fingerprint,
    required int rssi,
    required int hopCount,
    bool isRelay = true,
    bool isFriend = false,
    bool isLpn = false,
  }) {
    neighborTable.addOrUpdateNeighbor(NeighborEntry(
      unicastAddress: unicastAddress,
      peerId: peerId,
      peerName: peerName,
      fingerprint: fingerprint,
      rssi: rssi,
      lastSeen: DateTime.now(),
      hopCount: hopCount,
      isRelay: isRelay,
      isFriend: isFriend,
      isLpn: isLpn,
    ));

    _graphController.add(buildCurrentGraph());
  }

  TopologyGraph buildCurrentGraph() {
    final List<TopologyNode> nodes = [];
    final List<TopologyEdge> edges = [];

    // Local Node (V0)
    final localAddress = identityManager.unicastAddress;
    nodes.add(TopologyNode(
      unicastAddress: localAddress,
      nodeName: identityManager.nodeName,
      fingerprint: identityManager.fingerprint,
      isLocal: true,
    ));

    for (var neighbor in neighborTable.allNeighbors) {
      nodes.add(TopologyNode(
        unicastAddress: neighbor.unicastAddress,
        nodeName: neighbor.peerName,
        fingerprint: neighbor.fingerprint,
        isRelay: neighbor.isRelay,
        isFriend: neighbor.isFriend,
        isLpn: neighbor.isLpn,
      ));

      edges.add(TopologyEdge(
        sourceAddress: localAddress,
        targetAddress: neighbor.unicastAddress,
        rssi: neighbor.rssi,
        hopCount: neighbor.hopCount,
      ));
    }

    return TopologyGraph(nodes: nodes, edges: edges);
  }
}
