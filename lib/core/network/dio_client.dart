import 'package:dio/dio.dart';

import '../constants/api_constants.dart';
import 'token_storage.dart';

/// Фабрика настроенного `Dio`-клиента.
///
/// Настраивает базовый URL, таймауты и интерсептор, который автоматически
/// подставляет `Authorization: Bearer <token>` в каждый запрос (кроме входа).
///
/// Про refresh-токен: у бэкенда сейчас один access-токен без refresh (см.
/// `features/accounts/router.py` — выдаётся только access). Поэтому на 401 мы не
/// пытаемся молча обновить токен, а чистим сессию — пользователя вернёт на экран
/// входа. Когда на бэке появится refresh, логику добавим здесь же, в интерсепторе.
class DioClient {
  DioClient(this._tokenStorage, {this.onUnauthorized}) : dio = Dio(_baseOptions) {
    dio.interceptors.add(_authInterceptor());
  }

  final TokenStorage _tokenStorage;

  /// Вызывается после очистки токена на 401 (сессия протухла посреди работы).
  /// Позволяет вызывающему слою (DI-сборка в `core/providers.dart`) отреагировать,
  /// не заставляя этот класс знать о Riverpod-провайдерах фичи авторизации.
  final void Function()? onUnauthorized;

  /// Настроенный экземпляр Dio для датасорсов.
  final Dio dio;

  static final BaseOptions _baseOptions = BaseOptions(
    baseUrl: ApiConstants.baseUrl,
    connectTimeout: const Duration(seconds: 15),
    receiveTimeout: const Duration(seconds: 20),
    // Не бросаем исключение на 4xx сами — пусть датасорс/репозиторий решают, как
    // трактовать статус. Но 401/403/5xx всё же удобнее ловить как ошибки, поэтому
    // оставляем поведение по умолчанию (validateStatus < 400 = успех).
    headers: {'Accept': 'application/json'},
  );

  InterceptorsWrapper _authInterceptor() {
    return InterceptorsWrapper(
      onRequest: (options, handler) async {
        // К эндпоинту входа токен не добавляем (его ещё нет).
        if (options.path != ApiConstants.authToken) {
          final token = await _tokenStorage.readAccessToken();
          if (token != null && token.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $token';
          }
        }
        handler.next(options);
      },
      onError: (error, handler) async {
        // Токен недействителен/истёк — чистим сессию. Редирект на /login сделает
        // роутер, отслеживающий состояние авторизации (см. app_router.dart).
        if (error.response?.statusCode == 401 &&
            error.requestOptions.path != ApiConstants.authToken) {
          await _tokenStorage.clear();
          onUnauthorized?.call();
        }
        handler.next(error);
      },
    );
  }
}
