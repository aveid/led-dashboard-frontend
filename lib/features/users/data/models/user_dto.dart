import '../../domain/entities/app_user.dart';
import '../../domain/entities/user_role.dart';

/// DTO пользователя (зеркалит `UserRead` на бэке). Без кодогена — `fromJson`/
/// `toJson` вручную (frontend/CONTEXT.md §1).
///
/// Наследуется от [AppUser] (как `CityModel` от `City`): «форма JSON» *является*
/// доменной сущностью, отдельный `toDomain` не нужен.
class UserDto extends AppUser {
  const UserDto({
    required super.id,
    required super.username,
    required super.role,
    required super.isActive,
    super.createdAt,
  });

  factory UserDto.fromJson(Map<String, dynamic> json) {
    return UserDto(
      // id может прийти числом или строкой — приводим к строке защитно.
      id: json['id'].toString(),
      // Бэкенд идентифицирует по username; если поле отсутствует — пробуем email.
      username: (json['username'] ?? json['email'] ?? '') as String,
      role: UserRole.fromApi(json['role'] as String?),
      isActive: json['is_active'] as bool? ?? true,
      createdAt: _parseDate(json['created_at']),
    );
  }

  /// Тело запроса (для отладки/симметрии). На практике create/edit собирают
  /// точечные тела в датасорсе (разные подмножества полей), но toJson держим как
  /// часть контракта DTO.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'username': username,
      'role': role.asApi,
      'is_active': isActive,
      if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
    };
  }

  /// Дата защитно: `null`/некорректное → null (строку не роняем).
  static DateTime? _parseDate(Object? raw) {
    if (raw is! String || raw.isEmpty) return null;
    return DateTime.tryParse(raw);
  }
}
