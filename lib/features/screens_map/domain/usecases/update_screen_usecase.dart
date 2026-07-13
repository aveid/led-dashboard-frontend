import '../../../../core/error/failure.dart';
import '../../../../core/error/result.dart';
import '../../../../shared/domain/screen_status.dart';
import '../entities/screen.dart';
import '../repositories/screens_repository.dart';

/// Сценарий «Редактировать экран» (FR-10.2). Перевод в статус «активный» через
/// этот сценарий запрещён на бэке — для активации есть отдельный сценарий
/// активации (требует договор и фото, правило FR-4.2).
class UpdateScreenUseCase {
  const UpdateScreenUseCase(this._repository);

  final ScreensRepository _repository;

  Future<Result<Screen>> call({
    required String id,
    String? name,
    int? cityId,
    String? size,
    int? screenTypeId,
    double? latitude,
    double? longitude,
    ScreenStatus? status,
    String? landlordId,
    String? contactId,
    List<String>? campaignIds,
    String? comment,
    DateTime? rentalEndDate,
    bool clearRentalEndDate = false,
  }) {
    if (name != null && name.trim().isEmpty) {
      return Future.value(const Result.failure(ValidationFailure('Название не может быть пустым.')));
    }
    // Размер обязателен и не может быть пустым (в т.ч. у мигрированного экрана
    // с пустым size — пользователь обязан вписать значение).
    if (size != null && size.trim().isEmpty) {
      return Future.value(const Result.failure(ValidationFailure('Введите размер экрана.')));
    }
    return _repository.updateScreen(
      id: id,
      name: name?.trim(),
      cityId: cityId,
      size: size?.trim(),
      screenTypeId: screenTypeId,
      latitude: latitude,
      longitude: longitude,
      status: status,
      landlordId: landlordId,
      contactId: contactId,
      campaignIds: campaignIds,
      comment: comment?.trim(),
      rentalEndDate: rentalEndDate,
      clearRentalEndDate: clearRentalEndDate,
    );
  }
}
