import '../../../../core/error/result.dart';
import '../repositories/screens_repository.dart';

/// Сценарий «Удалить экран» — жест на карте (правый клик/долгий тап по
/// маркеру → «Удалить экран»). Тонкая обёртка над репозиторием.
class DeleteScreenUseCase {
  const DeleteScreenUseCase(this._repository);

  final ScreensRepository _repository;

  Future<Result<void>> call(String id) {
    return _repository.deleteScreen(id);
  }
}
