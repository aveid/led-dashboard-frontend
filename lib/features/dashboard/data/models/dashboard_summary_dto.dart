import '../../../screens_map/data/models/cost_summary_dto.dart' show LandlordCostDto;
import '../../../screens_map/data/models/money_dto.dart';
import '../../domain/entities/dashboard_summary.dart';

/// DTO договора, заканчивающегося в пределах порога (зеркалит `EndingContractSchema`).
class EndingContractDto {
  const EndingContractDto({
    required this.screenId,
    required this.screenName,
    required this.endDate,
    this.landlordId,
  });

  final String screenId;
  final String screenName;
  final String? landlordId;
  final DateTime endDate;

  factory EndingContractDto.fromJson(Map<String, dynamic> json) {
    return EndingContractDto(
      screenId: json['screen_id'] as String,
      screenName: json['screen_name'] as String,
      landlordId: json['landlord_id'] as String?,
      endDate: DateTime.parse(json['end_date'] as String),
    );
  }

  EndingContract toDomain() => EndingContract(
        screenId: screenId,
        screenName: screenName,
        landlordId: landlordId,
        endDate: endDate,
      );
}

/// DTO сводки дашборда (зеркалит `DashboardSummaryResponse` на бэке).
///
/// Переиспользует `LandlordCostDto` из фичи `screens_map` (тот же формат
/// `{landlord_id, screens_count, total}`, что и в разбивке FR-6.4) — дублировать
/// идентичный DTO ради формальной изоляции фич смысла не имеет.
class DashboardSummaryDto {
  const DashboardSummaryDto({
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
  final MoneyDto totalActiveRent;
  final List<LandlordCostDto> byLandlord;
  final List<EndingContractDto> endingSoon;

  factory DashboardSummaryDto.fromJson(Map<String, dynamic> json) {
    return DashboardSummaryDto(
      totalScreens: json['total_screens'] as int,
      activeCount: json['active_count'] as int,
      inactiveCount: json['inactive_count'] as int,
      potentialCount: json['potential_count'] as int,
      archivedCount: json['archived_count'] as int,
      totalActiveRent: MoneyDto.fromJson(json['total_active_rent'] as Map<String, dynamic>),
      byLandlord: (json['by_landlord'] as List<dynamic>? ?? [])
          .map((e) => LandlordCostDto.fromJson(e as Map<String, dynamic>))
          .toList(),
      endingSoon: (json['ending_soon'] as List<dynamic>? ?? [])
          .map((e) => EndingContractDto.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  DashboardSummary toDomain() => DashboardSummary(
        totalScreens: totalScreens,
        activeCount: activeCount,
        inactiveCount: inactiveCount,
        potentialCount: potentialCount,
        archivedCount: archivedCount,
        totalActiveRent: totalActiveRent.toDomain(),
        byLandlord: byLandlord.map((e) => e.toDomain()).toList(),
        endingSoon: endingSoon.map((e) => e.toDomain()).toList(),
      );
}
