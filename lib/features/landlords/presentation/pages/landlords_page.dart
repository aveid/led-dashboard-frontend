import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/money_formatter.dart';
import '../../../../shared/domain/money.dart';
import '../../../../shared/widgets/admin_only.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/status_chip.dart';
import '../../../auth/presentation/controllers/auth_providers.dart';
import '../../domain/entities/landlord.dart';
import '../../domain/entities/landlord_screen_brief.dart';
import '../providers/landlords_providers.dart';
import '../widgets/landlord_form_dialog.dart';

/// Минимальная высота тап-таргета для мобильных устройств (см. FRONTEND_CONTEXT §3).
const double _kMinTapTarget = 48;

/// Страница «Арендодатели» (FR-8): список раскрывающихся карточек + CRUD.
///
/// Каждая карточка (FR-8.5) разворачивается вниз и лениво подгружает список
/// экранов арендодателя через [landlordScreensProvider] — запрос уходит только
/// при первом раскрытии конкретной карточки.
class LandlordsPage extends ConsumerWidget {
  const LandlordsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final landlordsAsync = ref.watch(landlordsListProvider);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Row(
            children: [
              Expanded(
                child: Text('Арендодатели', style: Theme.of(context).textTheme.titleLarge),
              ),
              IconButton(
                tooltip: 'Обновить',
                icon: const Icon(Icons.refresh),
                onPressed: () => ref.invalidate(landlordsListProvider),
              ),
              // RBAC: создание арендодателя — admin only (список + раскрытие
              // экранов (FR-8.5) остаются всем).
              AdminOnly(
                child: FilledButton.icon(
                  onPressed: () => LandlordFormDialog.show(context),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Добавить'),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: landlordsAsync.when(
            data: (landlords) => landlords.isEmpty
                ? const _EmptyState()
                : _LandlordsList(landlords: landlords),
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) => _ErrorState(
              message: error is Failure ? error.message : 'Не удалось загрузить список',
              onRetry: () => ref.invalidate(landlordsListProvider),
            ),
          ),
        ),
      ],
    );
  }
}

class _LandlordsList extends StatelessWidget {
  const _LandlordsList({required this.landlords});

  final List<Landlord> landlords;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: landlords.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) => _LandlordCard(landlord: landlords[index]),
    );
  }
}

/// Раскрывающаяся карточка арендодателя (FR-8.5).
///
/// Локальный флаг [_expanded] управляет ленью: пока карточка свёрнута, мы НЕ
/// `watch`-аем [landlordScreensProvider], поэтому сетевой запрос не уходит. При
/// первом раскрытии флаг переключается → build подписывается на провайдер →
/// запрос уходит один раз для этой карточки. «Экранов: N» появляется в подписи
/// после загрузки как длина списка (FR-8.3).
class _LandlordCard extends ConsumerStatefulWidget {
  const _LandlordCard({required this.landlord});

  final Landlord landlord;

  @override
  ConsumerState<_LandlordCard> createState() => _LandlordCardState();
}

class _LandlordCardState extends ConsumerState<_LandlordCard> {
  bool _expanded = false;

  Future<void> _confirmDelete() async {
    final landlord = widget.landlord;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Удалить арендодателя?'),
        content: Text(
          '«${landlord.name}» будет удалён. У привязанных экранов арендодатель '
          'просто станет не указан — сами экраны не удаляются.',
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

    if (confirmed != true || !mounted) return;

    final result = await ref.read(landlordsListProvider.notifier).delete(landlord.id);
    if (!mounted) return;
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
  Widget build(BuildContext context) {
    final landlord = widget.landlord;
    // Подписываемся на провайдер только когда карточка раскрыта — иначе запрос не уходит.
    final screensAsync =
        _expanded ? ref.watch(landlordScreensProvider(landlord.id)) : null;
    // RBAC: для гостя цены (строки экранов + подпись «Σ») рендерятся пусто.
    final isGuest = ref.watch(isGuestProvider);

    final contactLine = [
      if (landlord.contactPerson.isNotEmpty) landlord.contactPerson,
      if (landlord.phone.isNotEmpty) landlord.phone,
      if (landlord.email.isNotEmpty) landlord.email,
    ].join(' · ');

    // «Экранов: N» + общая сумма аренды по арендодателю (FR-8.3/8.4) — считаем по
    // загруженному списку. Пока грузится — «…»; до раскрытия ничего не показываем.
    final countLabel = screensAsync?.maybeWhen(
      data: (list) {
        final withPrice = list.where((s) => s.monthlyPrice != null);
        final parts = ['Экранов: ${list.length}'];
        if (withPrice.isNotEmpty) {
          final total = withPrice.fold<double>(0, (sum, s) => sum + s.monthlyPrice!.amount);
          // Для гостя подпись «Σ …» целиком пустая → сегмент опускаем.
          final sumText = guestPriceText(isGuest: isGuest, money: Money(amount: total));
          if (sumText.isNotEmpty) parts.add('Σ $sumText');
        }
        return parts.join('  ·  ');
      },
      loading: () => 'Экранов: …',
      orElse: () => null,
    );
    final subtitleText = [
      if (contactLine.isNotEmpty) contactLine,
      if (countLabel != null) countLabel,
    ].join('  ·  ');

    return AppCard(
      padding: EdgeInsets.zero,
      child: Theme(
        // Убираем стандартные разделители ExpansionTile — карточка уже в рамке.
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          onExpansionChanged: (value) => setState(() => _expanded = value),
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          // Заголовок сам по себе тап-таргет раскрытия; минимум по высоте — 48px.
          title: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: _kMinTapTarget),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(landlord.name, style: Theme.of(context).textTheme.titleMedium),
                      if (subtitleText.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(subtitleText, style: Theme.of(context).textTheme.bodySmall),
                      ],
                    ],
                  ),
                ),
                // Кнопки редактирования/удаления сами перехватывают тап и не
                // сворачивают/разворачивают карточку. RBAC: правка/удаление —
                // admin only; раскрытие списка экранов (FR-8.5) остаётся всем.
                AdminOnly(
                  child: IconButton(
                    tooltip: 'Редактировать',
                    icon: const Icon(Icons.edit_outlined, size: 20),
                    onPressed: () => LandlordFormDialog.show(context, existing: landlord),
                  ),
                ),
                AdminOnly(
                  child: IconButton(
                    tooltip: 'Удалить',
                    icon: const Icon(Icons.delete_outline, size: 20, color: AppColors.danger),
                    onPressed: _confirmDelete,
                  ),
                ),
              ],
            ),
          ),
          children: [
            if (screensAsync != null)
              _ScreensSection(landlordId: landlord.id, screensAsync: screensAsync),
          ],
        ),
      ),
    );
  }
}

/// Тело раскрытой карточки: состояния loading / error+retry / empty / data.
class _ScreensSection extends ConsumerWidget {
  const _ScreensSection({required this.landlordId, required this.screensAsync});

  final String landlordId;
  final AsyncValue<List<LandlordScreenBrief>> screensAsync;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isGuest = ref.watch(isGuestProvider);
    return screensAsync.when(
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: Center(
          child: SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(strokeWidth: 2.5),
          ),
        ),
      ),
      error: (error, _) {
        // 404 LANDLORD_NOT_FOUND: арендодателя уже нет — мягкий рефетч списка
        // + короткий snackbar, без красного экрана.
        if (error is NotFoundFailure) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!context.mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Арендодатель больше не существует — список обновлён')),
            );
            ref.invalidate(landlordsListProvider);
          });
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Text('Арендодателя больше нет.'),
          );
        }
        final message = error is Failure ? error.message : 'Не удалось загрузить экраны';
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: [
              const Icon(Icons.error_outline, color: AppColors.danger, size: 20),
              const SizedBox(width: 8),
              Expanded(child: Text(message, style: Theme.of(context).textTheme.bodySmall)),
              ConstrainedBox(
                constraints: const BoxConstraints(minHeight: _kMinTapTarget),
                child: TextButton(
                  onPressed: () => ref.invalidate(landlordScreensProvider(landlordId)),
                  child: const Text('Повторить'),
                ),
              ),
            ],
          ),
        );
      },
      data: (screens) {
        if (screens.isEmpty) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Text('Нет экранов'),
          );
        }
        return Column(
          children: [
            for (final screen in screens) _ScreenRow(screen: screen, isGuest: isGuest),
          ],
        );
      },
    );
  }
}

/// Строка одного экрана в раскрытом списке: имя, бейдж статуса, размер, город.
class _ScreenRow extends StatelessWidget {
  const _ScreenRow({required this.screen, required this.isGuest});

  final LandlordScreenBrief screen;
  final bool isGuest;

  @override
  Widget build(BuildContext context) {
    final meta = [
      if (screen.size.isNotEmpty) screen.size,
      screen.city.name,
    ].join(' · ');

    // RBAC: для гостя цена — пустая строка (сегмент опускаем, чтобы не оставлять
    // висящий отступ под бейджем статуса).
    final priceText = guestPriceText(isGuest: isGuest, money: screen.monthlyPrice);

    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: _kMinTapTarget),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(screen.name, style: Theme.of(context).textTheme.bodyMedium),
                  const SizedBox(height: 2),
                  Text(meta, style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                StatusChip(screen.status),
                if (priceText.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    priceText,
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(fontWeight: FontWeight.w600),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text('Арендодателей пока нет', style: Theme.of(context).textTheme.bodyMedium),
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
