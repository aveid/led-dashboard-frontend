import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/presentation/controllers/auth_providers.dart';

/// Обёртка маскирования по роли (RBAC, NFR-8): показывает [child] только admin.
///
/// Для не-admin (в т.ч. пока роль грузится/при ошибке — fail-safe) возвращает
/// `SizedBox.shrink()`, т.е. контрол не занимает места. Единственный источник
/// роли — [isAdminProvider]; логику роли в виджетах не дублируем.
///
/// ⚠️ Это UX, а не безопасность: авторитетен бэкенд (403 на запрещённую операцию,
/// см. [ForbiddenFailure]). Маскировка лишь убирает бессмысленные для `user` кнопки.
class AdminOnly extends ConsumerWidget {
  const AdminOnly({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ref.watch(isAdminProvider) ? child : const SizedBox.shrink();
  }
}
