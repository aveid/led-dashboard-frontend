import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers.dart';
import '../../../users/domain/entities/app_user.dart';
import '../../../users/domain/entities/user_role.dart';
import '../../data/datasources/auth_remote_ds.dart';
import '../../data/repositories/auth_repository_impl.dart';
import '../../domain/repositories/auth_repository.dart';
import '../../domain/usecases/login_usecase.dart';

/// Провайдеры фичи «авторизация»: сборка зависимостей и состояние сессии.

/// Датасорс входа (использует общий dio-клиент).
final _authRemoteDataSourceProvider = Provider<AuthRemoteDataSource>((ref) {
  final dioClient = ref.watch(dioClientProvider);
  return AuthRemoteDataSource(dioClient.dio);
});

/// Репозиторий авторизации (связывает датасорс и хранилище токена).
final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepositoryImpl(
    remote: ref.watch(_authRemoteDataSourceProvider),
    tokenStorage: ref.watch(tokenStorageProvider),
  );
});

/// Сценарий входа.
final loginUseCaseProvider = Provider<LoginUseCase>((ref) {
  return LoginUseCase(ref.watch(authRepositoryProvider));
});

/// Признак аутентификации пользователя (есть ли валидная сессия).
///
/// От него зависит редирект в go_router: нет сессии → на /login. Меняется при
/// входе/выходе через [AuthController], который инвалидирует этот провайдер.
final isAuthenticatedProvider = FutureProvider<bool>((ref) {
  return ref.watch(authRepositoryProvider).isAuthenticated();
});

/// Текущий пользователь (`GET /api/auth/me`) — источник истины роли (RBAC, NFR-8).
///
/// Зависит от [isAuthenticatedProvider]: пока сессии нет — `null` (без запроса);
/// как только появляется — тянем `/me` через dio+JWT. При входе/выходе провайдер
/// сессии инвалидируется, этот пересчитывается автоматически (роль синкается после
/// смены её админом). Ошибку `/me` глотаем в `null` — роль просто «неизвестна»
/// (fail-safe: не-admin), без модальной ошибки; авторитетен всё равно бэкенд (403).
final currentUserProvider = FutureProvider<AppUser?>((ref) async {
  final isAuthenticated = await ref.watch(isAuthenticatedProvider.future);
  if (!isAuthenticated) return null;
  final result = await ref.watch(authRepositoryProvider).getCurrentUser();
  return result.when(onSuccess: (user) => user, onFailure: (_) => null);
});

/// Признак роли admin — единственный источник для маскирования UI по RBAC.
///
/// Fail-safe: при загрузке/ошибке/`null` → `false` (по умолчанию НЕ показываем
/// admin-контролы). Виджеты читают ТОЛЬКО этот провайдер (через `AdminOnly` или
/// инлайн `ref.watch(isAdminProvider)`), логику роли не дублируем.
final isAdminProvider = Provider<bool>((ref) {
  final user = ref.watch(currentUserProvider).valueOrNull;
  return user?.role == UserRole.admin;
});

/// Признак роли `guest` — источник доп-ограничений UX (скрытый договор + пустые
/// цены). `guest` = не-admin, поэтому все write-контролы и раздел «Пользователи»
/// уже скрыты через [isAdminProvider]; этот провайдер добавляет лишь маскирование
/// цен и секции «Документы / Договор».
///
/// Fail-safe: при загрузке/ошибке/`null` → `false` — кратковременный «недо-guest»
/// при загрузке роли не является утечкой, так как истинная граница на бэке (он
/// сам отдаёт guest'у `monthly_price: null` и не шлёт `DOCUMENT`-вложения). UI —
/// лишь зеркало. Ключуется по роли, а не по `null`-значению цены.
final isGuestProvider = Provider<bool>((ref) {
  final user = ref.watch(currentUserProvider).valueOrNull;
  return user?.role == UserRole.guest;
});
