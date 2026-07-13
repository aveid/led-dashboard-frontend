import 'package:dio/dio.dart';

import '../../../../core/constants/api_constants.dart';
import '../../../../core/network/api_exception.dart';
import '../models/screen_type_model.dart';

/// 409 при удалении типа экрана — тип используется экранами. Тело FastAPI-стиля:
/// `{ "detail": { "code": "screen_type_in_use", "message": "...", "used_by_count": N } }`.
///
/// Отдельное доменное исключение, потому что 409 здесь означает конкретно
/// «тип занят»: репозиторий превращает его в `ScreenTypeInUseFailure`, а UI —
/// в понятное сообщение с числом экранов.
class ScreenTypeInUseException implements Exception {
  const ScreenTypeInUseException(this.message, {this.usedByCount});

  final String message;
  final int? usedByCount;

  @override
  String toString() => 'ScreenTypeInUseException($message, usedByCount: $usedByCount)';
}

/// Удалённый источник данных типов экрана: CRUD через `/api/screen-types`.
///
/// Список приходит в конверте `{ data: [...], meta: {...} }`. Дубликат имени на
/// создании/изменении бэк отдаёт как `422` (обрабатывается репозиторием как
/// валидационная ошибка). Удаление занятого типа → `409` (`screen_type_in_use`),
/// которое переводится в [ScreenTypeInUseException].
class ScreenTypesRemoteDataSource {
  const ScreenTypesRemoteDataSource(this._dio);

  final Dio _dio;

  /// Загружает все типы. Для внутреннего справочника количество типов невелико
  /// (заведомо < 100), поэтому берём одним запросом с максимальным `per_page`.
  /// Бэк ограничивает `per_page ≤ 100` (общий валидатор пагинации) — большее
  /// значение вернёт `422` на query-параметр. Пагинация UI не нужна: поиск
  /// делается на клиенте по кэшированному списку, как договорено с Архитектором
  /// (единый источник для формы/страницы/фильтра).
  Future<List<ScreenTypeModel>> getScreenTypes() async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        ApiConstants.screenTypes,
        queryParameters: {'per_page': 100},
      );
      final data = (response.data?['data'] as List<dynamic>? ?? []);
      return data
          .map((e) => ScreenTypeModel.fromJson(e as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  Future<ScreenTypeModel> createScreenType({required String name, String? code}) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        ApiConstants.screenTypes,
        data: {
          'name': name.trim(),
          if (code != null && code.trim().isNotEmpty) 'code': code.trim(),
        },
      );
      return ScreenTypeModel.fromJson(response.data!);
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  Future<ScreenTypeModel> updateScreenType(int id, {String? name, String? code}) async {
    try {
      final response = await _dio.patch<Map<String, dynamic>>(
        '${ApiConstants.screenTypes}/$id',
        data: {
          if (name != null) 'name': name.trim(),
          if (code != null) 'code': code.trim(),
        },
      );
      return ScreenTypeModel.fromJson(response.data!);
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  Future<void> deleteScreenType(int id) async {
    try {
      await _dio.delete<void>('${ApiConstants.screenTypes}/$id');
    } on DioException catch (e) {
      if (e.response?.statusCode == 409) {
        // Тело FastAPI-стиля: полезная нагрузка лежит под ключом `detail`
        // (`{ code, message, used_by_count }`).
        final data = e.response?.data;
        final detail = data is Map ? data['detail'] : null;
        final message = detail is Map && detail['message'] is String
            ? detail['message'] as String
            : 'Тип используется экранами, удаление невозможно.';
        final usedByCount = detail is Map && detail['used_by_count'] is int
            ? detail['used_by_count'] as int
            : null;
        throw ScreenTypeInUseException(message, usedByCount: usedByCount);
      }
      throw ApiException.fromDio(e);
    }
  }
}
