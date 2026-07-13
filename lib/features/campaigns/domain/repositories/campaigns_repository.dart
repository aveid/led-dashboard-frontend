import '../../../../core/error/result.dart';
import '../entities/campaign.dart';

/// Порт (интерфейс) репозитория кампаний (FR-3.10).
abstract interface class CampaignsRepository {
  Future<Result<List<Campaign>>> getCampaigns();
  Future<Result<Campaign>> createCampaign(String name);
  Future<Result<Campaign>> updateCampaign({required String id, required String name});
  Future<Result<void>> deleteCampaign(String id);
}
