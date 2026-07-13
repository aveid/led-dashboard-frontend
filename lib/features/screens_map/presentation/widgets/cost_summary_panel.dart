import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/money_formatter.dart';
import '../../../../core/utils/web_file_saver.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/domain/landlord_cost.dart';
import '../../../auth/presentation/controllers/auth_providers.dart';
import '../../domain/entities/cost_summary.dart';
import '../providers/reference_providers.dart';
import '../providers/screens_providers.dart';
import '../providers/selection_providers.dart';

/// Панель расчёта стоимости выбранных экранов (FR-6.2–6.4) с выгрузкой в Excel
/// (FR-7.4). Появляется поверх карты, когда выбор непустой (см. `map_page.dart`).
class CostSummaryPanel extends ConsumerStatefulWidget {
  const CostSummaryPanel({super.key});

  @override
  ConsumerState<CostSummaryPanel> createState() => _CostSummaryPanelState();
}

class _CostSummaryPanelState extends ConsumerState<CostSummaryPanel> {
  bool _isExporting = false;

  Future<void> _export() async {
    final selectedIds = ref.read(selectedScreenIdsProvider).toList();
    setState(() => _isExporting = true);

    final result = await ref.read(exportScreensUseCaseProvider).call(screenIds: selectedIds);

    if (!mounted) return;
    setState(() => _isExporting = false);

    result.when(
      onSuccess: (bytes) {
        final filename = 'screens_export_${DateTime.now().millisecondsSinceEpoch}.xlsx';
        saveBytesAsFile(bytes, filename);
      },
      onFailure: (failure) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Не удалось выгрузить файл: ${failure.message}')),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final summaryAsync = ref.watch(costSummaryProvider);
    final landlordNames = ref.watch(landlordNamesProvider).valueOrNull ?? const {};
    // RBAC: гость видит панель (экспорт — это чтение), но суммы — пустой строкой.
    final isGuest = ref.watch(isGuestProvider);

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 12, offset: Offset(0, -2))],
      ),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
      child: summaryAsync.when(
        data: (summary) => summary == null
            ? const SizedBox.shrink()
            : _Content(
                summary: summary,
                landlordNames: landlordNames,
                isGuest: isGuest,
                isExporting: _isExporting,
                onExport: _export,
                onClear: () => ref.read(selectedScreenIdsProvider.notifier).clear(),
              ),
        loading: () => const SizedBox(
          height: 60,
          child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
        ),
        error: (error, _) => const SizedBox(
          height: 60,
          child: Center(child: Text('Не удалось посчитать стоимость')),
        ),
      ),
    );
  }
}

class _Content extends StatelessWidget {
  const _Content({
    required this.summary,
    required this.landlordNames,
    required this.isGuest,
    required this.isExporting,
    required this.onExport,
    required this.onClear,
  });

  final CostSummary summary;
  final Map<String, String> landlordNames;
  final bool isGuest;
  final bool isExporting;
  final VoidCallback onExport;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Выбрано экранов: ${summary.selectedCount}',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            IconButton(
              tooltip: 'Снять выделение',
              icon: const Icon(Icons.close),
              onPressed: onClear,
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          guestPriceText(isGuest: isGuest, money: summary.total),
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: AppColors.primary),
        ),
        if (summary.byLandlord.length > 1) ...[
          const SizedBox(height: 12),
          for (final item in summary.byLandlord)
            _LandlordRow(item: item, names: landlordNames, isGuest: isGuest),
        ],
        const SizedBox(height: 16),
        AppButton(
          label: isExporting ? 'Формируем файл…' : 'Скачать Excel',
          isLoading: isExporting,
          onPressed: onExport,
        ),
      ],
    );
  }
}

class _LandlordRow extends StatelessWidget {
  const _LandlordRow({required this.item, required this.names, required this.isGuest});

  final LandlordCost item;
  final Map<String, String> names;
  final bool isGuest;

  @override
  Widget build(BuildContext context) {
    final label = item.landlordId == null
        ? 'Без арендодателя'
        : (names[item.landlordId] ?? item.landlordId!);

    // Счётчик экранов — не цена, остаётся; сумма для гостя пустая → показываем
    // только счётчик, без висящего разделителя.
    final priceText = guestPriceText(isGuest: isGuest, money: item.total);
    final trailing =
        priceText.isEmpty ? '${item.screensCount}' : '${item.screensCount} · $priceText';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(child: Text(label, style: Theme.of(context).textTheme.bodyMedium)),
          Text(
            trailing,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}
