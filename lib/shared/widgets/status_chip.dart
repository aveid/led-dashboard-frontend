import 'package:flutter/material.dart';

import '../domain/screen_status.dart';

/// Чип статуса экрана: цветная точка + подпись (FR-2.3).
///
/// Цвет и подпись берутся из самого [ScreenStatus], поэтому чип не содержит
/// хардкод-цветов и остаётся согласованным с маркерами на карте.
class StatusChip extends StatelessWidget {
  const StatusChip(this.status, {super.key});

  final ScreenStatus status;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: status.color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: status.color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            status.label,
            style: TextStyle(
              color: status.color,
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
