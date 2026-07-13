import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/admin_only.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../domain/entities/campaign.dart';
import '../providers/campaigns_providers.dart';
import '../widgets/campaign_form_dialog.dart';

/// Страница «Кампании» (FR-3.10): список + создание/переименование/удаление.
class CampaignsPage extends ConsumerWidget {
  const CampaignsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final campaignsAsync = ref.watch(campaignsListProvider);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Row(
            children: [
              Expanded(
                child: Text('Кампании', style: Theme.of(context).textTheme.titleLarge),
              ),
              IconButton(
                tooltip: 'Обновить',
                icon: const Icon(Icons.refresh),
                onPressed: () => ref.invalidate(campaignsListProvider),
              ),
              // RBAC: создание кампании — admin only (список видим всем).
              AdminOnly(
                child: FilledButton.icon(
                  onPressed: () => CampaignFormDialog.show(context),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Добавить'),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: campaignsAsync.when(
            data: (campaigns) => campaigns.isEmpty
                ? const _EmptyState()
                : _CampaignsList(campaigns: campaigns),
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) => _ErrorState(
              message: error is Failure ? error.message : 'Не удалось загрузить список',
              onRetry: () => ref.invalidate(campaignsListProvider),
            ),
          ),
        ),
      ],
    );
  }
}

class _CampaignsList extends StatelessWidget {
  const _CampaignsList({required this.campaigns});

  final List<Campaign> campaigns;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: campaigns.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) => _CampaignRow(campaign: campaigns[index]),
    );
  }
}

class _CampaignRow extends ConsumerWidget {
  const _CampaignRow({required this.campaign});

  final Campaign campaign;

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Удалить кампанию?'),
        content: Text(
          '«${campaign.name}» будет удалена. Связь с экранами снимется — сами '
          'экраны не удаляются.',
        ),
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

    final result = await ref.read(campaignsListProvider.notifier).delete(campaign.id);
    if (!context.mounted) return;
    result.when(
      onSuccess: (_) {},
      onFailure: (failure) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Не удалось удалить: ${failure.message}')),
        );
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
            child: Text(campaign.name, style: Theme.of(context).textTheme.titleMedium),
          ),
          // RBAC: переименование/удаление кампании — admin only.
          AdminOnly(
            child: IconButton(
              tooltip: 'Переименовать',
              icon: const Icon(Icons.edit_outlined, size: 20),
              onPressed: () => CampaignFormDialog.show(context, existing: campaign),
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
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text('Кампаний пока нет', style: Theme.of(context).textTheme.bodyMedium),
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
