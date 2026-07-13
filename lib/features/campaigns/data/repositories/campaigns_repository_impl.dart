import '../../../../core/error/result.dart';
import '../../../../core/network/api_exception.dart';
import '../../domain/entities/campaign.dart';
import '../../domain/repositories/campaigns_repository.dart';
import '../datasources/campaigns_remote_ds.dart';

/// Реализация [CampaignsRepository]: датасорс → доменные сущности, ошибки → [Failure].
class CampaignsRepositoryImpl implements CampaignsRepository {
  const CampaignsRepositoryImpl(this._remote);

  final CampaignsRemoteDataSource _remote;

  @override
  Future<Result<List<Campaign>>> getCampaigns() async {
    try {
      final dtos = await _remote.getCampaigns();
      return Result.success(dtos.map((dto) => dto.toDomain()).toList());
    } on ApiException catch (e) {
      return Result.failure(e.toFailure());
    }
  }

  @override
  Future<Result<Campaign>> createCampaign(String name) async {
    try {
      final dto = await _remote.createCampaign(name);
      return Result.success(dto.toDomain());
    } on ApiException catch (e) {
      return Result.failure(e.toFailure());
    }
  }

  @override
  Future<Result<Campaign>> updateCampaign({required String id, required String name}) async {
    try {
      final dto = await _remote.updateCampaign(id: id, name: name);
      return Result.success(dto.toDomain());
    } on ApiException catch (e) {
      return Result.failure(e.toFailure());
    }
  }

  @override
  Future<Result<void>> deleteCampaign(String id) async {
    try {
      await _remote.deleteCampaign(id);
      return const Result.success(null);
    } on ApiException catch (e) {
      return Result.failure(e.toFailure());
    }
  }
}
