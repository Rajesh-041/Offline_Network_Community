import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import '../crypto/identity_manager.dart';
import '../data/models.dart';
import 'ble_packet.dart';

// ---------------------------------------------------------------------------
// IBleTransport — shared interface
// ---------------------------------------------------------------------------
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

// ---------------------------------------------------------------------------
// NativeBleTransport — real flutter_blue_plus implementation
// ---------------------------------------------------------------------------

/// MeshLink GATT UUIDs (Nordic UART Service layout)
const String _kServiceUuid   = '6e400001-b5a3-f393-e0a9-e50e24dcca9e';
const String _kRxCharUuid    = '6e400002-b5a3-f393-e0a9-e50e24dcca9e'; // Write (central → peripheral)
const String _kTxCharUuid    = '6e400003-b5a3-f393-e0a9-e50e24dcca9e'; // Notify (peripheral → central)

/// Maximum number of bytes per GATT write (conservative to avoid truncation)
const int _kMtu = 512;

class NativeBleTransport implements IBleTransport {
  final IdentityManager identityManager;

  final _packetController = StreamController<BlePacket>.broadcast();
  final _peersController  = StreamController<List<Peer>>.broadcast();

  bool _isScanning    = false;
  bool _isAdvertising = false;
  int  _batteryLevel  = 90;
  int  _batteryThreshold = 20;

  // --- Connected peers ---
  final Map<String, BluetoothDevice>         _connectedDevices = {};
  final Map<String, BluetoothCharacteristic> _rxCharacteristics = {};
  final Map<String, Peer>                    _activePeers = {};

  // --- Stream subscriptions ---
  StreamSubscription? _scanSubscription;
  final Map<String, StreamSubscription> _notifySubscriptions = {};

  // --- Reassembly ---
  final _reassembler = BlePacketReassembler();

  NativeBleTransport({required this.identityManager});

  @override Stream<BlePacket>  get onPacketReceived => _packetController.stream;
  @override Stream<List<Peer>> get onPeersUpdated   => _peersController.stream;
  @override bool get isScanning    => _isScanning;
  @override bool get isAdvertising => _isAdvertising;
  @override int  get batteryThresholdPercentage => _batteryThreshold;
  @override bool get isDutyCyclingActive => _batteryLevel < _batteryThreshold;

  // --------------------------------------------------------------------------
  // Public API
  // --------------------------------------------------------------------------

  @override
  Future<void> startScanAndAdvertise() async {
    await _requestPermissions();

    final bleOn = await FlutterBluePlus.adapterState.first;
    if (bleOn != BluetoothAdapterState.on) {
      debugPrint('[BLE] Bluetooth is OFF – cannot start');
      return;
    }

    _startScanning();
  }

  @override
  Future<void> stopScanAndAdvertise() async {
    _isScanning    = false;
    _isAdvertising = false;
    await FlutterBluePlus.stopScan();
    await _scanSubscription?.cancel();
  }

  @override
  Future<void> broadcastPacket(BlePacket packet) async {
    for (final peerId in _connectedDevices.keys.toList()) {
      await sendDirectPacket(peerId, packet);
    }
  }

  @override
  Future<void> sendDirectPacket(String targetPeerId, BlePacket packet) async {
    final rxChar = _rxCharacteristics[targetPeerId];
    if (rxChar == null) {
      debugPrint('[BLE] No RX characteristic for peer $targetPeerId – queuing for next connection');
      return;
    }

    try {
      final fullBytes = packet.toBytes();

      // Chunk into MTU-safe slices
      for (int offset = 0; offset < fullBytes.length; offset += _kMtu) {
        final end = (offset + _kMtu < fullBytes.length) ? offset + _kMtu : fullBytes.length;
        final slice = fullBytes.sublist(offset, end);

        // Build a chunk BlePacket so the receiver can reassemble
        final chunkPacket = BlePacket(
          packetId:    packet.packetId,
          senderId:    packet.senderId,
          payloadJson: base64Encode(slice),
          chunkIndex:  offset ~/ _kMtu,
          totalChunks: (fullBytes.length / _kMtu).ceil(),
        );

        await rxChar.write(
          chunkPacket.toBytes(),
          withoutResponse: rxChar.properties.writeWithoutResponse,
        );
      }
      debugPrint('[BLE] Sent ${fullBytes.length} bytes to $targetPeerId');
    } catch (e) {
      debugPrint('[BLE] sendDirectPacket error for $targetPeerId: $e');
      // Device might have disconnected – clean up
      _handleDisconnect(targetPeerId);
    }
  }

  @override
  void setBatteryLevel(int levelPercentage) {
    _batteryLevel = levelPercentage.clamp(0, 100);
  }

  @override
  void setBatteryThreshold(int threshold) {
    _batteryThreshold = threshold.clamp(5, 50);
  }

  // --------------------------------------------------------------------------
  // Scanning (Central role)
  // --------------------------------------------------------------------------

  void _startScanning() {
    _isScanning = true;
    debugPrint('[BLE] Starting BLE scan for MeshLink service $_kServiceUuid');

    _scanSubscription?.cancel();
    _scanSubscription = FlutterBluePlus.onScanResults.listen((results) {
      for (final result in results) {
        final deviceId = result.device.remoteId.toString();
        if (_connectedDevices.containsKey(deviceId)) continue;

        debugPrint('[BLE] Found MeshLink peer: ${result.device.platformName} (${result.device.remoteId}) RSSI=${result.rssi}');
        _connectToDevice(result.device, result.rssi);
      }
    });

    FlutterBluePlus.startScan(
      withServices: [Guid(_kServiceUuid)],
      timeout: const Duration(seconds: 30),
    ).then((_) {
      // Restart scan after timeout to keep discovering
      if (_isScanning) {
        Future.delayed(const Duration(seconds: 2), _startScanning);
      }
    });
  }

  // --------------------------------------------------------------------------
  // GATT Connection (Central role)
  // --------------------------------------------------------------------------

  Future<void> _connectToDevice(BluetoothDevice device, int rssi) async {
    final deviceId = device.remoteId.toString();

    try {
      await device.connect(timeout: const Duration(seconds: 8), autoConnect: false);
      _connectedDevices[deviceId] = device;

      // Listen for disconnection
      device.connectionState.listen((state) {
        if (state == BluetoothConnectionState.disconnected) {
          _handleDisconnect(deviceId);
        }
      });

      // Discover GATT services
      final services = await device.discoverServices();
      for (final service in services) {
        if (service.uuid.toString().toLowerCase() == _kServiceUuid) {
          BluetoothCharacteristic? rxChar;
          BluetoothCharacteristic? txChar;

          for (final char in service.characteristics) {
            final uuid = char.uuid.toString().toLowerCase();
            if (uuid == _kRxCharUuid) rxChar = char;
            if (uuid == _kTxCharUuid) txChar = char;
          }

          if (rxChar != null) {
            _rxCharacteristics[deviceId] = rxChar;

            // Request larger MTU for bigger payloads
            try { await device.requestMtu(512); } catch (_) {}
          }

          if (txChar != null && txChar.properties.notify) {
            // Subscribe to notifications for incoming packets
            await txChar.setNotifyValue(true);
            _notifySubscriptions[deviceId] = txChar.onValueReceived.listen((bytes) {
              _handleIncomingBytes(Uint8List.fromList(bytes), deviceId);
            });
          }

          // Exchange identity handshake: send our name/fingerprint
          await _sendIdentityHandshake(deviceId);

          // Register peer
          final peer = Peer(
            id:          deviceId,
            name:        device.platformName.isNotEmpty ? device.platformName : 'Node-${deviceId.substring(0, 4)}',
            fingerprint: deviceId.replaceAll(':', '').substring(0, 8).toUpperCase(),
            publicKeyHex: '',
            rssi:        rssi,
            batteryLevel: 85,
            lastSeen:    DateTime.now(),
            // status field removed – Peer does not have a status property
          );
          _activePeers[deviceId] = peer;
          _peersController.add(_activePeers.values.toList());

          debugPrint('[BLE] Connected and subscribed to ${device.platformName} ($deviceId)');
          break;
        }
      }
    } catch (e) {
      debugPrint('[BLE] Connect error for $deviceId: $e');
      _connectedDevices.remove(deviceId);
    }
  }

  void _handleDisconnect(String deviceId) {
    debugPrint('[BLE] Device disconnected: $deviceId');
    _connectedDevices.remove(deviceId);
    _rxCharacteristics.remove(deviceId);
    _notifySubscriptions[deviceId]?.cancel();
    _notifySubscriptions.remove(deviceId);
    _activePeers.remove(deviceId);
    _peersController.add(_activePeers.values.toList());

    // Re-scan after a brief delay so it can reconnect
    if (_isScanning) {
      Future.delayed(const Duration(seconds: 3), _startScanning);
    }
  }

  // --------------------------------------------------------------------------
  // Receive incoming GATT notification bytes
  // --------------------------------------------------------------------------

  void _handleIncomingBytes(Uint8List bytes, String fromDeviceId) {
    try {
      BlePacket chunk;
      try {
        chunk = BlePacket.fromBytes(bytes);
      } catch (_) {
        // Raw base64 chunk in payloadJson – decode and wrap
        final str = utf8.decode(bytes);
        chunk = BlePacket.fromJson(jsonDecode(str));
      }

      // Reassemble multi-chunk packets
      final fullPayload = _reassembler.addChunk(chunk);
      if (fullPayload == null) return; // still waiting for more chunks

      final completePacket = BlePacket(
        packetId:    chunk.packetId,
        senderId:    chunk.senderId,
        payloadJson: fullPayload,
      );

      // Handle identity handshake packet
      if (completePacket.payloadJson.startsWith('{"handshake":')) {
        _handleIdentityHandshake(jsonDecode(completePacket.payloadJson), fromDeviceId);
        return;
      }

      debugPrint('[BLE] Received complete packet from $fromDeviceId');
      _packetController.add(completePacket);
    } catch (e) {
      debugPrint('[BLE] Error parsing incoming bytes from $fromDeviceId: $e');
    }
  }

  // --------------------------------------------------------------------------
  // Identity Handshake — exchange name & fingerprint on connect
  // --------------------------------------------------------------------------

  Future<void> _sendIdentityHandshake(String targetPeerId) async {
    final handshakeJson = jsonEncode({
      'handshake': true,
      'nodeId':    identityManager.nodeId,
      'name':      identityManager.nodeName,
      'fingerprint': identityManager.fingerprint,
    });
    final handshakePacket = BlePacket(
      packetId: 'handshake_${DateTime.now().millisecondsSinceEpoch}',
      senderId: identityManager.nodeId,
      payloadJson: handshakeJson,
    );
    await sendDirectPacket(targetPeerId, handshakePacket);
  }

  void _handleIdentityHandshake(Map<String, dynamic> data, String deviceId) {
    final name        = data['name'] as String? ?? 'Unknown';
    final fingerprint = data['fingerprint'] as String? ?? deviceId.substring(0, 8);

    // Update the peer record with the real MeshLink identity
    if (_activePeers.containsKey(deviceId)) {
      final existing = _activePeers[deviceId]!;
      _activePeers[deviceId] = Peer(
        id:          existing.id,
        name:        name,
        fingerprint: fingerprint,
        publicKeyHex: existing.publicKeyHex,
        rssi:        existing.rssi,
        hops:        existing.hops,
        batteryLevel: existing.batteryLevel,
        lastSeen:    DateTime.now(),
      );
      _peersController.add(_activePeers.values.toList());
      debugPrint('[BLE] Handshake from "$name" fingerprint=$fingerprint');
    }
  }

  // --------------------------------------------------------------------------
  // Permission request helper
  // --------------------------------------------------------------------------

  Future<void> _requestPermissions() async {
    final statuses = await [
      Permission.bluetooth,
      Permission.bluetoothScan,
      Permission.bluetoothAdvertise,
      Permission.bluetoothConnect,
      Permission.locationWhenInUse,
    ].request();

    statuses.forEach((permission, status) {
      debugPrint('[BLE] Permission $permission → $status');
    });
  }
}
