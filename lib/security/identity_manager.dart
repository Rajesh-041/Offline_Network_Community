import 'dart:convert';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import '../crypto/crypto_engine.dart';
import 'key_manager.dart';

class IdentityManager {
  late String _nodeId;
  late String _nodeName;
  late Uint8List _privateKey;
  late String _publicKeyHex;
  late String _fingerprint;
  late MeshKeyManager _meshKeyManager;

  static final IdentityManager _instance = IdentityManager._internal();
  factory IdentityManager() => _instance;

  IdentityManager._internal() {
    initNewIdentity();
  }

  void initNewIdentity({String? name}) {
    _privateKey = CryptoEngine.generatePrivateKey();
    _publicKeyHex = CryptoEngine.derivePublicKeyHex(_privateKey);
    _fingerprint = CryptoEngine.getFingerprint(_publicKeyHex);
    _nodeId = 'node_$_fingerprint';
    _nodeName = name ?? 'Node-$_fingerprint';
    _meshKeyManager = MeshKeyManager(unicastAddress: _deriveUnicastFromFingerprint(_fingerprint));
  }

  static int _deriveUnicastFromFingerprint(String fp) {
    final bytes = utf8.encode(fp);
    final val = (bytes[0] << 8) | bytes[1];
    return (val & 0x7FFF) == 0 ? 0x0001 : (val & 0x7FFF); // Avoid 0 Unassigned Address
  }

  String get nodeId => _nodeId;
  String get nodeName => _nodeName;
  Uint8List get privateKey => _privateKey;
  String get publicKeyHex => _publicKeyHex;
  String get fingerprint => _fingerprint;
  MeshKeyManager get meshKeyManager => _meshKeyManager;
  int get unicastAddress => _meshKeyManager.unicastAddress;

  void updateName(String newName) {
    _nodeName = newName;
  }

  String sign(String content) {
    return CryptoEngine.signPayload(content, _privateKey);
  }

  void panicWipeIdentity() {
    initNewIdentity();
  }
}
