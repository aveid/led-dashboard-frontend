import '../../../../core/error/failure.dart';
import '../../../../core/error/result.dart';
import '../entities/screen.dart';
import '../repositories/screens_repository.dart';

/// Сценарий «Активировать экран» (FR-4). Само правило (нужны арендодатель,
/// договор и фото — FR-4.2) проверяется на бэке; здесь только базовая проверка
/// дат и суммы, чтобы не гонять заведомо некорректный запрос на сервер.
class ActivateScreenUseCase {
  const ActivateScreenUseCase(this._repository);

  final ScreensRepository _repository;

  Future<Result<Screen>> call({
    required String id,
    required double rentPrice,
    required DateTime startDate,
    required DateTime endDate,
  }) {
    if (rentPrice <= 0) {
      return Future.value(
        const Result.failure(ValidationFailure('Стоимость аренды должна быть больше нуля.')),
      );
    }
    if (endDate.isBefore(startDate)) {
      return Future.value(
        const Result.failure(ValidationFailure('Дата окончания раньше даты начала.')),
      );
    }
    return _repository.activateScreen(
      id: id,
      rentPrice: rentPrice,
      startDate: startDate,
      endDate: endDate,
    );
  }
}
