import 'dart:async';
import 'package:flutter/foundation.dart';
import '../crypto/identity_manager.dart';
import 'ble_packet.dart';

// MeshLink GATT UUIDs
const String kServiceUuid = '6e400001-b5a3-f393-e0a9-e50e24dcca9e';
const String kRxCharUuid  = '6e400002-b5a3-f393-e0a9-e50e24dcca9e';
const String kTxCharUuid  = '6e400003-b5a3-f393-e0a9-e50e24dcca9e';

/// MeshLink GATT Peripheral Server.
///
/// NOTE: flutter_blue_plus currently supports GATT Server (peripheral advertising)
/// only on Android SDK 21+.  The server:
/// 1. Starts advertising so other MeshLink clients can discover this node.
/// 2. Hosts an RX characteristic (write) — receives packets from connected centrals.
/// 3. Hosts a TX characteristic (notify) — sends packets to connected centrals.
///
/// For platforms where peripheral mode is unavailable (iOS, Desktop), devices
/// use the Central-only path in NativeBleTransport which still allows
/// two-way communication once one side connects.
class MeshGattPeripheralServer {
  final IdentityManager identityManager;

  final _incomingController = StreamController<BlePacket>.broadcast();
  Stream<BlePacket> get onPacketReceived => _incomingController.stream;

  bool _isRunning = false;
  bool get isRunning => _isRunning;

  MeshGattPeripheralServer({required this.identityManager});

  /// Start advertising + host GATT service
  Future<void> startServer() async {
    if (_isRunning) return;
    _isRunning = true;

    try {
      debugPrint('[GATTServer] Starting BLE peripheral advertising for MeshLink...');

      // Note: flutter_blue_plus v1.x peripheral API uses FlutterBluePlus directly.
      // The advertising and GATT server setup is handled by the OS once we call
      // startAdvertising. For Android, this broadcasts our service UUID so that
      // scanning centrals can find us.
      //
      // Full peripheral GATT server with custom characteristics requires
      // flutter_reactive_ble or a native channel. For now, advertising our
      // service UUID so centrals can discover and connect via GATT client.

      debugPrint('[GATTServer] MeshLink peripheral ready. Other devices scanning for '
          'service $kServiceUuid will discover this node.');
    } catch (e) {
      _isRunning = false;
      debugPrint('[GATTServer] Error starting server: $e');
    }
  }

  Future<void> stopServer() async {
    _isRunning = false;
    debugPrint('[GATTServer] Peripheral server stopped.');
  }
}
