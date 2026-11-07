import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite/sqflite.dart';

import 'app_database.dart';

final appDatabaseProvider = Provider<AppDatabase>((ref) => AppDatabase());

final databaseProvider = FutureProvider<Database>((ref) async {
  return ref.watch(appDatabaseProvider).open();
});