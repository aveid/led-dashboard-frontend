import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'network/dio_client.dart';
import 'network/token_storage.dart';

/// Провайдеры инфраструктуры уровня приложения (DI через Riverpod).
///
/// Здесь «собираются» общие зависимости, которые нужны многим фичам: хранилище
/// токена и HTTP-клиент. Фичи получают их через `ref.watch(...)`, а в тестах
/// эти провайдеры легко подменяются overrides (frontend/CONTEXT.md §7).

/// Хранилище JWT-токена (single instance на приложение).
final tokenStorageProvider = Provider<TokenStorage>((ref) {
  return TokenStorage();
});

/// Настроенный dio-клиент (с JWT-интерсептором).
///
/// [DioClient.onUnauthorized] бампает [sessionEpochProvider] на 401 — так
/// сетевой слой сигналит наверх о протухшей сессии, не зная о провайдере
/// авторизации напрямую (иначе core/ зависел бы от features/auth/, а тот уже
/// зависит от core/ — цикл). `isAuthenticatedProvider` следит за эпохой и
/// пересчитывается, роутер уводит пользователя на /login (см. auth_providers.dart).
final dioClientProvider = Provider<DioClient>((ref) {
  final tokenStorage = ref.watch(tokenStorageProvider);
  return DioClient(
    tokenStorage,
    onUnauthorized: () => ref.read(sessionEpochProvider.notifier).state++,
  );
});

/// Счётчик «эпох» сессии. Растёт при каждом принудительном завершении сессии
/// на сетевом уровне (401 у любого запроса, кроме самого входа — см.
/// `dio_client.dart`). Сам по себе ничего не значит — нужен только как повод
/// для зависимых провайдеров пересчитаться (см. [dioClientProvider] выше).
final sessionEpochProvider = StateProvider<int>((ref) => 0);
