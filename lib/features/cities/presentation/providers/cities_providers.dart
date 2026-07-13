import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error/result.dart';
import '../../../../core/providers.dart';
import '../../data/datasources/cities_remote_ds.dart';
import '../../data/repositories/cities_repository_impl.dart';
import '../../domain/entities/city.dart';
import '../../domain/repositories/cities_repository.dart';

/// Провайдеры фичи «города/регионы»: сборка зависимостей, список и мутации.

final _citiesRemoteDataSourceProvider = Provider<CitiesRemoteDataSource>((ref) {
  return CitiesRemoteDataSource(ref.watch(dioClientProvider).dio);
});

final citiesRepositoryProvider = Provider<CitiesRepository>((ref) {
  return CitiesRepositoryImpl(ref.watch(_citiesRemoteDataSourceProvider));
});

/// Все города (в т.ч. неактивные) — для раздела «Города / Регионы».
///
/// Мутации в [CitiesController] инвалидируют этот провайдер, поэтому список
/// перезапрашивается с бэка целиком (проще и надёжнее точечного обновления —
/// как и в фиче арендодателей).
final citiesProvider = FutureProvider<List<City>>((ref) async {
  final result = await ref.watch(citiesRepositoryProvider).getCities();
  return result.when(onSuccess: (v) => v, onFailure: (f) => throw f);
});

/// Только активные города — источник для дропдауна выбора города экрана.
///
/// Производный от [citiesProvider]: фильтруем на месте, чтобы не делать второй
/// запрос и не рассинхронизироваться со списком в разделе городов.
final activeCitiesProvider = FutureProvider<List<City>>((ref) async {
  final cities = await ref.watch(citiesProvider.future);
  return cities.where((c) => c.isActive).toList();
});

/// Мутации городов (создание/удаление) с последующим обновлением [citiesProvider].
///
/// `AsyncNotifier<void>` — сам список живёт в [citiesProvider]; контроллер только
/// выполняет мутацию и инвалидирует список при успехе. Методы возвращают
/// [Result], чтобы UI мог показать типизированную ошибку (дубликат / город в
/// использовании), не ловя исключения (frontend/CONTEXT.md §2).
class CitiesController extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<Result<City>> add(String name) async {
    final result = await ref.read(citiesRepositoryProvider).createCity(name);
    if (result.isSuccess) ref.invalidate(citiesProvider);
    return result;
  }

  Future<Result<void>> remove(int id) async {
    final result = await ref.read(citiesRepositoryProvider).deleteCity(id);
    if (result.isSuccess) ref.invalidate(citiesProvider);
    return result;
  }

  void refresh() => ref.invalidate(citiesProvider);
}

final citiesControllerProvider = AsyncNotifierProvider<CitiesController, void>(
  CitiesController.new,
);
