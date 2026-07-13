import '../../../../core/error/failure.dart';
import '../../../../core/error/result.dart';
import '../entities/landlord.dart';
import '../repositories/landlords_repository.dart';

/// Сценарии модуля «арендодатели» (FR-8). Все тонкие — валидация минимальна
/// (непустое название, как и на бэке), основная работа — в репозитории.

class ListLandlordsUseCase {
  const ListLandlordsUseCase(this._repository);
  final LandlordsRepository _repository;

  Future<Result<List<Landlord>>> call() => _repository.getLandlords();
}

class CreateLandlordUseCase {
  const CreateLandlordUseCase(this._repository);
  final LandlordsRepository _repository;

  Future<Result<Landlord>> call({
    required String name,
    String contactPerson = '',
    String phone = '',
    String email = '',
  }) {
    if (name.trim().isEmpty) {
      return Future.value(
        const Result.failure(ValidationFailure('Название арендодателя не может быть пустым.')),
      );
    }
    return _repository.createLandlord(
      name: name.trim(),
      contactPerson: contactPerson.trim(),
      phone: phone.trim(),
      email: email.trim(),
    );
  }
}

class UpdateLandlordUseCase {
  const UpdateLandlordUseCase(this._repository);
  final LandlordsRepository _repository;

  Future<Result<Landlord>> call({
    required String id,
    String? name,
    String? contactPerson,
    String? phone,
    String? email,
  }) {
    if (name != null && name.trim().isEmpty) {
      return Future.value(
        const Result.failure(ValidationFailure('Название арендодателя не может быть пустым.')),
      );
    }
    return _repository.updateLandlord(
      id: id,
      name: name?.trim(),
      contactPerson: contactPerson?.trim(),
      phone: phone?.trim(),
      email: email?.trim(),
    );
  }
}

class DeleteLandlordUseCase {
  const DeleteLandlordUseCase(this._repository);
  final LandlordsRepository _repository;

  Future<Result<void>> call(String id) => _repository.deleteLandlord(id);
}
