import 'package:intl/intl.dart';

import '../../shared/domain/money.dart';

/// Форматирует сумму в сомах для отображения: `220000` → `220 000 сом`.
///
/// Используется везде, где показывается стоимость аренды (карточка экрана,
/// панель расчёта FR-6, сводка дашборда FR-9), чтобы формат был единым.
String formatSom(num amount) {
  final formatted = NumberFormat.decimalPattern('ru').format(amount);
  return '$formatted сом';
}

/// Текст цены с учётом роли (RBAC, NFR-8). Единая точка маскирования сумм:
/// везде, где раньше стоял прямой `formatSom(...)`, теперь идёт этот helper.
///
/// * Для гостя ([isGuest] == true) — всегда пустая строка `''` (пустая строка
///   на месте суммы, а не «скрыто»). Маскирование ключуется по роли, а не по
///   `null`-значению цены: бэкенд и так отдаёт guest'у `null`, но UI рендерит
///   `''` по роли ради стабильного layout (лейбл цены остаётся, значение пусто).
/// * Нет цены ([money] == null) — тоже пустая строка (как было: цена скрыта).
/// * Иначе — обычный `formatSom` (напр. `220 000 сом`).
String guestPriceText({required bool isGuest, required Money? money}) {
  if (isGuest) return '';
  if (money == null) return '';
  return formatSom(money.amount);
}
