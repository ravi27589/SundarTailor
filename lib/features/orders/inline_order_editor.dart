import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../data/models/tailor_order.dart';
import '../../data/repository/order_repository.dart';

class InlineOrderEditor extends ConsumerStatefulWidget {
  const InlineOrderEditor({
    super.key,
    required this.order,
    required this.onCancel,
    required this.onSaved,
  });

  final TailorOrder order;
  final VoidCallback onCancel;
  final VoidCallback onSaved;

  @override
  ConsumerState<InlineOrderEditor> createState() => _InlineOrderEditorState();
}

class _InlineOrderEditorState extends ConsumerState<InlineOrderEditor> {
  late DateTime _deliveryDate;
  late OrderStatus _status;
  var _isSaving = false;

  @override
  void initState() {
    super.initState();
    _deliveryDate = widget.order.deliveryDate;
    _status = OrderStatus.editableStatuses.contains(widget.order.status)
        ? widget.order.status
        : OrderStatus.booked;
  }

  @override
  void didUpdateWidget(covariant InlineOrderEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.order.id != widget.order.id ||
        oldWidget.order.updatedDate != widget.order.updatedDate) {
      _deliveryDate = widget.order.deliveryDate;
      _status = OrderStatus.editableStatuses.contains(widget.order.status)
          ? widget.order.status
          : OrderStatus.booked;
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 660;
        final dateField = _DeliveryDateControl(
          date: _deliveryDate,
          onChanged: (date) => setState(() => _deliveryDate = date),
        );
        final statusField = DropdownButtonFormField<OrderStatus>(
          initialValue: _status,
          decoration: const InputDecoration(
            labelText: 'Status',
            isDense: true,
          ),
          items: [
            for (final status in OrderStatus.editableStatuses)
              DropdownMenuItem(value: status, child: Text(status.label)),
          ],
          onChanged: _isSaving
              ? null
              : (status) {
                  if (status != null) {
                    setState(() => _status = status);
                  }
                },
        );
        final actions = Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextButton(
                onPressed: _isSaving ? null : widget.onCancel,
                child: const Text('Cancel')),
            const SizedBox(width: 8),
            FilledButton.icon(
              onPressed: _isSaving ? null : _save,
              icon: const Icon(Icons.save_outlined, size: 18),
              label: Text(_isSaving ? 'Saving...' : 'Save'),
            ),
          ],
        );

        return Container(
          margin: const EdgeInsets.only(top: 10),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFF7F9FB),
            border: Border.all(color: const Color(0xFFD9DEE3)),
            borderRadius: BorderRadius.circular(6),
          ),
          child: wide
              ? Row(
                  children: [
                    Expanded(child: dateField),
                    const SizedBox(width: 12),
                    Expanded(child: statusField),
                    const SizedBox(width: 8),
                    actions,
                  ],
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    dateField,
                    const SizedBox(height: 12),
                    statusField,
                    const SizedBox(height: 8),
                    Align(alignment: Alignment.centerRight, child: actions),
                  ],
                ),
        );
      },
    );
  }

  Future<void> _save() async {
    if (!_isFutureDate(_deliveryDate)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Delivery date must be in the future.')),
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      final repository = await ref.read(orderRepositoryProvider.future);
      await repository.updateOrder(
        TailorOrder(
          id: widget.order.id,
          orderNumber: widget.order.orderNumber,
          customerId: widget.order.customerId,
          bookingDate: widget.order.bookingDate,
          deliveryDate: _deliveryDate,
          orderDetails: widget.order.orderDetails,
          comments: widget.order.comments,
          quantity: widget.order.quantity,
          amount: widget.order.amount,
          advancePaid: widget.order.advancePaid,
          status: _status,
          createdDate: widget.order.createdDate,
          updatedDate: widget.order.updatedDate,
          deletedDate: widget.order.deletedDate,
        ),
      );
      if (mounted) {
        widget.onSaved();
      }
    } on Object catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Unable to update order: $error')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }
}

class _DeliveryDateControl extends StatelessWidget {
  const _DeliveryDateControl({required this.date, required this.onChanged});

  final DateTime date;
  final ValueChanged<DateTime> onChanged;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () async {
        final tomorrow = _tomorrow();
        final initialDate = _isFutureDate(date) ? date : tomorrow;
        final selected = await showDatePicker(
          context: context,
          initialDate: initialDate,
          firstDate: tomorrow,
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
        child: Text(DateFormat('dd-MM-yyyy').format(date)),
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
