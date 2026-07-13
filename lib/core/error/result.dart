import 'failure.dart';

/// Результат операции: либо успех со значением, либо ошибка (`Failure`).
///
/// Своя маленькая замена `Either` из fpdart — чтобы не тащить внешнюю зависимость
/// ради одного типа (решение «без лишних зависимостей», frontend/CONTEXT.md §1).
/// Репозитории возвращают `Result<T>`, контроллеры разбирают его через `when`,
/// поэтому исключения не «протекают» в UI.
///
/// `sealed` даёт исчерпывающий разбор: [Success] или [Err].
sealed class Result<T> {
  const Result();

  /// Успех со значением [value].
  const factory Result.success(T value) = Success<T>;

  /// Ошибка [failure].
  const factory Result.failure(Failure failure) = Err<T>;

  /// Разбор результата: вызывает [onSuccess] для успеха или [onFailure] для ошибки.
  /// Возвращает значение того же типа [R] из любой ветки.
  R when<R>({
    required R Function(T value) onSuccess,
    required R Function(Failure failure) onFailure,
  }) {
    final self = this;
    return switch (self) {
      Success<T>() => onSuccess(self.value),
      Err<T>() => onFailure(self.failure),
    };
  }

  /// Успешно ли завершилась операция.
  bool get isSuccess => this is Success<T>;

  /// Значение при успехе, иначе null (удобно для быстрых проверок).
  T? get valueOrNull => this is Success<T> ? (this as Success<T>).value : null;
}

/// Ветка успеха.
final class Success<T> extends Result<T> {
  const Success(this.value);
  final T value;
}

/// Ветка ошибки.
final class Err<T> extends Result<T> {
  const Err(this.failure);
  final Failure failure;
}
