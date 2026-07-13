import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error/result.dart';
import '../../../../core/providers.dart';
import '../../data/datasources/landlords_remote_ds.dart';
import '../../data/repositories/landlords_repository_impl.dart';
import '../../domain/entities/landlord.dart';
import '../../domain/entities/landlord_screen_brief.dart';
import '../../domain/repositories/landlords_repository.dart';
import '../../domain/usecases/landlords_usecases.dart';

/// Провайдеры фичи «арендодатели»: сборка зависимостей и список с мутациями.

final _landlordsRemoteDataSourceProvider = Provider<LandlordsRemoteDataSource>((ref) {
  return LandlordsRemoteDataSource(ref.watch(dioClientProvider).dio);
});

final landlordsRepositoryProvider = Provider<LandlordsRepository>((ref) {
  return LandlordsRepositoryImpl(ref.watch(_landlordsRemoteDataSourceProvider));
});

final _listUseCaseProvider = Provider<ListLandlordsUseCase>((ref) {
  return ListLandlordsUseCase(ref.watch(landlordsRepositoryProvider));
});
final _createUseCaseProvider = Provider<CreateLandlordUseCase>((ref) {
  return CreateLandlordUseCase(ref.watch(landlordsRepositoryProvider));
});
final _updateUseCaseProvider = Provider<UpdateLandlordUseCase>((ref) {
  return UpdateLandlordUseCase(ref.watch(landlordsRepositoryProvider));
});
final _deleteUseCaseProvider = Provider<DeleteLandlordUseCase>((ref) {
  return DeleteLandlordUseCase(ref.watch(landlordsRepositoryProvider));
});

/// Список арендодателей с CRUD-мутациями (FR-8).
///
/// `AsyncNotifier` — после каждой успешной мутации (создание/редактирование/
/// удаление) вызывается `ref.invalidateSelf()` и список перезапрашивается с
/// бэка целиком. Это проще и надёжнее точечного обновления локального
/// состояния (нет риска разойтись с сервером), а список арендодателей — не тот
/// объём данных, где перезапрос был бы заметно медленным.
class LandlordsListController extends AsyncNotifier<List<Landlord>> {
  @override
  Future<List<Landlord>> build() async {
    final result = await ref.read(_listUseCaseProvider).call();
    return result.when(onSuccess: (v) => v, onFailure: (f) => throw f);
  }

  Future<Result<Landlord>> create({
    required String name,
    String contactPerson = '',
    String phone = '',
    String email = '',
  }) async {
    final result = await ref.read(_createUseCaseProvider).call(
          name: name,
          contactPerson: contactPerson,
          phone: phone,
          email: email,
        );
    if (result.isSuccess) ref.invalidateSelf();
    return result;
  }

  Future<Result<Landlord>> updateLandlord({
    required String id,
    String? name,
    String? contactPerson,
    String? phone,
    String? email,
  }) async {
    final result = await ref.read(_updateUseCaseProvider).call(
          id: id,
          name: name,
          contactPerson: contactPerson,
          phone: phone,
          email: email,
        );
    if (result.isSuccess) ref.invalidateSelf();
    return result;
  }

  Future<Result<void>> delete(String id) async {
    final result = await ref.read(_deleteUseCaseProvider).call(id);
    if (result.isSuccess) ref.invalidateSelf();
    return result;
  }
}

final landlordsListProvider = AsyncNotifierProvider<LandlordsListController, List<Landlord>>(
  LandlordsListController.new,
);

/// Экраны одного арендодателя (FR-8.5), ленивая загрузка по id.
///
/// `FutureProvider.family` выбран специально: он грузит данные только когда его
/// начинают `watch` — т.е. при первом раскрытии конкретной карточки, а не для
/// всех арендодателей сразу. И он не задевает правило про зарезервированные
/// имена методов `Notifier` (`update`/`state`/`future`/`ref`).
///
/// Ключ — `landlord.id` (String, как в [Landlord]). Ошибка репозитория
/// пробрасывается в `AsyncValue.error` (в т.ч. `NotFoundFailure` при 404
/// `LANDLORD_NOT_FOUND` — UI трактует её как «арендодателя уже нет»).
final landlordScreensProvider =
    FutureProvider.family<List<LandlordScreenBrief>, String>((ref, landlordId) async {
  final result = await ref.watch(landlordsRepositoryProvider).getLandlordScreens(landlordId);
  return result.when(
    onSuccess: (value) => value,
    onFailure: (failure) => throw failure, // уходит в AsyncValue.error
  );
});
