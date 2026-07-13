import 'user_role.dart';

/// Доменная сущность пользователя системы (аккаунт).
///
/// Используется и разделом «Пользователи» (CRUD), и как текущий пользователь
/// (`GET /api/auth/me`) — источник роли для маскирования UI по RBAC (NFR-8).
/// Чистый Dart, без деталей сети (парсинг — в `UserDto`).
class AppUser {
  const AppUser({
    required this.id,
    required this.username,
    required this.role,
    required this.isActive,
    this.createdAt,
  });

  /// Идентификатор (строкой — не зависим от того, int он на бэке или иной; путь
  /// PATCH/DELETE подставляется как строка в любом случае).
  final String id;
  final String username;
  final UserRole role;
  final bool isActive;
  final DateTime? createdAt;

  bool get isAdmin => role == UserRole.admin;

  AppUser copyWith({
    String? id,
    String? username,
    UserRole? role,
    bool? isActive,
    DateTime? createdAt,
  }) {
    return AppUser(
      id: id ?? this.id,
      username: username ?? this.username,
      role: role ?? this.role,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
