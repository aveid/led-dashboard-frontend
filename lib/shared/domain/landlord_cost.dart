import 'money.dart';

/// Разбивка стоимости/количества по одному арендодателю.
///
/// Общий тип (FR-6.4 и FR-9.4 используют одинаковую форму данных на бэке —
/// `LandlordCostSchema`), поэтому вынесен в `shared/domain`: и `screens_map`
/// (расчёт стоимости выбранных), и `dashboard` (сводка по всем экранам) на него
/// ссылаются, не зная друг о друге.
class LandlordCost {
  const LandlordCost({required this.landlordId, required this.screensCount, required this.total});

  final String? landlordId;
  final int screensCount;
  final Money total;
}
