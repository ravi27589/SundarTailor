import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import '../../data/models/sync_queue_entry.dart';

class SyncQueueRepository {
  const SyncQueueRepository({Uuid uuid = const Uuid()}) : _uuid = uuid;

  final Uuid _uuid;

  Future<void> enqueue(
    DatabaseExecutor executor, {
    required SyncEntityType entityType,
    required String entityId,
    required SyncOperation operation,
    required Map<String, Object?> payload,
  }) async {
    final entry = SyncQueueEntry(
      id: _uuid.v4(),
      entityType: entityType,
      entityId: entityId,
      operation: operation,
      payload: payload,
      createdDate: DateTime.now().toUtc(),
    );

    await executor.insert('sync_queue', entry.toMap());
  }

  Future<List<SyncQueueEntry>> pending(Database database,
      {int limit = 50}) async {
    final rows = await database.query(
      'sync_queue',
      orderBy: 'created_date ASC',
      limit: limit,
    );

    return rows.map(SyncQueueEntry.fromMap).toList(growable: false);
  }

  Future<void> remove(Database database, String id) async {
    await database.delete('sync_queue', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<SyncQueueEntry>> pendingForType(
    Database database,
    SyncEntityType type, {
    int limit = 500,
  }) async {
    final rows = await database.query(
      'sync_queue',
      where: 'entity_type = ?',
      whereArgs: [type.name],
      orderBy: 'created_date ASC, rowid ASC',
      limit: limit,
    );
    return rows.map(SyncQueueEntry.fromMap).toList(growable: false);
  }

  Future<void> markFailed(Database database, String id, Object error) async {
    await database.update(
      'sync_queue',
      {
        'last_attempt_date': DateTime.now().toUtc().toIso8601String(),
        'error': error.toString(),
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}
