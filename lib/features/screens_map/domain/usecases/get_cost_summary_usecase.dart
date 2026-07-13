import '../../../../core/error/failure.dart';
import '../../../../core/error/result.dart';
import '../entities/cost_summary.dart';
import '../repositories/screens_repository.dart';

/// Сценарий «Рассчитать стоимость выбранных экранов» (FR-6).
class GetCostSummaryUseCase {
  const GetCostSummaryUseCase(this._repository);

  final ScreensRepository _repository;

  Future<Result<CostSummary>> call(List<String> screenIds) {
    if (screenIds.isEmpty) {
      return Future.value(
        const Result.failure(ValidationFailure('Выберите хотя бы один экран.')),
      );
    }
    return _repository.getCostSummary(screenIds);
  }
}
