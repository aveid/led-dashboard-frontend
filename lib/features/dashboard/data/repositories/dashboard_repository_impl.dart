import '../../../../core/error/result.dart';
import '../../../../core/network/api_exception.dart';
import '../../domain/entities/dashboard_summary.dart';
import '../../domain/repositories/dashboard_repository.dart';
import '../datasources/dashboard_remote_ds.dart';

/// Реализация [DashboardRepository]: датасорс → доменную сущность, ошибки → [Failure].
class DashboardRepositoryImpl implements DashboardRepository {
  const DashboardRepositoryImpl(this._remote);

  final DashboardRemoteDataSource _remote;

  @override
  Future<Result<DashboardSummary>> getSummary({int thresholdDays = 30}) async {
    try {
      final dto = await _remote.getSummary(thresholdDays: thresholdDays);
      return Result.success(dto.toDomain());
    } on ApiException catch (e) {
      return Result.failure(e.toFailure());
    }
  }
}
