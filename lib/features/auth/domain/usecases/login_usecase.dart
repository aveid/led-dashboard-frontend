import '../../../../core/error/failure.dart';
import '../../../../core/error/result.dart';
import '../repositories/auth_repository.dart';

/// Сценарий «Вход в систему».
///
/// Тонкий use case поверх репозитория. Здесь же — простая проверка, что поля не
/// пустые (до обращения к сети): это доменная валидация, ей место не в виджете.
class LoginUseCase {
  const LoginUseCase(this._repository);

  final AuthRepository _repository;

  /// Проверяет ввод и выполняет вход.
  Future<Result<void>> call({required String username, required String password}) {
    if (username.trim().isEmpty || password.isEmpty) {
      return Future.value(
        const Result.failure(ValidationFailure('Введите логин и пароль.')),
      );
    }
    return _repository.login(username: username.trim(), password: password);
  }
}
