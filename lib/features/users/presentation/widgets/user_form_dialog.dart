import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_text_field.dart';
import '../../domain/entities/app_user.dart';
import '../../domain/entities/user_role.dart';
import '../providers/users_providers.dart';

/// Диалог создания/редактирования пользователя (раздел «Пользователи», admin only).
///
/// Один виджет на оба сценария: [existing] == null → создание, иначе — правка.
/// * `username` — только при создании (на правке показан неизменяемым).
/// * `password` — при создании обязателен; при правке опционален («сбросить пароль»).
/// * `role` — dropdown admin/user/guest (по `UserRole.values`); `is_active` — switch.
/// Валидация пустоты/длины до отправки. Дубль имени (422) → инлайн «Имя занято»,
/// LAST_ADMIN (409) → инлайн-предупреждение, 403 → snackbar (без разлогина).
class UserFormDialog extends ConsumerStatefulWidget {
  const UserFormDialog({this.existing, super.key});

  final AppUser? existing;

  static Future<void> show(BuildContext context, {AppUser? existing}) {
    return showDialog<void>(
      context: context,
      builder: (context) => UserFormDialog(existing: existing),
    );
  }

  @override
  ConsumerState<UserFormDialog> createState() => _UserFormDialogState();
}

class _UserFormDialogState extends ConsumerState<UserFormDialog> {
  late final _usernameController = TextEditingController(text: widget.existing?.username);
  final _passwordController = TextEditingController();

  late UserRole _role = widget.existing?.role ?? UserRole.user;
  late bool _isActive = widget.existing?.isActive ?? true;

  bool _isSubmitting = false;
  String? _error;

  bool get _isEditing => widget.existing != null;

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final password = _passwordController.text;

    if (!_isEditing) {
      final username = _usernameController.text.trim();
      if (username.isEmpty) {
        setState(() => _error = 'Введите имя пользователя.');
        return;
      }
      if (username.length < 3) {
        setState(() => _error = 'Имя не короче 3 символов.');
        return;
      }
      if (password.isEmpty) {
        setState(() => _error = 'Введите пароль.');
        return;
      }
      if (password.length < 6) {
        setState(() => _error = 'Пароль не короче 6 символов.');
        return;
      }
    } else if (password.isNotEmpty && password.length < 6) {
      // На правке пароль опционален, но если задан — минимальная длина та же.
      setState(() => _error = 'Пароль не короче 6 символов.');
      return;
    }

    setState(() {
      _isSubmitting = true;
      _error = null;
    });

    final controller = ref.read(usersControllerProvider.notifier);
    final result = _isEditing
        ? await controller.editUser(
            widget.existing!.id,
            role: _role,
            isActive: _isActive,
            // Пустой пароль → сброс не запрашиваем (шлём только если ввели).
            password: password.isEmpty ? null : password,
          )
        : await controller.createUser(
            username: _usernameController.text.trim(),
            password: password,
            role: _role,
            isActive: _isActive,
          );
    if (!mounted) return;

    result.when(
      onSuccess: (_) => Navigator.of(context).pop(),
      onFailure: (failure) {
        setState(() {
          _isSubmitting = false;
          _error = switch (failure) {
            ValidationFailure() => 'Имя занято.',
            LastAdminFailure() => 'Нельзя понизить последнего администратора.',
            _ => failure.message,
          };
        });
        // 403 показываем ещё и snackbar'ом (страховка), без разлогина.
        if (failure is ForbiddenFailure) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(failure.message)),
          );
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(_isEditing ? 'Редактировать пользователя' : 'Новый пользователь'),
      content: SizedBox(
        width: 380,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_isEditing)
                // Имя менять нельзя — показываем как статичную подпись.
                _ReadonlyField(label: 'Имя пользователя', value: widget.existing!.username)
              else
                AppTextField(
                  label: 'Имя пользователя',
                  controller: _usernameController,
                  hintText: 'например, ivan',
                  autofocus: true,
                ),
              const SizedBox(height: 12),
              AppTextField(
                label: _isEditing ? 'Новый пароль (необязательно)' : 'Пароль',
                controller: _passwordController,
                hintText: _isEditing ? 'оставьте пустым, чтобы не менять' : '••••••••',
                obscureText: true,
                onSubmitted: (_) => _submit(),
              ),
              const SizedBox(height: 16),
              _buildRoleDropdown(),
              const SizedBox(height: 12),
              _buildActiveSwitch(),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!, style: const TextStyle(color: AppColors.danger, fontSize: 13)),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
          child: const Text('Отмена'),
        ),
        SizedBox(
          width: 140,
          child: AppButton(
            label: _isEditing ? 'Сохранить' : 'Создать',
            isLoading: _isSubmitting,
            onPressed: _submit,
          ),
        ),
      ],
    );
  }

  Widget _buildRoleDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Роль', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 6),
        DropdownButtonFormField<UserRole>(
          value: _role,
          isExpanded: true,
          items: [
            for (final role in UserRole.values)
              DropdownMenuItem(value: role, child: Text(role.label)),
          ],
          onChanged: (value) {
            if (value != null) setState(() => _role = value);
          },
        ),
      ],
    );
  }

  Widget _buildActiveSwitch() {
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 48), // тап-таргет ≥ 48px
      child: Row(
        children: [
          Expanded(
            child: Text('Активен', style: Theme.of(context).textTheme.titleMedium),
          ),
          Switch(
            value: _isActive,
            onChanged: (value) => setState(() => _isActive = value),
          ),
        ],
      ),
    );
  }
}

/// Неизменяемое поле-подпись (для username на правке).
class _ReadonlyField extends StatelessWidget {
  const _ReadonlyField({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 6),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          decoration: BoxDecoration(
            color: AppColors.bg,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.border),
          ),
          child: Text(value, style: Theme.of(context).textTheme.bodyMedium),
        ),
      ],
    );
  }
}
