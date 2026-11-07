import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/responsive/breakpoints.dart';
import 'core/routing/app_navigation.dart';
import 'core/theme/app_theme.dart';
import 'features/customers/customers_screen.dart';
import 'features/dashboard/dashboard_screen.dart';
import 'features/orders/orders_screen.dart';
import 'features/sync/sync_scheduler.dart';

void main() {
  runApp(const ProviderScope(child: SundarTailorApp()));
}

class SundarTailorApp extends StatelessWidget {
  const SundarTailorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Sundar Tailor',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      home: const AppShell(),
    );
  }
}

class AppShell extends ConsumerWidget {
  const AppShell({super.key});

  static const _screens = [
    DashboardScreen(),
    CustomersScreen(),
    OrdersScreen(),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(syncSchedulerProvider);
    final isTablet = Breakpoints.isTablet(context);
    final selectedIndex = ref.watch(appNavigationIndexProvider);
    final navigation = ref.read(appNavigationIndexProvider.notifier);

    if (isTablet) {
      return Scaffold(
        body: Row(
          children: [
            NavigationRail(
              selectedIndex: selectedIndex,
              onDestinationSelected: (index) => navigation.state = index,
              labelType: NavigationRailLabelType.all,
              destinations: const [
                NavigationRailDestination(
                  icon: Icon(Icons.dashboard_outlined),
                  selectedIcon: Icon(Icons.dashboard),
                  label: Text('Dashboard'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.people_outline),
                  selectedIcon: Icon(Icons.people),
                  label: Text('Customers'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.assignment_outlined),
                  selectedIcon: Icon(Icons.assignment),
                  label: Text('Orders'),
                ),
              ],
            ),
            const VerticalDivider(width: 1),
            Expanded(child: _screens[selectedIndex]),
          ],
        ),
      );
    }

    return Scaffold(
      body: _screens[selectedIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: selectedIndex,
        onDestinationSelected: (index) => navigation.state = index,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard),
            label: 'Dashboard',
          ),
          NavigationDestination(
            icon: Icon(Icons.people_outline),
            selectedIcon: Icon(Icons.people),
            label: 'Customers',
          ),
          NavigationDestination(
            icon: Icon(Icons.assignment_outlined),
            selectedIcon: Icon(Icons.assignment),
            label: 'Orders',
          ),
        ],
      ),
    );
  }
}
