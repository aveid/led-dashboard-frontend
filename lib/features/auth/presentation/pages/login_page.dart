import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/app_text_field.dart';
import '../controllers/login_controller.dart';

/// Экран входа в систему.
///
/// Простая форма логин/пароль по центру. Вся логика — в [LoginController]
/// (валидация в use case, запрос в репозитории); страница лишь отображает
/// состояние и вызывает контроллер. После успешного входа редирект на карту
/// делает роутер (следит за сессией), поэтому здесь навигации нет.
class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    await ref.read(loginControllerProvider.notifier).login(
          username: _usernameController.text,
          password: _passwordController.text,
        );
    // Успех/ошибку отражает состояние; при успехе роутер уводит с /login сам.
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(loginControllerProvider);

    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: AppCard(
              padding: const EdgeInsets.all(28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('LED Dashboard KG', style: Theme.of(context).textTheme.headlineSmall),
                  const SizedBox(height: 4),
                  Text(
                    'Вход в панель управления экранами',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 24),
                  AppTextField(
                    label: 'Логин',
                    controller: _usernameController,
                    hintText: 'admin',
                    autofocus: true,
                  ),
                  const SizedBox(height: 16),
                  AppTextField(
                    label: 'Пароль',
                    controller: _passwordController,
                    hintText: '••••••••',
                    obscureText: true,
                    onSubmitted: (_) => _submit(),
                  ),
                  if (state.error != null) ...[
                    const SizedBox(height: 16),
                    _ErrorBanner(message: state.error!),
                  ],
                  const SizedBox(height: 24),
                  AppButton(
                    label: 'Войти',
                    isLoading: state.isSubmitting,
                    onPressed: _submit,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Плашка с текстом ошибки входа.
class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.danger.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.danger.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: AppColors.danger, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(color: AppColors.danger, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}
