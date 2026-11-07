import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../data/models/customer.dart';
import '../../data/models/tailor_order.dart';
import '../../data/repository/customer_repository.dart';
import '../../data/repository/order_repository.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/order_status_chip.dart';
import '../../widgets/brand_title.dart';
import '../dashboard/dashboard_screen.dart';
import 'inline_order_editor.dart';
import 'order_print_service.dart';

enum _OrderSortField {
  orderNumber('Order Number'),
  itemType('Order Item/Type'),
  customerName('Customer Name'),
  deliveryDate('Delivery Date');

  const _OrderSortField(this.label);

  final String label;
}

class OrdersScreen extends ConsumerStatefulWidget {
  const OrdersScreen({super.key});

  @override
  ConsumerState<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends ConsumerState<OrdersScreen> {
  _OrderSortField _sortField = _OrderSortField.deliveryDate;
  var _ascending = true;

  @override
  Widget build(BuildContext context) {
    final orders = ref.watch(ordersProvider);
    final selectedStatus = ref.watch(orderStatusFilterProvider);

    return Scaffold(
      appBar: AppBar(title: const BrandTitle(title: 'Orders')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                TextField(
                  decoration: const InputDecoration(
                    labelText: 'Search orders',
                    prefixIcon: Icon(Icons.search),
                  ),
                  onChanged: (value) {
                    ref.read(orderSearchQueryProvider.notifier).state = value;
                  },
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<OrderStatus?>(
                  initialValue: selectedStatus,
                  decoration: const InputDecoration(labelText: 'Status'),
                  items: [
                    const DropdownMenuItem<OrderStatus?>(
                      value: null,
                      child: Text('All'),
                    ),
                    ...OrderStatus.values
                        .where((status) =>
                            status != OrderStatus.delivered &&
                            status != OrderStatus.cancelled)
                        .map(
                          (status) => DropdownMenuItem<OrderStatus?>(
                            value: status,
                            child: Text(status.label),
                          ),
                        ),
                  ],
                  onChanged: (value) {
                    ref.read(orderStatusFilterProvider.notifier).state = value;
                  },
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<_OrderSortField>(
                        key: const ValueKey('order-sort-field'),
                        initialValue: _sortField,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Sort by',
                          prefixIcon: Icon(Icons.sort),
                          isDense: true,
                        ),
                        items: [
                          for (final field in _OrderSortField.values)
                            DropdownMenuItem(
                              value: field,
                              child: Text(field.label),
                            ),
                        ],
                        onChanged: (field) {
                          if (field != null) {
                            setState(() => _sortField = field);
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      tooltip:
                          _ascending ? 'Sort descending' : 'Sort ascending',
                      onPressed: () => setState(() => _ascending = !_ascending),
                      icon: Icon(
                        _ascending ? Icons.arrow_upward : Icons.arrow_downward,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: orders.when(
              data: (items) {
                final activeItems = items
                    .where((item) =>
                        item.order.status != OrderStatus.delivered &&
                        item.order.status != OrderStatus.cancelled)
                    .toList();
                activeItems.sort(_compareOrders);
                if (activeItems.isEmpty) {
                  return const EmptyState(message: 'No orders found');
                }
                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  itemCount: activeItems.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, index) => _OrderTile(
                    item: activeItems[index],
                    onCancel: () =>
                        _cancelOrder(context, ref, activeItems[index]),
                    onPrint: () =>
                        _printOrder(context, ref, activeItems[index]),
                  ),
                );
              },
              error: (error, stackTrace) =>
                  EmptyState(message: 'Unable to load orders: $error'),
              loading: () => const Center(child: CircularProgressIndicator()),
            ),
          ),
        ],
      ),
    );
  }

  int _compareOrders(OrderListItem left, OrderListItem right) {
    final comparison = switch (_sortField) {
      _OrderSortField.orderNumber =>
        left.order.orderNumber.toLowerCase().compareTo(
              right.order.orderNumber.toLowerCase(),
            ),
      _OrderSortField.itemType =>
        left.order.orderDetails.toLowerCase().compareTo(
              right.order.orderDetails.toLowerCase(),
            ),
      _OrderSortField.customerName => left.customerName.toLowerCase().compareTo(
            right.customerName.toLowerCase(),
          ),
      _OrderSortField.deliveryDate =>
        left.order.deliveryDate.compareTo(right.order.deliveryDate),
    };

    if (comparison != 0) {
      return _ascending ? comparison : -comparison;
    }
    return left.order.orderNumber.compareTo(right.order.orderNumber);
  }
}

class _OrderTile extends ConsumerStatefulWidget {
  const _OrderTile({
    required this.item,
    required this.onCancel,
    required this.onPrint,
  });

  final OrderListItem item;
  final VoidCallback onCancel;
  final VoidCallback onPrint;

  @override
  ConsumerState<_OrderTile> createState() => _OrderTileState();
}

class _OrderTileState extends ConsumerState<_OrderTile> {
  var _editing = false;

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final order = item.order;
    final orderedDate = DateFormat('dd MMM yyyy').format(order.bookingDate);
    final deliveryDate = DateFormat('dd MMM yyyy').format(order.deliveryDate);

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    order.orderDetails,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ),
                OrderStatusChip(status: order.status),
              ],
            ),
            const SizedBox(height: 4),
            Text('${item.customerName}  ·  Qty: ${order.quantity}'),
            if (order.comments.isNotEmpty) Text('Comments: ${order.comments}'),
            const SizedBox(height: 8),
            Wrap(
              spacing: 18,
              runSpacing: 6,
              children: [
                Text('Ordered: $orderedDate'),
                Text('Delivery: $deliveryDate'),
                Text(order.orderNumber),
              ],
            ),
            const SizedBox(height: 4),
            Align(
              alignment: Alignment.centerRight,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    tooltip: 'Print order',
                    onPressed: widget.onPrint,
                    icon: const Icon(Icons.print_outlined),
                  ),
                  IconButton(
                    tooltip: _editing ? 'Close order editor' : 'Edit order',
                    onPressed: () => setState(() => _editing = !_editing),
                    icon: const Icon(Icons.edit_outlined),
                  ),
                  IconButton(
                    tooltip: 'Cancel order',
                    onPressed: widget.onCancel,
                    icon: const Icon(Icons.cancel_outlined),
                  ),
                ],
              ),
            ),
            if (_editing)
              InlineOrderEditor(
                order: order,
                onCancel: () => setState(() => _editing = false),
                onSaved: () {
                  setState(() => _editing = false);
                  ref.invalidate(ordersProvider);
                  ref.invalidate(customerOrdersProvider(order.customerId));
                  ref.invalidate(dashboardProvider);
                },
              ),
          ],
        ),
      ),
    );
  }
}

Future<void> _cancelOrder(
  BuildContext context,
  WidgetRef ref,
  OrderListItem item,
) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Cancel order?'),
      content: Text(
          'Cancel ${item.order.orderDetails} order ${item.order.orderNumber}?'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Cancel Order'),
        ),
      ],
    ),
  );
  if (confirmed != true || !context.mounted) {
    return;
  }

  final repository = await ref.read(orderRepositoryProvider.future);
  await repository.cancelOrder(item.order);
  ref.invalidate(ordersProvider);
  ref.invalidate(customerOrdersProvider(item.order.customerId));
  ref.invalidate(dashboardProvider);
}

Future<void> _printOrder(
  BuildContext context,
  WidgetRef ref,
  OrderListItem item,
) async {
  final customer = await _loadOrderCustomer(ref, item.order.customerId);
  if (customer == null) {
    return;
  }
  try {
    await OrderPrintService.printDrafts(
      customer: customer,
      orderedDate: item.order.bookingDate,
      orderNumber: item.order.orderNumber,
      drafts: [
        OrderDraft(
          itemType: item.order.orderDetails,
          comments: item.order.comments,
          quantity: item.order.quantity,
          deliveryDate: item.order.deliveryDate,
        ),
      ],
    );
  } on Object catch (error) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to print order: $error')),
      );
    }
  }
}

Future<Customer?> _loadOrderCustomer(WidgetRef ref, String customerId) async {
  return ref.read(customerByIdProvider(customerId).future);
}
