import 'package:dio/dio.dart';

import '../error/failure.dart';

/// Исключение уровня датасорса: единая обёртка над ошибками dio/HTTP.
///
/// Датасорсы бросают это исключение, а репозитории ловят его и превращают в
/// [Failure] (через [toFailure]). Так «сырые» `DioException` не доходят до UI.
class ApiException implements Exception {
  const ApiException({required this.statusCode, required this.message});

  /// HTTP-статус ответа (или null, если запрос вообще не дошёл до сервера).
  final int? statusCode;

  /// Сообщение об ошибке (по возможности — из тела ответа сервера).
  final String message;

  /// Строит [ApiException] из ошибки dio, аккуратно доставая сообщение сервера.
  ///
  /// Наш бэкенд отдаёт ошибки в формате `{"error": {"type": "...", "message": "..."}}`
  /// (см. `core/api/errors.py`), а FastAPI — под ключом `detail`. `detail` бывает
  /// трёх видов: строка (простые ошибки/401), объект (бизнес-ошибка вроде
  /// `{code, message, ...}`), либо список валидации `[{loc, msg, type}, ...]`
  /// (`422`). Разбираем все варианты.
  factory ApiException.fromDio(DioException error) {
    final response = error.response;
    final statusCode = response?.statusCode;
    var message = 'Ошибка запроса';

    final data = response?.data;
    if (data is Map) {
      final err = data['error'];
      final detail = data['detail'];
      if (err is Map && err['message'] is String) {
        message = err['message'] as String;
      } else if (detail is String) {
        message = detail;
      } else if (detail is Map && detail['message'] is String) {
        message = detail['message'] as String;
      } else if (detail is List && detail.isNotEmpty) {
        // Валидация FastAPI: собираем читаемое «поле: сообщение» по записям.
        final parts = detail.whereType<Map>().map((e) {
          final msg = e['msg']?.toString() ?? 'некорректное значение';
          final loc = e['loc'];
          final field = loc is List && loc.isNotEmpty ? loc.last.toString() : null;
          return field != null ? '$field: $msg' : msg;
        });
        if (parts.isNotEmpty) message = parts.join('; ');
      }
    } else if (error.type == DioExceptionType.connectionError ||
        error.type == DioExceptionType.connectionTimeout) {
      message = 'Нет связи с сервером';
    }

    return ApiException(statusCode: statusCode, message: message);
  }

  /// Переводит исключение в доменный [Failure] по HTTP-статусу.
  Failure toFailure() {
    return switch (statusCode) {
      400 => ValidationFailure(message),
      401 => UnauthorizedFailure(message),
      // 403 → «Недостаточно прав» (RBAC, NFR-8). Defense-in-depth для замаскированных
      // мутаций: даже если контрол показался не-admin'у, 403 лишь покажет snackbar
      // и НЕ разлогинит (токены чистит только 401 — см. dio_client.dart).
      403 => ForbiddenFailure(
          // Бэк на ADMIN_ONLY шлёт `detail:{code}` без текста → message остаётся
          // общим 'Ошибка запроса'. В таком случае показываем понятное «Недостаточно
          // прав», иначе — осмысленный текст сервера.
          message == 'Ошибка запроса' ? 'Недостаточно прав.' : message,
        ),
      404 => NotFoundFailure(message),
      409 => ConflictFailure(message),
      422 => ValidationFailure(message),
      null => NetworkFailure(message),
      _ => ServerFailure(message),
    };
  }

  @override
  String toString() => 'ApiException($statusCode, $message)';
}
