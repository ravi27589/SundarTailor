import 'dart:convert';

enum SyncEntityType {
  customer,
  order;
}

enum SyncOperation {
  upsert,
  delete;
}

class SyncQueueEntry {
  const SyncQueueEntry({
    required this.id,
    required this.entityType,
    required this.entityId,
    required this.operation,
    required this.payload,
    required this.createdDate,
    this.lastAttemptDate,
    this.error,
  });

  final String id;
  final SyncEntityType entityType;
  final String entityId;
  final SyncOperation operation;
  final Map<String, Object?> payload;
  final DateTime createdDate;
  final DateTime? lastAttemptDate;
  final String? error;

  factory SyncQueueEntry.fromMap(Map<String, Object?> map) {
    return SyncQueueEntry(
      id: map['id'] as String,
      entityType: SyncEntityType.values.byName(map['entity_type'] as String),
      entityId: map['entity_id'] as String,
      operation: SyncOperation.values.byName(map['operation'] as String),
      payload: jsonDecode(map['payload'] as String) as Map<String, Object?>,
      createdDate: DateTime.parse(map['created_date'] as String),
      lastAttemptDate: _parseOptionalDate(map['last_attempt_date']),
      error: map['error'] as String?,
    );
  }

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'entity_type': entityType.name,
      'entity_id': entityId,
      'operation': operation.name,
      'payload': jsonEncode(payload),
      'created_date': createdDate.toIso8601String(),
      'last_attempt_date': lastAttemptDate?.toIso8601String(),
      'error': error,
    };
  }
}

DateTime? _parseOptionalDate(Object? value) {
  if (value is! String || value.isEmpty) {
    return null;
  }
  return DateTime.parse(value);
}