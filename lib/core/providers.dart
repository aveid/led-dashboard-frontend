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
final dioClientProvider = Provider<DioClient>((ref) {
  final tokenStorage = ref.watch(tokenStorageProvider);
  return DioClient(tokenStorage);
});
