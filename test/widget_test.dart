// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sundar_tailor/data/models/customer.dart';
import 'package:sundar_tailor/data/models/tailor_order.dart';
import 'package:sundar_tailor/data/repository/customer_repository.dart';
import 'package:sundar_tailor/data/repository/order_repository.dart';
import 'package:sundar_tailor/features/customers/customer_form_screen.dart';
import 'package:sundar_tailor/features/customers/customers_screen.dart';
import 'package:sundar_tailor/features/dashboard/dashboard_screen.dart';
import 'package:sundar_tailor/features/orders/inline_order_editor.dart';
import 'package:sundar_tailor/features/orders/orders_screen.dart';
import 'package:sundar_tailor/features/orders/take_order_screen.dart';
import 'package:sundar_tailor/features/sync/supabase_sync_service.dart';
import 'package:sundar_tailor/features/sync/sync_scheduler.dart';
import 'package:sundar_tailor/main.dart';

void main() {
  test('Supabase sync requires an HTTPS URL and publishable key', () {
    expect(
      const SupabaseSyncConfig(
        url: '',
        publishableKey: '',
      ).isConfigured,
      isFalse,
    );
    expect(
      const SupabaseSyncConfig(
        url: 'https://shop.supabase.co',
        publishableKey: 'public-key',
      ).isConfigured,
      isTrue,
    );
    expect(
      const SupabaseSyncConfig(
        url: 'http://shop.supabase.co',
        publishableKey: 'public-key',
      ).isConfigured,
      isFalse,
    );
  });

  test('sync scheduler stays dormant when sync is not configured', () async {
    var syncAttempts = 0;
    final scheduler = SyncScheduler(
      enabled: false,
      onSync: () async {
        syncAttempts++;
      },
      onStatusChanged: (_) {},
    );

    scheduler.start();
    await scheduler.syncNow();
    scheduler.dispose();

    expect(syncAttempts, 0);
  });

  testWidgets('shows the Sundar Tailor dashboard', (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: SundarTailorApp()));

    expect(find.text('Dashboard'), findsWidgets);
    expect(find.byType(Image), findsOneWidget);
  });

  testWidgets('dashboard customer and pending stats navigate to their screens',
      (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(420, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          dashboardProvider.overrideWith(
            (ref) async => const DashboardSummary(
              totalCustomers: 12,
              pendingOrders: 4,
              completedOrders: 8,
              todaysDeliveries: [],
            ),
          ),
          customersProvider.overrideWith((ref) async => []),
          ordersProvider.overrideWith((ref) async => []),
        ],
        child: const SundarTailorApp(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Total Customers'));
    await tester.pumpAndSettle();
    expect(find.byType(CustomersScreen), findsOneWidget);

    await tester.tap(find.text('Dashboard').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Pending Orders'));
    await tester.pumpAndSettle();
    expect(find.byType(OrdersScreen), findsOneWidget);
  });

  testWidgets('shows the customer master-detail layout on wide screens', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final customer = Customer(
      id: 'customer-1',
      customerNumber: 'C000001',
      name: 'S VENU',
      phone: '9989490333',
      shirtMeasurements: const {},
      trouserMeasurements: const {},
      pajamaMeasurements: const {},
      suitMeasurements: const {},
      shortsMeasurements: const {},
      kurtaMeasurements: const {},
      safariMeasurements: const {},
      notes: '',
      createdDate: DateTime(2026),
      updatedDate: DateTime(2026),
    );
    final orderRepository = OrderRepository.memory();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          customersProvider.overrideWith((ref) async => [customer]),
          orderRepositoryProvider.overrideWith((ref) async => orderRepository),
          customerOrdersProvider(customer.id).overrideWith((ref) async => []),
        ],
        child: const MaterialApp(home: CustomersScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Add New Customer'), findsOneWidget);
    expect(find.text('Phone No.'), findsOneWidget);
    expect(find.text('S VENU'), findsWidgets);
    expect(find.text('Order History'), findsOneWidget);
    expect(find.text('No orders for this customer yet'), findsOneWidget);

    await tester.tap(find.byTooltip('Take order for customer'));
    await tester.pumpAndSettle();
    expect(find.text('Take Order'), findsOneWidget);
    expect(find.text('Order Item 1'), findsOneWidget);
  });

  testWidgets('uses the same structured layout for add and edit forms', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final customer = Customer(
      id: 'customer-2',
      customerNumber: 'C000002',
      name: 'S VENU',
      phone: '9989490333',
      shirtMeasurements: const {'Chest': '40'},
      trouserMeasurements: const {
        'Waist': '34',
        'Hip': '40',
        'Length': '40',
        'Bottom': '16',
      },
      pajamaMeasurements: const {'Waist': '34', 'Length': '41'},
      suitMeasurements: const {'Coat': '40', 'Sleeve': '24'},
      shortsMeasurements: const {'Waist': '34', 'Length': '18'},
      kurtaMeasurements: const {'Length': '40'},
      safariMeasurements: const {'Chest': '42'},
      notes: '',
      createdDate: DateTime(2026),
      updatedDate: DateTime(2026),
    );

    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: CustomerFormScreen()),
      ),
    );
    expect(find.text('Add New Customer'), findsOneWidget);
    expect(find.text('Measurements'), findsOneWidget);
    expect(find.text('Shirt'), findsOneWidget);
    expect(find.text('Kurta'), findsOneWidget);
    expect(find.text('Safari'), findsOneWidget);
    expect(find.text('Additional Measurements / Notes'), findsOneWidget);
    final saveButton = find.byType(FloatingActionButton);
    expect(saveButton, findsOneWidget);
    final saveButtonRect = tester.getRect(saveButton);
    expect(saveButtonRect.right, greaterThan(1300));
    expect(saveButtonRect.bottom, greaterThan(900));

    final addMeasurementTexts = tester
        .widgetList<TextFormField>(find.byType(TextFormField))
        .map((field) => field.controller?.text ?? '')
        .toList();
    expect(addMeasurementTexts, contains('SP SC 2.5 TP 1. 1FP\n'));
    expect(
      addMeasurementTexts,
      contains('DLS 1.5 SP 2BCT 8R SELF HOOK\n'),
    );

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: CustomerFormScreen(
            key: const ValueKey('edit-customer-form'),
            customer: customer,
          ),
        ),
      ),
    );
    expect(find.text('Edit Customer'), findsOneWidget);
    expect(find.text('C000002'), findsOneWidget);
    expect(find.text('Take Order'), findsOneWidget);
    final measurementTexts = tester
        .widgetList<TextFormField>(find.byType(TextFormField))
        .map((field) => field.controller?.text ?? '')
        .toList();
    expect(
      measurementTexts,
      contains('SP SC 2.5 TP 1. 1FP\nChest: 40'),
    );
    expect(
        measurementTexts,
        contains(
            'DLS 1.5 SP 2BCT 8R SELF HOOK\nWaist: 34\nHip: 40\nLength: 40\nBottom: 16'));
    expect(measurementTexts, contains('Waist: 34\nLength: 41'));
    expect(measurementTexts, contains('Coat: 40\nSleeve: 24'));
    expect(measurementTexts, contains('Waist: 34\nLength: 18'));
    expect(measurementTexts, contains('Length: 40'));
    expect(measurementTexts, contains('Chest: 42'));
    expect(find.text('Bottom'), findsNothing);
  });

  testWidgets('mobile customer row cart opens Take Order', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final customer = Customer(
      id: 'mobile-order-customer',
      customerNumber: 'C000006',
      name: 'Ravi Chandra',
      phone: '9876543210',
      shirtMeasurements: const {},
      trouserMeasurements: const {},
      pajamaMeasurements: const {},
      suitMeasurements: const {},
      shortsMeasurements: const {},
      kurtaMeasurements: const {},
      safariMeasurements: const {},
      notes: '',
      createdDate: DateTime(2026),
      updatedDate: DateTime(2026),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          customersProvider.overrideWith((ref) async => [customer]),
          orderRepositoryProvider.overrideWith(
            (ref) async => OrderRepository.memory(),
          ),
          customerOrdersProvider(customer.id).overrideWith((ref) async => []),
        ],
        child: const MaterialApp(home: CustomersScreen()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Take order for customer'));
    await tester.pumpAndSettle();

    expect(find.text('Take Order'), findsOneWidget);
    expect(find.text('Order Item 1'), findsOneWidget);
  });

  testWidgets('customer search debounces, matches name/phone, and clears', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final repository = CustomerRepository.memory();
    await repository.createCustomer(name: 'Ravi Chandra', phone: '888123');
    await repository.createCustomer(name: 'Alya Rao', phone: '555987');

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          customerRepositoryProvider.overrideWith((ref) async => repository),
        ],
        child: const MaterialApp(home: CustomersScreen()),
      ),
    );
    await tester.pumpAndSettle();

    final container = ProviderScope.containerOf(
      tester.element(find.byType(CustomersScreen)),
      listen: false,
    );
    final searchField = find.byType(TextField).first;

    await tester.enterText(searchField, 'rAvI');
    await tester.pump();
    expect(container.read(customerSearchQueryProvider), '');
    await tester.pump(const Duration(milliseconds: 499));
    expect(container.read(customerSearchQueryProvider), '');
    await tester.pump(const Duration(milliseconds: 1));
    await tester.pumpAndSettle();

    expect(container.read(customerSearchQueryProvider), 'rAvI');
    expect(find.text('Ravi Chandra'), findsOneWidget);
    expect(find.text('Alya Rao'), findsNothing);
    expect(tester.widget<TextField>(searchField).controller!.text, 'rAvI');

    await tester.enterText(searchField, '555');
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();
    expect(find.text('Alya Rao'), findsOneWidget);
    expect(find.text('Ravi Chandra'), findsNothing);

    await tester.tap(find.byTooltip('Clear search'));
    await tester.pumpAndSettle();
    expect(container.read(customerSearchQueryProvider), '');
    expect(tester.widget<TextField>(searchField).controller!.text, '');
    expect(find.text('Ravi Chandra'), findsOneWidget);
    expect(find.text('Alya Rao'), findsOneWidget);
  });

  testWidgets('take order supports add-more rows and quantity stepper', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final customer = Customer(
      id: 'take-order-customer',
      customerNumber: 'C000003',
      name: 'Ravi Chandra',
      phone: '9876543210',
      shirtMeasurements: const {'measurements': 'Chest: 40'},
      trouserMeasurements: const {},
      pajamaMeasurements: const {},
      suitMeasurements: const {},
      shortsMeasurements: const {},
      kurtaMeasurements: const {},
      safariMeasurements: const {},
      notes: '',
      createdDate: DateTime(2026),
      updatedDate: DateTime(2026),
    );
    final repository = OrderRepository.memory();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          orderRepositoryProvider.overrideWith((ref) async => repository),
          customerOrdersProvider(customer.id).overrideWith((ref) async => []),
        ],
        child: MaterialApp(home: TakeOrderScreen(customer: customer)),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Customer ID'), findsOneWidget);
    expect(find.text('Order Item 1'), findsOneWidget);
    expect(find.text('Save Order'), findsOneWidget);
    expect(find.text('Print'), findsOneWidget);

    await tester.tap(find.text('Add more'));
    await tester.pumpAndSettle();
    expect(find.text('Order Item 2'), findsOneWidget);

    await tester.tap(find.byTooltip('Increase quantity').first);
    await tester.pumpAndSettle();
    expect(find.text('2'), findsOneWidget);
  });

  testWidgets(
      'order edit expands inline with future date and requested statuses', (
    WidgetTester tester,
  ) async {
    final repository = OrderRepository.memory();
    final now = DateTime.now();
    final futureDate = DateTime(now.year, now.month, now.day + 3);
    final order = await repository.createOrder(
      customerId: 'inline-customer',
      customerName: 'Ravi Chandra',
      customerPhone: '9876543210',
      deliveryDate: futureDate,
      orderDetails: 'Shirt',
      quantity: 2,
    );
    final item = OrderListItem(
      order: order,
      customerName: 'Ravi Chandra',
      customerPhone: '9876543210',
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          orderRepositoryProvider.overrideWith((ref) async => repository),
          ordersProvider.overrideWith((ref) async => [item]),
        ],
        child: const MaterialApp(home: OrdersScreen()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Edit order'));
    await tester.pumpAndSettle();

    expect(find.byType(InlineOrderEditor), findsOneWidget);
    expect(find.text('Orders'), findsOneWidget);
    expect(find.text('Take Order'), findsNothing);
    expect(
      find.descendant(
        of: find.byType(InlineOrderEditor),
        matching: find.text('Delivery Date'),
      ),
      findsOneWidget,
    );
    expect(find.byTooltip('Cancel order'), findsOneWidget);
    expect(find.byTooltip('Delete order'), findsNothing);

    final statusDropdown = find.descendant(
      of: find.byType(InlineOrderEditor),
      matching: find.byType(DropdownButtonFormField<OrderStatus>),
    );
    await tester.tap(statusDropdown);
    await tester.pumpAndSettle();
    for (final status in const [
      'Booked',
      'Drying',
      'Cutting',
      'Stitching',
      'Finishing',
      'Ironing',
      'Ready',
      'Delivered',
    ]) {
      expect(find.text(status), findsWidgets);
    }
    expect(find.text('Trial'), findsNothing);
    expect(find.text('Cancelled'), findsNothing);
  });

  testWidgets(
      'All Orders hides delivered/cancelled but customer history keeps them', (
    WidgetTester tester,
  ) async {
    final repository = OrderRepository.memory();
    final now = DateTime.now();
    final deliveryDate = DateTime(now.year, now.month, now.day + 5);
    const customerId = 'order-visibility-customer';

    await repository.createOrder(
      customerId: customerId,
      customerName: 'Ravi Chandra',
      customerPhone: '9876543210',
      deliveryDate: deliveryDate,
      orderDetails: 'Active Shirt',
      status: OrderStatus.stitching,
    );
    await repository.createOrder(
      customerId: customerId,
      customerName: 'Ravi Chandra',
      customerPhone: '9876543210',
      deliveryDate: deliveryDate,
      orderDetails: 'Delivered Suit',
      status: OrderStatus.delivered,
    );
    await repository.createOrder(
      customerId: customerId,
      customerName: 'Ravi Chandra',
      customerPhone: '9876543210',
      deliveryDate: deliveryDate,
      orderDetails: 'Cancelled Kurta',
      status: OrderStatus.cancelled,
    );
    final allOrders = await repository.searchOrders();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ordersProvider.overrideWith((ref) async => allOrders),
        ],
        child: const MaterialApp(home: OrdersScreen()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Active Shirt'), findsOneWidget);
    expect(find.text('Delivered Suit'), findsNothing);
    expect(find.text('Cancelled Kurta'), findsNothing);

    final customer = Customer(
      id: customerId,
      customerNumber: 'C000005',
      name: 'Ravi Chandra',
      phone: '9876543210',
      shirtMeasurements: const {},
      trouserMeasurements: const {},
      pajamaMeasurements: const {},
      suitMeasurements: const {},
      shortsMeasurements: const {},
      kurtaMeasurements: const {},
      safariMeasurements: const {},
      notes: '',
      createdDate: DateTime(2026),
      updatedDate: DateTime(2026),
    );
    await tester.pumpWidget(
      ProviderScope(
        key: const ValueKey('customer-order-history-scope'),
        overrides: [
          orderRepositoryProvider.overrideWith((ref) async => repository),
          customerOrdersProvider(customer.id)
              .overrideWith((ref) => repository.ordersForCustomer(customer.id)),
        ],
        child: MaterialApp(home: TakeOrderScreen(customer: customer)),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Active Shirt'), findsOneWidget);
    expect(find.text('Delivered Suit'), findsOneWidget);
    expect(find.text('Cancelled Kurta'), findsOneWidget);
  });

  testWidgets('orders sort by supported fields and direction', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    OrderListItem makeItem({
      required String id,
      required String number,
      required String itemType,
      required String customerName,
      required DateTime delivery,
    }) {
      final ordered = DateTime(2026, 10, 1);
      return OrderListItem(
        order: TailorOrder(
          id: id,
          orderNumber: number,
          customerId: id,
          bookingDate: ordered,
          deliveryDate: delivery,
          orderDetails: itemType,
          amount: 0,
          advancePaid: 0,
          status: OrderStatus.booked,
          createdDate: ordered,
          updatedDate: ordered,
        ),
        customerName: customerName,
        customerPhone: '9876543210',
      );
    }

    final items = [
      makeItem(
        id: 'order-1',
        number: 'ORD-003',
        itemType: 'Trousers',
        customerName: 'Charlie',
        delivery: DateTime(2026, 11, 5),
      ),
      makeItem(
        id: 'order-2',
        number: 'ORD-002',
        itemType: 'Kurta',
        customerName: 'Ravi',
        delivery: DateTime(2026, 11, 2),
      ),
      makeItem(
        id: 'order-3',
        number: 'ORD-001',
        itemType: 'Shirt',
        customerName: 'Anu',
        delivery: DateTime(2026, 11, 3),
      ),
    ];

    await tester.pumpWidget(
      ProviderScope(
        overrides: [ordersProvider.overrideWith((ref) async => items)],
        child: const MaterialApp(home: OrdersScreen()),
      ),
    );
    await tester.pumpAndSettle();

    Future<void> chooseSort(String label) async {
      await tester.tap(find.byKey(const ValueKey('order-sort-field')));
      await tester.pumpAndSettle();
      await tester.tap(find.text(label).last);
      await tester.pumpAndSettle();
    }

    expect(tester.getTopLeft(find.text('Kurta')).dy,
        lessThan(tester.getTopLeft(find.text('Shirt')).dy));
    expect(tester.getTopLeft(find.text('Shirt')).dy,
        lessThan(tester.getTopLeft(find.text('Trousers')).dy));

    await tester.tap(find.byKey(const ValueKey('order-sort-field')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Customer Name').last);
    await tester.pumpAndSettle();

    final anuY = tester.getTopLeft(find.text('Anu  ·  Qty: 1')).dy;
    final charlieY = tester.getTopLeft(find.text('Charlie  ·  Qty: 1')).dy;
    final raviY = tester.getTopLeft(find.text('Ravi  ·  Qty: 1')).dy;
    expect(anuY, lessThan(charlieY));
    expect(charlieY, lessThan(raviY));

    await tester.tap(find.byTooltip('Sort descending'));
    await tester.pumpAndSettle();
    expect(
      tester.getTopLeft(find.text('Ravi  ·  Qty: 1')).dy,
      lessThan(tester.getTopLeft(find.text('Anu  ·  Qty: 1')).dy),
    );

    await tester.tap(find.byTooltip('Sort ascending'));
    await tester.pumpAndSettle();
    await chooseSort('Order Item/Type');
    expect(tester.getTopLeft(find.text('Kurta')).dy,
        lessThan(tester.getTopLeft(find.text('Shirt')).dy));
    expect(tester.getTopLeft(find.text('Shirt')).dy,
        lessThan(tester.getTopLeft(find.text('Trousers')).dy));

    await chooseSort('Order Number');
    expect(tester.getTopLeft(find.text('ORD-001')).dy,
        lessThan(tester.getTopLeft(find.text('ORD-002')).dy));
    expect(tester.getTopLeft(find.text('ORD-002')).dy,
        lessThan(tester.getTopLeft(find.text('ORD-003')).dy));
  });

  testWidgets('Take Order action opens the order-entry screen', (
    WidgetTester tester,
  ) async {
    final customer = Customer(
      id: 'take-order-navigation-customer',
      customerNumber: 'C000004',
      name: 'Ravi Chandra',
      phone: '9876543210',
      shirtMeasurements: const {},
      trouserMeasurements: const {},
      pajamaMeasurements: const {},
      suitMeasurements: const {},
      shortsMeasurements: const {},
      kurtaMeasurements: const {},
      safariMeasurements: const {},
      notes: '',
      createdDate: DateTime(2026),
      updatedDate: DateTime(2026),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          orderRepositoryProvider.overrideWith(
            (ref) async => OrderRepository.memory(),
          ),
          customerOrdersProvider(customer.id).overrideWith((ref) async => []),
        ],
        child: MaterialApp(home: CustomerFormScreen(customer: customer)),
      ),
    );

    await tester.tap(find.text('Take Order'));
    await tester.pumpAndSettle();

    expect(find.text('Take Order'), findsOneWidget);
    expect(find.text('Order Item 1'), findsOneWidget);
    expect(find.text('Save Order'), findsOneWidget);
  });

  test('order repository batch create, edit, and delete', () async {
    final repository = OrderRepository.memory();
    final delivery = DateTime(2026, 11, 5);
    final created = await repository.createOrders(
      customerId: 'customer-batch',
      customerName: 'Ravi Chandra',
      customerPhone: '9876543210',
      drafts: [
        OrderDraft(
          itemType: 'Shirt',
          comments: 'Slim fit',
          quantity: 2,
          deliveryDate: delivery,
        ),
        OrderDraft(
          itemType: 'Kurta',
          comments: '',
          quantity: 1,
          deliveryDate: delivery,
        ),
      ],
    );

    expect(created, hasLength(2));
    expect(created.first.quantity, 2);
    expect(created.first.comments, 'Slim fit');
    expect(created.first.bookingDate, isNotNull);
    expect(await repository.ordersForCustomer('customer-batch'), hasLength(2));

    final order = created.first;
    await repository.updateOrder(
      TailorOrder(
        id: order.id,
        orderNumber: order.orderNumber,
        customerId: order.customerId,
        bookingDate: order.bookingDate,
        deliveryDate: order.deliveryDate,
        orderDetails: 'Shirt',
        comments: 'Updated fit',
        quantity: 3,
        amount: order.amount,
        advancePaid: order.advancePaid,
        status: order.status,
        createdDate: order.createdDate,
        updatedDate: order.updatedDate,
      ),
    );
    expect(
      (await repository.ordersForCustomer('customer-batch'))
          .first
          .order
          .quantity,
      3,
    );

    final cancelled = await repository.cancelOrder(created.last);
    expect(cancelled.status, OrderStatus.cancelled);
    final afterCancellation =
        await repository.ordersForCustomer('customer-batch');
    expect(afterCancellation, hasLength(2));
    expect(
      afterCancellation.last.order.status,
      OrderStatus.cancelled,
    );

    await repository.deleteOrder(order);
    expect(await repository.ordersForCustomer('customer-batch'), hasLength(1));
  });

  test('order repository rejects delivery dates that are not in the future',
      () async {
    final repository = OrderRepository.memory();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    await expectLater(
      repository.createOrders(
        customerId: 'future-date-customer',
        customerName: 'Ravi Chandra',
        customerPhone: '9876543210',
        drafts: [
          OrderDraft(
            itemType: 'Shirt',
            comments: '',
            quantity: 1,
            deliveryDate: today,
          ),
        ],
      ),
      throwsArgumentError,
    );
  });
}
