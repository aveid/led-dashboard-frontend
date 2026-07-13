import 'package:flutter_test/flutter_test.dart';
import 'package:led_dashboard/core/error/failure.dart';
import 'package:led_dashboard/core/error/result.dart';
import 'package:led_dashboard/features/auth/domain/repositories/auth_repository.dart';
import 'package:led_dashboard/features/auth/domain/usecases/login_usecase.dart';
import 'package:mocktail/mocktail.dart';

class _MockAuthRepository extends Mock implements AuthRepository {}

void main() {
  late _MockAuthRepository repository;
  late LoginUseCase useCase;

  setUp(() {
    repository = _MockAuthRepository();
    useCase = LoginUseCase(repository);
  });

  test('пустой логин или пароль → ValidationFailure, репозиторий не вызывается', () async {
    final result = await useCase.call(username: '   ', password: '');

    expect(result, isA<Err<void>>());
    final failure = (result as Err<void>).failure;
    expect(failure, isA<ValidationFailure>());
    verifyNever(() => repository.login(
          username: any(named: 'username'),
          password: any(named: 'password'),
        ));
  });

  test('корректный ввод → делегирует репозиторию и возвращает его результат', () async {
    when(() => repository.login(username: 'admin', password: 'admin12345'))
        .thenAnswer((_) async => const Result.success(null));

    final result = await useCase.call(username: '  admin  ', password: 'admin12345');

    expect(result.isSuccess, isTrue);
    // Логин обрезается от пробелов перед передачей в репозиторий.
    verify(() => repository.login(username: 'admin', password: 'admin12345')).called(1);
  });

  test('ошибка репозитория пробрасывается наверх как есть', () async {
    when(() => repository.login(username: 'admin', password: 'bad'))
        .thenAnswer((_) async => const Result.failure(UnauthorizedFailure()));

    final result = await useCase.call(username: 'admin', password: 'bad');

    expect(result, isA<Err<void>>());
    expect((result as Err<void>).failure, isA<UnauthorizedFailure>());
  });
}
