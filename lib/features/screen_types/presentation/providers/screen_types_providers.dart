import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error/result.dart';
import '../../../../core/providers.dart';
import '../../data/datasources/screen_types_remote_ds.dart';
import '../../data/repositories/screen_types_repository_impl.dart';
import '../../domain/entities/screen_type.dart';
import '../../domain/repositories/screen_types_repository.dart';

/// Провайдеры фичи «типы экрана»: сборка зависимостей, кэшированный список и
/// мутации.

final _screenTypesRemoteDataSourceProvider = Provider<ScreenTypesRemoteDataSource>((ref) {
  return ScreenTypesRemoteDataSource(ref.watch(dioClientProvider).dio);
});

final screenTypesRepositoryProvider = Provider<ScreenTypesRepository>((ref) {
  return ScreenTypesRepositoryImpl(ref.watch(_screenTypesRemoteDataSourceProvider));
});

/// Единый источник типов экрана: используется разделом «Тип экрана», дропдауном
/// в форме экрана и фильтром списка экранов (как договорено с Архитектором —
/// один запрос/кэш в одном месте). Мутации в [ScreenTypesController] инвалидируют
/// этот провайдер, поэтому все три места получают свежий список после CRUD.
final screenTypesProvider = FutureProvider<List<ScreenType>>((ref) async {
  final result = await ref.watch(screenTypesRepositoryProvider).getScreenTypes();
  return result.when(onSuccess: (v) => v, onFailure: (f) => throw f);
});

/// Мутации типов экрана (создание/редактирование/удаление) с последующим
/// обновлением [screenTypesProvider].
///
/// `AsyncNotifier<void>` — сам список живёт в [screenTypesProvider]; контроллер
/// только выполняет мутацию и инвалидирует список при успехе. Методы возвращают
/// [Result], чтобы UI показал типизированную ошибку (валидация/дубликат, тип в
/// использовании) без ловли исключений (FRONTEND_CONTEXT.md §2). Имена методов
/// без зарезервированных слов (`update`/`state`/`future`/`ref`).
class ScreenTypesController extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<Result<ScreenType>> add({required String name, String? code}) async {
    final result = await ref.read(screenTypesRepositoryProvider).createScreenType(
          name: name,
          code: code,
        );
    if (result.isSuccess) ref.invalidate(screenTypesProvider);
    return result;
  }

  Future<Result<ScreenType>> edit(int id, {String? name, String? code}) async {
    final result = await ref.read(screenTypesRepositoryProvider).updateScreenType(
          id,
          name: name,
          code: code,
        );
    if (result.isSuccess) ref.invalidate(screenTypesProvider);
    return result;
  }

  Future<Result<void>> remove(int id) async {
    final result = await ref.read(screenTypesRepositoryProvider).deleteScreenType(id);
    if (result.isSuccess) ref.invalidate(screenTypesProvider);
    return result;
  }

  void refresh() => ref.invalidate(screenTypesProvider);
}

final screenTypesControllerProvider = AsyncNotifierProvider<ScreenTypesController, void>(
  ScreenTypesController.new,
);
