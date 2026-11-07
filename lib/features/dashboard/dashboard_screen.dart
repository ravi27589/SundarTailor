import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repository/customer_repository.dart';
import '../../data/repository/order_repository.dart';
import '../../core/routing/app_navigation.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/order_status_chip.dart';
import '../../widgets/brand_title.dart';
import '../sync/supabase_sync_service.dart';
import '../sync/cloud_sync_screen.dart';
import '../sync/sync_scheduler.dart';

final dashboardProvider = FutureProvider<DashboardSummary>((ref) async {
  final customerRepository = await ref.watch(customerRepositoryProvider.future);
  final orderRepository = await ref.watch(orderRepositoryProvider.future);

  final results = await Future.wait<Object>([
    customerRepository.countCustomers(),
    orderRepository.countPendingOrders(),
    orderRepository.countDeliveredOrders(),
    orderRepository.todaysDeliveries(),
  ]);

  return DashboardSummary(
    totalCustomers: results[0] as int,
    pendingOrders: results[1] as int,
    completedOrders: results[2] as int,
    todaysDeliveries: results[3] as List<OrderListItem>,
  );
});

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summary = ref.watch(dashboardProvider);
    final syncStatus = ref.watch(cloudSyncStatusProvider);

    return Scaffold(
      appBar: AppBar(
        title: const BrandTitle(title: 'Sundar Tailors'),
        actions: [
          IconButton(
            tooltip: 'Cloud sync settings',
            icon: const Icon(Icons.cloud_outlined),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const CloudSyncScreen()),
            ),
          ),
        ],
      ),
      body: summary.when(
        data: (data) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _StatCard(
                  label: 'Total Customers',
                  value: data.totalCustomers,
                  onTap: () => _openDashboardDestination(
                    ref,
                    1,
                  ),
                ),
                _StatCard(
                  label: 'Pending Orders',
                  value: data.pendingOrders,
                  onTap: () => _openDashboardDestination(
                    ref,
                    2,
                  ),
                ),
                _StatCard(
                    label: 'Completed Orders', value: data.completedOrders),
              ],
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: ActionChip(
                avatar: Icon(_syncIcon(syncStatus)),
                label: Text(syncStatus.label),
                onPressed: syncStatus == CloudSyncStatus.syncing
                    ? null
                    : () {
                        if (syncStatus == CloudSyncStatus.signedOut ||
                            syncStatus == CloudSyncStatus.notConfigured ||
                            syncStatus == CloudSyncStatus.failed) {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const CloudSyncScreen(),
                            ),
                          );
                        } else {
                          ref.read(syncSchedulerProvider).syncNow();
                        }
                      },
              ),
            ),
            const SizedBox(height: 24),
            Text('Today\'s Deliveries',
                style: Theme.of(context).textTheme.titleLarge),
            if (data.todaysDeliveries.isEmpty)
              const EmptyState(message: 'No deliveries due today')
            else
              ...data.todaysDeliveries.map(
                (item) => Card(
                  child: ListTile(
                    title: Text(item.order.orderNumber),
                    subtitle: Text(
                      '${item.customerName} • ${item.order.orderDetails} • Qty ${item.order.quantity}',
                    ),
                    trailing: OrderStatusChip(status: item.order.status),
                  ),
                ),
              ),
          ],
        ),
        error: (error, stackTrace) =>
            EmptyState(message: 'Unable to load dashboard: $error'),
        loading: () => const Center(child: CircularProgressIndicator()),
      ),
    );
  }

  IconData _syncIcon(CloudSyncStatus status) {
    return switch (status) {
      CloudSyncStatus.notConfigured ||
      CloudSyncStatus.signedOut =>
        Icons.cloud_off_outlined,
      CloudSyncStatus.waiting ||
      CloudSyncStatus.offline =>
        Icons.cloud_queue_outlined,
      CloudSyncStatus.syncing => Icons.sync,
      CloudSyncStatus.synced => Icons.cloud_done_outlined,
      CloudSyncStatus.failed => Icons.sync_problem_outlined,
    };
  }
}

void _openDashboardDestination(
  WidgetRef ref,
  int destinationIndex,
) {
  ref.read(appNavigationIndexProvider.notifier).state = destinationIndex;
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.label, required this.value, this.onTap});

  final String label;
  final int value;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 180,
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: Theme.of(context).textTheme.labelLarge),
                const SizedBox(height: 8),
                Text('$value',
                    style: Theme.of(context).textTheme.headlineMedium),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class DashboardSummary {
  const DashboardSummary({
    required this.totalCustomers,
    required this.pendingOrders,
    required this.completedOrders,
    required this.todaysDeliveries,
  });

  final int totalCustomers;
  final int pendingOrders;
  final int completedOrders;
  final List<OrderListItem> todaysDeliveries;
}
