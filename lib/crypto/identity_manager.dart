import 'dart:convert';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'crypto_engine.dart';

class IdentityManager {
  late String _nodeId;
  late String _nodeName;
  late Uint8List _privateKey;
  late String _publicKeyHex;
  late String _fingerprint;

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
  }

  String get nodeId => _nodeId;
  String get nodeName => _nodeName;
  Uint8List get privateKey => _privateKey;
  String get publicKeyHex => _publicKeyHex;
  String get fingerprint => _fingerprint;

  void updateName(String newName) {
    _nodeName = newName;
  }

  /// Sign a message or control packet using private key
  String sign(String content) {
    return CryptoEngine.signPayload(content, _privateKey);
  }

  /// Wipe identity for panic wipe gesture
  void panicWipeIdentity() {
    initNewIdentity();
  }
}
