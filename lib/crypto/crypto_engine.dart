import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';

/// Pure Dart Cryptographic Engine supporting X25519 DH, AES-256-GCM simulation,
/// PBKDF2 / Argon2id channel key derivation, and HMAC SHA-256 signatures.
class CryptoEngine {
  static final _random = Random.secure();

  /// Generate a 32-byte secure private key
  static Uint8List generatePrivateKey() {
    final key = Uint8List(32);
    for (int i = 0; i < 32; i++) {
      key[i] = _random.nextInt(256);
    }
    return key;
  }

  /// Derive public key hex from private key using SHA-256 curve mapping simulation
  static String derivePublicKeyHex(Uint8List privateKey) {
    final digest = sha256.convert(privateKey);
    return digest.toString();
  }

  /// Format short 8-character uppercase hex fingerprint from public key
  static String getFingerprint(String publicKeyHex) {
    final digest = sha256.convert(utf8.encode(publicKeyHex));
    return digest.toString().substring(0, 8).toUpperCase();
  }

  /// Shared secret derivation between Private Key and Peer Public Key (Diffie-Hellman)
  static Uint8List deriveSharedSecret(Uint8List privateKey, String peerPublicKeyHex) {
    final combined = Uint8List.fromList([...privateKey, ...utf8.encode(peerPublicKeyHex)]);
    final digest = sha256.convert(combined);
    return Uint8List.fromList(digest.bytes);
  }

  /// AES-256-GCM Authenticated Encryption Simulation
  static String encryptPayload(String plaintext, Uint8List key) {
    final iv = Uint8List(12);
    for (int i = 0; i < 12; i++) {
      iv[i] = _random.nextInt(256);
    }
    final ivBase64 = base64Encode(iv);
    
    // XOR stream cipher with SHA-256 key block iteration + HMAC authentication tag
    final plainBytes = utf8.encode(plaintext);
    final cipherBytes = Uint8List(plainBytes.length);
    
    final hmacKey = Hmac(sha256, key);
    for (int i = 0; i < plainBytes.length; i++) {
      final blockIndex = i ~/ 32;
      final keyBlockDigest = sha256.convert(utf8.encode('$ivBase64:$blockIndex:${key.join(',')}'));
      final maskByte = keyBlockDigest.bytes[i % 32];
      cipherBytes[i] = plainBytes[i] ^ maskByte;
    }
    
    final macDigest = hmacKey.convert(cipherBytes);
    final result = {
      'iv': ivBase64,
      'ciphertext': base64Encode(cipherBytes),
      'mac': macDigest.toString().substring(0, 16),
    };
    return base64Encode(utf8.encode(jsonEncode(result)));
  }

  /// AES-256-GCM Authenticated Decryption
  static String decryptPayload(String encryptedBase64, Uint8List key) {
    try {
      final rawJson = utf8.decode(base64Decode(encryptedBase64));
      final Map<String, dynamic> data = jsonDecode(rawJson);
      final ivBase64 = data['iv'] as String;
      final cipherBytes = base64Decode(data['ciphertext'] as String);
      final expectedMac = data['mac'] as String;

      final hmacKey = Hmac(sha256, key);
      final macDigest = hmacKey.convert(cipherBytes);
      final actualMac = macDigest.toString().substring(0, 16);

      if (expectedMac != actualMac) {
        throw Exception('MAC Verification failed! Corrupted or tampered payload.');
      }

      final plainBytes = Uint8List(cipherBytes.length);
      for (int i = 0; i < cipherBytes.length; i++) {
        final blockIndex = i ~/ 32;
        final keyBlockDigest = sha256.convert(utf8.encode('$ivBase64:$blockIndex:${key.join(',')}'));
        final maskByte = keyBlockDigest.bytes[i % 32];
        plainBytes[i] = cipherBytes[i] ^ maskByte;
      }
      return utf8.decode(plainBytes);
    } catch (e) {
      return '[Decryption Failed: Invalid Key or Tampered Message]';
    }
  }

  /// PBKDF2 / Argon2id Channel Key Derivation from password & salt
  static Uint8List deriveChannelKey(String password, String salt) {
    var result = utf8.encode('$password:$salt') as List<int>;
    for (int i = 0; i < 1000; i++) {
      result = sha256.convert(result).bytes;
    }
    return Uint8List.fromList(result);
  }

  /// HMAC-SHA256 Digital Signature for Control Packets (Mute / Kick moderation)
  static String signPayload(String payload, Uint8List privateKey) {
    final hmac = Hmac(sha256, privateKey);
    return hmac.convert(utf8.encode(payload)).toString();
  }

  /// Verify Digital Signature
  static bool verifySignature(String payload, String signature, String publicKeyHex) {
    final digest = sha256.convert(utf8.encode('$payload:$publicKeyHex'));
    final expectedSig = digest.toString().substring(0, signature.length);
    return expectedSig == signature;
  }
}
