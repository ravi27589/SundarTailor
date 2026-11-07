import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sundar_tailor/data/database/schema.dart';
import 'package:sundar_tailor/data/models/customer.dart';
import 'package:sundar_tailor/data/models/sync_queue_entry.dart';
import 'package:sundar_tailor/data/models/tailor_order.dart';
import 'package:sundar_tailor/data/repository/customer_repository.dart';
import 'package:sundar_tailor/data/repository/order_repository.dart';
import 'package:sundar_tailor/features/sync/cloud_sync_screen.dart';
import 'package:sundar_tailor/features/sync/supabase_sync_service.dart';
import 'package:sundar_tailor/features/sync/sync_queue_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  late Database database;
  late _RemoteStore remote;
  late SupabaseSyncService service;
  const queue = SyncQueueRepository();

  setUp(() async {
    database = await databaseFactoryFfi.openDatabase(
      inMemoryDatabasePath,
      options: OpenDatabaseOptions(
        version: 1,
        onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
        onCreate: (db, _) async {
          await db.execute(DatabaseSchema.createCustomers);
          await db.execute(DatabaseSchema.createOrders);
          await db.execute(DatabaseSchema.createSyncQueue);
          await db.execute(DatabaseSchema.createSyncState);
        },
      ),
    );
    remote = _RemoteStore();
    service = SupabaseSyncService(
      database: database,
      remote: remote,
      owner: 'https://shop.supabase.co|shop-user',
    );
  });

  tearDown(() async => database.close());

  test('migrates existing SQLite data once and ignores Appwrite cursors',
      () async {
    await database.insert('customers', _customer('c1').toMap());
    await database.insert('sync_state', {
      'key': 'last_pull_customer',
      'value': '2099-01-01T00:00:00Z',
    });
    final first = await service.synchronize();
    expect(first.uploaded, 1);
    expect(first.downloaded, 1);
    expect(first.failed, 0);
    expect(await queue.pending(database), isEmpty);
    expect(remote.rows[SyncEntityType.customer]!['c1'], isNotNull);
    final second = await service.synchronize();
    expect(second.uploaded, 0);
    expect(second.downloaded, 0);
  });

  test('assigns a three-character device suffix for new offline numbers',
      () async {
    await service.synchronize();
    final customers = CustomerRepository(database);
    final first = await customers.createCustomer(name: 'One', phone: '123');
    final second = await customers.createCustomer(name: 'Two', phone: '456');
    expect(first.customerNumber, 'C000001-001');
    expect(second.customerNumber, 'C000002-001');
    final orders = OrderRepository(database);
    final order = await orders.createOrder(
      customerId: first.id,
      deliveryDate: DateTime.now().add(const Duration(days: 3)),
      orderDetails: 'Shirt',
    );
    final next = await orders.createOrder(
      customerId: first.id,
      deliveryDate: DateTime.now().add(const Duration(days: 4)),
      orderDetails: 'Trouser',
    );
    expect(order.orderNumber, matches(r'^ORD-\d{8}-001-001$'));
    expect(next.orderNumber, matches(r'^ORD-\d{8}-002-001$'));
    expect(await queue.pending(database), hasLength(4));
  });

  test('uploads all customers across queue pages before uploading orders',
      () async {
    await database.transaction((txn) async {
      for (var index = 0; index < 501; index++) {
        await txn.insert('customers', _customer('c$index').toMap());
      }
      await txn.insert('orders', _order('o1', 'c500').toMap());
    });
    final summary = await service.synchronize();
    expect(summary.uploaded, 502);
    expect(summary.downloaded, 502);
    expect(summary.failed, 0);
    expect(remote.writes.last, 'order:o1');
    expect(remote.pullRequests, greaterThan(5));
  });

  test('retains failed uploads and does not upload later edits out of order',
      () async {
    final customer = _customer('c1');
    await database.insert('customers', customer.toMap());
    await queue.enqueue(
      database,
      entityType: SyncEntityType.customer,
      entityId: customer.id,
      operation: SyncOperation.upsert,
      payload: customer.toMap(),
    );
    final edited = customer.copyWith(
      name: 'Latest edit',
      updatedDate: DateTime.utc(2026, 2),
    );
    await database.update('customers', edited.toMap());
    await queue.enqueue(
      database,
      entityType: SyncEntityType.customer,
      entityId: customer.id,
      operation: SyncOperation.upsert,
      payload: edited.toMap(),
    );
    remote.failIds.add('c1');
    final failed = await service.synchronize();
    expect(failed.failed, 1);
    expect(failed.error, contains('Upload rejected'));
    expect(await queue.pending(database), hasLength(2));
    expect((await queue.pending(database)).first.error, isNotNull);
    remote.failIds.clear();
    final retried = await service.synchronize();
    expect(retried.uploaded, 2);
    expect(retried.failed, 0);
    expect(remote.rows[SyncEntityType.customer]!['c1']!['name'], 'Latest edit');
    expect(await queue.pending(database), isEmpty);
  });

  test('older upload loses to newer cloud data after pending write succeeds',
      () async {
    final old = _customer('c1');
    final cloud = old.copyWith(
      name: 'Cloud winner',
      updatedDate: DateTime.utc(2026, 3),
    );
    await database.insert('customers', old.toMap());
    remote.seed(SyncEntityType.customer, cloud.toMap());
    remote.failIds.add('c1');
    final failed = await service.synchronize();
    expect(failed.downloaded, 0);
    expect((await database.query('customers')).single['name'], old.name);
    expect(
      await database.query('sync_state',
          where: 'key = ?', whereArgs: ['supabase_pull_customer']),
      isEmpty,
    );
    remote.failIds.clear();
    await service.synchronize();
    expect((await database.query('customers')).single['name'], 'Cloud winner');
  });

  test('pull preserves an edit queued while upload is in flight', () async {
    final customer = _customer('c1');
    await database.insert('customers', customer.toMap());
    remote.onUpload = () async {
      remote.onUpload = null;
      final updated = customer.copyWith(
        name: 'Changed during sync',
        updatedDate: DateTime.utc(2026, 4),
      );
      await database.update('customers', updated.toMap());
      await queue.enqueue(
        database,
        entityType: SyncEntityType.customer,
        entityId: customer.id,
        operation: SyncOperation.upsert,
        payload: updated.toMap(),
      );
    };
    await service.synchronize();
    expect((await database.query('customers')).single['name'],
        'Changed during sync');
    expect(await queue.pending(database), isEmpty);
  });

  test(
      'pull converts JSONB, clears nulls and updates without replacing parents',
      () async {
    final customer = _customer('c1');
    await database.insert('customers', customer.toMap());
    await database.insert('orders', _order('o1', 'c1').toMap());
    await service.synchronize();
    remote.seed(SyncEntityType.customer, {
      ...customer.toMap(),
      'shirt_measurements': {'Chest': '40'},
      'deleted_date': null,
      'updated_date': '2026-04-01T00:00:00+00:00',
    });
    remote.seed(SyncEntityType.order, {
      ..._order('o1', 'c1').toMap(),
      'deleted_date': '2026-04-01T00:00:00+00:00',
      'updated_date': '2026-04-01T00:00:00+00:00',
    });
    await service.synchronize();
    final saved = Customer.fromMap((await database.query('customers')).single);
    expect(saved.shirtMeasurements, {'Chest': '40'});
    expect(saved.deletedDate, isNull);
    expect(await database.query('orders'), hasLength(1));
    expect(await OrderRepository(database).searchOrders(), isEmpty);
  });

  test('rejects a different shop before any cloud requests', () async {
    await service.synchronize();
    final otherRemote = _RemoteStore();
    final otherService = SupabaseSyncService(
      database: database,
      remote: otherRemote,
      owner: 'https://shop.supabase.co|different-user',
    );
    await expectLater(otherService.synchronize(), throwsStateError);
    expect(otherRemote.registrations, 0);
    expect(otherRemote.writes, isEmpty);
    expect(otherRemote.pullRequests, 0);
  });

  test('invalid device suffix is reported without uploading data', () async {
    remote.suffix = 'TOO-LONG';
    await expectLater(service.synchronize(), throwsStateError);
    expect(remote.writes, isEmpty);
  });

  testWidgets('cloud settings explains offline mode without configuration',
      (tester) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [
        supabaseSyncConfigProvider.overrideWithValue(
          const SupabaseSyncConfig(url: '', publishableKey: ''),
        ),
      ],
      child: const MaterialApp(home: CloudSyncScreen()),
    ));
    await tester.pumpAndSettle();
    expect(find.textContaining('Build with SUPABASE_URL'), findsOneWidget);
    expect(find.text('Sign in'), findsNothing);
  });

  testWidgets('configured signed-out shop shows runtime login validation',
      (tester) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [
        supabaseSyncConfigProvider.overrideWithValue(const SupabaseSyncConfig(
          url: 'https://shop.supabase.co',
          publishableKey: 'public-key',
        )),
        shopUserProvider.overrideWith((ref) => Stream.value(null)),
      ],
      child: const MaterialApp(home: CloudSyncScreen()),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Sign in to enable cloud sync'), findsOneWidget);
    await tester.tap(find.text('Sign in'));
    await tester.pump();
    expect(find.text('Enter the shop email and password.'), findsOneWidget);
  });
}

Customer _customer(String id) => Customer(
      id: id,
      customerNumber: 'C$id',
      name: 'Customer $id',
      phone: '123',
      shirtMeasurements: const {},
      trouserMeasurements: const {},
      pajamaMeasurements: const {},
      suitMeasurements: const {},
      shortsMeasurements: const {},
      kurtaMeasurements: const {},
      safariMeasurements: const {},
      notes: '',
      createdDate: DateTime.utc(2026),
      updatedDate: DateTime.utc(2026),
    );

TailorOrder _order(String id, String customerId) => TailorOrder(
      id: id,
      orderNumber: 'ORD-$id',
      customerId: customerId,
      bookingDate: DateTime.utc(2026),
      deliveryDate: DateTime.utc(2027),
      orderDetails: 'Shirt',
      amount: 100,
      advancePaid: 20,
      status: OrderStatus.booked,
      createdDate: DateTime.utc(2026),
      updatedDate: DateTime.utc(2026),
    );

class _RemoteStore implements CloudRemoteStore {
  final rows = <SyncEntityType, Map<String, Map<String, Object?>>>{
    for (final type in SyncEntityType.values) type: {},
  };
  final failIds = <String>{};
  final writes = <String>[];
  var version = 0;
  var registrations = 0;
  var pullRequests = 0;
  var suffix = '001';
  Future<void> Function()? onUpload;

  @override
  Future<String> registerDevice(String deviceId) async {
    registrations++;
    return suffix;
  }

  void seed(SyncEntityType type, Map<String, Object?> row) {
    rows[type]![row['id']! as String] = {
      ...row,
      'shop_id': 'shop-user',
      'sync_version': ++version,
    };
  }

  @override
  Future<void> upsert(SyncEntityType type, Map<String, Object?> row) async {
    final id = row['id']! as String;
    if (failIds.contains(id)) throw StateError('Upload rejected for $id');
    if (type == SyncEntityType.order &&
        !rows[SyncEntityType.customer]!.containsKey(row['customer_id'])) {
      throw StateError('Missing parent customer');
    }
    writes.add('${type.name}:$id');
    final existing = rows[type]![id];
    if (existing == null ||
        !DateTime.parse(existing['updated_date']! as String)
            .isAfter(DateTime.parse(row['updated_date']! as String))) {
      seed(type, row);
    }
    await onUpload?.call();
  }

  @override
  Future<List<Map<String, Object?>>> pull(
    SyncEntityType type, {
    required int afterVersion,
    required int limit,
  }) async {
    pullRequests++;
    final result = rows[type]!
        .values
        .where((row) => (row['sync_version']! as int) > afterVersion)
        .toList()
      ..sort((a, b) =>
          (a['sync_version']! as int).compareTo(b['sync_version']! as int));
    return result.take(limit).map((row) {
      final result = Map<String, Object?>.from(row);
      for (final key in result.keys.toList()) {
        if (key.endsWith('_measurements') && result[key] is String) {
          result[key] = jsonDecode(result[key]! as String);
        }
      }
      return result;
    }).toList();
  }
}
