import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../domain/entities/app_user.dart';
import '../../domain/entities/user_role.dart';
import '../providers/users_providers.dart';
import '../widgets/user_form_dialog.dart';

/// Минимальная высота тап-таргета (FRONTEND_CONTEXT §3).
const double _kMinTapTarget = 48;

/// Страница «Пользователи» (RBAC, admin only): список аккаунтов + CRUD.
///
/// Доступна только admin: пункт меню строится лишь при `isAdmin`, а прямой заход
/// по URL перехватывает guard в роутере (redirect на /map). Сама страница —
/// обычный список карточек с действиями создания/правки/удаления.
class UsersPage extends ConsumerWidget {
  const UsersPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final usersAsync = ref.watch(usersProvider);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Row(
            children: [
              Expanded(
                child: Text('Пользователи', style: Theme.of(context).textTheme.titleLarge),
              ),
              IconButton(
                tooltip: 'Обновить',
                icon: const Icon(Icons.refresh),
                onPressed: () => ref.read(usersControllerProvider.notifier).refresh(),
              ),
              FilledButton.icon(
                onPressed: () => UserFormDialog.show(context),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Добавить'),
              ),
            ],
          ),
        ),
        Expanded(
          child: usersAsync.when(
            data: (users) =>
                users.isEmpty ? const _EmptyState() : _UsersList(users: users),
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) => _ErrorState(
              message: error is Failure ? error.message : 'Не удалось загрузить список',
              onRetry: () => ref.invalidate(usersProvider),
            ),
          ),
        ),
      ],
    );
  }
}

class _UsersList extends StatelessWidget {
  const _UsersList({required this.users});

  final List<AppUser> users;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: users.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) => _UserRow(user: users[index]),
    );
  }
}

class _UserRow extends ConsumerWidget {
  const _UserRow({required this.user});

  final AppUser user;

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Удалить пользователя?'),
        content: Text('«${user.username}» будет удалён.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Удалить', style: TextStyle(color: AppColors.danger)),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    final result = await ref.read(usersControllerProvider.notifier).removeUser(user.id);
    if (!context.mounted) return;
    result.when(
      onSuccess: (_) {},
      onFailure: (failure) {
        final message = switch (failure) {
          // Уже удалён кем-то другим — мягко, без красного экрана: рефетч + подсказка.
          NotFoundFailure() => 'Пользователь уже удалён. Список обновлён.',
          LastAdminFailure() => 'Нельзя удалить последнего администратора.',
          _ => 'Не удалось удалить: ${failure.message}',
        };
        if (failure is NotFoundFailure) ref.invalidate(usersProvider);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
      },
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        user.username,
                        style: Theme.of(context).textTheme.titleMedium,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    _RoleBadge(role: user.role),
                  ],
                ),
                const SizedBox(height: 4),
                _StatusLine(isActive: user.isActive),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Редактировать',
            icon: const Icon(Icons.edit_outlined, size: 20),
            constraints: const BoxConstraints(minWidth: _kMinTapTarget, minHeight: _kMinTapTarget),
            onPressed: () => UserFormDialog.show(context, existing: user),
          ),
          IconButton(
            tooltip: 'Удалить',
            icon: const Icon(Icons.delete_outline, size: 20, color: AppColors.danger),
            constraints: const BoxConstraints(minWidth: _kMinTapTarget, minHeight: _kMinTapTarget),
            onPressed: () => _confirmDelete(context, ref),
          ),
        ],
      ),
    );
  }
}

/// Бейдж роли: admin — брендовый цвет, user — нейтральный, guest — синий (info).
class _RoleBadge extends StatelessWidget {
  const _RoleBadge({required this.role});

  final UserRole role;

  @override
  Widget build(BuildContext context) {
    final color = switch (role) {
      UserRole.admin => AppColors.primary,
      UserRole.user => AppColors.textSecondary,
      UserRole.guest => AppColors.info,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        role.label,
        style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600),
      ),
    );
  }
}

/// Строка статуса активности с цветной точкой.
class _StatusLine extends StatelessWidget {
  const _StatusLine({required this.isActive});

  final bool isActive;

  @override
  Widget build(BuildContext context) {
    final color = isActive ? AppColors.success : AppColors.textMuted;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          isActive ? 'Активен' : 'Отключён',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: color),
        ),
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text('Пользователей пока нет', style: Theme.of(context).textTheme.bodyMedium),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline, color: AppColors.danger, size: 32),
          const SizedBox(height: 8),
          Text(message, style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 12),
          TextButton(onPressed: onRetry, child: const Text('Повторить')),
        ],
      ),
    );
  }
}
