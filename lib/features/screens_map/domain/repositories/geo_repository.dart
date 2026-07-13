import '../../../../core/error/result.dart';
import '../entities/kg_boundary.dart';

/// Порт (интерфейс) репозитория географии (FR-1.6).
abstract interface class GeoRepository {
  /// Загружает границу Кыргызстана (`GET /api/geo/kyrgyzstan`). Ошибку сети/парса
  /// оборачивает в [Result.failure] — исключения наружу не летят. Граница
  /// статична, поэтому вызывается лениво и один раз (см. `kgBoundaryProvider`).
  Future<Result<KgBoundary>> getKgBoundary();
}
