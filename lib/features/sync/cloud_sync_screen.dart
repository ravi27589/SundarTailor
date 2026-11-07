import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../data/database/database_providers.dart';
import 'supabase_sync_service.dart';
import 'sync_scheduler.dart';

class CloudSyncScreen extends ConsumerStatefulWidget {
  const CloudSyncScreen({super.key});

  @override
  ConsumerState<CloudSyncScreen> createState() => _CloudSyncScreenState();
}

class _CloudSyncScreenState extends ConsumerState<CloudSyncScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  var _busy = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    if (_email.text.trim().isEmpty || _password.text.isEmpty) {
      setState(() => _error = 'Enter the shop email and password.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final url = ref.read(supabaseSyncConfigProvider).url;
      final password = _password.text;
      final email = _email.text.trim();
      final database = await ref.read(databaseProvider.future);
      if (!mounted) return;
      final client = await ref.read(supabaseClientProvider.future);
      if (client == null) {
        throw StateError('Supabase is not configured.');
      }
      final response = await client.auth.signInWithPassword(
        email: email,
        password: password,
      );
      final user = response.user;
      if (user == null) {
        throw StateError('Sign-in did not return a shop account.');
      }
      try {
        await SupabaseSyncService.bindShop(database, '$url|${user.id}');
      } on Object {
        await client.auth.signOut(scope: SignOutScope.local);
        rethrow;
      }
      if (mounted) _password.clear();
    } on Object catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _signOut() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final client = await ref.read(supabaseClientProvider.future);
      if (client == null) {
        throw StateError('Supabase is not configured.');
      }
      await client.auth.signOut(scope: SignOutScope.local);
    } on Object catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final config = ref.watch(supabaseSyncConfigProvider);
    final user = ref.watch(shopUserProvider);
    final status = ref.watch(cloudSyncStatusProvider);
    final error = _error ??
        ref.watch(cloudSyncErrorProvider) ??
        (user.hasError ? user.error.toString() : null);
    final syncing = status == CloudSyncStatus.syncing;
    return Scaffold(
      appBar: AppBar(title: const Text('Cloud sync')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text(status.label, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          const Text(
            'Customers and orders are saved on this device first. Sign in '
            'with the same shop account on each device to sync privately. '
            'Signing out keeps local data and pending changes on this device.',
          ),
          const SizedBox(height: 16),
          if (kIsWeb)
            const Text(
              'This web preview uses in-memory data. Persistent SQLite and '
              'cloud sync are available in the Android app.',
            )
          else if (!config.isConfigured)
            const Text(
              'Build with SUPABASE_URL and SUPABASE_PUBLISHABLE_KEY to enable '
              'cloud sync. Local SQLite works without configuration.',
            )
          else if (user.isLoading)
            const Center(child: CircularProgressIndicator())
          else if (user.valueOrNull == null) ...[
            TextField(
              controller: _email,
              enabled: !_busy,
              keyboardType: TextInputType.emailAddress,
              autofillHints: const [AutofillHints.username],
              decoration: const InputDecoration(labelText: 'Shop email'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _password,
              enabled: !_busy,
              obscureText: true,
              autofillHints: const [AutofillHints.password],
              decoration: const InputDecoration(labelText: 'Password'),
              onSubmitted: (_) {
                if (!_busy) _signIn();
              },
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _busy ? null : _signIn,
              child: Text(_busy ? 'Signing in...' : 'Sign in'),
            ),
            const Text(
                'Create the shop account in the Supabase dashboard first.'),
          ] else ...[
            Text('Shop account: ${user.valueOrNull!.email ?? ''}'),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: syncing || _busy
                  ? null
                  : () => ref.read(syncSchedulerProvider).syncNow(),
              icon: const Icon(Icons.sync),
              label: const Text('Sync now'),
            ),
            TextButton(
              onPressed: syncing || _busy ? null : _signOut,
              child: const Text('Sign out on this device'),
            ),
          ],
          if (error != null) ...[
            const SizedBox(height: 16),
            SelectableText(
              error,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
        ],
      ),
    );
  }
}
