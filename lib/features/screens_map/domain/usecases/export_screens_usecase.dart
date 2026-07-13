import '../../../../core/error/result.dart';
import '../entities/screen_filters.dart';
import '../repositories/screens_repository.dart';

/// Сценарий «Выгрузить экраны в Excel» (FR-7). Возвращает байты .xlsx-файла —
/// сохранение/скачивание в браузере делает презентационный слой.
class ExportScreensUseCase {
  const ExportScreensUseCase(this._repository);

  final ScreensRepository _repository;

  Future<Result<List<int>>> call({
    List<String> screenIds = const [],
    ScreenFilters filters = const ScreenFilters.empty(),
  }) {
    return _repository.exportScreens(screenIds: screenIds, filters: filters);
  }
}
