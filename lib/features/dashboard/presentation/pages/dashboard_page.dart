import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/money_formatter.dart';
import '../../../../shared/domain/landlord_cost.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../auth/presentation/controllers/auth_providers.dart';
import '../../../screens_map/presentation/providers/reference_providers.dart';
import '../../domain/entities/dashboard_summary.dart';
import '../providers/dashboard_providers.dart';

/// Страница «Дашборд» (FR-9): сводная статистика по всем экранам.
class DashboardPage extends ConsumerWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summaryAsync = ref.watch(dashboardSummaryProvider);
    final thresholdDays = ref.watch(thresholdDaysProvider);
    final landlordNames = ref.watch(landlordNamesProvider).valueOrNull ?? const {};
    // RBAC: для гостя денежные подписи дашборда рендерятся пустой строкой.
    final isGuest = ref.watch(isGuestProvider);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Row(
            children: [
              Expanded(
                child: Text('Дашборд', style: Theme.of(context).textTheme.titleLarge),
              ),
              IconButton(
                tooltip: 'Обновить',
                icon: const Icon(Icons.refresh),
                onPressed: () => ref.invalidate(dashboardSummaryProvider),
              ),
            ],
          ),
        ),
        Expanded(
          child: summaryAsync.when(
            data: (summary) => _DashboardContent(
              summary: summary,
              thresholdDays: thresholdDays,
              landlordNames: landlordNames,
              isGuest: isGuest,
              onThresholdChanged: (days) => ref.read(thresholdDaysProvider.notifier).state = days,
            ),
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) => Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.error_outline, color: AppColors.danger, size: 32),
                  const SizedBox(height: 8),
                  Text(
                    error is Failure ? error.message : 'Не удалось загрузить сводку',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: () => ref.invalidate(dashboardSummaryProvider),
                    child: const Text('Повторить'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _DashboardContent extends StatelessWidget {
  const _DashboardContent({
    required this.summary,
    required this.thresholdDays,
    required this.landlordNames,
    required this.isGuest,
    required this.onThresholdChanged,
  });

  final DashboardSummary summary;
  final int thresholdDays;
  final Map<String, String> landlordNames;
  final bool isGuest;
  final ValueChanged<int> onThresholdChanged;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // --- Счётчики по статусам (FR-9.1, FR-9.2) ---
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _StatCard(label: 'Всего экранов', value: '${summary.totalScreens}', color: AppColors.primary),
            _StatCard(label: 'Активные', value: '${summary.activeCount}', color: AppColors.statusActive),
            _StatCard(label: 'Неактивные', value: '${summary.inactiveCount}', color: AppColors.statusInactive),
            _StatCard(label: 'Потенциальные', value: '${summary.potentialCount}', color: AppColors.statusPotential),
            _StatCard(label: 'Архивные', value: '${summary.archivedCount}', color: AppColors.statusArchived),
          ],
        ),
        const SizedBox(height: 20),

        // --- Общая сумма аренды активных (FR-9.3) ---
        AppCard(
          child: Row(
            children: [
              const Icon(Icons.payments_outlined, color: AppColors.primary, size: 28),
              const SizedBox(width: 14),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Аренда активных экранов в месяц', style: Theme.of(context).textTheme.bodySmall),
                  Text(
                    guestPriceText(isGuest: isGuest, money: summary.totalActiveRent),
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // --- Разбивка по арендодателям (FR-9.4) ---
        Text('По арендодателям', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        AppCard(
          child: summary.byLandlord.isEmpty
              ? const Text('Нет данных')
              : Column(
                  children: [
                    for (final item in summary.byLandlord)
                      _LandlordBreakdownRow(item: item, names: landlordNames, isGuest: isGuest),
                  ],
                ),
        ),
        const SizedBox(height: 20),

        // --- Договоры, заканчивающиеся в пределах порога (FR-9.5) ---
        Row(
          children: [
            Expanded(child: Text('Скоро заканчиваются', style: Theme.of(context).textTheme.titleMedium)),
            DropdownButton<int>(
              value: thresholdDays,
              isDense: true,
              items: const [
                DropdownMenuItem(value: 7, child: Text('7 дней')),
                DropdownMenuItem(value: 14, child: Text('14 дней')),
                DropdownMenuItem(value: 30, child: Text('30 дней')),
                DropdownMenuItem(value: 60, child: Text('60 дней')),
              ],
              onChanged: (value) {
                if (value != null) onThresholdChanged(value);
              },
            ),
          ],
        ),
        const SizedBox(height: 8),
        AppCard(
          child: summary.endingSoon.isEmpty
              ? const Text('Нет договоров, заканчивающихся в этот срок')
              : Column(
                  children: [
                    for (final item in summary.endingSoon) _EndingContractRow(item: item, names: landlordNames),
                  ],
                ),
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.label, required this.value, required this.color});

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 160,
      child: AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(value, style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: color)),
            const SizedBox(height: 4),
            Text(label, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}

class _LandlordBreakdownRow extends StatelessWidget {
  const _LandlordBreakdownRow({required this.item, required this.names, required this.isGuest});

  final LandlordCost item;
  final Map<String, String> names;
  final bool isGuest;

  @override
  Widget build(BuildContext context) {
    final label = item.landlordId == null
        ? 'Без арендодателя'
        : (names[item.landlordId] ?? item.landlordId!);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(child: Text(label, style: Theme.of(context).textTheme.bodyMedium)),
          Text('${item.screensCount} экр.', style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(width: 12),
          // Счётчик экранов остаётся, сумма для гостя — пустая строка.
          Text(
            guestPriceText(isGuest: isGuest, money: item.total),
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}

class _EndingContractRow extends StatelessWidget {
  const _EndingContractRow({required this.item, required this.names});

  final EndingContract item;
  final Map<String, String> names;

  @override
  Widget build(BuildContext context) {
    final landlordLabel = item.landlordId == null ? '' : (names[item.landlordId] ?? item.landlordId!);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.screenName, style: Theme.of(context).textTheme.bodyMedium),
                if (landlordLabel.isNotEmpty)
                  Text(landlordLabel, style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
          Text(_formatDate(item.endDate), style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }

  // Ручное форматирование без intl.DateFormat — см. пояснение в screen_card_sheet.dart.
  String _formatDate(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    return '$day.$month.${date.year}';
  }
}
