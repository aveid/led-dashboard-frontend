import '../../../../shared/domain/landlord_cost.dart';
import '../../domain/entities/cost_summary.dart';
import 'money_dto.dart';

/// DTO разбивки по арендодателю (зеркалит `LandlordCostSchema` на бэке).
class LandlordCostDto {
  const LandlordCostDto({required this.landlordId, required this.screensCount, required this.total});

  final String? landlordId;
  final int screensCount;
  final MoneyDto total;

  factory LandlordCostDto.fromJson(Map<String, dynamic> json) {
    return LandlordCostDto(
      landlordId: json['landlord_id'] as String?,
      screensCount: json['screens_count'] as int,
      total: MoneyDto.fromJson(json['total'] as Map<String, dynamic>),
    );
  }

  LandlordCost toDomain() =>
      LandlordCost(landlordId: landlordId, screensCount: screensCount, total: total.toDomain());
}

/// DTO ответа расчёта стоимости (зеркалит `CostSummaryResponse` на бэке).
class CostSummaryDto {
  const CostSummaryDto({required this.selectedCount, required this.total, required this.byLandlord});

  final int selectedCount;
  final MoneyDto total;
  final List<LandlordCostDto> byLandlord;

  factory CostSummaryDto.fromJson(Map<String, dynamic> json) {
    return CostSummaryDto(
      selectedCount: json['selected_count'] as int,
      total: MoneyDto.fromJson(json['total'] as Map<String, dynamic>),
      byLandlord: (json['by_landlord'] as List<dynamic>? ?? [])
          .map((e) => LandlordCostDto.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  CostSummary toDomain() => CostSummary(
        selectedCount: selectedCount,
        total: total.toDomain(),
        byLandlord: byLandlord.map((e) => e.toDomain()).toList(),
      );
}
