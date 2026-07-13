import 'package:dio/dio.dart';

import '../../../../core/constants/api_constants.dart';
import '../../../../core/network/api_exception.dart';
import '../../../users/data/models/user_dto.dart';
import '../../../users/domain/entities/app_user.dart';
import '../models/token_dto.dart';

/// Удалённый источник данных авторизации: общается с API входа.
///
/// Бэкенд ожидает вход по стандартной OAuth2-форме (`application/x-www-form-urlencoded`
/// с полями `username`/`password`), поэтому отправляем именно форму, а не JSON
/// (см. `features/accounts/router.py`). Ошибки dio превращаем в [ApiException].
class AuthRemoteDataSource {
  const AuthRemoteDataSource(this._dio);

  final Dio _dio;

  /// Отправляет логин/пароль и возвращает DTO токена. Бросает [ApiException] при ошибке.
  Future<TokenDto> login({required String username, required String password}) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        ApiConstants.authToken,
        data: {'username': username, 'password': password},
        options: Options(
          contentType: Headers.formUrlEncodedContentType, // OAuth2 form
        ),
      );
      return TokenDto.fromJson(response.data!);
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  /// Текущий пользователь (`GET /api/auth/me`, dio+JWT) — источник роли (RBAC,
  /// NFR-8). Ответ той же формы, что и `/api/users` → парсим через [UserDto].
  Future<AppUser> getMe() async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(ApiConstants.authMe);
      return UserDto.fromJson(response.data!);
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }
}
