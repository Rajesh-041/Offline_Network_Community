import 'dart:convert';
import 'dart:typed_data';
import '../crypto/crypto_engine.dart';
import 'database_helper.dart';

class BackupService {
  final DatabaseHelper dbHelper;

  BackupService({required this.dbHelper});

  /// Export chat database as an encrypted backup string using password & salt
  String createEncryptedBackup(String password) {
    final rawJson = dbHelper.exportEncryptedJson();
    final salt = DateTime.now().millisecondsSinceEpoch.toString();
    final key = CryptoEngine.deriveChannelKey(password, salt);
    final encryptedCiphertext = CryptoEngine.encryptPayload(rawJson, key);

    final payload = {
      'type': 'MESHLINK_BACKUP_V1',
      'salt': salt,
      'data': encryptedCiphertext,
    };
    return base64Encode(utf8.encode(jsonEncode(payload)));
  }

  /// Restore chat database from an encrypted backup payload
  bool restoreFromEncryptedBackup(String backupBase64, String password) {
    try {
      final rawStr = utf8.decode(base64Decode(backupBase64.trim()));
      final Map<String, dynamic> payload = jsonDecode(rawStr);

      if (payload['type'] != 'MESHLINK_BACKUP_V1') {
        throw Exception('Invalid backup format version!');
      }

      final salt = payload['salt'] as String;
      final encryptedData = payload['data'] as String;
      final key = CryptoEngine.deriveChannelKey(password, salt);

      final decryptedJson = CryptoEngine.decryptPayload(encryptedData, key);
      if (decryptedJson.startsWith('[Decryption Failed')) {
        return false;
      }

      dbHelper.importJson(decryptedJson);
      return true;
    } catch (e) {
      return false;
    }
  }
}
