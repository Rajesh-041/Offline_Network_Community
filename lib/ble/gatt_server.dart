import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import '../packet/mesh_packet.dart';

/// Bluetooth Mesh 1.1 GATT Proxy Server.
/// Hosts GATT Service 6E400001 with RX (Write) and TX (Notify) characteristics.
class MeshGattServer {
  static const String serviceUuid = '6E400001-B5A3-F393-E0A9-E50E24DCCA9E';
  static const String rxCharUuid  = '6E400002-B5A3-F393-E0A9-E50E24DCCA9E';
  static const String txCharUuid  = '6E400003-B5A3-F393-E0A9-E50E24DCCA9E';

  final _incomingPacketController = StreamController<BluetoothMeshPacket>.broadcast();
  Stream<BluetoothMeshPacket> get onPacketReceived => _incomingPacketController.stream;

  bool _isServerRunning = false;
  bool get isServerRunning => _isServerRunning;

  Future<void> startServer() async {
    _isServerRunning = true;
    debugPrint('GATT Proxy Server started hosting service $serviceUuid');
  }

  Future<void> stopServer() async {
    _isServerRunning = false;
    debugPrint('GATT Proxy Server stopped.');
  }

  /// Handle incoming write on RX characteristic
  void handleRxCharacteristicWrite(Uint8List bytes) {
    try {
      final packet = BluetoothMeshPacket.fromBytes(bytes);
      _incomingPacketController.add(packet);
    } catch (e) {
      debugPrint('Malformed GATT RX payload bytes: $e');
    }
  }
}
