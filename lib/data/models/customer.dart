import 'dart:convert';

class Customer {
  const Customer({
    required this.id,
    required this.customerNumber,
    required this.name,
    required this.phone,
    required this.shirtMeasurements,
    required this.trouserMeasurements,
    required this.pajamaMeasurements,
    required this.suitMeasurements,
    required this.shortsMeasurements,
    required this.kurtaMeasurements,
    required this.safariMeasurements,
    required this.notes,
    required this.createdDate,
    required this.updatedDate,
    this.deletedDate,
  });

  final String id;
  final String customerNumber;
  final String name;
  final String phone;
  final Map<String, String> shirtMeasurements;
  final Map<String, String> trouserMeasurements;
  final Map<String, String> pajamaMeasurements;
  final Map<String, String> suitMeasurements;
  final Map<String, String> shortsMeasurements;
  final Map<String, String> kurtaMeasurements;
  final Map<String, String> safariMeasurements;
  final String notes;
  final DateTime createdDate;
  final DateTime updatedDate;
  final DateTime? deletedDate;

  factory Customer.fromMap(Map<String, Object?> map) {
    return Customer(
      id: map['id'] as String,
      customerNumber: map['customer_number'] as String,
      name: map['name'] as String,
      phone: map['phone'] as String,
      shirtMeasurements: _decodeMeasurements(map['shirt_measurements']),
      trouserMeasurements: _decodeMeasurements(map['trouser_measurements']),
      pajamaMeasurements: _decodeMeasurements(map['pajama_measurements']),
      suitMeasurements: _decodeMeasurements(map['suit_measurements']),
      shortsMeasurements: _decodeMeasurements(map['shorts_measurements']),
      kurtaMeasurements: _decodeMeasurements(map['kurta_measurements']),
      safariMeasurements: _decodeMeasurements(map['safari_measurements']),
      notes: map['notes'] as String? ?? '',
      createdDate: DateTime.parse(map['created_date'] as String),
      updatedDate: DateTime.parse(map['updated_date'] as String),
      deletedDate: _parseOptionalDate(map['deleted_date']),
    );
  }

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'customer_number': customerNumber,
      'name': name,
      'phone': phone,
      'shirt_measurements': jsonEncode(shirtMeasurements),
      'trouser_measurements': jsonEncode(trouserMeasurements),
      'pajama_measurements': jsonEncode(pajamaMeasurements),
      'suit_measurements': jsonEncode(suitMeasurements),
      'shorts_measurements': jsonEncode(shortsMeasurements),
      'kurta_measurements': jsonEncode(kurtaMeasurements),
      'safari_measurements': jsonEncode(safariMeasurements),
      'notes': notes,
      'created_date': createdDate.toIso8601String(),
      'updated_date': updatedDate.toIso8601String(),
      'deleted_date': deletedDate?.toIso8601String(),
    };
  }

  Customer copyWith({
    String? name,
    String? phone,
    Map<String, String>? shirtMeasurements,
    Map<String, String>? trouserMeasurements,
    Map<String, String>? pajamaMeasurements,
    Map<String, String>? suitMeasurements,
    Map<String, String>? shortsMeasurements,
    Map<String, String>? kurtaMeasurements,
    Map<String, String>? safariMeasurements,
    String? notes,
    DateTime? updatedDate,
  }) {
    return Customer(
      id: id,
      customerNumber: customerNumber,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      shirtMeasurements: shirtMeasurements ?? this.shirtMeasurements,
      trouserMeasurements: trouserMeasurements ?? this.trouserMeasurements,
      pajamaMeasurements: pajamaMeasurements ?? this.pajamaMeasurements,
      suitMeasurements: suitMeasurements ?? this.suitMeasurements,
      shortsMeasurements: shortsMeasurements ?? this.shortsMeasurements,
      kurtaMeasurements: kurtaMeasurements ?? this.kurtaMeasurements,
      safariMeasurements: safariMeasurements ?? this.safariMeasurements,
      notes: notes ?? this.notes,
      createdDate: createdDate,
      updatedDate: updatedDate ?? this.updatedDate,
      deletedDate: deletedDate,
    );
  }
}

Map<String, String> _decodeMeasurements(Object? value) {
  if (value is! String || value.isEmpty) {
    return const {};
  }

  final decoded = jsonDecode(value) as Map<String, Object?>;
  return decoded.map((key, value) => MapEntry(key, value?.toString() ?? ''));
}

DateTime? _parseOptionalDate(Object? value) {
  if (value is! String || value.isEmpty) {
    return null;
  }
  return DateTime.parse(value);
}
