import 'dart:convert';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'crypto_engine.dart';

class ChannelCrypto {
  /// Generate hashed password string for verification
  static String hashPassword(String password, String salt) {
    final digest = sha256.convert(utf8.encode('$password:$salt:mesh_salt'));
    return digest.toString();
  }

  /// Verify password match against hash
  static bool verifyPassword(String password, String salt, String expectedHash) {
    return hashPassword(password, salt) == expectedHash;
  }

  /// Encrypt channel payload with key derived from channel password
  static String encryptChannelMessage(String content, String password, String salt) {
    final key = CryptoEngine.deriveChannelKey(password, salt);
    return CryptoEngine.encryptPayload(content, key);
  }

  /// Decrypt channel payload with key derived from channel password
  static String decryptChannelMessage(String encryptedContent, String password, String salt) {
    final key = CryptoEngine.deriveChannelKey(password, salt);
    return CryptoEngine.decryptPayload(encryptedContent, key);
  }
}
