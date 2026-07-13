import '../../../../core/error/result.dart';
import '../entities/dashboard_summary.dart';

/// Порт (интерфейс) репозитория сводки дашборда (FR-9).
abstract interface class DashboardRepository {
  /// [thresholdDays] — порог «скоро заканчивается» в днях (FR-9.5, по умолчанию 30).
  Future<Result<DashboardSummary>> getSummary({int thresholdDays = 30});
}
