import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';
import '../data/models/tailor_order.dart';

class OrderStatusChip extends StatelessWidget {
  const OrderStatusChip({super.key, required this.status});

  final OrderStatus status;

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      OrderStatus.booked => StatusColors.booked,
      OrderStatus.drying => StatusColors.drying,
      OrderStatus.cutting => StatusColors.cutting,
      OrderStatus.stitching => StatusColors.stitching,
      OrderStatus.finishing => StatusColors.finishing,
      OrderStatus.ironing => StatusColors.ironing,
      OrderStatus.trial => StatusColors.trial,
      OrderStatus.ready => StatusColors.ready,
      OrderStatus.delivered => StatusColors.delivered,
      OrderStatus.cancelled => StatusColors.cancelled,
    };

    return Chip(
      label: Text(status.label),
      labelStyle: const TextStyle(color: Colors.white),
      backgroundColor: color,
      side: BorderSide.none,
      visualDensity: VisualDensity.compact,
    );
  }
}
