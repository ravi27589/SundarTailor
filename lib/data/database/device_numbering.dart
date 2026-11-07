import 'package:sqflite/sqflite.dart';

Future<String> deviceNumberSuffix(DatabaseExecutor executor) async {
  final rows = await executor.query(
    'sync_state',
    where: 'key = ?',
    whereArgs: ['supabase_device_suffix'],
    limit: 1,
  );
  return rows.isEmpty ? '' : '-${rows.single['value']}';
}
