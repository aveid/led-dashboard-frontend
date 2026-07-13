import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Хранилище JWT-токена.
///
/// Абстракция над `flutter_secure_storage`, чтобы остальной код (интерсептор,
/// репозиторий авторизации) не зависел напрямую от пакета и его легко было
/// подменить в тестах. На вебе secure_storage использует поддержку браузера;
/// это безопаснее, чем localStorage напрямую.
class TokenStorage {
  TokenStorage([FlutterSecureStorage? storage])
      : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  static const _accessTokenKey = 'access_token';

  /// Сохраняет access-токен.
  Future<void> saveAccessToken(String token) {
    return _storage.write(key: _accessTokenKey, value: token);
  }

  /// Возвращает сохранённый access-токен или null, если его нет.
  Future<String?> readAccessToken() {
    return _storage.read(key: _accessTokenKey);
  }

  /// Удаляет токен (выход из системы).
  Future<void> clear() {
    return _storage.delete(key: _accessTokenKey);
  }
}
