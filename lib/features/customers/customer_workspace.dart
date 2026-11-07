import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../data/models/customer.dart';
import '../../data/repository/order_repository.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/order_status_chip.dart';

class CustomerWorkspace extends StatefulWidget {
  const CustomerWorkspace({
    super.key,
    required this.customers,
    required this.searchController,
    required this.onSearch,
    required this.onClearSearch,
    required this.onAdd,
    required this.onEdit,
    required this.onTakeOrder,
  });

  final List<Customer> customers;
  final TextEditingController searchController;
  final ValueChanged<String> onSearch;
  final VoidCallback onClearSearch;
  final VoidCallback onAdd;
  final ValueChanged<Customer> onEdit;
  final ValueChanged<Customer> onTakeOrder;

  @override
  State<CustomerWorkspace> createState() => _CustomerWorkspaceState();
}

class _CustomerWorkspaceState extends State<CustomerWorkspace> {
  String? _selectedCustomerId;

  Customer? get _selectedCustomer {
    for (final customer in widget.customers) {
      if (customer.id == _selectedCustomerId) {
        return customer;
      }
    }
    return widget.customers.isEmpty ? null : widget.customers.first;
  }

  @override
  Widget build(BuildContext context) {
    final selected = _selectedCustomer;

    return Row(
      children: [
        Expanded(
          flex: 48,
          child: _CustomerTablePanel(
            customers: widget.customers,
            searchController: widget.searchController,
            onSearch: widget.onSearch,
            onClearSearch: widget.onClearSearch,
            selectedCustomer: selected,
            onSelect: (customer) => setState(() {
              _selectedCustomerId = customer.id;
            }),
            onAdd: widget.onAdd,
            onEdit: widget.onEdit,
            onTakeOrder: widget.onTakeOrder,
          ),
        ),
        const VerticalDivider(width: 1),
        Expanded(
          flex: 52,
          child: selected == null
              ? const EmptyState(message: 'Select a customer to see details')
              : _CustomerDetailPanel(
                  customer: selected,
                  rowNumber: widget.customers.indexOf(selected) + 1,
                  onEdit: () => widget.onEdit(selected),
                ),
        ),
      ],
    );
  }
}

class _CustomerTablePanel extends StatelessWidget {
  const _CustomerTablePanel({
    required this.customers,
    required this.searchController,
    required this.onSearch,
    required this.onClearSearch,
    required this.selectedCustomer,
    required this.onSelect,
    required this.onAdd,
    required this.onEdit,
    required this.onTakeOrder,
  });

  final List<Customer> customers;
  final TextEditingController searchController;
  final ValueChanged<String> onSearch;
  final VoidCallback onClearSearch;
  final Customer? selectedCustomer;
  final ValueChanged<Customer> onSelect;
  final VoidCallback onAdd;
  final ValueChanged<Customer> onEdit;
  final ValueChanged<Customer> onTakeOrder;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
          child: Row(
            children: [
              FilledButton.icon(
                onPressed: onAdd,
                icon: const Icon(Icons.person_add_alt_1, size: 18),
                label: const Text('Add New Customer'),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: SizedBox(
                  height: 44,
                  child: TextField(
                    controller: searchController,
                    decoration: const InputDecoration(
                      hintText: 'Search customers',
                      prefixIcon: Icon(Icons.search),
                      contentPadding: EdgeInsets.symmetric(vertical: 10),
                    ).copyWith(
                      suffixIcon: ValueListenableBuilder<TextEditingValue>(
                        valueListenable: searchController,
                        builder: (context, value, child) => value.text.isEmpty
                            ? const SizedBox.shrink()
                            : IconButton(
                                tooltip: 'Clear search',
                                onPressed: onClearSearch,
                                icon: const Icon(Icons.clear),
                              ),
                      ),
                    ),
                    onChanged: onSearch,
                  ),
                ),
              ),
            ],
          ),
        ),
        const _CustomerTableHeader(),
        Expanded(
          child: customers.isEmpty
              ? const EmptyState(message: 'No customers found')
              : ListView.builder(
                  itemCount: customers.length,
                  itemBuilder: (context, index) {
                    final customer = customers[index];
                    return _CustomerTableRow(
                      rowNumber: index + 1,
                      customer: customer,
                      selected: customer.id == selectedCustomer?.id,
                      onSelect: () => onSelect(customer),
                      onEdit: () => onEdit(customer),
                      onTakeOrder: () => onTakeOrder(customer),
                    );
                  },
                ),
        ),
        Container(
          height: 34,
          alignment: Alignment.centerLeft,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: const BoxDecoration(
            border: Border(top: BorderSide(color: Color(0xFFD9DEE3))),
          ),
          child: Text('${customers.length} customers'),
        ),
      ],
    );
  }
}

class _CustomerTableHeader extends StatelessWidget {
  const _CustomerTableHeader();

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.labelLarge?.copyWith(
          fontWeight: FontWeight.w700,
          color: const Color(0xFF202124),
        );

    return Container(
      height: 44,
      decoration: const BoxDecoration(
        color: Color(0xFFF1F3F5),
        border:
            Border.symmetric(horizontal: BorderSide(color: Color(0xFFD9DEE3))),
      ),
      child: Row(
        children: [
          _TableCell(flex: 1, child: Text('No.', style: style)),
          _TableCell(flex: 3, child: Text('Name', style: style)),
          _TableCell(flex: 2, child: Text('Phone No.', style: style)),
          _TableCell(flex: 2, child: Text('Action', style: style)),
        ],
      ),
    );
  }
}

class _CustomerTableRow extends StatelessWidget {
  const _CustomerTableRow({
    required this.rowNumber,
    required this.customer,
    required this.selected,
    required this.onSelect,
    required this.onEdit,
    required this.onTakeOrder,
  });

  final int rowNumber;
  final Customer customer;
  final bool selected;
  final VoidCallback onSelect;
  final VoidCallback onEdit;
  final VoidCallback onTakeOrder;

  @override
  Widget build(BuildContext context) {
    final rowColor = selected
        ? const Color(0xFFE6F1FF)
        : rowNumber.isEven
            ? const Color(0xFFF7F8F9)
            : Colors.white;

    return Material(
      color: rowColor,
      child: InkWell(
        onTap: onSelect,
        child: Container(
          constraints: const BoxConstraints(minHeight: 58),
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: Color(0xFFE0E3E6))),
          ),
          child: Row(
            children: [
              _TableCell(flex: 1, child: Text('$rowNumber')),
              _TableCell(
                flex: 3,
                child: Text(customer.name,
                    maxLines: 1, overflow: TextOverflow.ellipsis),
              ),
              _TableCell(
                flex: 2,
                child: Text(customer.phone,
                    maxLines: 1, overflow: TextOverflow.ellipsis),
              ),
              _TableCell(
                flex: 2,
                child: Row(
                  children: [
                    IconButton(
                      tooltip: 'View customer',
                      onPressed: onSelect,
                      visualDensity: VisualDensity.compact,
                      icon: const Icon(Icons.visibility_outlined, size: 19),
                    ),
                    IconButton(
                      tooltip: 'Take order for customer',
                      onPressed: onTakeOrder,
                      visualDensity: VisualDensity.compact,
                      icon: const Icon(Icons.shopping_cart_outlined, size: 18),
                    ),
                    IconButton(
                      tooltip: 'Edit customer',
                      onPressed: onEdit,
                      visualDensity: VisualDensity.compact,
                      icon: const Icon(Icons.edit_outlined, size: 18),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CustomerDetailPanel extends ConsumerWidget {
  const _CustomerDetailPanel({
    required this.customer,
    required this.rowNumber,
    required this.onEdit,
  });

  final Customer customer;
  final int rowNumber;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final orders = ref.watch(customerOrdersProvider(customer.id));

    return Column(
      children: [
        Container(
          height: 46,
          margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
          decoration: BoxDecoration(
            color: const Color(0xFF0877E8),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Row(
            children: [
              Expanded(
                  flex: 1,
                  child:
                      Center(child: Text('$rowNumber', style: _bannerStyle))),
              Expanded(
                flex: 3,
                child: Center(
                  child: Text(customer.name,
                      style: _bannerStyle, overflow: TextOverflow.ellipsis),
                ),
              ),
              Expanded(
                flex: 2,
                child: Center(
                  child: Text(customer.phone,
                      style: _bannerStyle, overflow: TextOverflow.ellipsis),
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              FilledButton.icon(
                onPressed: onEdit,
                icon: const Icon(Icons.edit_outlined, size: 18),
                label: const Text('Edit'),
              ),
              const SizedBox(width: 10),
              OutlinedButton.icon(
                onPressed: () =>
                    ref.invalidate(customerOrdersProvider(customer.id)),
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('Refresh orders'),
              ),
            ],
          ),
        ),
        Container(
          alignment: Alignment.centerLeft,
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
          decoration: const BoxDecoration(
            border: Border(top: BorderSide(color: Color(0xFFD9DEE3))),
          ),
          child: Text('Order History',
              style: Theme.of(context).textTheme.titleMedium),
        ),
        const _OrderTableHeader(),
        Expanded(
          child: orders.when(
            data: (items) => items.isEmpty
                ? const EmptyState(message: 'No orders for this customer yet')
                : ListView.builder(
                    itemCount: items.length,
                    itemBuilder: (context, index) =>
                        _OrderTableRow(item: items[index]),
                  ),
            error: (error, stackTrace) => EmptyState(
              message: 'Unable to load orders: $error',
            ),
            loading: () => const Center(child: CircularProgressIndicator()),
          ),
        ),
      ],
    );
  }

  static const _bannerStyle = TextStyle(
    color: Colors.white,
    fontWeight: FontWeight.w700,
    fontSize: 15,
  );
}

class _OrderTableHeader extends StatelessWidget {
  const _OrderTableHeader();

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.labelLarge?.copyWith(
          color: const Color(0xFF202124),
          fontWeight: FontWeight.w700,
        );

    return Container(
      height: 44,
      decoration: const BoxDecoration(
        color: Color(0xFFF1F3F5),
        border:
            Border.symmetric(horizontal: BorderSide(color: Color(0xFFD9DEE3))),
      ),
      child: Row(
        children: [
          _TableCell(flex: 3, child: Text('Item', style: style)),
          _TableCell(flex: 1, child: Text('Qty', style: style)),
          _TableCell(flex: 2, child: Text('Ordered', style: style)),
          _TableCell(flex: 2, child: Text('Delivery', style: style)),
          _TableCell(flex: 2, child: Text('Status', style: style)),
        ],
      ),
    );
  }
}

class _OrderTableRow extends StatelessWidget {
  const _OrderTableRow({required this.item});

  final OrderListItem item;

  @override
  Widget build(BuildContext context) {
    final order = item.order;
    final orderedDate = DateFormat('dd-MMM-yyyy').format(order.bookingDate);
    final deliveryDate = DateFormat('dd-MMM-yyyy').format(order.deliveryDate);

    return Container(
      constraints: const BoxConstraints(minHeight: 58),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFFE0E3E6))),
      ),
      child: Row(
        children: [
          _TableCell(
              flex: 3,
              child: Text(order.orderDetails,
                  maxLines: 1, overflow: TextOverflow.ellipsis)),
          _TableCell(
              flex: 1,
              child: Text('${order.quantity}',
                  maxLines: 1, overflow: TextOverflow.ellipsis)),
          _TableCell(
              flex: 2,
              child: Text(orderedDate,
                  maxLines: 1, overflow: TextOverflow.ellipsis)),
          _TableCell(
              flex: 2,
              child: Text(deliveryDate,
                  maxLines: 1, overflow: TextOverflow.ellipsis)),
          _TableCell(
            flex: 2,
            child: Align(
              alignment: Alignment.centerLeft,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: OrderStatusChip(status: order.status),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TableCell extends StatelessWidget {
  const _TableCell({required this.flex, required this.child});

  final int flex;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      flex: flex,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 9),
        child: child,
      ),
    );
  }
}
