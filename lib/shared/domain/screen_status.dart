import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

/// Статус LED-экрана (FR-2.1). Значения `value` совпадают со строками бэкенда
/// (`ScreenStatus` в `features/screens/domain/enums.py`): active/inactive/…
///
/// К каждому статусу привязаны цвет маркера (FR-1.3/2.3) и подпись на русском —
/// чтобы не разносить эту таблицу соответствий по разным виджетам.
enum ScreenStatus {
  active('active', 'Активный', AppColors.statusActive),
  inactive('inactive', 'Неактивный', AppColors.statusInactive),
  potential('potential', 'Потенциальный', AppColors.statusPotential),
  archived('archived', 'Архивный', AppColors.statusArchived);

  const ScreenStatus(this.value, this.label, this.color);

  /// Строковое значение, как в API.
  final String value;

  /// Человекочитаемая подпись (русский).
  final String label;

  /// Цвет статуса (маркер на карте, чип).
  final Color color;

  /// Разбирает значение из API в enum; неизвестное — трактуем как потенциальный.
  static ScreenStatus fromValue(String value) {
    return ScreenStatus.values.firstWhere(
      (status) => status.value == value,
      orElse: () => ScreenStatus.potential,
    );
  }
}
