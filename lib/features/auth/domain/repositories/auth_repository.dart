import '../../../../core/error/result.dart';
import '../../../users/domain/entities/app_user.dart';

/// Порт (интерфейс) репозитория авторизации.
///
/// Domain объявляет, ЧТО умеет авторизация, не зная КАК (dio/secure_storage —
/// детали data-слоя). UI и use cases зависят от этого интерфейса (DIP).
abstract interface class AuthRepository {
  /// Выполняет вход по логину и паролю. При успехе токен сохраняется в хранилище,
  /// возвращается `Result.success(null)`; при ошибке — `Result.failure(...)`.
  Future<Result<void>> login({required String username, required String password});

  /// Выходит из системы (удаляет сохранённый токен).
  Future<void> logout();

  /// Возвращает текущего пользователя (`GET /api/auth/me`) — источник роли (RBAC).
  /// При ошибке — `Result.failure(...)` (вызывающий трактует как «роль неизвестна»).
  Future<Result<AppUser>> getCurrentUser();

  /// Проверяет, есть ли сохранённая сессия (валидный по наличию токен).
  Future<bool> isAuthenticated();
}
