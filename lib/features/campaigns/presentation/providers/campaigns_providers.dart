import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error/result.dart';
import '../../../../core/providers.dart';
import '../../data/datasources/campaigns_remote_ds.dart';
import '../../data/repositories/campaigns_repository_impl.dart';
import '../../domain/entities/campaign.dart';
import '../../domain/repositories/campaigns_repository.dart';
import '../../domain/usecases/campaigns_usecases.dart';

/// Провайдеры фичи «кампании»: сборка зависимостей и список с мутациями.

final _campaignsRemoteDataSourceProvider = Provider<CampaignsRemoteDataSource>((ref) {
  return CampaignsRemoteDataSource(ref.watch(dioClientProvider).dio);
});

final campaignsRepositoryProvider = Provider<CampaignsRepository>((ref) {
  return CampaignsRepositoryImpl(ref.watch(_campaignsRemoteDataSourceProvider));
});

final _listUseCaseProvider = Provider<ListCampaignsUseCase>((ref) {
  return ListCampaignsUseCase(ref.watch(campaignsRepositoryProvider));
});
final _createUseCaseProvider = Provider<CreateCampaignUseCase>((ref) {
  return CreateCampaignUseCase(ref.watch(campaignsRepositoryProvider));
});
final _updateUseCaseProvider = Provider<UpdateCampaignUseCase>((ref) {
  return UpdateCampaignUseCase(ref.watch(campaignsRepositoryProvider));
});
final _deleteUseCaseProvider = Provider<DeleteCampaignUseCase>((ref) {
  return DeleteCampaignUseCase(ref.watch(campaignsRepositoryProvider));
});

/// Список кампаний с CRUD-мутациями (FR-3.10). Тот же принцип, что и у
/// арендодателей: после успешной мутации — `invalidateSelf()` и перезапрос.
class CampaignsListController extends AsyncNotifier<List<Campaign>> {
  @override
  Future<List<Campaign>> build() async {
    final result = await ref.read(_listUseCaseProvider).call();
    return result.when(onSuccess: (v) => v, onFailure: (f) => throw f);
  }

  Future<Result<Campaign>> create(String name) async {
    final result = await ref.read(_createUseCaseProvider).call(name);
    if (result.isSuccess) ref.invalidateSelf();
    return result;
  }

  Future<Result<Campaign>> updateCampaign({required String id, required String name}) async {
    final result = await ref.read(_updateUseCaseProvider).call(id: id, name: name);
    if (result.isSuccess) ref.invalidateSelf();
    return result;
  }

  Future<Result<void>> delete(String id) async {
    final result = await ref.read(_deleteUseCaseProvider).call(id);
    if (result.isSuccess) ref.invalidateSelf();
    return result;
  }
}

final campaignsListProvider = AsyncNotifierProvider<CampaignsListController, List<Campaign>>(
  CampaignsListController.new,
);
