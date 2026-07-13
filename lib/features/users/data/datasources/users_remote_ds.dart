import 'package:dio/dio.dart';

import '../../../../core/constants/api_constants.dart';
import '../../../../core/network/api_exception.dart';
import '../../domain/entities/user_role.dart';
import '../models/user_dto.dart';

/// 409 `detail.code = LAST_ADMIN` — попытка удалить/понизить последнего админа.
///
/// Отдельное исключение (а не общий 409): смысл конкретный, репозиторий переведёт
/// его в `LastAdminFailure`, а UI покажет понятный snackbar.
class LastAdminException implements Exception {
  const LastAdminException([this.message = 'Нельзя удалить или понизить последнего администратора.']);
  final String message;

  @override
  String toString() => 'LastAdminException($message)';
}

/// Удалённый источник данных раздела «Пользователи»: CRUD через `/api/users`
/// (dio + JWT). Ответы парсим вручную (NO CODEGEN); bare-array как у `/api/cities`.
///
/// Значимые ошибки (`detail` — по контракту от Архитектора):
/// * 409 `{code: LAST_ADMIN}` → [LastAdminException];
/// * 404 `{code: USER_NOT_FOUND}` → 404 → `NotFoundFailure` (трактуем «уже удалён»);
/// * 422 дубль имени → `ValidationFailure` (UI: «Имя занято»);
/// * 403 `{code: ADMIN_ONLY}` → `ForbiddenFailure` (общий маппинг), без разлогина.
class UsersRemoteDataSource {
  const UsersRemoteDataSource(this._dio);

  final Dio _dio;

  Future<List<UserDto>> list() async {
    try {
      final response = await _dio.get<List<dynamic>>(ApiConstants.users);
      return response.data!
          .map((e) => UserDto.fromJson(e as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  Future<UserDto> create({
    required String username,
    required String password,
    required UserRole role,
    bool? isActive,
  }) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        ApiConstants.users,
        data: {
          'username': username.trim(),
          'password': password,
          'role': role.asApi,
          if (isActive != null) 'is_active': isActive,
        },
      );
      return UserDto.fromJson(response.data!);
    } on DioException catch (e) {
      _mapLastAdmin(e);
      throw ApiException.fromDio(e);
    }
  }

  Future<UserDto> update(
    String id, {
    UserRole? role,
    bool? isActive,
    String? password,
  }) async {
    try {
      final response = await _dio.patch<Map<String, dynamic>>(
        '${ApiConstants.users}/$id',
        data: {
          if (role != null) 'role': role.asApi,
          if (isActive != null) 'is_active': isActive,
          if (password != null && password.isNotEmpty) 'password': password,
        },
      );
      return UserDto.fromJson(response.data!);
    } on DioException catch (e) {
      _mapLastAdmin(e);
      throw ApiException.fromDio(e);
    }
  }

  Future<void> delete(String id) async {
    try {
      await _dio.delete<void>('${ApiConstants.users}/$id');
    } on DioException catch (e) {
      _mapLastAdmin(e);
      throw ApiException.fromDio(e);
    }
  }

  /// Если это 409 с `detail.code == LAST_ADMIN` — бросаем [LastAdminException].
  /// Иначе метод ничего не делает (вызывающий бросит общий [ApiException]).
  void _mapLastAdmin(DioException e) {
    if (e.response?.statusCode != 409) return;
    final data = e.response?.data;
    if (data is Map) {
      final detail = data['detail'];
      if (detail is Map && detail['code'] == 'LAST_ADMIN') {
        throw LastAdminException(ApiException.fromDio(e).message);
      }
    }
  }
}
