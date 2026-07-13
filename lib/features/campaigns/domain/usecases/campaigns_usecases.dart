import '../../../../core/error/failure.dart';
import '../../../../core/error/result.dart';
import '../entities/campaign.dart';
import '../repositories/campaigns_repository.dart';

/// Сценарии модуля «кампании» (FR-3.10).

class ListCampaignsUseCase {
  const ListCampaignsUseCase(this._repository);
  final CampaignsRepository _repository;

  Future<Result<List<Campaign>>> call() => _repository.getCampaigns();
}

class CreateCampaignUseCase {
  const CreateCampaignUseCase(this._repository);
  final CampaignsRepository _repository;

  Future<Result<Campaign>> call(String name) {
    if (name.trim().isEmpty) {
      return Future.value(
        const Result.failure(ValidationFailure('Название кампании не может быть пустым.')),
      );
    }
    return _repository.createCampaign(name.trim());
  }
}

class UpdateCampaignUseCase {
  const UpdateCampaignUseCase(this._repository);
  final CampaignsRepository _repository;

  Future<Result<Campaign>> call({required String id, required String name}) {
    if (name.trim().isEmpty) {
      return Future.value(
        const Result.failure(ValidationFailure('Название кампании не может быть пустым.')),
      );
    }
    return _repository.updateCampaign(id: id, name: name.trim());
  }
}

class DeleteCampaignUseCase {
  const DeleteCampaignUseCase(this._repository);
  final CampaignsRepository _repository;

  Future<Result<void>> call(String id) => _repository.deleteCampaign(id);
}
