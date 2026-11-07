import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite/sqflite.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../data/database/database_providers.dart';
import '../../data/models/customer.dart';
import '../../data/models/sync_queue_entry.dart';
import '../../data/models/tailor_order.dart';
import 'sync_queue_repository.dart';

class SupabaseSyncConfig {
  const SupabaseSyncConfig({required this.url, required this.publishableKey});

  factory SupabaseSyncConfig.fromEnvironment() => const SupabaseSyncConfig(
        url: String.fromEnvironment('SUPABASE_URL'),
        publishableKey: String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY'),
      );

  final String url;
  final String publishableKey;

  bool get isConfigured {
    final uri = Uri.tryParse(url);
    return uri != null &&
        uri.scheme == 'https' &&
        uri.host.isNotEmpty &&
        publishableKey.isNotEmpty;
  }
}

enum CloudSyncStatus {
  notConfigured,
  signedOut,
  waiting,
  syncing,
  synced,
  offline,
  failed;

  String get label => switch (this) {
        CloudSyncStatus.notConfigured => 'Cloud sync not configured',
        CloudSyncStatus.signedOut => 'Sign in to enable cloud sync',
        CloudSyncStatus.waiting => 'Waiting to sync',
        CloudSyncStatus.syncing => 'Syncing...',
        CloudSyncStatus.synced => 'Cloud data is up to date',
        CloudSyncStatus.offline => 'Offline; changes saved on this device',
        CloudSyncStatus.failed => 'Sync failed; open Cloud sync for details',
      };
}

class CloudSyncSummary {
  const CloudSyncSummary({
    required this.uploaded,
    required this.downloaded,
    required this.failed,
    this.error,
  });

  final int uploaded;
  final int downloaded;
  final int failed;
  final String? error;
}

final supabaseSyncConfigProvider = Provider<SupabaseSyncConfig>(
  (ref) => SupabaseSyncConfig.fromEnvironment(),
);

final supabaseClientProvider = FutureProvider<SupabaseClient?>((ref) async {
  final config = ref.watch(supabaseSyncConfigProvider);
  if (kIsWeb || !config.isConfigured) return null;
  await Supabase.initialize(
    url: config.url,
    // Keep compatibility with the SDK versions supporting Dart 3.4.
    // ignore: deprecated_member_use
    anonKey: config.publishableKey,
  );
  return Supabase.instance.client;
});

final shopUserProvider = StreamProvider<User?>((ref) async* {
  final client = await ref.watch(supabaseClientProvider.future);
  if (client == null) {
    yield null;
    return;
  }
  yield client.auth.currentUser;
  yield* client.auth.onAuthStateChange
      .map((event) => event.session?.user)
      .distinct((previous, next) => previous?.id == next?.id);
});

final cloudSyncErrorProvider = StateProvider<String?>((ref) => null);

final cloudSyncStatusProvider = StateProvider<CloudSyncStatus>((ref) {
  if (kIsWeb || !ref.watch(supabaseSyncConfigProvider).isConfigured) {
    return CloudSyncStatus.notConfigured;
  }
  final hasError =
      ref.watch(shopUserProvider.select((value) => value.hasError));
  final isLoading =
      ref.watch(shopUserProvider.select((value) => value.isLoading));
  final userId = ref.watch(
    shopUserProvider.select((value) => value.valueOrNull?.id),
  );
  if (hasError) return CloudSyncStatus.failed;
  if (isLoading) return CloudSyncStatus.waiting;
  return userId == null ? CloudSyncStatus.signedOut : CloudSyncStatus.waiting;
});

final supabaseSyncServiceProvider =
    FutureProvider<SupabaseSyncService?>((ref) async {
  final user = await ref.watch(shopUserProvider.future);
  if (user == null) return null;
  final client = await ref.watch(supabaseClientProvider.future);
  if (client == null) return null;
  final database = await ref.watch(databaseProvider.future);
  return SupabaseSyncService(
    database: database,
    remote: SupabaseRemoteStore(client, user.id),
    owner: '${ref.watch(supabaseSyncConfigProvider).url}|${user.id}',
  );
});

abstract class CloudRemoteStore {
  Future<String> registerDevice(String deviceId);
  Future<void> upsert(SyncEntityType type, Map<String, Object?> row);
  Future<List<Map<String, Object?>>> pull(
    SyncEntityType type, {
    required int afterVersion,
    required int limit,
  });
}

class SupabaseRemoteStore implements CloudRemoteStore {
  SupabaseRemoteStore(this.client, this.userId);
  final SupabaseClient client;
  final String userId;

  void _requireShop() {
    if (client.auth.currentUser?.id != userId) {
      throw StateError(
          'The shop session changed. Sign in again before syncing.');
    }
  }

  @override
  Future<String> registerDevice(String deviceId) async {
    _requireShop();
    return await client.rpc<String>(
      'register_sync_device',
      params: {'device_id': deviceId},
    );
  }

  @override
  Future<void> upsert(SyncEntityType type, Map<String, Object?> row) async {
    _requireShop();
    final payload = Map<String, Object?>.from(row);
    for (final key in payload.keys.toList()) {
      if (key.endsWith('_measurements') && payload[key] is String) {
        payload[key] = jsonDecode(payload[key]! as String);
      }
    }
    await client.rpc('sync_upsert_${type.name}', params: {'payload': payload});
  }

  @override
  Future<List<Map<String, Object?>>> pull(
    SyncEntityType type, {
    required int afterVersion,
    required int limit,
  }) async {
    _requireShop();
    final rows = await client
        .from(type == SyncEntityType.customer ? 'customers' : 'orders')
        .select()
        .eq('shop_id', userId)
        .gt('sync_version', afterVersion)
        .order('sync_version')
        .limit(limit);
    return rows.map((row) => Map<String, Object?>.from(row)).toList();
  }
}

class SupabaseSyncService {
  SupabaseSyncService({
    required Database database,
    required CloudRemoteStore remote,
    required this.owner,
    SyncQueueRepository queue = const SyncQueueRepository(),
  })  : _database = database,
        _remote = remote,
        _queue = queue;

  final Database _database;
  final CloudRemoteStore _remote;
  final SyncQueueRepository _queue;
  final String owner;
  var _isSyncing = false;

  static Future<void> bindShop(Database database, String owner) async {
    await database.transaction((txn) async {
      final rows = await txn.query(
        'sync_state',
        where: 'key = ?',
        whereArgs: ['supabase_owner'],
      );
      if (rows.isNotEmpty && rows.single['value'] != owner) {
        throw StateError(
          'This device database belongs to another shop account or Supabase '
          'project. Sign in with the original account. Use a separate app '
          'installation for a different shop.',
        );
      }
      if (rows.isEmpty) {
        await txn.insert('sync_state', {
          'key': 'supabase_owner',
          'value': owner,
        });
      }
    });
  }

  Future<CloudSyncSummary> synchronize() async {
    if (_isSyncing) throw StateError('A sync is already running.');
    _isSyncing = true;
    var uploaded = 0;
    var downloaded = 0;
    var failed = 0;
    String? lastError;
    try {
      await bindShop(_database, owner);
      await _registerDevice();
      await _seedExistingRows();
      // Upload customers before orders, including when a queue spans >500 rows.
      for (final type in SyncEntityType.values) {
        final blocked = <String>{};
        while (true) {
          final pending = await _queue.pendingForType(_database, type);
          if (pending.isEmpty) break;
          var completed = 0;
          for (final entry in pending) {
            if (blocked.contains(entry.entityId)) continue;
            try {
              await _remote.upsert(type, entry.payload);
              await _queue.remove(_database, entry.id);
              uploaded++;
              completed++;
            } on Object catch (error, stack) {
              await _queue.markFailed(_database, entry.id, error);
              debugPrint('Cloud upload failed: $error\n$stack');
              blocked.add(entry.entityId);
              failed++;
              lastError = error.toString();
            }
          }
          if (completed == 0 || blocked.isNotEmpty) break;
        }
      }
      for (final type in SyncEntityType.values) {
        downloaded += await _pull(type);
      }
      return CloudSyncSummary(
        uploaded: uploaded,
        downloaded: downloaded,
        failed: failed,
        error: lastError,
      );
    } finally {
      _isSyncing = false;
    }
  }

  Future<void> _registerDevice() async {
    final deviceId = await _database.transaction((txn) async {
      final rows = await txn.query(
        'sync_state',
        where: 'key = ?',
        whereArgs: ['supabase_device_id'],
      );
      if (rows.isNotEmpty) return rows.single['value']! as String;
      final id = const Uuid().v4();
      await txn
          .insert('sync_state', {'key': 'supabase_device_id', 'value': id});
      return id;
    });
    final suffix = await _remote.registerDevice(deviceId);
    if (!RegExp(r'^[0-9A-Z]{3}$').hasMatch(suffix)) {
      throw StateError('Supabase returned an invalid device suffix.');
    }
    await _database.insert(
      'sync_state',
      {'key': 'supabase_device_suffix', 'value': suffix},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> _seedExistingRows() async {
    await _database.transaction((txn) async {
      final seeded = await txn.query(
        'sync_state',
        where: 'key = ?',
        whereArgs: ['supabase_seeded'],
      );
      if (seeded.isNotEmpty) return;
      for (final type in SyncEntityType.values) {
        final table = _table(type);
        final rows = await txn.rawQuery('''
SELECT * FROM $table
WHERE NOT EXISTS (
  SELECT 1 FROM sync_queue
  WHERE entity_type = ? AND entity_id = $table.id
)
''', [type.name]);
        for (final row in rows) {
          await _queue.enqueue(
            txn,
            entityType: type,
            entityId: row['id']! as String,
            operation: row['deleted_date'] == null
                ? SyncOperation.upsert
                : SyncOperation.delete,
            payload: row,
          );
        }
      }
      await txn.insert('sync_state', {
        'key': 'supabase_seeded',
        'value': 'true',
      });
    });
  }

  Future<int> _pull(SyncEntityType type) async {
    final key = 'supabase_pull_${type.name}';
    final state = await _database.query(
      'sync_state',
      where: 'key = ?',
      whereArgs: [key],
    );
    var cursor =
        state.isEmpty ? 0 : int.parse(state.single['value']! as String);
    var applied = 0;
    var blocked = false;
    const pageSize = 100;
    while (true) {
      final rows = await _remote.pull(
        type,
        afterVersion: cursor,
        limit: pageSize,
      );
      for (final row in rows) {
        final version = (row['sync_version']! as num).toInt();
        if (version <= cursor) {
          throw StateError('Cloud returned an invalid sync version.');
        }
        cursor = version;
        final didApply = await _database.transaction((txn) async {
          final pending = await txn.query(
            'sync_queue',
            columns: ['id'],
            where: 'entity_type = ? AND entity_id = ?',
            whereArgs: [type.name, row['id']],
            limit: 1,
          );
          if (pending.isNotEmpty) return false;
          final local = _localRow(type, row);
          // UPDATE rather than REPLACE preserves customer/order foreign keys.
          final count = await txn.update(
            _table(type),
            local,
            where: 'id = ?',
            whereArgs: [local['id']],
          );
          if (count == 0) await txn.insert(_table(type), local);
          return true;
        });
        if (didApply) {
          applied++;
        } else {
          blocked = true;
        }
      }
      // Retain the old cursor if any row was skipped for a pending local write.
      if (!blocked && rows.isNotEmpty) {
        await _database.insert(
          'sync_state',
          {'key': key, 'value': cursor.toString()},
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
      if (rows.length < pageSize) break;
    }
    return applied;
  }

  static Map<String, Object?> _localRow(
    SyncEntityType type,
    Map<String, Object?> row,
  ) {
    final normalized = Map<String, Object?>.from(row);
    for (final key in normalized.keys.toList()) {
      if (key.endsWith('_date') && normalized[key] is String) {
        normalized[key] = DateTime.parse(normalized[key]! as String)
            .toUtc()
            .toIso8601String();
      }
      if (key.endsWith('_measurements') && normalized[key] is Map) {
        normalized[key] = jsonEncode(normalized[key]);
      }
    }
    return type == SyncEntityType.customer
        ? Customer.fromMap(normalized).toMap()
        : TailorOrder.fromMap(normalized).toMap();
  }

  static String _table(SyncEntityType type) =>
      type == SyncEntityType.customer ? 'customers' : 'orders';
}
