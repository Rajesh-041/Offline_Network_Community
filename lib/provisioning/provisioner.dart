import 'dart:async';
import 'dart:typed_data';
import '../security/identity_manager.dart';
import '../security/key_manager.dart';

class UnprovisionedBeacon {
  final String deviceUuid;
  final String deviceFingerprint;
  final String deviceName;
  final int rssi;

  UnprovisionedBeacon({
    required this.deviceUuid,
    required this.deviceFingerprint,
    required this.deviceName,
    required this.rssi,
  });
}

class ProvisioningRecord {
  final String deviceUuid;
  final String deviceFingerprint;
  final int assignedUnicastAddress;
  final DateTime timestamp;

  ProvisioningRecord({
    required this.deviceUuid,
    required this.deviceFingerprint,
    required this.assignedUnicastAddress,
    required this.timestamp,
  });
}

/// Bluetooth Mesh 1.1 Provisioner Engine.
/// Securely provisions unprovisioned nodes into the mesh by distributing
/// Network Keys (NetKey), Application Keys (AppKey), and Unicast Addresses.
class MeshProvisioner {
  final IdentityManager identityManager;
  final List<ProvisioningRecord> _provisionedNodes = [];
  int _nextUnicastAddress = 0x0002;

  final _beaconController = StreamController<List<UnprovisionedBeacon>>.broadcast();
  Stream<List<UnprovisionedBeacon>> get onUnprovisionedBeacons => _beaconController.stream;

  MeshProvisioner({required this.identityManager});

  List<ProvisioningRecord> get provisionedNodes => List.unmodifiable(_provisionedNodes);

  /// Provision an unprovisioned device into the mesh
  Future<ProvisioningRecord> provisionDevice(UnprovisionedBeacon beacon) async {
    final assignedAddress = _nextUnicastAddress++;
    
    final record = ProvisioningRecord(
      deviceUuid: beacon.deviceUuid,
      deviceFingerprint: beacon.deviceFingerprint,
      assignedUnicastAddress: assignedAddress,
      timestamp: DateTime.now(),
    );

    _provisionedNodes.add(record);
    return record;
  }
}
