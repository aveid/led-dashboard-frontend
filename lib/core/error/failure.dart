import '../../shared/domain/attachment_type.dart';

/// Типы ошибок уровня приложения (Failure).
///
/// Domain/UI работают с этими типами, а не с «сырыми» исключениями из dio/сети.
/// Так ошибка становится частью контракта: контроллер знает, какие бывают
/// ситуации, и показывает пользователю понятное сообщение (frontend/CONTEXT.md §6).
///
/// `sealed` позволяет исчерпывающе разобрать все варианты через switch — если
/// добавить новый тип, компилятор укажет места, где его забыли обработать.
sealed class Failure {
  const Failure(this.message);

  /// Человекочитаемое сообщение (можно показать пользователю).
  final String message;

  @override
  String toString() => '$runtimeType($message)';
}

/// Сетевая проблема: нет соединения, таймаут, сервер недоступен.
final class NetworkFailure extends Failure {
  const NetworkFailure([super.message = 'Нет связи с сервером. Проверьте подключение.']);
}

/// Неверные учётные данные или истёкшая сессия (HTTP 401).
final class UnauthorizedFailure extends Failure {
  const UnauthorizedFailure([super.message = 'Требуется вход. Проверьте логин и пароль.']);
}

/// Запрошенный ресурс не найден (HTTP 404).
final class NotFoundFailure extends Failure {
  const NotFoundFailure([super.message = 'Запрошенные данные не найдены.']);
}

/// Недостаточно прав на операцию (HTTP 403). Возникает, когда не-admin пытается
/// выполнить запись (создание/изменение/удаление, раздел «Пользователи») — бэкенд
/// авторитетен и возвращает 403 (RBAC, NFR-8). Это страховочная сетка на случай,
/// если контрол случайно показался не-admin'у: UI прячет кнопки записи, но даже
/// при обходе маскировки вредного эффекта нет. ВАЖНО: 403 ≠ logout — токены
/// чистит и уводит на /login только 401; 403 лишь показывает snackbar.
final class ForbiddenFailure extends Failure {
  const ForbiddenFailure([super.message = 'Недостаточно прав.']);
}

/// Попытка удалить/понизить последнего администратора (HTTP 409, `detail.code =
/// LAST_ADMIN`). Отдельный тип от [ConflictFailure]: UI показывает по нему
/// понятное «Нельзя удалить/понизить последнего администратора».
final class LastAdminFailure extends Failure {
  const LastAdminFailure([super.message = 'Нельзя удалить или понизить последнего администратора.']);
}

/// Ошибка валидации входных данных (HTTP 400).
final class ValidationFailure extends Failure {
  const ValidationFailure([super.message = 'Данные заполнены неверно.']);
}

/// Нарушение бизнес-правила на сервере (HTTP 409), например активация без
/// договора и фото (FR-4.2).
final class ConflictFailure extends Failure {
  const ConflictFailure([super.message = 'Действие невозможно в текущем состоянии.']);
}

/// Город с таким названием уже существует (HTTP 409 на создании/изменении города).
///
/// Отдельный тип от [ConflictFailure], потому что 409 у городов означает разное
/// в зависимости от операции — UI показывает своё сообщение для каждого случая.
final class CityDuplicateFailure extends Failure {
  const CityDuplicateFailure([super.message = 'Город с таким названием уже существует.']);
}

/// У города есть привязанные экраны — удаление невозможно (HTTP 409 на удалении).
final class CityInUseFailure extends Failure {
  const CityInUseFailure([super.message = 'Нельзя удалить: у города есть привязанные экраны.']);
}

/// Тип экрана используется экранами — удаление невозможно (HTTP 409 на удалении
/// типа экрана, `error: screen_type_in_use`).
///
/// Отдельный тип от [ConflictFailure]: 409 при удалении типа означает конкретно
/// «тип занят», и UI показывает по нему понятное сообщение с числом экранов.
/// [usedByCount] — сколько экранов используют тип (для формулировки), либо null,
/// если бэк не прислал число.
final class ScreenTypeInUseFailure extends Failure {
  const ScreenTypeInUseFailure(super.message, {this.usedByCount});

  final int? usedByCount;
}

/// Превышен лимит вложений одного вида на экране (HTTP 409 при загрузке).
///
/// Отдельный тип от [ConflictFailure], потому что UI показывает по нему понятный
/// «лимитный» snackbar (максимум N фото/документов), а не общий текст про 409.
/// [kind] — вид загружавшегося вложения (фото vs документ), чтобы UI при желании
/// уточнил формулировку. Страховка на случай гонки/устаревшего UI: авторитетную
/// проверку делает бэкенд.
final class AttachmentLimitFailure extends Failure {
  const AttachmentLimitFailure(this.kind, [super.message = 'Достигнут лимит вложений одного вида.']);

  final AttachmentType kind;
}

/// Прочая/непредвиденная ошибка (в т.ч. 500).
final class ServerFailure extends Failure {
  const ServerFailure([super.message = 'Внутренняя ошибка сервера. Попробуйте позже.']);
}
