import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/admin_only.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../domain/entities/screen_type.dart';
import '../providers/screen_types_providers.dart';
import '../widgets/screen_type_form_dialog.dart';

/// Страница «Тип экрана»: список типов + поиск + добавление/редактирование/
/// удаление.
///
/// Поиск делается на клиенте по кэшированному [screenTypesProvider] (единый
/// источник для формы экрана и фильтра) — отдельный запрос на каждый ввод не
/// нужен для внутреннего справочника.
class ScreenTypesPage extends ConsumerStatefulWidget {
  const ScreenTypesPage({super.key});

  @override
  ConsumerState<ScreenTypesPage> createState() => _ScreenTypesPageState();
}

class _ScreenTypesPageState extends ConsumerState<ScreenTypesPage> {
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final typesAsync = ref.watch(screenTypesProvider);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Row(
            children: [
              Expanded(
                child: Text('Тип экрана', style: Theme.of(context).textTheme.titleLarge),
              ),
              IconButton(
                tooltip: 'Обновить',
                icon: const Icon(Icons.refresh),
                onPressed: () => ref.read(screenTypesControllerProvider.notifier).refresh(),
              ),
              // RBAC: добавление типа экрана — admin only (список видим всем).
              AdminOnly(
                child: FilledButton.icon(
                  onPressed: () => ScreenTypeFormDialog.show(context),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Добавить тип'),
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: TextField(
            controller: _searchController,
            onChanged: (value) => setState(() => _query = value.trim().toLowerCase()),
            decoration: InputDecoration(
              hintText: 'Поиск по названию',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _query.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _query = '');
                      },
                    ),
            ),
          ),
        ),
        Expanded(
          child: typesAsync.when(
            data: (types) {
              final filtered = _query.isEmpty
                  ? types
                  : types.where((t) => t.name.toLowerCase().contains(_query)).toList();
              if (types.isEmpty) return const _EmptyState(message: 'Типов пока нет');
              if (filtered.isEmpty) return const _EmptyState(message: 'Ничего не найдено');
              return _TypesList(types: filtered);
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) => _ErrorState(
              message: error is Failure ? error.message : 'Не удалось загрузить список',
              onRetry: () => ref.invalidate(screenTypesProvider),
            ),
          ),
        ),
      ],
    );
  }
}

class _TypesList extends StatelessWidget {
  const _TypesList({required this.types});

  final List<ScreenType> types;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: types.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) => _TypeRow(type: types[index]),
    );
  }
}

class _TypeRow extends ConsumerWidget {
  const _TypeRow({required this.type});

  final ScreenType type;

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Удалить тип?'),
        content: Text('Удалить тип «${type.name}»?'),
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

    final result = await ref.read(screenTypesControllerProvider.notifier).remove(type.id);
    if (!context.mounted) return;
    result.when(
      onSuccess: (_) => ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Тип удалён.')),
      ),
      onFailure: (failure) {
        // 409 «тип используется» — не баг: показываем понятное сообщение с числом
        // экранов, сам тип остаётся в списке.
        final message = failure is ScreenTypeInUseFailure
            ? (failure.usedByCount != null
                ? 'Тип используется на ${failure.usedByCount} экранах — сначала измените их тип.'
                : failure.message)
            : 'Не удалось удалить: ${failure.message}';
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
      },
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final code = type.code;
    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(type.name, style: Theme.of(context).textTheme.titleMedium),
                if (code != null && code.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(code, style: Theme.of(context).textTheme.bodySmall),
                ],
              ],
            ),
          ),
          // RBAC: редактирование/удаление типа — admin only.
          AdminOnly(
            child: IconButton(
              tooltip: 'Редактировать',
              icon: const Icon(Icons.edit_outlined, size: 20),
              onPressed: () => ScreenTypeFormDialog.show(context, existing: type),
            ),
          ),
          AdminOnly(
            child: IconButton(
              tooltip: 'Удалить',
              icon: const Icon(Icons.delete_outline, size: 20, color: AppColors.danger),
              onPressed: () => _confirmDelete(context, ref),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(message, style: Theme.of(context).textTheme.bodyMedium),
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
