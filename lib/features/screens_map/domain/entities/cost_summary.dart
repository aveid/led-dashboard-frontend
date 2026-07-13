import '../../../../shared/domain/landlord_cost.dart';
import '../../../../shared/domain/money.dart';

/// Результат расчёта стоимости выбранных экранов (FR-6.2–6.4).
class CostSummary {
  const CostSummary({
    required this.selectedCount,
    required this.total,
    required this.byLandlord,
  });

  final int selectedCount;
  final Money total;
  final List<LandlordCost> byLandlord;
}
