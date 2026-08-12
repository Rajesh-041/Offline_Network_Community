import 'dart:math';
import 'package:flutter/material.dart';
import '../../ble/ble_simulation.dart';
import '../../data/models.dart';

class MeshMapScreen extends StatefulWidget {
  final List<Peer> activePeers;
  final String localNodeId;
  final BleSimulationEngine simulationEngine;

  const MeshMapScreen({
    super.key,
    required this.activePeers,
    required this.localNodeId,
    required this.simulationEngine,
  });

  @override
  State<MeshMapScreen> createState() => _MeshMapScreenState();
}

class _MeshMapScreenState extends State<MeshMapScreen> with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  void _addSimulatedNode() {
    final rand = Random();
    final id = 'peer_node_${DateTime.now().millisecondsSinceEpoch % 10000}';
    final newNode = SimulatedPeerNode(
      id: id,
      name: 'Peer-${id.substring(10)}',
      fingerprint: id.substring(10).toUpperCase(),
      publicKeyHex: 'pubkey_$id',
      rssi: -55 - rand.nextInt(35),
      batteryLevel: 40 + rand.nextInt(55),
      hops: rand.nextInt(2) + 1,
      positionX: (rand.nextDouble() * 220) - 110,
      positionY: (rand.nextDouble() * 220) - 110,
    );
    widget.simulationEngine.injectPeer(newNode);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Simulated mesh node added: ${newNode.name}')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.map_rounded, color: Color(0xFF6366F1)),
            SizedBox(width: 8),
            Text('Mesh Topology Visualizer'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_location_alt_rounded),
            tooltip: 'Simulate Nearby Node',
            onPressed: _addSimulatedNode,
          ),
        ],
      ),
      body: Column(
        children: [
          // Topology Map canvas
          Expanded(
            child: Container(
              margin: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.grey.withOpacity(0.2)),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: AnimatedBuilder(
                  animation: _pulseController,
                  builder: (context, child) {
                    return CustomPaint(
                      painter: MeshGraphPainter(
                        peers: widget.activePeers,
                        localNodeId: widget.localNodeId,
                        pulseValue: _pulseController.value,
                      ),
                      child: Container(),
                    );
                  },
                ),
              ),
            ),
          ),
          // Topology statistics legend card
          Card(
            margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildLegendItem(Icons.sensors, 'Active Peers', '${widget.activePeers.length + 1}'),
                  _buildLegendItem(Icons.alt_route, 'Max Hops', '3 Hops'),
                  _buildLegendItem(Icons.bluetooth, 'Link Protocol', 'BLE Mesh'),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLegendItem(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 18, color: const Color(0xFF6366F1)),
        const SizedBox(width: 6),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
            Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
          ],
        ),
      ],
    );
  }
}

class MeshGraphPainter extends CustomPainter {
  final List<Peer> peers;
  final String localNodeId;
  final double pulseValue;

  MeshGraphPainter({
    required this.peers,
    required this.localNodeId,
    required this.pulseValue,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final paintLine = Paint()..strokeWidth = 2.0;

    // Fixed radial positioning for peers relative to central node
    final Map<String, Offset> nodePositions = {};
    nodePositions[localNodeId] = center;

    final double radiusStep = min(size.width, size.height) * 0.35;
    for (int i = 0; i < peers.length; i++) {
      final angle = (2 * pi * i / peers.length) - (pi / 2);
      final peer = peers[i];
      final distance = radiusStep * (peer.hops == 1 ? 0.8 : 1.3);
      final offset = Offset(
        center.dx + distance * cos(angle),
        center.dy + distance * sin(angle),
      );
      nodePositions[peer.id] = offset;
    }

    // 1. Draw connection lines and pulse traffic
    for (var peer in peers) {
      final pos = nodePositions[peer.id] ?? center;
      final targetPos = peer.hops == 1 ? center : nodePositions.values.elementAt(1);

      Color lineColor = Colors.greenAccent;
      if (peer.rssi < -80) {
        lineColor = Colors.orangeAccent;
      } else if (peer.rssi < -87) {
        lineColor = Colors.redAccent;
      }

      paintLine.color = lineColor.withOpacity(0.5);
      canvas.drawLine(targetPos, pos, paintLine);

      // Pulse particle along link line
      final pulseDx = targetPos.dx + (pos.dx - targetPos.dx) * pulseValue;
      final pulseDy = targetPos.dy + (pos.dy - targetPos.dy) * pulseValue;
      canvas.drawCircle(Offset(pulseDx, pulseDy), 4, Paint()..color = lineColor);
    }

    // 2. Draw Local Node (Center)
    final localPaint = Paint()..color = const Color(0xFF6366F1);
    canvas.drawCircle(center, 24, localPaint);
    canvas.drawCircle(center, 24 + (pulseValue * 12), Paint()..color = const Color(0xFF6366F1).withOpacity(1.0 - pulseValue)..style = PaintingStyle.stroke..strokeWidth = 2);

    final textPainter = TextPainter(
      text: const TextSpan(
        text: 'YOU',
        style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    textPainter.paint(canvas, center - Offset(textPainter.width / 2, textPainter.height / 2));

    // 3. Draw Peer Nodes
    for (var peer in peers) {
      final pos = nodePositions[peer.id]!;
      final peerPaint = Paint()..color = peer.isDirect ? const Color(0xFF10B981) : const Color(0xFFF59E0B);
      canvas.drawCircle(pos, 18, peerPaint);

      final pPainter = TextPainter(
        text: TextSpan(
          text: peer.fingerprint.substring(0, 4),
          style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      pPainter.paint(canvas, pos - Offset(pPainter.width / 2, pPainter.height / 2));

      // Label below node
      final labelPainter = TextPainter(
        text: TextSpan(
          text: '${peer.name}\n${peer.rssi}dBm | ${peer.batteryLevel}%',
          style: const TextStyle(color: Colors.grey, fontSize: 9),
        ),
        textAlign: TextAlign.center,
        textDirection: TextDirection.ltr,
      )..layout();
      labelPainter.paint(canvas, pos + Offset(-labelPainter.width / 2, 20));
    }
  }

  @override
  bool shouldRepaint(covariant MeshGraphPainter oldDelegate) => true;
}
