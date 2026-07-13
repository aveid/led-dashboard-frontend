import '../../../../core/error/result.dart';
import '../entities/dashboard_summary.dart';
import '../repositories/dashboard_repository.dart';

/// Сценарий «Получить сводку для главного экрана» (FR-9).
class GetDashboardSummaryUseCase {
  const GetDashboardSummaryUseCase(this._repository);

  final DashboardRepository _repository;

  Future<Result<DashboardSummary>> call({int thresholdDays = 30}) {
    return _repository.getSummary(thresholdDays: thresholdDays);
  }
}
