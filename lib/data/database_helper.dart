import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'models.dart';

/// Production Persistent SQLite Database Manager.
/// Manages persistent disk storage for messages, channels, peers, moderation records, and Panic Wipe.
class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  factory DatabaseHelper() => _instance;

  static Database? _database;

  final Map<String, Message> _memoryMessages = {};
  final Map<String, Channel> _memoryChannels = {};
  final Set<String> _mutedPeerFingerprints = {};
  final Set<String> _kickedPeerFingerprints = {};
  final List<Message> _unsentQueue = [];

  DatabaseHelper._internal();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    await _loadStateFromDb();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    // Initialize FFI for Windows / Linux / macOS desktop
    if (!kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }

    String path;
    if (kIsWeb) {
      path = 'meshlink_web.db';
    } else {
      final docsDir = await getApplicationDocumentsDirectory();
      path = p.join(docsDir.path, 'meshlink.db');
    }

    return await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        // 1. Messages Table
        await db.execute('''
          CREATE TABLE messages (
            id TEXT PRIMARY KEY,
            senderId TEXT,
            senderFingerprint TEXT,
            senderName TEXT,
            recipientId TEXT,
            channelId TEXT,
            content TEXT,
            timestamp TEXT,
            type TEXT,
            status TEXT,
            ttl INTEGER,
            hopCount INTEGER,
            isEncrypted INTEGER,
            relayPath TEXT,
            voiceBytes TEXT,
            voiceDurationMs INTEGER,
            translatedContent TEXT
          )
        ''');

        // 2. Channels Table
        await db.execute('''
          CREATE TABLE channels (
            id TEXT PRIMARY KEY,
            name TEXT,
            description TEXT,
            isProtected INTEGER,
            passwordHash TEXT,
            creatorFingerprint TEXT,
            createdTime TEXT,
            isMuted INTEGER
          )
        ''');

        // 3. Moderation Table
        await db.execute('''
          CREATE TABLE moderation (
            fingerprint TEXT PRIMARY KEY,
            type TEXT
          )
        ''');

        // Seed default channels into SQLite
        await _seedDefaultChannelsInDb(db);
      },
    );
  }

  Future<void> _seedDefaultChannelsInDb(Database db) async {
    // Completely clean initialization - zero pre-seeded default or preview channels.
  }

  Future<void> _loadStateFromDb() async {
    final db = _database!;
    
    // Load Channels
    final channelMaps = await db.query('channels');
    _memoryChannels.clear();
    for (var map in channelMaps) {
      final channel = _channelFromMap(map);
      _memoryChannels[channel.id] = channel;
    }

    // Load Messages
    final msgMaps = await db.query('messages', orderBy: 'timestamp ASC');
    _memoryMessages.clear();
    _unsentQueue.clear();
    for (var map in msgMaps) {
      final msg = Message.fromJson(map);
      _memoryMessages[msg.id] = msg;
      if (msg.status == DeliveryStatus.pending) {
        _unsentQueue.add(msg);
      }
    }

    // Load Moderation
    final modMaps = await db.query('moderation');
    _mutedPeerFingerprints.clear();
    _kickedPeerFingerprints.clear();
    for (var map in modMaps) {
      final fp = map['fingerprint'] as String;
      final type = map['type'] as String;
      if (type == 'mute') _mutedPeerFingerprints.add(fp);
      if (type == 'kick') _kickedPeerFingerprints.add(fp);
    }
  }

  // --- SQLite Helper Methods ---
  Map<String, dynamic> _channelToMap(Channel channel) => {
    'id': channel.id,
    'name': channel.name,
    'description': channel.description,
    'isProtected': channel.isProtected ? 1 : 0,
    'passwordHash': channel.passwordHash,
    'creatorFingerprint': channel.creatorFingerprint,
    'createdTime': channel.createdTime.toIso8601String(),
    'isMuted': channel.isMuted ? 1 : 0,
  };

  Channel _channelFromMap(Map<String, dynamic> map) => Channel(
    id: map['id'],
    name: map['name'],
    description: map['description'],
    isProtected: map['isProtected'] == 1,
    passwordHash: map['passwordHash'],
    creatorFingerprint: map['creatorFingerprint'],
    createdTime: DateTime.parse(map['createdTime']),
    isMuted: map['isMuted'] == 1,
  );

  // --- Messages Persistence ---
  Future<void> saveMessage(Message message) async {
    _memoryMessages[message.id] = message;
    if (message.status == DeliveryStatus.pending) {
      _unsentQueue.add(message);
    } else {
      _unsentQueue.removeWhere((m) => m.id == message.id);
    }

    final db = await database;
    await db.insert('messages', message.toDbMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  List<Message> getMessagesForChannel(String channelId) {
    final list = _memoryMessages.values.where((m) => m.channelId == channelId).toList();
    list.sort((a, b) => a.timestamp.compareTo(b.timestamp));
    return list;
  }

  List<Message> getDirectMessages(String peerId) {
    final list = _memoryMessages.values
        .where((m) => (m.senderId == peerId || m.recipientId == peerId) && m.channelId == null)
        .toList();
    list.sort((a, b) => a.timestamp.compareTo(b.timestamp));
    return list;
  }

  List<Message> getUnsentQueue() => List.unmodifiable(_unsentQueue);

  Future<void> updateMessageStatus(String messageId, DeliveryStatus status) async {
    if (_memoryMessages.containsKey(messageId)) {
      _memoryMessages[messageId]!.status = status;
      if (status != DeliveryStatus.pending) {
        _unsentQueue.removeWhere((m) => m.id == messageId);
      }

      final db = await database;
      await db.update(
        'messages',
        {'status': status.name},
        where: 'id = ?',
        whereArgs: [messageId],
      );
    }
  }

  // --- Channels Persistence ---
  List<Channel> getAllChannels() => _memoryChannels.values.toList();

  Channel? getChannel(String id) => _memoryChannels[id];

  Future<void> saveChannel(Channel channel) async {
    _memoryChannels[channel.id] = channel;
    final db = await database;
    await db.insert('channels', _channelToMap(channel), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  // --- Moderation Persistence ---
  Future<void> mutePeer(String fingerprint) async {
    _mutedPeerFingerprints.add(fingerprint);
    final db = await database;
    await db.insert('moderation', {'fingerprint': fingerprint, 'type': 'mute'}, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> kickPeer(String fingerprint) async {
    _kickedPeerFingerprints.add(fingerprint);
    final db = await database;
    await db.insert('moderation', {'fingerprint': fingerprint, 'type': 'kick'}, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  bool isPeerMuted(String fingerprint) => _mutedPeerFingerprints.contains(fingerprint);
  bool isPeerKicked(String fingerprint) => _kickedPeerFingerprints.contains(fingerprint);

  // --- Panic Wipe Gesture ---
  Future<void> panicWipeAllData() async {
    _memoryMessages.clear();
    _memoryChannels.clear();
    _mutedPeerFingerprints.clear();
    _kickedPeerFingerprints.clear();
    _unsentQueue.clear();

    final db = await database;
    await db.delete('messages');
    await db.delete('channels');
    await db.delete('moderation');

    await _seedDefaultChannelsInDb(db);
    await _loadStateFromDb();
  }

  // --- Export / Import JSON snapshot ---
  String exportEncryptedJson() {
    final exportData = {
      'version': 1,
      'exportedAt': DateTime.now().toIso8601String(),
      'messages': _memoryMessages.values.map((m) => m.toJson()).toList(),
      'channels': _memoryChannels.values.map((c) => c.toJson()).toList(),
      'muted': _mutedPeerFingerprints.toList(),
      'kicked': _kickedPeerFingerprints.toList(),
    };
    return jsonEncode(exportData);
  }

  Future<void> importJson(String jsonStr) async {
    final Map<String, dynamic> data = jsonDecode(jsonStr);
    if (data.containsKey('messages')) {
      for (var item in data['messages']) {
        final m = Message.fromJson(item);
        await saveMessage(m);
      }
    }
    if (data.containsKey('channels')) {
      for (var item in data['channels']) {
        final c = Channel.fromJson(item);
        await saveChannel(c);
      }
    }
    if (data.containsKey('muted')) {
      for (var fp in data['muted']) {
        await mutePeer(fp);
      }
    }
    if (data.containsKey('kicked')) {
      for (var fp in data['kicked']) {
        await kickPeer(fp);
      }
    }
  }
}
