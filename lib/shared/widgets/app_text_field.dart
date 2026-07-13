import 'package:flutter/material.dart';

/// Текстовое поле приложения с подписью (label) над ним.
///
/// Оформление берётся из `inputDecorationTheme` (app_theme.dart). Оборачивает
/// стандартный `TextField`, добавляя единообразную подпись и отступы, чтобы
/// формы во всех фичах выглядели одинаково.
class AppTextField extends StatelessWidget {
  const AppTextField({
    required this.label,
    required this.controller,
    this.hintText,
    this.obscureText = false,
    this.keyboardType,
    this.onSubmitted,
    this.autofocus = false,
    super.key,
  });

  final String label;
  final TextEditingController controller;
  final String? hintText;
  final bool obscureText;
  final TextInputType? keyboardType;
  final ValueChanged<String>? onSubmitted;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          obscureText: obscureText,
          keyboardType: keyboardType,
          autofocus: autofocus,
          onSubmitted: onSubmitted,
          decoration: InputDecoration(hintText: hintText),
        ),
      ],
    );
  }
}
