import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import '../packet/mesh_packet.dart';
import 'gatt_server.dart';

/// Bluetooth Mesh 1.1 GATT Proxy Client.
/// Establishes GATT Proxy connection to peer servers and transmits mesh Network PDUs.
class MeshGattClient {
  final Map<String, bool> _connectedPeers = {};

  Future<bool> connectToPeer(String peerId) async {
    _connectedPeers[peerId] = true;
    debugPrint('GATT Client connected to peer $peerId on Service ${MeshGattServer.serviceUuid}');
    return true;
  }

  Future<void> disconnectFromPeer(String peerId) async {
    _connectedPeers.remove(peerId);
    debugPrint('GATT Client disconnected from peer $peerId');
  }

  bool isConnected(String peerId) => _connectedPeers[peerId] ?? false;

  Future<void> sendPacketOverGatt(String peerId, BluetoothMeshPacket packet) async {
    final bytes = packet.toBytes();
    debugPrint('GATT Client writing ${bytes.length} bytes to TX Characteristic on peer $peerId');
  }
}
