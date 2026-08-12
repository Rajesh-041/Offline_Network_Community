import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import '../data/models.dart';
import '../crypto/identity_manager.dart';
import 'ble_packet.dart';
import 'ble_transport.dart';

class SimulatedPeerNode {
  final String id;
  final String name;
  final String fingerprint;
  final String publicKeyHex;
  int rssi;
  int batteryLevel;
  int hops;
  bool isOnline;
  double positionX; // for force-directed map
  double positionY;

  SimulatedPeerNode({
    required this.id,
    required this.name,
    required this.fingerprint,
    required this.publicKeyHex,
    required this.rssi,
    required this.batteryLevel,
    this.hops = 1,
    this.isOnline = true,
    this.positionX = 0.0,
    this.positionY = 0.0,
  });

  Peer toPeer() => Peer(
    id: id,
    name: name,
    fingerprint: fingerprint,
    publicKeyHex: publicKeyHex,
    rssi: rssi,
    batteryLevel: batteryLevel,
    lastSeen: DateTime.now(),
    isDirect: hops == 1,
    hops: hops,
    latencyMs: (15.0 + hops * 12.0) + (Random().nextDouble() * 5.0),
    deliverySuccessRate: max(0.60, 0.99 - (hops * 0.08)),
  );
}

class BleSimulationEngine implements IBleTransport {
  final IdentityManager identityManager;
  final _packetController = StreamController<BlePacket>.broadcast();
  final _peersController = StreamController<List<Peer>>.broadcast();

  bool _isScanning = false;
  bool _isAdvertising = false;
  int _batteryLevel = 85;
  int _batteryThreshold = 20;
  Timer? _discoveryTimer;
  Timer? _rssiFlaggerTimer;

  final Map<String, SimulatedPeerNode> _meshNodes = {};

  BleSimulationEngine({required this.identityManager}) {
    _seedDefaultMeshNodes();
  }

  void _seedDefaultMeshNodes() {
    _meshNodes['peer_alpha'] = SimulatedPeerNode(
      id: 'peer_alpha',
      name: 'Echo-Alpha',
      fingerprint: 'A1B2C3D4',
      publicKeyHex: 'pubkey_alpha_998877665544332211',
      rssi: -52,
      batteryLevel: 92,
      hops: 1,
      positionX: -120.0,
      positionY: -80.0,
    );

    _meshNodes['peer_beta'] = SimulatedPeerNode(
      id: 'peer_beta',
      name: 'Vortex-Beta',
      fingerprint: 'E5F67890',
      publicKeyHex: 'pubkey_beta_112233445566778899',
      rssi: -68,
      batteryLevel: 74,
      hops: 1,
      positionX: 110.0,
      positionY: -90.0,
    );

    _meshNodes['peer_gamma'] = SimulatedPeerNode(
      id: 'peer_gamma',
      name: 'Relay-Gamma',
      fingerprint: '11223344',
      publicKeyHex: 'pubkey_gamma_aabbccddeeff001122',
      rssi: -81,
      batteryLevel: 45,
      hops: 2,
      positionX: -40.0,
      positionY: 130.0,
    );

    _meshNodes['peer_delta'] = SimulatedPeerNode(
      id: 'peer_delta',
      name: 'Outpost-Delta',
      fingerprint: '99887766',
      publicKeyHex: 'pubkey_delta_ffeeddccbbaa998877',
      rssi: -89,
      batteryLevel: 18,
      hops: 3,
      positionX: 130.0,
      positionY: 110.0,
    );
  }

  @override
  Stream<BlePacket> get onPacketReceived => _packetController.stream;

  @override
  Stream<List<Peer>> get onPeersUpdated => _peersController.stream;

  @override
  bool get isScanning => _isScanning;

  @override
  bool get isAdvertising => _isAdvertising;

  @override
  int get batteryThresholdPercentage => _batteryThreshold;

  @override
  bool get isDutyCyclingActive => _batteryLevel < _batteryThreshold;

  @override
  Future<void> startScanAndAdvertise() async {
    _isScanning = true;
    _isAdvertising = true;
    _startPeerDiscoveryLoop();
    _startRssiJitterLoop();
  }

  @override
  Future<void> stopScanAndAdvertise() async {
    _isScanning = false;
    _isAdvertising = false;
    _discoveryTimer?.cancel();
    _rssiFlaggerTimer?.cancel();
  }

  void _startPeerDiscoveryLoop() {
    _discoveryTimer?.cancel();
    final intervalMs = isDutyCyclingActive ? 5000 : 1500;
    _discoveryTimer = Timer.periodic(Duration(milliseconds: intervalMs), (_) {
      if (!_isScanning) return;
      final activePeers = _meshNodes.values
          .where((n) => n.isOnline)
          .map((n) => n.toPeer())
          .toList();
      _peersController.add(activePeers);
    });
  }

  void _startRssiJitterLoop() {
    _rssiFlaggerTimer?.cancel();
    final rand = Random();
    _rssiFlaggerTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      for (var node in _meshNodes.values) {
        final delta = rand.nextInt(7) - 3;
        node.rssi = (node.rssi + delta).clamp(-95, -40);
      }
    });
  }

  @override
  Future<void> broadcastPacket(BlePacket packet) async {
    // Inject packet into local simulation pipeline with small propagation delay
    Future.delayed(const Duration(milliseconds: 120), () {
      _packetController.add(packet);
    });
  }

  @override
  Future<void> sendDirectPacket(String targetPeerId, BlePacket packet) async {
    Future.delayed(const Duration(milliseconds: 80), () {
      _packetController.add(packet);
    });
  }

  @override
  void setBatteryLevel(int levelPercentage) {
    _batteryLevel = levelPercentage.clamp(0, 100);
    if (_isScanning) {
      _startPeerDiscoveryLoop(); // refresh duty cycling
    }
  }

  @override
  void setBatteryThreshold(int threshold) {
    _batteryThreshold = threshold.clamp(5, 50);
  }

  void injectPeer(SimulatedPeerNode node) {
    _meshNodes[node.id] = node;
    _peersController.add(_meshNodes.values.map((n) => n.toPeer()).toList());
  }

  void removePeer(String nodeId) {
    _meshNodes.remove(nodeId);
    _peersController.add(_meshNodes.values.map((n) => n.toPeer()).toList());
  }

  List<SimulatedPeerNode> get rawSimulatedNodes => _meshNodes.values.toList();
}
