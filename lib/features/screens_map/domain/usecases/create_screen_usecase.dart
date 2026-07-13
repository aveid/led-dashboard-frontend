import '../../../../core/error/failure.dart';
import '../../../../core/error/result.dart';
import '../../../../shared/domain/screen_status.dart';
import '../entities/screen.dart';
import '../repositories/screens_repository.dart';

/// Сценарий «Создать экран» (FR-10.1). Минимальная валидация — совпадает с тем,
/// что и так проверит бэк (`ValidationError` на пустой город/название), но
/// проверить на фронте дешевле, чем ждать round-trip до сервера за очевидной ошибкой.
class CreateScreenUseCase {
  const CreateScreenUseCase(this._repository);

  final ScreensRepository _repository;

  Future<Result<Screen>> call({
    required String name,
    required int cityId,
    required String size,
    required int screenTypeId,
    required double latitude,
    required double longitude,
    ScreenStatus status = ScreenStatus.potential,
    String? landlordId,
    String? contactId,
    List<String> campaignIds = const [],
    String comment = '',
    DateTime? rentalEndDate,
  }) {
    if (name.trim().isEmpty) {
      return Future.value(const Result.failure(ValidationFailure('Введите название экрана.')));
    }
    if (size.trim().isEmpty) {
      return Future.value(const Result.failure(ValidationFailure('Введите размер экрана.')));
    }
    return _repository.createScreen(
      name: name.trim(),
      cityId: cityId,
      size: size.trim(),
      screenTypeId: screenTypeId,
      latitude: latitude,
      longitude: longitude,
      status: status,
      landlordId: landlordId,
      contactId: contactId,
      campaignIds: campaignIds,
      comment: comment.trim(),
      rentalEndDate: rentalEndDate,
    );
  }
}
