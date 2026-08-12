import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:meshlink/crypto/crypto_engine.dart';
import 'package:meshlink/crypto/identity_manager.dart';
import 'package:meshlink/data/database_helper.dart';
import 'package:meshlink/data/models.dart';
import 'package:meshlink/ml/adaptive_router.dart';

void main() {
  group('MeshLink Cryptographic Security Tests', () {
    test('X25519 Identity Key generation & fingerprint formatting', () {
      final identity = IdentityManager();
      expect(identity.fingerprint.length, equals(8));
      expect(identity.nodeId.startsWith('node_'), isTrue);
    });

    test('AES-256-GCM Payload Encryption & Decryption Roundtrip', () {
      final key = CryptoEngine.generatePrivateKey();
      const plaintext = 'Top Secret Mesh Message Payload 123!';

      final ciphertext = CryptoEngine.encryptPayload(plaintext, key);
      expect(ciphertext.length, greaterThan(20));

      final decrypted = CryptoEngine.decryptPayload(ciphertext, key);
      expect(decrypted, equals(plaintext));
    });

    test('MAC Tamper Detection in Ciphertext', () {
      final key = CryptoEngine.generatePrivateKey();
      const plaintext = 'Normal message';
      final ciphertext = CryptoEngine.encryptPayload(plaintext, key);

      final wrongKey = CryptoEngine.generatePrivateKey();
      final failedDecryption = CryptoEngine.decryptPayload(ciphertext, wrongKey);
      expect(failedDecryption.contains('Decryption Failed'), isTrue);
    });
  });

  group('Tiny ML Adaptive Mesh Router Tests', () {
    test('Optimal Relay Route Prediction Ranking', () {
      final mlRouter = TinyMlAdaptiveRouter();
      final peers = [
        Peer(id: 'p1', name: 'Low RSSI', fingerprint: '1111', publicKeyHex: 'pk1', rssi: -90, batteryLevel: 30, lastSeen: DateTime.now()),
        Peer(id: 'p2', name: 'High RSSI', fingerprint: '2222', publicKeyHex: 'pk2', rssi: -45, batteryLevel: 95, lastSeen: DateTime.now()),
      ];

      final ranked = mlRouter.predictOptimalRoutes(peers);
      expect(ranked.first.peer.id, equals('p2')); // Node with high RSSI & battery should rank #1
    });
  });

  group('Database & Panic Wipe Storage Tests', () {
    test('Panic Wipe Purges All Local Database State', () async {
      final db = DatabaseHelper();
      final msg = Message(
        id: 'm100',
        senderId: 'n1',
        senderFingerprint: 'A1B2',
        senderName: 'TestUser',
        content: 'Secret chat text',
        timestamp: DateTime.now(),
      );

      await db.saveMessage(msg);
      expect(db.getMessagesForChannel('public').length, greaterThanOrEqualTo(0));

      await db.panicWipeAllData();
      final messagesAfterWipe = db.getMessagesForChannel('public');
      expect(messagesAfterWipe.isEmpty, isTrue);
    });
  });
}
