import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repository/customer_repository.dart';
import '../../data/repository/order_repository.dart';
import '../dashboard/dashboard_screen.dart';
import 'supabase_sync_service.dart';

final syncSchedulerProvider = Provider<SyncScheduler>((ref) {
  final config = ref.watch(supabaseSyncConfigProvider);
  final userId = ref.watch(shopUserProvider.select(
    (value) => value.valueOrNull?.id,
  ));
  var active = true;
  final scheduler = SyncScheduler(
    enabled: !kIsWeb && config.isConfigured && userId != null,
    onStatusChanged: (status) {
      if (active) ref.read(cloudSyncStatusProvider.notifier).state = status;
    },
    onError: (error) {
      if (active) {
        ref.read(cloudSyncErrorProvider.notifier).state = error.toString();
      }
    },
    onSync: () async {
      if (active) ref.read(cloudSyncErrorProvider.notifier).state = null;
      final service = await ref.read(supabaseSyncServiceProvider.future);
      if (service == null) {
        throw StateError('Sign in before syncing.');
      }
      final summary = await service.synchronize();
      if (!active) return;
      ref.read(cloudSyncErrorProvider.notifier).state = summary.error;
      ref.read(cloudSyncStatusProvider.notifier).state =
          summary.failed == 0 ? CloudSyncStatus.synced : CloudSyncStatus.failed;
      ref.invalidate(customersProvider);
      ref.invalidate(customerByIdProvider);
      ref.invalidate(ordersProvider);
      ref.invalidate(customerOrdersProvider);
      ref.invalidate(dashboardProvider);
    },
  );
  scheduler.start();
  ref.onDispose(() {
    active = false;
    scheduler.dispose();
  });
  return scheduler;
});

class SyncScheduler {
  SyncScheduler({
    required this.enabled,
    required this.onSync,
    required this.onStatusChanged,
    this.onError,
    Connectivity? connectivity,
  }) : _connectivity = connectivity ?? Connectivity();

  static const retryInterval = Duration(minutes: 5);

  final bool enabled;
  final Future<void> Function() onSync;
  final ValueChanged<CloudSyncStatus> onStatusChanged;
  final ValueChanged<Object>? onError;
  final Connectivity _connectivity;
  StreamSubscription<List<ConnectivityResult>>? _subscription;
  Timer? _timer;
  var _running = false;
  var _disposed = false;

  void start() {
    if (!enabled || _disposed) {
      return;
    }

    _subscription = _connectivity.onConnectivityChanged.listen(
      _handleConnectivity,
      onError: (Object error) {
        onError?.call(error);
        onStatusChanged(CloudSyncStatus.failed);
      },
    );
    _timer = Timer.periodic(retryInterval, (_) => syncNow());
    unawaited(syncNow());
  }

  Future<void> syncNow() async {
    if (!enabled || _running || _disposed) {
      return;
    }

    _running = true;
    try {
      final connectivity = await _connectivity.checkConnectivity();
      if (connectivity.isEmpty ||
          connectivity.every((result) => result == ConnectivityResult.none)) {
        onStatusChanged(CloudSyncStatus.offline);
        return;
      }

      onStatusChanged(CloudSyncStatus.syncing);
      await onSync();
    } on Object catch (error, stack) {
      debugPrint('Cloud sync failed: $error\n$stack');
      if (!_disposed) {
        onError?.call(error);
        onStatusChanged(CloudSyncStatus.failed);
      }
    } finally {
      _running = false;
    }
  }

  void _handleConnectivity(List<ConnectivityResult> results) {
    final isOnline = results.any((result) => result != ConnectivityResult.none);
    if (isOnline) {
      unawaited(syncNow());
    } else {
      onStatusChanged(CloudSyncStatus.offline);
    }
  }

  void dispose() {
    _disposed = true;
    _timer?.cancel();
    _subscription?.cancel();
  }
}
