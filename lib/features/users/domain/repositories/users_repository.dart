import '../../../../core/error/result.dart';
import '../entities/app_user.dart';
import '../entities/user_role.dart';

/// Порт репозитория раздела «Пользователи» (admin only — бэкенд гейтит).
///
/// Domain объявляет, ЧТО умеет модуль пользователей, не зная КАК (dio/JWT —
/// детали data-слоя). Все методы возвращают [Result], пряча исключения сети.
abstract interface class UsersRepository {
  /// Список всех пользователей (bare array, как `/api/cities`).
  Future<Result<List<AppUser>>> list();

  /// Создать пользователя. Пароль обязателен на создании.
  Future<Result<AppUser>> create({
    required String username,
    required String password,
    required UserRole role,
    bool? isActive,
  });

  /// Изменить подмножество полей: роль, активность и/или сброс пароля.
  Future<Result<AppUser>> edit(
    String id, {
    UserRole? role,
    bool? isActive,
    String? password,
  });

  /// Удалить пользователя (204).
  Future<Result<void>> remove(String id);
}
