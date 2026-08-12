import 'dart:async';
import 'package:flutter/foundation.dart';
import '../data/models.dart';

class BleScanningManager {
  bool _isScanning = false;
  final _discoveredStreamController = StreamController<Peer>.broadcast();

  bool get isScanning => _isScanning;
  Stream<Peer> get onPeerDiscovered => _discoveredStreamController.stream;

  Future<void> startScanning({required String serviceUuid}) async {
    _isScanning = true;
    debugPrint('BLE Scanning Bearer Started for Service $serviceUuid');
  }

  Future<void> stopScanning() async {
    _isScanning = false;
    debugPrint('BLE Scanning Bearer Stopped.');
  }

  void injectDiscoveredPeer(Peer peer) {
    _discoveredStreamController.add(peer);
  }
}
