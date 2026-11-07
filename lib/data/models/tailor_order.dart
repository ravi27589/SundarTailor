enum OrderStatus {
  booked,
  drying,
  cutting,
  stitching,
  finishing,
  ironing,
  trial,
  ready,
  delivered,
  cancelled;

  static const editableStatuses = [
    booked,
    drying,
    cutting,
    stitching,
    finishing,
    ironing,
    ready,
    delivered,
  ];

  String get label {
    return switch (this) {
      OrderStatus.booked => 'Booked',
      OrderStatus.drying => 'Drying',
      OrderStatus.cutting => 'Cutting',
      OrderStatus.stitching => 'Stitching',
      OrderStatus.finishing => 'Finishing',
      OrderStatus.ironing => 'Ironing',
      OrderStatus.trial => 'Trial',
      OrderStatus.ready => 'Ready',
      OrderStatus.delivered => 'Delivered',
      OrderStatus.cancelled => 'Cancelled',
    };
  }

  static OrderStatus fromStorage(String value) {
    return OrderStatus.values.firstWhere(
      (status) => status.name == value,
      orElse: () => OrderStatus.booked,
    );
  }
}

class TailorOrder {
  const TailorOrder({
    required this.id,
    required this.orderNumber,
    required this.customerId,
    required this.bookingDate,
    required this.deliveryDate,
    required this.orderDetails,
    this.comments = '',
    this.quantity = 1,
    required this.amount,
    required this.advancePaid,
    required this.status,
    required this.createdDate,
    required this.updatedDate,
    this.deletedDate,
  });

  final String id;
  final String orderNumber;
  final String customerId;
  final DateTime bookingDate;
  final DateTime deliveryDate;
  final String orderDetails;
  final String comments;
  final int quantity;
  final double amount;
  final double advancePaid;
  final OrderStatus status;
  final DateTime createdDate;
  final DateTime updatedDate;
  final DateTime? deletedDate;

  double get balanceAmount => amount - advancePaid;

  factory TailorOrder.fromMap(Map<String, Object?> map) {
    return TailorOrder(
      id: map['id'] as String,
      orderNumber: map['order_number'] as String,
      customerId: map['customer_id'] as String,
      bookingDate: DateTime.parse(map['booking_date'] as String),
      deliveryDate: DateTime.parse(map['delivery_date'] as String),
      orderDetails: map['order_details'] as String,
      comments: map['comments'] as String? ?? '',
      quantity: (map['quantity'] as num?)?.toInt() ?? 1,
      amount: (map['amount'] as num).toDouble(),
      advancePaid: (map['advance_paid'] as num).toDouble(),
      status: OrderStatus.fromStorage(map['status'] as String),
      createdDate: DateTime.parse(map['created_date'] as String),
      updatedDate: DateTime.parse(map['updated_date'] as String),
      deletedDate: _parseOptionalDate(map['deleted_date']),
    );
  }

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'order_number': orderNumber,
      'customer_id': customerId,
      'booking_date': bookingDate.toIso8601String(),
      'delivery_date': deliveryDate.toIso8601String(),
      'order_details': orderDetails,
      'comments': comments,
      'quantity': quantity,
      'amount': amount,
      'advance_paid': advancePaid,
      'status': status.name,
      'created_date': createdDate.toIso8601String(),
      'updated_date': updatedDate.toIso8601String(),
      'deleted_date': deletedDate?.toIso8601String(),
    };
  }
}

class OrderDraft {
  const OrderDraft({
    required this.itemType,
    required this.comments,
    required this.quantity,
    required this.deliveryDate,
  });

  final String itemType;
  final String comments;
  final int quantity;
  final DateTime deliveryDate;
}

DateTime? _parseOptionalDate(Object? value) {
  if (value is! String || value.isEmpty) {
    return null;
  }
  return DateTime.parse(value);
}
