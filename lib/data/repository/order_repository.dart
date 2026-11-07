import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import '../database/database_providers.dart';
import '../database/device_numbering.dart';
import '../models/sync_queue_entry.dart';
import '../models/tailor_order.dart';
import '../../features/sync/sync_queue_repository.dart';

final orderRepositoryProvider = FutureProvider<OrderRepository>((ref) async {
  if (kIsWeb) {
    return OrderRepository.memory();
  }

  final database = await ref.watch(databaseProvider.future);
  return OrderRepository(database);
});

final orderSearchQueryProvider = StateProvider<String>((ref) => '');
final orderStatusFilterProvider = StateProvider<OrderStatus?>((ref) => null);

final ordersProvider = FutureProvider<List<OrderListItem>>((ref) async {
  final query = ref.watch(orderSearchQueryProvider);
  final status = ref.watch(orderStatusFilterProvider);
  final repository = await ref.watch(orderRepositoryProvider.future);
  return repository.searchOrders(query: query, status: status);
});

final customerOrdersProvider =
    FutureProvider.family<List<OrderListItem>, String>((ref, customerId) async {
  final repository = await ref.watch(orderRepositoryProvider.future);
  return repository.ordersForCustomer(customerId);
});

class OrderRepository {
  OrderRepository(this._database, {Uuid? uuid, SyncQueueRepository? syncQueue})
      : _uuid = uuid ?? const Uuid(),
        _syncQueue = syncQueue ?? const SyncQueueRepository(),
        _memoryOrders = null;

  OrderRepository.memory({Uuid? uuid})
      : _database = null,
        _uuid = uuid ?? const Uuid(),
        _syncQueue = const SyncQueueRepository(),
        _memoryOrders = <OrderListItem>[];

  final Database? _database;
  final Uuid _uuid;
  final SyncQueueRepository _syncQueue;
  final List<OrderListItem>? _memoryOrders;
  final DateFormat _orderDateFormat = DateFormat('yyyyMMdd');

  Future<TailorOrder> createOrder({
    required String customerId,
    required DateTime deliveryDate,
    required String orderDetails,
    String comments = '',
    int quantity = 1,
    double amount = 0,
    double advancePaid = 0,
    OrderStatus status = OrderStatus.booked,
    String customerName = 'Local customer',
    String customerPhone = '',
  }) async {
    final created = await createOrders(
      customerId: customerId,
      customerName: customerName,
      customerPhone: customerPhone,
      drafts: [
        OrderDraft(
          itemType: orderDetails,
          comments: comments,
          quantity: quantity,
          deliveryDate: deliveryDate,
        ),
      ],
      amount: amount,
      advancePaid: advancePaid,
      status: status,
    );
    return created.single;
  }

  Future<List<TailorOrder>> createOrders({
    required String customerId,
    required String customerName,
    required String customerPhone,
    required List<OrderDraft> drafts,
    double amount = 0,
    double advancePaid = 0,
    OrderStatus status = OrderStatus.booked,
  }) async {
    if (drafts.isEmpty) {
      throw ArgumentError.value(
          drafts, 'drafts', 'At least one item is required');
    }
    if (drafts.any((draft) => !_isFutureDeliveryDate(draft.deliveryDate))) {
      throw ArgumentError.value(
        drafts,
        'drafts',
        'Delivery dates must be in the future.',
      );
    }

    final database = _database;
    if (database == null) {
      final orders = _memoryOrders!;
      final now = DateTime.now().toUtc();
      final created = <TailorOrder>[];
      for (final draft in drafts) {
        final prefix = 'ORD-${_orderDateFormat.format(now)}-';
        final dailyCount = orders
            .where((item) => item.order.orderNumber.startsWith(prefix))
            .length;
        final order = _createOrderFromDraft(
          id: _uuid.v4(),
          orderNumber: '$prefix${(dailyCount + 1).toString().padLeft(3, '0')}',
          customerId: customerId,
          draft: draft,
          amount: amount,
          advancePaid: advancePaid,
          status: status,
          now: now,
        );
        created.add(order);
        orders.add(
          OrderListItem(
            order: order,
            customerName: customerName,
            customerPhone: customerPhone,
          ),
        );
      }
      return created;
    }

    return database.transaction((transaction) async {
      final now = DateTime.now().toUtc();
      final created = <TailorOrder>[];
      for (final draft in drafts) {
        final order = _createOrderFromDraft(
          id: _uuid.v4(),
          orderNumber: await _nextOrderNumber(transaction, now),
          customerId: customerId,
          draft: draft,
          amount: amount,
          advancePaid: advancePaid,
          status: status,
          now: now,
        );
        await transaction.insert('orders', order.toMap());
        await _syncQueue.enqueue(
          transaction,
          entityType: SyncEntityType.order,
          entityId: order.id,
          operation: SyncOperation.upsert,
          payload: order.toMap(),
        );
        created.add(order);
      }
      return created;
    });
  }

  TailorOrder _createOrderFromDraft({
    required String id,
    required String orderNumber,
    required String customerId,
    required OrderDraft draft,
    required double amount,
    required double advancePaid,
    required OrderStatus status,
    required DateTime now,
  }) {
    return TailorOrder(
      id: id,
      orderNumber: orderNumber,
      customerId: customerId,
      bookingDate: now,
      deliveryDate: draft.deliveryDate,
      orderDetails: draft.itemType.trim(),
      comments: draft.comments.trim(),
      quantity: draft.quantity,
      amount: amount,
      advancePaid: advancePaid,
      status: status,
      createdDate: now,
      updatedDate: now,
    );
  }

  Future<TailorOrder> updateOrder(TailorOrder order) async {
    if (!_isFutureDeliveryDate(order.deliveryDate)) {
      throw ArgumentError.value(
        order.deliveryDate,
        'deliveryDate',
        'Delivery date must be in the future.',
      );
    }

    final updated = TailorOrder(
      id: order.id,
      orderNumber: order.orderNumber,
      customerId: order.customerId,
      bookingDate: order.bookingDate,
      deliveryDate: order.deliveryDate,
      orderDetails: order.orderDetails.trim(),
      comments: order.comments.trim(),
      quantity: order.quantity,
      amount: order.amount,
      advancePaid: order.advancePaid,
      status: order.status,
      createdDate: order.createdDate,
      updatedDate: DateTime.now().toUtc(),
      deletedDate: order.deletedDate,
    );
    final database = _database;

    if (database == null) {
      final orders = _memoryOrders!;
      final index = orders.indexWhere((item) => item.order.id == updated.id);
      if (index == -1) {
        throw StateError('Order ${updated.id} does not exist.');
      }
      final existing = orders[index];
      orders[index] = OrderListItem(
        order: updated,
        customerName: existing.customerName,
        customerPhone: existing.customerPhone,
      );
      return updated;
    }

    await database.transaction((transaction) async {
      await transaction.update(
        'orders',
        updated.toMap(),
        where: 'id = ?',
        whereArgs: [updated.id],
      );
      await _syncQueue.enqueue(
        transaction,
        entityType: SyncEntityType.order,
        entityId: updated.id,
        operation: SyncOperation.upsert,
        payload: updated.toMap(),
      );
    });
    return updated;
  }

  Future<void> deleteOrder(TailorOrder order) async {
    final now = DateTime.now().toUtc();
    final deleted = TailorOrder(
      id: order.id,
      orderNumber: order.orderNumber,
      customerId: order.customerId,
      bookingDate: order.bookingDate,
      deliveryDate: order.deliveryDate,
      orderDetails: order.orderDetails,
      comments: order.comments,
      quantity: order.quantity,
      amount: order.amount,
      advancePaid: order.advancePaid,
      status: order.status,
      createdDate: order.createdDate,
      updatedDate: now,
      deletedDate: now,
    );
    final database = _database;

    if (database == null) {
      _memoryOrders!.removeWhere((item) => item.order.id == order.id);
      return;
    }

    await database.transaction((transaction) async {
      await transaction.update(
        'orders',
        {
          'deleted_date': now.toIso8601String(),
          'updated_date': now.toIso8601String()
        },
        where: 'id = ?',
        whereArgs: [order.id],
      );
      await _syncQueue.enqueue(
        transaction,
        entityType: SyncEntityType.order,
        entityId: order.id,
        operation: SyncOperation.delete,
        payload: deleted.toMap(),
      );
    });
  }

  Future<TailorOrder> cancelOrder(TailorOrder order) async {
    final updated = TailorOrder(
      id: order.id,
      orderNumber: order.orderNumber,
      customerId: order.customerId,
      bookingDate: order.bookingDate,
      deliveryDate: order.deliveryDate,
      orderDetails: order.orderDetails,
      comments: order.comments,
      quantity: order.quantity,
      amount: order.amount,
      advancePaid: order.advancePaid,
      status: OrderStatus.cancelled,
      createdDate: order.createdDate,
      updatedDate: DateTime.now().toUtc(),
      deletedDate: order.deletedDate,
    );
    final database = _database;

    if (database == null) {
      final orders = _memoryOrders!;
      final index = orders.indexWhere((item) => item.order.id == order.id);
      if (index == -1) {
        throw StateError('Order ${order.id} does not exist.');
      }
      final existing = orders[index];
      orders[index] = OrderListItem(
        order: updated,
        customerName: existing.customerName,
        customerPhone: existing.customerPhone,
      );
      return updated;
    }

    await database.transaction((transaction) async {
      await transaction.update(
        'orders',
        updated.toMap(),
        where: 'id = ?',
        whereArgs: [updated.id],
      );
      await _syncQueue.enqueue(
        transaction,
        entityType: SyncEntityType.order,
        entityId: updated.id,
        operation: SyncOperation.upsert,
        payload: updated.toMap(),
      );
    });

    return updated;
  }

  Future<List<OrderListItem>> searchOrders({
    String query = '',
    OrderStatus? status,
  }) async {
    final database = _database;
    final normalized = query.trim();

    if (database == null) {
      return _memoryOrders!.where((item) {
        final matchesStatus = status == null || item.order.status == status;
        if (!matchesStatus) {
          return false;
        }

        if (normalized.isEmpty) {
          return true;
        }

        final lowerQuery = normalized.toLowerCase();
        return item.order.orderNumber.toLowerCase().contains(lowerQuery) ||
            item.customerName.toLowerCase().contains(lowerQuery) ||
            item.customerPhone.contains(normalized);
      }).toList(growable: false);
    }

    final where = <String>['o.deleted_date IS NULL', 'c.deleted_date IS NULL'];
    final args = <Object?>[];

    if (normalized.isNotEmpty) {
      where.add('''
(o.order_number LIKE ? OR c.name LIKE ? OR c.phone LIKE ?)
''');
      args.addAll(['%$normalized%', '%$normalized%', '%$normalized%']);
    }

    if (status != null) {
      where.add('o.status = ?');
      args.add(status.name);
    }

    final rows = await database.rawQuery(
      '''
SELECT o.*, c.name AS customer_name, c.phone AS customer_phone
FROM orders o
JOIN customers c ON c.id = o.customer_id
WHERE ${where.join(' AND ')}
ORDER BY o.delivery_date ASC, o.created_date ASC
''',
      args,
    );

    return rows.map(OrderListItem.fromMap).toList(growable: false);
  }

  Future<List<OrderListItem>> ordersForCustomer(String customerId) async {
    final database = _database;
    if (database == null) {
      return _memoryOrders!
          .where((item) => item.order.customerId == customerId)
          .toList(growable: false);
    }

    final rows = await database.rawQuery(
      '''
SELECT o.*, c.name AS customer_name, c.phone AS customer_phone
FROM orders o
JOIN customers c ON c.id = o.customer_id
WHERE o.customer_id = ?
  AND o.deleted_date IS NULL
  AND c.deleted_date IS NULL
ORDER BY o.delivery_date ASC, o.created_date ASC
''',
      [customerId],
    );

    return rows.map(OrderListItem.fromMap).toList(growable: false);
  }

  Future<int> countPendingOrders() async {
    final database = _database;
    if (database == null) {
      return _memoryOrders!
          .where((item) =>
              item.order.status != OrderStatus.delivered &&
              item.order.status != OrderStatus.cancelled)
          .length;
    }

    final result = await database.rawQuery(
      '''
SELECT COUNT(*) AS count FROM orders
WHERE deleted_date IS NULL AND status NOT IN (?, ?)
''',
      [OrderStatus.delivered.name, OrderStatus.cancelled.name],
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  Future<int> countDeliveredOrders() async {
    final database = _database;
    if (database == null) {
      return _memoryOrders!
          .where((item) => item.order.status == OrderStatus.delivered)
          .length;
    }

    final result = await database.rawQuery(
      'SELECT COUNT(*) AS count FROM orders WHERE deleted_date IS NULL AND status = ?',
      [OrderStatus.delivered.name],
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  Future<List<OrderListItem>> todaysDeliveries() async {
    final database = _database;
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day).toIso8601String();
    final end = DateTime(now.year, now.month, now.day + 1).toIso8601String();

    if (database == null) {
      final startDate = DateTime.parse(start);
      final endDate = DateTime.parse(end);
      return _memoryOrders!.where((item) {
        return !item.order.deliveryDate.isBefore(startDate) &&
            item.order.deliveryDate.isBefore(endDate);
      }).toList(growable: false);
    }

    final rows = await database.rawQuery(
      '''
SELECT o.*, c.name AS customer_name, c.phone AS customer_phone
FROM orders o
JOIN customers c ON c.id = o.customer_id
WHERE o.deleted_date IS NULL
  AND c.deleted_date IS NULL
  AND o.delivery_date >= ?
  AND o.delivery_date < ?
ORDER BY o.delivery_date ASC
''',
      [start, end],
    );

    return rows.map(OrderListItem.fromMap).toList(growable: false);
  }

  Future<String> _nextOrderNumber(
      Transaction transaction, DateTime date) async {
    final dayKey = _orderDateFormat.format(date);
    final prefix = 'ORD-$dayKey-';
    final rows = await transaction.rawQuery(
      'SELECT MAX(CAST(SUBSTR(order_number, ?) AS INTEGER)) AS number '
      'FROM orders WHERE order_number LIKE ?',
      [prefix.length + 1, '$prefix%'],
    );
    final sequence = (rows.single['number'] as num?)?.toInt() ?? 0;
    final suffix = await deviceNumberSuffix(transaction);
    return '$prefix${(sequence + 1).toString().padLeft(3, '0')}$suffix';
  }
}

bool _isFutureDeliveryDate(DateTime date) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final deliveryDay = DateTime(date.year, date.month, date.day);
  return deliveryDay.isAfter(today);
}

class OrderListItem {
  const OrderListItem({
    required this.order,
    required this.customerName,
    required this.customerPhone,
  });

  final TailorOrder order;
  final String customerName;
  final String customerPhone;

  factory OrderListItem.fromMap(Map<String, Object?> map) {
    return OrderListItem(
      order: TailorOrder.fromMap(map),
      customerName: map['customer_name'] as String,
      customerPhone: map['customer_phone'] as String,
    );
  }
}
