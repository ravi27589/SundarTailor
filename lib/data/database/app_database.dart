import 'package:path/path.dart' as path;
import 'package:sqflite/sqflite.dart';

import 'schema.dart';

class AppDatabase {
  Database? _database;

  Future<Database> open() async {
    final existing = _database;
    if (existing != null) {
      return existing;
    }

    final databasePath =
        path.join(await getDatabasesPath(), 'sundar_tailor.db');

    final opened = await openDatabase(
      databasePath,
      version: DatabaseSchema.version,
      onCreate: _create,
      onUpgrade: _upgrade,
      onConfigure: (database) async {
        await database.execute('PRAGMA foreign_keys = ON');
      },
    );
    _database = opened;
    return opened;
  }

  Future<void> _create(Database database, int version) async {
    await database.execute(DatabaseSchema.createCustomers);
    await database.execute(DatabaseSchema.createOrders);
    await database.execute(DatabaseSchema.createSyncQueue);
    await database.execute(DatabaseSchema.createSyncState);

    for (final statement in DatabaseSchema.indexes) {
      await database.execute(statement);
    }
  }

  Future<void> _upgrade(
    Database database,
    int oldVersion,
    int newVersion,
  ) async {
    if (oldVersion < 2) {
      await database.execute(
        "ALTER TABLE customers ADD COLUMN kurta_measurements TEXT NOT NULL DEFAULT '{}'",
      );
      await database.execute(
        "ALTER TABLE customers ADD COLUMN safari_measurements TEXT NOT NULL DEFAULT '{}'",
      );
    }
    if (oldVersion < 3) {
      await database.execute(
        "ALTER TABLE orders ADD COLUMN comments TEXT NOT NULL DEFAULT ''",
      );
      await database.execute(
        'ALTER TABLE orders ADD COLUMN quantity INTEGER NOT NULL DEFAULT 1',
      );
    }
    if (oldVersion < 4) {
      await database.execute(DatabaseSchema.createSyncState);
    }
  }
}
