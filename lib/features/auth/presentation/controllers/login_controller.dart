import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error/failure.dart';
import 'auth_providers.dart';

/// Состояние экрана входа (иммутабельное).
///
/// Держит флаг загрузки и текст ошибки. UI реагирует на изменения декларативно
/// (frontend/CONTEXT.md §7). Успех отдельным полем не храним — при успехе
/// перерисовывается роутер (сессия появилась), и пользователь уходит с /login.
class LoginState {
  const LoginState({this.isSubmitting = false, this.error});

  final bool isSubmitting;
  final String? error;

  LoginState copyWith({bool? isSubmitting, String? error, bool clearError = false}) {
    return LoginState(
      isSubmitting: isSubmitting ?? this.isSubmitting,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

/// Контроллер входа: вызывает use case и обновляет [LoginState].
class LoginController extends Notifier<LoginState> {
  @override
  LoginState build() => const LoginState();

  /// Пытается войти. Возвращает true при успехе (роутер сам уведёт с /login).
  Future<bool> login({required String username, required String password}) async {
    state = state.copyWith(isSubmitting: true, clearError: true);

    final result = await ref.read(loginUseCaseProvider).call(
          username: username,
          password: password,
        );

    return result.when(
      onSuccess: (_) {
        // Обновляем признак сессии, чтобы роутер пустил дальше, и роль текущего
        // пользователя (`/auth/me`) — от неё зависит маскирование UI по RBAC.
        ref.invalidate(isAuthenticatedProvider);
        ref.invalidate(currentUserProvider);
        state = state.copyWith(isSubmitting: false);
        return true;
      },
      onFailure: (Failure failure) {
        state = state.copyWith(isSubmitting: false, error: failure.message);
        return false;
      },
    );
  }
}

/// Провайдер контроллера входа.
final loginControllerProvider = NotifierProvider<LoginController, LoginState>(
  LoginController.new,
);
