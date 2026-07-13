import 'package:flutter/material.dart';

/// Основная кнопка приложения.
///
/// Тонкая обёртка над `ElevatedButton` (стиль берётся из темы, см. app_theme.dart)
/// с поддержкой состояния загрузки: при [isLoading] показывает спиннер и
/// блокирует нажатие. Позволяет не дублировать эту логику в каждом экране.
class AppButton extends StatelessWidget {
  const AppButton({
    required this.label,
    required this.onPressed,
    this.isLoading = false,
    this.fullWidth = true,
    super.key,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;
  final bool fullWidth;

  @override
  Widget build(BuildContext context) {
    final button = ElevatedButton(
      onPressed: isLoading ? null : onPressed,
      child: isLoading
          ? const SizedBox(
              height: 20,
              width: 20,
              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
            )
          : Text(label),
    );
    return fullWidth ? SizedBox(width: double.infinity, child: button) : button;
  }
}
