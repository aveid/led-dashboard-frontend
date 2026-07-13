import '../../../../core/error/result.dart';
import '../../../../core/network/api_exception.dart';
import '../../domain/entities/kg_boundary.dart';
import '../../domain/repositories/geo_repository.dart';
import '../datasources/geo_remote_ds.dart';

/// Реализация [GeoRepository]: датасорс → доменная граница, ошибки → [Failure].
///
/// Никаких исключений наружу: dio/parse-ошибка становится [Result.failure], а
/// UI при неудаче просто не рисует маску (graceful degradation, FR-1.6).
class GeoRepositoryImpl implements GeoRepository {
  const GeoRepositoryImpl(this._remote);

  final GeoRemoteDataSource _remote;

  @override
  Future<Result<KgBoundary>> getKgBoundary() async {
    try {
      final boundary = await _remote.fetchKgBoundary();
      return Result.success(boundary);
    } on ApiException catch (e) {
      return Result.failure(e.toFailure());
    }
  }
}
