import 'dart:convert';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import '../crypto/crypto_engine.dart';

/// Bluetooth Mesh 1.1 Transport & Network Layer Encryption Engine.
/// Encrypts application payloads using AppKey/NetKey prior to relaying.
class MeshEncryptionEngine {
  /// Encrypt Network PDU payload using AppKey / NetKey
  static String encryptNetworkPayload(String plaintext, Uint8List key, int seq, int srcAddress) {
    final iv = _generateNonce(seq, srcAddress);
    return CryptoEngine.encryptPayload(plaintext, _deriveSessionKey(key, iv));
  }

  /// Decrypt Network PDU payload
  static String decryptNetworkPayload(String ciphertextBase64, Uint8List key, int seq, int srcAddress) {
    final iv = _generateNonce(seq, srcAddress);
    return CryptoEngine.decryptPayload(ciphertextBase64, _deriveSessionKey(key, iv));
  }

  static Uint8List _generateNonce(int seq, int srcAddress) {
    final nonceStr = '$seq:$srcAddress:mesh1.1_nonce';
    final digest = sha256.convert(utf8.encode(nonceStr));
    return Uint8List.fromList(digest.bytes.sublist(0, 16));
  }

  static Uint8List _deriveSessionKey(Uint8List masterKey, Uint8List nonce) {
    final combined = Uint8List.fromList([...masterKey, ...nonce]);
    final digest = sha256.convert(combined);
    return Uint8List.fromList(digest.bytes.sublist(0, 16));
  }
}
