import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import '../database/database_providers.dart';
import '../database/device_numbering.dart';
import '../models/customer.dart';
import '../models/sync_queue_entry.dart';
import '../../features/sync/sync_queue_repository.dart';

final customerRepositoryProvider =
    FutureProvider<CustomerRepository>((ref) async {
  if (kIsWeb) {
    return CustomerRepository.memory();
  }

  final database = await ref.watch(databaseProvider.future);
  return CustomerRepository(database);
});

final customerSearchQueryProvider = StateProvider<String>((ref) => '');

final customersProvider = FutureProvider<List<Customer>>((ref) async {
  final query = ref.watch(customerSearchQueryProvider);
  final repository = await ref.watch(customerRepositoryProvider.future);
  return repository.searchCustomers(query);
});

final customerByIdProvider =
    FutureProvider.family<Customer?, String>((ref, customerId) async {
  final repository = await ref.watch(customerRepositoryProvider.future);
  return repository.getCustomerById(customerId);
});

class CustomerRepository {
  CustomerRepository(this._database,
      {Uuid? uuid, SyncQueueRepository? syncQueue})
      : _uuid = uuid ?? const Uuid(),
        _syncQueue = syncQueue ?? const SyncQueueRepository(),
        _memoryCustomers = null;

  CustomerRepository.memory({Uuid? uuid})
      : _database = null,
        _uuid = uuid ?? const Uuid(),
        _syncQueue = const SyncQueueRepository(),
        _memoryCustomers = <Customer>[];

  final Database? _database;
  final Uuid _uuid;
  final SyncQueueRepository _syncQueue;
  final List<Customer>? _memoryCustomers;

  Future<Customer> createCustomer({
    required String name,
    required String phone,
    Map<String, String> shirtMeasurements = const {},
    Map<String, String> trouserMeasurements = const {},
    Map<String, String> pajamaMeasurements = const {},
    Map<String, String> suitMeasurements = const {},
    Map<String, String> shortsMeasurements = const {},
    Map<String, String> kurtaMeasurements = const {},
    Map<String, String> safariMeasurements = const {},
    String notes = '',
  }) async {
    final database = _database;
    if (database == null) {
      final customers = _memoryCustomers!;
      final now = DateTime.now().toUtc();
      final customer = Customer(
        id: _uuid.v4(),
        customerNumber: 'C${(customers.length + 1).toString().padLeft(6, '0')}',
        name: name.trim(),
        phone: phone.trim(),
        shirtMeasurements: shirtMeasurements,
        trouserMeasurements: trouserMeasurements,
        pajamaMeasurements: pajamaMeasurements,
        suitMeasurements: suitMeasurements,
        shortsMeasurements: shortsMeasurements,
        kurtaMeasurements: kurtaMeasurements,
        safariMeasurements: safariMeasurements,
        notes: notes.trim(),
        createdDate: now,
        updatedDate: now,
      );
      customers.add(customer);
      return customer;
    }

    return database.transaction((transaction) async {
      final now = DateTime.now().toUtc();
      final customer = Customer(
        id: _uuid.v4(),
        customerNumber: await _nextCustomerNumber(transaction),
        name: name.trim(),
        phone: phone.trim(),
        shirtMeasurements: shirtMeasurements,
        trouserMeasurements: trouserMeasurements,
        pajamaMeasurements: pajamaMeasurements,
        suitMeasurements: suitMeasurements,
        shortsMeasurements: shortsMeasurements,
        kurtaMeasurements: kurtaMeasurements,
        safariMeasurements: safariMeasurements,
        notes: notes.trim(),
        createdDate: now,
        updatedDate: now,
      );

      await transaction.insert('customers', customer.toMap());
      await _syncQueue.enqueue(
        transaction,
        entityType: SyncEntityType.customer,
        entityId: customer.id,
        operation: SyncOperation.upsert,
        payload: customer.toMap(),
      );
      return customer;
    });
  }

  Future<List<Customer>> searchCustomers(String query) async {
    final database = _database;
    final normalized = query.trim();
    final searchTerm = normalized.toLowerCase();

    if (database == null) {
      final customers = _memoryCustomers!;
      if (normalized.isEmpty) {
        return List.unmodifiable(customers);
      }

      return customers.where((customer) {
        return customer.name.toLowerCase().contains(searchTerm) ||
            customer.phone.toLowerCase().contains(searchTerm) ||
            customer.customerNumber.toLowerCase().contains(searchTerm);
      }).toList(growable: false);
    }

    final rows = await database.query(
      'customers',
      where: normalized.isEmpty
          ? 'deleted_date IS NULL'
          : '''
deleted_date IS NULL AND (
  LOWER(name) LIKE ? OR LOWER(phone) LIKE ? OR LOWER(customer_number) LIKE ?
)
''',
      whereArgs: normalized.isEmpty
          ? null
          : ['%$searchTerm%', '%$searchTerm%', '%$searchTerm%'],
      orderBy: 'name COLLATE NOCASE ASC',
    );

    return rows.map(Customer.fromMap).toList(growable: false);
  }

  Future<Customer> updateCustomer(Customer customer) async {
    final updated = customer.copyWith(updatedDate: DateTime.now().toUtc());
    final database = _database;

    if (database == null) {
      final customers = _memoryCustomers!;
      final index = customers.indexWhere((item) => item.id == updated.id);
      if (index == -1) {
        throw StateError('Customer ${updated.id} does not exist.');
      }
      customers[index] = updated;
      return updated;
    }

    await database.transaction((transaction) async {
      await transaction.update(
        'customers',
        updated.toMap(),
        where: 'id = ?',
        whereArgs: [updated.id],
      );
      await _syncQueue.enqueue(
        transaction,
        entityType: SyncEntityType.customer,
        entityId: updated.id,
        operation: SyncOperation.upsert,
        payload: updated.toMap(),
      );
    });

    return updated;
  }

  Future<int> countCustomers() async {
    final database = _database;
    if (database == null) {
      return _memoryCustomers!.length;
    }

    final result = await database.rawQuery(
      'SELECT COUNT(*) AS count FROM customers WHERE deleted_date IS NULL',
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  Future<Customer?> getCustomerById(String id) async {
    final database = _database;
    if (database == null) {
      for (final customer in _memoryCustomers!) {
        if (customer.id == id) {
          return customer;
        }
      }
      return null;
    }

    final rows = await database.query(
      'customers',
      where: 'id = ? AND deleted_date IS NULL',
      whereArgs: [id],
      limit: 1,
    );
    return rows.isEmpty ? null : Customer.fromMap(rows.first);
  }

  Future<String> _nextCustomerNumber(Transaction transaction) async {
    final rows = await transaction.rawQuery(
      'SELECT MAX(CAST(SUBSTR(customer_number, 2) AS INTEGER)) AS number '
      'FROM customers',
    );
    final number = (rows.single['number'] as num?)?.toInt() ?? 0;
    final suffix = await deviceNumberSuffix(transaction);
    return 'C${(number + 1).toString().padLeft(6, '0')}$suffix';
  }
}
