import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers.dart';
import '../../data/datasources/geo_remote_ds.dart';
import '../../data/repositories/geo_repository_impl.dart';
import '../../domain/entities/kg_boundary.dart';
import '../../domain/repositories/geo_repository.dart';

/// Провайдеры географии карты (FR-1.6): DI репозитория границы + сама граница.

final _geoRemoteDataSourceProvider = Provider<GeoRemoteDataSource>((ref) {
  final dioClient = ref.watch(dioClientProvider);
  return GeoRemoteDataSource(dioClient.dio);
});

final geoRepositoryProvider = Provider<GeoRepository>((ref) {
  return GeoRepositoryImpl(ref.watch(_geoRemoteDataSourceProvider));
});

/// Граница Кыргызстана для маски-затемнения (FR-1.6, Вариант 2).
///
/// `FutureProvider` (не `Notifier`) — граница статична, инвалидация не нужна, и
/// заодно обходит правило про зарезервированные имена методов Notifier. Грузится
/// лениво и один раз при первом `watch` со страницы карты. При ошибке провайдер
/// уходит в `AsyncError` — UI это гасит (`maybeWhen(orElse: [])`) и просто не
/// рисует маску; «жёсткое» ограничение делает рамка Варианта 1.
final kgBoundaryProvider = FutureProvider<KgBoundary>((ref) async {
  final res = await ref.watch(geoRepositoryProvider).getKgBoundary();
  return res.when(
    onSuccess: (boundary) => boundary,
    onFailure: (failure) => throw failure,
  );
});
