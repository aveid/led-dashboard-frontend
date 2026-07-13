import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers.dart';
import '../../data/datasources/screens_remote_ds.dart';
import '../../data/repositories/screens_repository_impl.dart';
import '../../domain/entities/cost_summary.dart';
import '../../domain/entities/screen.dart';
import '../../domain/repositories/screens_repository.dart';
import '../../domain/usecases/activate_screen_usecase.dart';
import '../../domain/usecases/create_screen_usecase.dart';
import '../../domain/usecases/delete_attachment_usecase.dart';
import '../../domain/usecases/export_screens_usecase.dart';
import '../../domain/usecases/get_cost_summary_usecase.dart';
import '../../domain/usecases/get_screens_usecase.dart';
import '../../domain/usecases/update_screen_usecase.dart';
import '../../domain/usecases/upload_attachment_usecase.dart';
import 'filters_providers.dart';
import 'selection_providers.dart';

/// Провайдеры фичи «карта экранов»: сборка зависимостей, список, стоимость,
/// экспорт, создание/редактирование/активация/загрузка вложений.

final _screensRemoteDataSourceProvider = Provider<ScreensRemoteDataSource>((ref) {
  final dioClient = ref.watch(dioClientProvider);
  return ScreensRemoteDataSource(dioClient.dio);
});

final screensRepositoryProvider = Provider<ScreensRepository>((ref) {
  return ScreensRepositoryImpl(ref.watch(_screensRemoteDataSourceProvider));
});

final _getScreensUseCaseProvider = Provider<GetScreensUseCase>((ref) {
  return GetScreensUseCase(ref.watch(screensRepositoryProvider));
});

final _getCostSummaryUseCaseProvider = Provider<GetCostSummaryUseCase>((ref) {
  return GetCostSummaryUseCase(ref.watch(screensRepositoryProvider));
});

final exportScreensUseCaseProvider = Provider<ExportScreensUseCase>((ref) {
  return ExportScreensUseCase(ref.watch(screensRepositoryProvider));
});

final createScreenUseCaseProvider = Provider<CreateScreenUseCase>((ref) {
  return CreateScreenUseCase(ref.watch(screensRepositoryProvider));
});

final updateScreenUseCaseProvider = Provider<UpdateScreenUseCase>((ref) {
  return UpdateScreenUseCase(ref.watch(screensRepositoryProvider));
});

final activateScreenUseCaseProvider = Provider<ActivateScreenUseCase>((ref) {
  return ActivateScreenUseCase(ref.watch(screensRepositoryProvider));
});

final uploadAttachmentUseCaseProvider = Provider<UploadAttachmentUseCase>((ref) {
  return UploadAttachmentUseCase(ref.watch(screensRepositoryProvider));
});

final deleteAttachmentUseCaseProvider = Provider<DeleteAttachmentUseCase>((ref) {
  return DeleteAttachmentUseCase(ref.watch(screensRepositoryProvider));
});

/// Список экранов для карты (FR-1.2), с учётом текущих фильтров (FR-5).
///
/// Следит за [screenFiltersProvider] — при любом изменении фильтров провайдер
/// автоматически перезапрашивает список с бэка. `ref.invalidate(screensProvider)`
/// используется для ручного обновления (кнопка «Обновить», а также после
/// создания/редактирования/активации/загрузки вложения — см. диалоги в
/// `presentation/widgets/`, каждый из них инвалидирует этот провайдер при успехе).
final screensProvider = FutureProvider<List<Screen>>((ref) async {
  final filters = ref.watch(screenFiltersProvider);
  final result = await ref.watch(_getScreensUseCaseProvider).call(filters: filters);
  return result.when(
    onSuccess: (screens) => screens,
    // throw (тип Never) совместим с R любой ветки when — иначе Future.error(...)
    // не унифицировался бы по типу с List<Screen> из onSuccess.
    onFailure: (failure) => throw failure,
  );
});

/// Расчёт стоимости выбранных экранов (FR-6.2–6.4). null — если ничего не выбрано.
///
/// Следит за [selectedScreenIdsProvider] — пересчитывается при каждом изменении
/// выбора (тап по маркеру в режиме выбора).
final costSummaryProvider = FutureProvider<CostSummary?>((ref) async {
  final selectedIds = ref.watch(selectedScreenIdsProvider);
  if (selectedIds.isEmpty) return null;

  final result = await ref.watch(_getCostSummaryUseCaseProvider).call(selectedIds.toList());
  return result.when(
    onSuccess: (summary) => summary,
    onFailure: (failure) => throw failure,
  );
});
