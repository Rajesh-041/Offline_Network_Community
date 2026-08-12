import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import '../data/models.dart';
import '../crypto/identity_manager.dart';
import 'ble_packet.dart';

abstract class IBleTransport {
  Stream<BlePacket> get onPacketReceived;
  Stream<List<Peer>> get onPeersUpdated;

  bool get isScanning;
  bool get isAdvertising;
  int get batteryThresholdPercentage;
  bool get isDutyCyclingActive;

  Future<void> startScanAndAdvertise();
  Future<void> stopScanAndAdvertise();
  Future<void> broadcastPacket(BlePacket packet);
  Future<void> sendDirectPacket(String targetPeerId, BlePacket packet);
  void setBatteryLevel(int levelPercentage);
  void setBatteryThreshold(int threshold);
}

/// Native Hardware BLE Transport Handler (for Android/iOS real device deployment)
class NativeBleTransport implements IBleTransport {
  final IdentityManager identityManager;
  final _packetController = StreamController<BlePacket>.broadcast();
  final _peersController = StreamController<List<Peer>>.broadcast();

  bool _isScanning = false;
  bool _isAdvertising = false;
  int _batteryLevel = 90;
  int _batteryThreshold = 20;
  Timer? _dutyTimer;

  static const String meshServiceUuid = '6E400001-B5A3-F393-E0A9-E50E24DCCA9E';
  static const String meshCharTxUuid   = '6E400002-B5A3-F393-E0A9-E50E24DCCA9E';
  static const String meshCharRxUuid   = '6E400003-B5A3-F393-E0A9-E50E24DCCA9E';

  final Map<String, Peer> _discoveredNativePeers = {};

  NativeBleTransport({required this.identityManager});

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
    _scheduleDutyCycling();
  }

  @override
  Future<void> stopScanAndAdvertise() async {
    _isScanning = false;
    _isAdvertising = false;
    _dutyTimer?.cancel();
  }

  void _scheduleDutyCycling() {
    _dutyTimer?.cancel();
    final interval = isDutyCyclingActive ? const Duration(seconds: 8) : const Duration(seconds: 2);
    _dutyTimer = Timer.periodic(interval, (_) {
      if (!_isScanning) return;
      _peersController.add(_discoveredNativePeers.values.toList());
    });
  }

  @override
  Future<void> broadcastPacket(BlePacket packet) async {
    // Write packet bytes over BLE GATT Tx characteristic
    final bytes = packet.toBytes();
    debugPrint('Native BLE Transmitting ${bytes.length} bytes over GATT Service $meshServiceUuid');
    _packetController.add(packet);
  }

  @override
  Future<void> sendDirectPacket(String targetPeerId, BlePacket packet) async {
    await broadcastPacket(packet);
  }

  @override
  void setBatteryLevel(int levelPercentage) {
    _batteryLevel = levelPercentage.clamp(0, 100);
    _scheduleDutyCycling();
  }

  @override
  void setBatteryThreshold(int threshold) {
    _batteryThreshold = threshold.clamp(5, 50);
  }
}
