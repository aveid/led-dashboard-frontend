import '../../../../core/error/result.dart';
import '../entities/screen.dart';
import '../entities/screen_filters.dart';
import '../repositories/screens_repository.dart';

/// Сценарий «Получить список экранов для карты» с учётом фильтров (FR-1.2, FR-5).
class GetScreensUseCase {
  const GetScreensUseCase(this._repository);

  final ScreensRepository _repository;

  Future<Result<List<Screen>>> call({ScreenFilters filters = const ScreenFilters.empty()}) {
    return _repository.getScreens(filters: filters);
  }
}
