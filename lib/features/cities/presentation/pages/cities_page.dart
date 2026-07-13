import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/admin_only.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../domain/entities/city.dart';
import '../providers/cities_providers.dart';
import '../widgets/add_city_dialog.dart';

/// Страница «Города / Регионы»: список городов + добавление/удаление.
class CitiesPage extends ConsumerWidget {
  const CitiesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final citiesAsync = ref.watch(citiesProvider);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Row(
            children: [
              Expanded(
                child: Text('Города / Регионы', style: Theme.of(context).textTheme.titleLarge),
              ),
              IconButton(
                tooltip: 'Обновить',
                icon: const Icon(Icons.refresh),
                onPressed: () => ref.read(citiesControllerProvider.notifier).refresh(),
              ),
              // RBAC: добавление города — admin only (список видим всем).
              AdminOnly(
                child: FilledButton.icon(
                  onPressed: () => AddCityDialog.show(context),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Добавить город'),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: citiesAsync.when(
            data: (cities) =>
                cities.isEmpty ? const _EmptyState() : _CitiesList(cities: cities),
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) => _ErrorState(
              message: error is Failure ? error.message : 'Не удалось загрузить список',
              onRetry: () => ref.invalidate(citiesProvider),
            ),
          ),
        ),
      ],
    );
  }
}

class _CitiesList extends StatelessWidget {
  const _CitiesList({required this.cities});

  final List<City> cities;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: cities.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) => _CityRow(city: cities[index]),
    );
  }
}

class _CityRow extends ConsumerWidget {
  const _CityRow({required this.city});

  final City city;

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Удалить город?'),
        content: Text('«${city.name}» будет удалён из справочника.'),
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

    final result = await ref.read(citiesControllerProvider.notifier).remove(city.id);
    if (!context.mounted) return;
    result.when(
      onSuccess: (_) {},
      onFailure: (failure) {
        final message = failure is CityInUseFailure
            ? 'Нельзя удалить: у города есть привязанные экраны'
            : 'Не удалось удалить: ${failure.message}';
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
                Text(city.name, style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 2),
                Text(
                  'Экранов: ${city.screensCount}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          // RBAC: удаление города — admin only.
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
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text('Городов пока нет', style: Theme.of(context).textTheme.bodyMedium),
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
