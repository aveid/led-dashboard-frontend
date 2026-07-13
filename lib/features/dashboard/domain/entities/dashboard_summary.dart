import '../../../../shared/domain/landlord_cost.dart';
import '../../../../shared/domain/money.dart';

/// Договор, заканчивающийся в пределах порога (FR-9.5).
class EndingContract {
  const EndingContract({
    required this.screenId,
    required this.screenName,
    required this.endDate,
    this.landlordId,
  });

  final String screenId;
  final String screenName;
  final String? landlordId;
  final DateTime endDate;
}

/// Сводная информация для главного экрана (FR-9).
class DashboardSummary {
  const DashboardSummary({
    required this.totalScreens,
    required this.activeCount,
    required this.inactiveCount,
    required this.potentialCount,
    required this.archivedCount,
    required this.totalActiveRent,
    required this.byLandlord,
    required this.endingSoon,
  });

  final int totalScreens;
  final int activeCount;
  final int inactiveCount;
  final int potentialCount;
  final int archivedCount;
  final Money totalActiveRent;
  final List<LandlordCost> byLandlord;
  final List<EndingContract> endingSoon;
}
