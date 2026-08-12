import 'dart:typed_data';
import '../security/identity_manager.dart';

class MeshProvisionee {
  final IdentityManager identityManager;
  bool _isProvisioned = false;

  MeshProvisionee({required this.identityManager});

  bool get isProvisioned => _isProvisioned;

  /// Receive provisioning payload from Provisioner node
  void receiveProvisioningData({
    required Uint8List netKey,
    required Uint8List appKey,
    required Uint8List devKey,
    required int unicastAddress,
    required int ivIndex,
  }) {
    identityManager.meshKeyManager.updateKeys(
      netKey: netKey,
      appKey: appKey,
      devKey: devKey,
      unicastAddress: unicastAddress,
      ivIndex: ivIndex,
    );
    _isProvisioned = true;
  }
}
