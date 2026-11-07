import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/customer.dart';
import '../../data/repository/customer_repository.dart';
import '../dashboard/dashboard_screen.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/brand_title.dart';
import 'customer_form_screen.dart';
import 'customer_workspace.dart';
import '../orders/take_order_screen.dart';

class CustomersScreen extends ConsumerStatefulWidget {
  const CustomersScreen({super.key});

  @override
  ConsumerState<CustomersScreen> createState() => _CustomersScreenState();
}

class _CustomersScreenState extends ConsumerState<CustomersScreen> {
  late final TextEditingController _searchController;
  Timer? _searchDebounce;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController(
      text: ref.read(customerSearchQueryProvider),
    );
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final customers = ref.watch(customersProvider);

    return Scaffold(
      appBar: AppBar(title: const BrandTitle(title: 'Customers')),
      body: LayoutBuilder(
        builder: (context, constraints) => customers.when(
          skipLoadingOnReload: true,
          data: (items) => constraints.maxWidth >= 980
              ? CustomerWorkspace(
                  customers: items,
                  searchController: _searchController,
                  onSearch: _debounceSearch,
                  onClearSearch: _clearSearch,
                  onAdd: () => _openCustomerForm(context, ref),
                  onEdit: (customer) =>
                      _openCustomerForm(context, ref, customer),
                  onTakeOrder: (customer) => _openTakeOrder(context, customer),
                )
              : _CompactCustomerList(
                  customers: items,
                  searchController: _searchController,
                  onSearch: _debounceSearch,
                  onClearSearch: _clearSearch,
                  onEdit: (customer) =>
                      _openCustomerForm(context, ref, customer),
                  onTakeOrder: (customer) => _openTakeOrder(context, customer),
                ),
          error: (error, stackTrace) => EmptyState(
            message: 'Unable to load customers: $error',
          ),
          loading: () => const Center(child: CircularProgressIndicator()),
        ),
      ),
      floatingActionButton: MediaQuery.sizeOf(context).width < 980
          ? FloatingActionButton(
              tooltip: 'Add customer',
              onPressed: () => _openCustomerForm(context, ref),
              child: const Icon(Icons.person_add_alt_1),
            )
          : null,
    );
  }

  void _debounceSearch(String value) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 500), () {
      if (mounted) {
        ref.read(customerSearchQueryProvider.notifier).state = value.trim();
      }
    });
  }

  void _clearSearch() {
    _searchDebounce?.cancel();
    _searchController.clear();
    ref.read(customerSearchQueryProvider.notifier).state = '';
  }

  Future<void> _openCustomerForm(
    BuildContext context,
    WidgetRef ref, [
    Customer? customer,
  ]) async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => CustomerFormScreen(customer: customer),
      ),
    );

    if (saved == true) {
      ref.invalidate(customersProvider);
      ref.invalidate(dashboardProvider);
    }
  }

  Future<void> _openTakeOrder(
    BuildContext context,
    Customer customer,
  ) async {
    await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => TakeOrderScreen(customer: customer),
      ),
    );
  }
}

class _CompactCustomerList extends StatelessWidget {
  const _CompactCustomerList({
    required this.customers,
    required this.searchController,
    required this.onSearch,
    required this.onClearSearch,
    required this.onEdit,
    required this.onTakeOrder,
  });

  final List<Customer> customers;
  final TextEditingController searchController;
  final ValueChanged<String> onSearch;
  final VoidCallback onClearSearch;
  final ValueChanged<Customer> onEdit;
  final ValueChanged<Customer> onTakeOrder;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: TextField(
            controller: searchController,
            decoration: const InputDecoration(
              labelText: 'Search customers',
              prefixIcon: Icon(Icons.search),
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
        Expanded(
          child: customers.isEmpty
              ? const EmptyState(message: 'No customers found')
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  itemCount: customers.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, index) => Card(
                    child: ListTile(
                      title: Text(customers[index].name),
                      subtitle: Text(
                        '${customers[index].customerNumber} • ${customers[index].phone}',
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            tooltip: 'Take order for customer',
                            onPressed: () => onTakeOrder(customers[index]),
                            icon: const Icon(Icons.shopping_cart_outlined),
                          ),
                          IconButton(
                            tooltip: 'Edit customer',
                            onPressed: () => onEdit(customers[index]),
                            icon: const Icon(Icons.edit_outlined),
                          ),
                        ],
                      ),
                      onTap: () => onEdit(customers[index]),
                    ),
                  ),
                ),
        ),
      ],
    );
  }
}
