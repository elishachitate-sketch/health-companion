import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';

import '../models/cognitive_session_record.dart';

class CognitiveLocalStore {
  CognitiveLocalStore({
    required Database database,
  }) : _db = database;

  CognitiveLocalStore.inMemory() : _db = null;

  final Database? _db;
  final List<CognitiveSessionRecord> _memoryRecords = [];
  final Set<String> _syncedMemoryRecordIds = {};

  bool get isEphemeral => _db == null;
  Database? get database => _db;

  static Future<CognitiveLocalStore> open() async {
    if (kIsWeb ||
        !const {
          TargetPlatform.android,
          TargetPlatform.iOS,
          TargetPlatform.macOS,
        }.contains(defaultTargetPlatform)) {
      return CognitiveLocalStore.inMemory();
    }

    const secureStorage = FlutterSecureStorage();

    final key = await secureStorage.read(key: 'cognitive_db_key');
    final dbKey = key ?? _generateNewKey();
    if (key == null) {
      await secureStorage.write(key: 'cognitive_db_key', value: dbKey);
    }

    final database = await openDatabase(
      'cognitive_logs.db',
      version: 1,
      password: dbKey,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE cognitive_logs (
            id TEXT PRIMARY KEY,
            session_id TEXT NOT NULL,
            timestamp TEXT NOT NULL,
            task_type TEXT NOT NULL,
            completion_status TEXT NOT NULL,
            raw_score INTEGER NOT NULL,
            reaction_time_ms INTEGER NOT NULL,
            error_rate REAL NOT NULL,
            cognitive_load_index INTEGER NOT NULL DEFAULT 0,
            patient_id TEXT NOT NULL,
            payload_json TEXT NOT NULL,
            synced INTEGER NOT NULL DEFAULT 0
          )
        ''');
      },
    );

    return CognitiveLocalStore(database: database);
  }

  static String _generateNewKey() {
    final random = Random.secure();
    final bytes = List<int>.generate(32, (_) => random.nextInt(256));
    return base64UrlEncode(bytes).substring(0, 32);
  }

  Future<void> saveRecord(CognitiveSessionRecord record) async {
    final db = _db;
    if (db == null) {
      final detached = CognitiveSessionRecord.fromJson(record.toJson());
      _memoryRecords
          .removeWhere((existing) => existing.sessionId == detached.sessionId);
      _memoryRecords.add(detached);
      _syncedMemoryRecordIds.remove(detached.sessionId);
      return;
    }
    final payload = jsonEncode(record.toJson());

    await db.insert(
      'cognitive_logs',
      {
        'id': record.sessionId,
        'session_id': record.sessionId,
        'timestamp': record.timestamp.toUtc().toIso8601String(),
        'task_type': record.taskType.name,
        'completion_status': record.completionStatus.name,
        'raw_score': record.rawScore,
        'reaction_time_ms': record.reactionTimeMs,
        'error_rate': record.errorRate,
        // Legacy schema column retained for existing encrypted databases.
        // New records do not calculate or persist a clinical load index.
        'cognitive_load_index': 0,
        'patient_id': record.patientId,
        'payload_json': payload,
        'synced': 0,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<CognitiveSessionRecord>> getPendingSync() async {
    final db = _db;
    if (db == null) {
      return _memoryRecords
          .where((record) => !_syncedMemoryRecordIds.contains(record.sessionId))
          .toList(growable: false);
    }
    final rows = await db.query(
      'cognitive_logs',
      where: 'synced = ?',
      whereArgs: [0],
      orderBy: 'timestamp ASC',
    );

    return rows.map((row) {
      final payload =
          jsonDecode(row['payload_json'] as String) as Map<String, dynamic>;
      return CognitiveSessionRecord.fromJson(payload);
    }).toList();
  }

  Future<List<CognitiveSessionRecord>> getRecordsSince(DateTime since) async {
    final db = _db;
    if (db == null) {
      return _memoryRecords
          .where((record) => !record.timestamp.isBefore(since.toUtc()))
          .toList(growable: false)
        ..sort((left, right) => left.timestamp.compareTo(right.timestamp));
    }
    final rows = await db.query(
      'cognitive_logs',
      where: 'timestamp >= ?',
      whereArgs: [since.toUtc().toIso8601String()],
      orderBy: 'timestamp ASC',
    );

    return rows.map((row) {
      final payload =
          jsonDecode(row['payload_json'] as String) as Map<String, dynamic>;
      return CognitiveSessionRecord.fromJson(payload);
    }).toList();
  }

  Future<void> markSynced(String sessionId) async {
    final db = _db;
    if (db == null) {
      _syncedMemoryRecordIds.add(sessionId);
      return;
    }
    await db.update(
      'cognitive_logs',
      {'synced': 1},
      where: 'session_id = ?',
      whereArgs: [sessionId],
    );
  }

  Future<void> deleteRecordsForPatient(String patientId) async {
    final db = _db;
    if (db == null) {
      final removedIds = _memoryRecords
          .where((record) => record.patientId == patientId)
          .map((record) => record.sessionId)
          .toSet();
      _memoryRecords.removeWhere((record) => record.patientId == patientId);
      _syncedMemoryRecordIds.removeAll(removedIds);
      return;
    }
    await db.delete(
      'cognitive_logs',
      where: 'patient_id = ?',
      whereArgs: [patientId],
    );
  }
}
