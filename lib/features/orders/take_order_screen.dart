import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../data/models/customer.dart';
import '../../data/models/tailor_order.dart';
import '../../data/repository/order_repository.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/order_status_chip.dart';
import '../../widgets/brand_title.dart';
import '../dashboard/dashboard_screen.dart';
import 'inline_order_editor.dart';
import 'order_print_service.dart';

const _orderItemTypes = [
  'Shirt',
  'Trousers',
  'Shorts',
  'Kurta',
  'Pajama',
  'Suit',
  'Safari',
  'Other',
];

class TakeOrderScreen extends ConsumerStatefulWidget {
  const TakeOrderScreen({super.key, required this.customer, this.order});

  final Customer customer;
  final TailorOrder? order;

  @override
  ConsumerState<TakeOrderScreen> createState() => _TakeOrderScreenState();
}

class _TakeOrderScreenState extends ConsumerState<TakeOrderScreen> {
  final _formKey = GlobalKey<FormState>();
  final _dateFormat = DateFormat('dd-MM-yyyy');
  late final List<_OrderEntryState> _entries;
  var _isSaving = false;

  @override
  void initState() {
    super.initState();
    final order = widget.order;
    _entries = [
      if (order != null)
        _OrderEntryState.fromOrder(order)
      else
        _OrderEntryState(),
    ];
  }

  @override
  void dispose() {
    for (final entry in _entries) {
      entry.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final orderList = ref.watch(customerOrdersProvider(widget.customer.id));

    return Scaffold(
      appBar: AppBar(title: const BrandTitle(title: 'Take Order')),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            children: [
              _CustomerSummary(customer: widget.customer),
              const SizedBox(height: 16),
              for (var index = 0; index < _entries.length; index++) ...[
                _OrderEntryCard(
                  key: ValueKey(_entries[index]),
                  entry: _entries[index],
                  index: index,
                  canRemove: _entries.length > 1,
                  onChanged: () => setState(() {}),
                  onRemove: () => _removeEntry(index),
                  dateFormat: _dateFormat,
                ),
                const SizedBox(height: 10),
              ],
              Align(
                alignment: Alignment.centerLeft,
                child: FilledButton.icon(
                  onPressed: _isSaving ? null : _addEntry,
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF239B56),
                  ),
                  icon: const Icon(Icons.add),
                  label: const Text('Add more'),
                ),
              ),
              const SizedBox(height: 24),
              Text('Existing Orders',
                  style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 10),
              orderList.when(
                data: (orders) => orders.isEmpty
                    ? const EmptyState(
                        message: 'No orders for this customer yet')
                    : Column(
                        children: [
                          for (final item in orders)
                            _ExistingOrderCard(
                              item: item,
                              dateFormat: _dateFormat,
                              onCancel: () => _cancelOrder(item.order),
                              onPrint: () => _printExisting(item.order),
                              onSaved: _refreshOrders,
                            ),
                        ],
                      ),
                error: (error, stackTrace) => EmptyState(
                  message: 'Unable to load orders: $error',
                ),
                loading: () => const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(child: CircularProgressIndicator()),
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _isSaving ? null : _printDrafts,
                  icon: const Icon(Icons.print_outlined),
                  label: const Text('Print'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton.icon(
                  onPressed: _isSaving ? null : _save,
                  icon: const Icon(Icons.save_outlined),
                  label: Text(_isSaving ? 'Saving...' : 'Save Order'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _addEntry() {
    setState(() => _entries.add(_OrderEntryState()));
  }

  void _removeEntry(int index) {
    setState(() {
      _entries.removeAt(index).dispose();
    });
  }

  List<OrderDraft> _drafts() {
    return _entries
        .map(
          (entry) => OrderDraft(
            itemType: entry.itemType ?? '',
            comments: entry.commentsController.text.trim(),
            quantity: entry.quantity,
            deliveryDate: entry.deliveryDate,
          ),
        )
        .toList(growable: false);
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    setState(() => _isSaving = true);
    try {
      final repository = await ref.read(orderRepositoryProvider.future);
      final drafts = _drafts();
      final existing = widget.order;

      if (existing == null) {
        await repository.createOrders(
          customerId: widget.customer.id,
          customerName: widget.customer.name,
          customerPhone: widget.customer.phone,
          drafts: drafts,
        );
      } else {
        final first = drafts.first;
        await repository.updateOrder(
          TailorOrder(
            id: existing.id,
            orderNumber: existing.orderNumber,
            customerId: existing.customerId,
            bookingDate: existing.bookingDate,
            deliveryDate: first.deliveryDate,
            orderDetails: first.itemType,
            comments: first.comments,
            quantity: first.quantity,
            amount: existing.amount,
            advancePaid: existing.advancePaid,
            status: existing.status,
            createdDate: existing.createdDate,
            updatedDate: DateTime.now().toUtc(),
          ),
        );
        if (drafts.length > 1) {
          await repository.createOrders(
            customerId: widget.customer.id,
            customerName: widget.customer.name,
            customerPhone: widget.customer.phone,
            drafts: drafts.skip(1).toList(growable: false),
          );
        }
      }

      _refreshOrders();
      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } on Object catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Unable to save order: $error')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Future<void> _printDrafts() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    await _print(_drafts(), DateTime.now());
  }

  Future<void> _printExisting(TailorOrder order) async {
    await _print(
      [
        OrderDraft(
          itemType: order.orderDetails,
          comments: order.comments,
          quantity: order.quantity,
          deliveryDate: order.deliveryDate,
        ),
      ],
      order.bookingDate,
      orderNumber: order.orderNumber,
    );
  }

  Future<void> _print(
    List<OrderDraft> drafts,
    DateTime orderedDate, {
    String? orderNumber,
  }) async {
    try {
      await OrderPrintService.printDrafts(
        customer: widget.customer,
        drafts: drafts,
        orderedDate: orderedDate,
        orderNumber: orderNumber,
      );
    } on Object catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Unable to print order: $error')),
        );
      }
    }
  }

  Future<void> _cancelOrder(TailorOrder order) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel order?'),
        content:
            Text('Cancel ${order.orderDetails} order ${order.orderNumber}?'),
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

    if (confirmed != true || !mounted) {
      return;
    }
    final repository = await ref.read(orderRepositoryProvider.future);
    await repository.cancelOrder(order);
    _refreshOrders();
  }

  void _refreshOrders() {
    ref.invalidate(customerOrdersProvider(widget.customer.id));
    ref.invalidate(ordersProvider);
    ref.invalidate(dashboardProvider);
  }
}

class _CustomerSummary extends StatelessWidget {
  const _CustomerSummary({required this.customer});

  final Customer customer;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 720;
        final fields = [
          _SummaryField(label: 'Customer ID', value: customer.customerNumber),
          _SummaryField(label: 'Name', value: customer.name),
          _SummaryField(label: 'Phone', value: customer.phone),
        ];
        return Wrap(
          spacing: 14,
          runSpacing: 10,
          children: [
            for (final field in fields)
              SizedBox(
                width: wide
                    ? (constraints.maxWidth - 28) / 3
                    : constraints.maxWidth,
                child: field,
              ),
          ],
        );
      },
    );
  }
}

class _SummaryField extends StatelessWidget {
  const _SummaryField({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return InputDecorator(
      decoration: InputDecoration(labelText: label, isDense: true),
      child: Text(value, maxLines: 1, overflow: TextOverflow.ellipsis),
    );
  }
}

class _OrderEntryState {
  _OrderEntryState({
    this.itemType,
    String comments = '',
    this.quantity = 1,
    DateTime? deliveryDate,
  })  : commentsController = TextEditingController(text: comments),
        deliveryDate = deliveryDate ?? _tomorrow();

  factory _OrderEntryState.fromOrder(TailorOrder order) {
    return _OrderEntryState(
      itemType: order.orderDetails,
      comments: order.comments,
      quantity: order.quantity,
      deliveryDate: order.deliveryDate,
    );
  }

  String? itemType;
  final TextEditingController commentsController;
  int quantity;
  DateTime deliveryDate;

  void dispose() => commentsController.dispose();
}

class _OrderEntryCard extends StatelessWidget {
  const _OrderEntryCard({
    super.key,
    required this.entry,
    required this.index,
    required this.canRemove,
    required this.onChanged,
    required this.onRemove,
    required this.dateFormat,
  });

  final _OrderEntryState entry;
  final int index;
  final bool canRemove;
  final VoidCallback onChanged;
  final VoidCallback onRemove;
  final DateFormat dateFormat;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Order Item ${index + 1}',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ),
                if (canRemove)
                  IconButton(
                    tooltip: 'Remove item',
                    onPressed: onRemove,
                    icon: const Icon(Icons.delete_outline),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            LayoutBuilder(
              builder: (context, constraints) {
                final wide = constraints.maxWidth >= 720;
                final itemField = DropdownButtonFormField<String>(
                  initialValue: entry.itemType,
                  decoration: const InputDecoration(
                    labelText: 'Order Item / Type',
                    isDense: true,
                  ),
                  items: [
                    for (final type in _orderItemTypes)
                      DropdownMenuItem(value: type, child: Text(type)),
                  ],
                  validator: (value) => value == null || value.isEmpty
                      ? 'Select an item type'
                      : null,
                  onChanged: (value) {
                    entry.itemType = value;
                    onChanged();
                  },
                );
                final commentsField = TextFormField(
                  controller: entry.commentsController,
                  decoration: const InputDecoration(
                    labelText: 'Comments',
                    hintText: 'Comments',
                    isDense: true,
                  ),
                  maxLines: wide ? 1 : 2,
                );
                final quantityField = _QuantityStepper(
                  quantity: entry.quantity,
                  onChanged: (value) {
                    entry.quantity = value;
                    onChanged();
                  },
                );
                final deliveryField = _DeliveryDateField(
                  date: entry.deliveryDate,
                  dateFormat: dateFormat,
                  onChanged: (value) {
                    entry.deliveryDate = value;
                    onChanged();
                  },
                );

                if (wide) {
                  return Column(
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(flex: 3, child: itemField),
                          const SizedBox(width: 12),
                          Expanded(flex: 5, child: commentsField),
                          const SizedBox(width: 12),
                          SizedBox(width: 148, child: quantityField),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: SizedBox(width: 260, child: deliveryField),
                      ),
                    ],
                  );
                }

                return Column(
                  children: [
                    itemField,
                    const SizedBox(height: 12),
                    commentsField,
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(child: quantityField),
                        const SizedBox(width: 12),
                        Expanded(child: deliveryField),
                      ],
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _QuantityStepper extends StatelessWidget {
  const _QuantityStepper({required this.quantity, required this.onChanged});

  final int quantity;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return InputDecorator(
      decoration: const InputDecoration(labelText: 'Quantity', isDense: true),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            tooltip: 'Decrease quantity',
            onPressed: quantity > 1 ? () => onChanged(quantity - 1) : null,
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.remove),
          ),
          Text('$quantity', style: Theme.of(context).textTheme.titleMedium),
          IconButton(
            tooltip: 'Increase quantity',
            onPressed: () => onChanged(quantity + 1),
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.add),
          ),
        ],
      ),
    );
  }
}

class _DeliveryDateField extends StatelessWidget {
  const _DeliveryDateField({
    required this.date,
    required this.dateFormat,
    required this.onChanged,
  });

  final DateTime date;
  final DateFormat dateFormat;
  final ValueChanged<DateTime> onChanged;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () async {
        final selected = await showDatePicker(
          context: context,
          initialDate: _isFutureDate(date) ? date : _tomorrow(),
          firstDate: _tomorrow(),
          lastDate: DateTime(2100),
        );
        if (selected != null) {
          onChanged(selected);
        }
      },
      child: InputDecorator(
        decoration: const InputDecoration(
          labelText: 'Delivery Date',
          suffixIcon: Icon(Icons.calendar_month_outlined),
          isDense: true,
        ),
        child: Text(dateFormat.format(date)),
      ),
    );
  }
}

class _ExistingOrderCard extends StatefulWidget {
  const _ExistingOrderCard({
    required this.item,
    required this.dateFormat,
    required this.onCancel,
    required this.onPrint,
    required this.onSaved,
  });

  final OrderListItem item;
  final DateFormat dateFormat;
  final VoidCallback onCancel;
  final VoidCallback onPrint;
  final VoidCallback onSaved;

  @override
  State<_ExistingOrderCard> createState() => _ExistingOrderCardState();
}

class _ExistingOrderCardState extends State<_ExistingOrderCard> {
  var _editing = false;

  @override
  Widget build(BuildContext context) {
    final order = widget.item.order;
    final textTheme = Theme.of(context).textTheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    order.orderDetails,
                    style: textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
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
            Text('Qty: ${order.quantity}'),
            if (order.comments.isNotEmpty) Text('Comments: ${order.comments}'),
            const SizedBox(height: 6),
            Wrap(
              spacing: 18,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text('Ordered: ${widget.dateFormat.format(order.bookingDate)}'),
                Text(
                    'Delivery: ${widget.dateFormat.format(order.deliveryDate)}'),
                OrderStatusChip(status: order.status),
              ],
            ),
            if (_editing)
              InlineOrderEditor(
                order: order,
                onCancel: () => setState(() => _editing = false),
                onSaved: () {
                  setState(() => _editing = false);
                  widget.onSaved();
                },
              ),
          ],
        ),
      ),
    );
  }
}

DateTime _tomorrow() {
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day + 1);
}

bool _isFutureDate(DateTime date) {
  final now = DateTime.now();
  return DateTime(date.year, date.month, date.day)
      .isAfter(DateTime(now.year, now.month, now.day));
}
