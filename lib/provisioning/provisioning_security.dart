import 'dart:convert';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import '../crypto/crypto_engine.dart';

class ProvisioningSecurity {
  /// Generate 16-byte random confirmation value
  static Uint8List generateRandomConfirmation() {
    return CryptoEngine.generatePrivateKey().sublist(0, 16);
  }

  /// Derive Provisioning Session Key from Confirmation & Public Key Exchange
  static Uint8List deriveSessionKey(Uint8List privKey, String peerPubKeyHex, Uint8List randomVal) {
    final dh = CryptoEngine.deriveSharedSecret(privKey, peerPubKeyHex);
    final combined = Uint8List.fromList([...dh, ...randomVal]);
    final digest = sha256.convert(combined);
    return Uint8List.fromList(digest.bytes.sublist(0, 16));
  }
}
