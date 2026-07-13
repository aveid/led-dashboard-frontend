import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/money_formatter.dart';
import '../../../../shared/domain/attachment_type.dart';
import '../../../../shared/widgets/admin_only.dart';
import '../../../auth/presentation/controllers/auth_providers.dart';
import '../../../../shared/domain/screen_status.dart';
import '../../../../shared/widgets/status_chip.dart';
import '../../domain/attachment_policy.dart';
import '../../domain/entities/attachment.dart';
import '../../domain/entities/screen.dart';
import '../providers/reference_providers.dart';
import '../providers/screens_providers.dart';
import 'activate_screen_dialog.dart';
import 'attachment_document_tile.dart';
import 'attachment_photo_preview.dart';
import 'screen_form_dialog.dart';

/// Карточка экрана (FR-3): показывается снизу по тапу на маркер.
///
/// Отображает все основные поля экрана. Имена арендодателя/кампании
/// подтягиваются асинхронно (справочники) — пока грузятся, показываем сам id
/// как временную подпись, чтобы не блокировать открытие карточки ожиданием.
///
/// Открывается по фиксированному снимку [Screen], но следит за [screensProvider]
/// и берёт актуальную версию экрана оттуда по id: если presigned-ссылка вложения
/// протухла, [onExpired] инвалидирует список, тот перезапрашивается, и карточка
/// перерисовывается со свежими ссылками (FR-3.12/3.13).
class ScreenCardSheet extends ConsumerStatefulWidget {
  const ScreenCardSheet({required this.screen, super.key});

  final Screen screen;

  /// Открывает карточку модальным листом снизу экрана.
  static Future<void> show(BuildContext context, Screen screen) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true, // снимает лимит ~половины экрана
      useSafeArea: true, // на полной высоте не залезать под статус-бар/вырез
      backgroundColor: Colors.transparent,
      builder: (context) => ScreenCardSheet(screen: screen),
    );
  }

  @override
  ConsumerState<ScreenCardSheet> createState() => _ScreenCardSheetState();
}

class _ScreenCardSheetState extends ConsumerState<ScreenCardSheet> {
  /// Максимум автоматических перезапросов за жизнь карточки. Ограничение важно:
  /// если ссылка падает не из-за протухания, а стабильно (CORS/404/недоступный
  /// хост MinIO), перезапрос не поможет — без лимита это ушло бы в бесконечный
  /// цикл обновлений списка. После лимита просто показываем заглушку.
  static const _maxReloadAttempts = 2;

  /// Сколько перезапросов уже сделали (не сбрасывается — это и есть лимит).
  int _reloadAttempts = 0;

  /// Один перезапрос уже запланирован в этом кадре — не плодим дубли, когда сразу
  /// несколько вложений сообщают об ошибке. Сбрасывается по приходу свежих данных.
  bool _reloadScheduled = false;

  /// Актуальная версия экрана из [screensProvider] (по id), либо исходный снимок,
  /// если список ещё грузится или экран не попал в текущую выборку фильтров.
  Screen _currentScreen() {
    final screens = ref.watch(screensProvider).valueOrNull;
    if (screens == null) return widget.screen;
    for (final s in screens) {
      if (s.id == widget.screen.id) return s;
    }
    return widget.screen;
  }

  /// Реакция на протухшую presigned-ссылку: перезапрашиваем экраны за свежими
  /// ссылками. Вызывается из `errorBuilder`/неуспешного `launchUrl`, т.е. во
  /// время build — поэтому инвалидацию откладываем на следующий микротаск.
  /// Число попыток ограничено [_maxReloadAttempts], чтобы стабильно падающая
  /// ссылка (CORS/404) не зациклила обновление списка.
  void _handleExpired() {
    if (_reloadScheduled || _reloadAttempts >= _maxReloadAttempts) return;
    _reloadScheduled = true;
    _reloadAttempts++;
    Future.microtask(() {
      if (!mounted) return;
      ref.invalidate(screensProvider);
    });
  }

  @override
  Widget build(BuildContext context) {
    // По приходу свежих данных снимаем «запланировано», чтобы следующий кадр мог
    // сделать ещё попытку (в пределах [_maxReloadAttempts]).
    ref.listen(screensProvider, (previous, next) {
      if (next.hasValue) _reloadScheduled = false;
    });

    final screen = _currentScreen();

    // RBAC: для гостя цены рендерятся пустой строкой, а секция «Документы /
    // Договор» не монтируется вовсе (секция «Фото» остаётся). Бэкенд авторитетен
    // (guest получает monthly_price: null и без DOCUMENT-вложений) — это UX-зеркало.
    final isGuest = ref.watch(isGuestProvider);

    final landlordNames = ref.watch(landlordNamesProvider).valueOrNull ?? const {};
    final campaignNames = ref.watch(campaignNamesProvider).valueOrNull ?? const {};

    final landlordLabel = screen.landlordId == null
        ? 'Не указан'
        : (landlordNames[screen.landlordId] ?? screen.landlordId!);
    final campaignLabel = screen.currentCampaignId == null
        ? '—'
        : (campaignNames[screen.currentCampaignId] ?? screen.currentCampaignId!);

    final photos = screen.attachments
        .where((a) => a.type == AttachmentType.photo)
        .toList();
    final documents = screen.attachments
        .where((a) => a.type != AttachmentType.photo)
        .toList();

    return DraggableScrollableSheet(
      initialChildSize: 0.95, // открывается почти на всю высоту
      minChildSize: 0.5, // ниже — свайп к закрытию
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: ListView(
            controller: scrollController,
            padding: const EdgeInsets.all(20),
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: Text(screen.name, style: Theme.of(context).textTheme.headlineSmall),
                  ),
                  if (_isExpiringSoon(screen)) ...[
                    const _ExpiringSoonChip(),
                    const SizedBox(width: 6),
                  ],
                  StatusChip(screen.status),
                ],
              ),
              const SizedBox(height: 4),
              Text(screen.addressLine, style: Theme.of(context).textTheme.bodyMedium),
              const SizedBox(height: 12),
              // RBAC: «Редактировать»/«Активировать» — admin only. Сама карточка,
              // превью и просмотр остаются всем.
              AdminOnly(child: _ActionsRow(screen: screen)),
              const Divider(height: 32),
              _InfoRow(label: 'Размер', value: screen.size.isEmpty ? '—' : screen.size),
              _InfoRow(label: 'Тип экрана', value: screen.screenType?.name ?? '—'),
              _InfoRow(label: 'Арендодатель', value: landlordLabel),
              _InfoRow(
                label: 'Стоимость аренды',
                value: guestPriceText(isGuest: isGuest, money: screen.monthlyPrice),
              ),
              if (screen.currentRental != null)
                _InfoRow(
                  label: 'Срок аренды',
                  value: _formatPeriod(
                    screen.currentRental!.startDate,
                    screen.currentRental!.endDate,
                  ),
                ),
              // Дата окончания аренды (FR-4.4): показываем только при наличии —
              // при null строку скрываем (не рисуем «—»). По истечении бэк сам
              // архивирует экран при чтении.
              if (screen.rentalEndDate != null)
                _InfoRow(label: 'Аренда до', value: _formatDate(screen.rentalEndDate!)),
              _InfoRow(label: 'Кампания', value: campaignLabel),
              const Divider(height: 32),
              _AttachmentSection(
                title: 'Фото',
                emptyLabel: 'Нет фото',
                uploadLabel: 'Загрузить фото',
                uploadType: AttachmentType.photo,
                screenId: screen.id,
                attachments: photos,
                onExpired: _handleExpired,
              ),
              // RBAC: секция «Документы / Договор» скрыта для гостя целиком
              // (включая заголовок и кнопку загрузки). Бэкенд и так не шлёт
              // guest'у DOCUMENT-вложения — прячем блок ради чистого UX.
              if (!isGuest) ...[
                const SizedBox(height: 16),
                _AttachmentSection(
                  title: 'Документы / Договор',
                  emptyLabel: 'Нет документов',
                  uploadLabel: 'Загрузить договор',
                  uploadType: AttachmentType.contract,
                  screenId: screen.id,
                  attachments: documents,
                  onExpired: _handleExpired,
                ),
              ],
              if (screen.comment.isNotEmpty) ...[
                const Divider(height: 32),
                Text('Комментарий', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 6),
                Text(screen.comment, style: Theme.of(context).textTheme.bodyMedium),
              ],
              const SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }

  /// Форматирует период аренды как `dd.MM.yyyy — dd.MM.yyyy` без intl.DateFormat:
  /// DateFormat с локалью 'ru' требует предварительного async-вызова
  /// `initializeDateFormatting('ru')`, иначе бросает LocaleDataException в
  /// рантайме. Формат чисто цифровой — ручная сборка строки надёжнее и проще.
  String _formatPeriod(DateTime start, DateTime end) {
    return '${_formatDate(start)} — ${_formatDate(end)}';
  }

  String _formatDate(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    return '$day.$month.${date.year}';
  }

  /// «Истекает скоро» (FR-4.4, косметика): активный экран с датой окончания в
  /// пределах ближайших 7 дней (считая от сегодня, по дате без времени). Это не
  /// бизнес-логика — реальную архивацию делает бэк; чип лишь подсказка оператору.
  bool _isExpiringSoon(Screen screen) {
    final end = screen.rentalEndDate;
    if (end == null || screen.status != ScreenStatus.active) return false;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final endDay = DateTime(end.year, end.month, end.day);
    final daysLeft = endDay.difference(today).inDays;
    return daysLeft >= 0 && daysLeft <= 7;
  }
}

/// Предупреждающий чип «истекает скоро» рядом со статусом (FR-4.4).
class _ExpiringSoonChip extends StatelessWidget {
  const _ExpiringSoonChip();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.schedule, size: 13, color: AppColors.warning),
          SizedBox(width: 4),
          Text(
            'Истекает скоро',
            style: TextStyle(
              color: AppColors.warning,
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

/// Секция вложений одного вида (фото либо документы) с инлайн-кнопкой загрузки
/// в строке заголовка и заглушкой, если пусто.
///
/// Кнопка сразу открывает выбор файла с зафиксированным [uploadType] — отдельного
/// выбора типа в UI больше нет. При [kMaxAttachmentsPerKind] уже загруженных
/// вложениях своего вида кнопка неактивна с подсказкой (бэкенд авторитетен, клиент
/// лишь зеркалит лимит). После успешной загрузки инвалидируем [screensProvider] —
/// список/превью и доступность кнопок пересчитываются, presigned-url переразрешаются.
class _AttachmentSection extends ConsumerStatefulWidget {
  const _AttachmentSection({
    required this.title,
    required this.emptyLabel,
    required this.uploadLabel,
    required this.uploadType,
    required this.screenId,
    required this.attachments,
    required this.onExpired,
  });

  final String title;
  final String emptyLabel;
  final String uploadLabel;
  final AttachmentType uploadType;
  final String screenId;
  final List<Attachment> attachments;
  final VoidCallback onExpired;

  @override
  ConsumerState<_AttachmentSection> createState() => _AttachmentSectionState();
}

class _AttachmentSectionState extends ConsumerState<_AttachmentSection> {
  bool _isUploading = false;

  /// Лимит вида достигнут: считаем свои (уже отфильтрованные) вложения. Для
  /// «Документы / Договор» это contract + other вместе — как их считает бэкенд.
  bool get _atCap => widget.attachments.length >= kMaxAttachmentsPerKind;

  /// Выбор файла (с байтами — на Web `path` пустой) и загрузка с фиксированным
  /// [uploadType]. Фото → только изображения, документ → любой файл.
  Future<void> _pickAndUpload() async {
    if (_atCap || _isUploading) return;

    final result = await FilePicker.platform.pickFiles(
      type: widget.uploadType == AttachmentType.photo ? FileType.image : FileType.any,
      withData: true, // Web: нужны bytes, т.к. path пустой
    );
    if (result == null || result.files.isEmpty) return;
    final picked = result.files.first;
    final bytes = picked.bytes;
    if (bytes == null) return;

    setState(() => _isUploading = true);

    final uploadResult = await ref.read(uploadAttachmentUseCaseProvider).call(
          screenId: widget.screenId,
          attachmentType: widget.uploadType,
          fileBytes: bytes,
          filename: picked.name,
        );
    if (!mounted) return;

    uploadResult.when(
      onSuccess: (_) {
        // Рефетч детали экрана: превью обновятся, presigned-url переразрешатся,
        // кнопки пересчитают доступность по новому счётчику.
        ref.invalidate(screensProvider);
        setState(() => _isUploading = false);
      },
      onFailure: (failure) {
        setState(() => _isUploading = false);
        // 409 ATTACHMENT_LIMIT_EXCEEDED → AttachmentLimitFailure (страховка на
        // гонку/рассинхрон); прочие ошибки → общий текст.
        final msg = failure is AttachmentLimitFailure
            ? failure.message
            : 'Не удалось загрузить файл';
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // RBAC: загрузка вложений — admin only; для не-admin кнопку не строим
    // (превью/зум/«Открыть» ниже остаются всем).
    final isAdmin = ref.watch(isAdminProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(widget.title, style: Theme.of(context).textTheme.titleMedium),
            ),
            if (isAdmin) ...[
              const SizedBox(width: 12),
              _UploadAttachmentButton(
                label: widget.uploadLabel,
                atCap: _atCap,
                isUploading: _isUploading,
                onPressed: _pickAndUpload,
              ),
            ],
          ],
        ),
        const SizedBox(height: 8),
        if (widget.attachments.isEmpty)
          Text(widget.emptyLabel, style: Theme.of(context).textTheme.bodySmall)
        else
          for (final att in widget.attachments) ...[
            _DeletableAttachment(
              screenId: widget.screenId,
              attachment: att,
              onExpired: widget.onExpired,
            ),
            const SizedBox(height: 8),
          ],
      ],
    );
  }
}

/// Инлайн-кнопка загрузки в строке заголовка секции. Тап-таргет ≥ 48px (правило
/// UI). Неактивна на лимите (подсказка почему) и на время самой загрузки.
class _UploadAttachmentButton extends StatelessWidget {
  const _UploadAttachmentButton({
    required this.label,
    required this.atCap,
    required this.isUploading,
    required this.onPressed,
  });

  final String label;
  final bool atCap;
  final bool isUploading;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final enabled = !atCap && !isUploading;
    return Tooltip(
      message: atCap
          ? 'Достигнут лимит: максимум $kMaxAttachmentsPerKind'
          : label,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 48), // тап-таргет ≥ 48px
        child: OutlinedButton.icon(
          onPressed: enabled ? onPressed : null,
          icon: isUploading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.upload_file, size: 16),
          label: Text(label),
        ),
      ),
    );
  }
}

/// Вложение с превью и контролом удаления (FR-3.12/3.13).
///
/// Оборачивает превью (фото/документ) и накладывает кнопку удаления сверху.
/// На время запроса показывает индикатор и блокирует кнопку. Успех → инвалидация
/// списка экранов: карточка исчезнет сама, а presigned-ссылки остальных
/// вложений переосвежатся при рефетче. Ошибка → snackbar, элемент остаётся.
class _DeletableAttachment extends ConsumerStatefulWidget {
  const _DeletableAttachment({
    required this.screenId,
    required this.attachment,
    required this.onExpired,
  });

  final String screenId;
  final Attachment attachment;
  final VoidCallback onExpired;

  @override
  ConsumerState<_DeletableAttachment> createState() => _DeletableAttachmentState();
}

class _DeletableAttachmentState extends ConsumerState<_DeletableAttachment> {
  bool _isDeleting = false;

  Future<void> _confirmDelete() async {
    // Диалог по центру для действия (правило UI: центральные диалоги для действий).
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Удалить вложение'),
        content: const Text('Удалить это вложение?'),
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

    setState(() => _isDeleting = true);

    final result = await ref.read(deleteAttachmentUseCaseProvider).call(
          screenId: widget.screenId,
          attachmentId: widget.attachment.id!,
        );
    if (!mounted) return;

    result.when(
      // Не снимаем _isDeleting: рефетч уберёт этот элемент из списка, кнопка
      // остаётся заблокированной до перерисовки — без мигания «удалено/не удалено».
      onSuccess: (_) => ref.invalidate(screensProvider),
      onFailure: (failure) {
        setState(() => _isDeleting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Не удалось удалить: ${failure.message}')),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final att = widget.attachment;
    final preview = att.type == AttachmentType.photo
        ? AttachmentPhotoPreview(attachment: att, onExpired: widget.onExpired)
        : AttachmentDocumentTile(attachment: att, onExpired: widget.onExpired);

    // Без id удалить нечего (бэк почти всегда его присылает) — скрываем кнопку.
    if (att.id == null) return preview;

    // RBAC: удаление вложений — admin only; для не-admin показываем только превью
    // (просмотр/зум/«Открыть» доступны всем).
    if (!ref.watch(isAdminProvider)) return preview;

    final deleteButton = _DeleteAttachmentButton(
      isDeleting: _isDeleting,
      onPressed: _confirmDelete,
    );

    // Изображение (фото/скан) — высокое превью: кнопку накладываем в угол.
    // PDF/прочее — карточка-строка со своей кнопкой «Открыть» справа: ставим
    // удаление рядом, чтобы не перекрывать «Открыть».
    if (att.isImage) {
      return Stack(
        children: [
          preview,
          Positioned(top: 4, right: 4, child: deleteButton),
        ],
      );
    }
    return Row(
      children: [
        Expanded(child: preview),
        deleteButton,
      ],
    );
  }
}

/// Круглая кнопка удаления поверх превью. Тап-таргет 48px (правило UI). На время
/// запроса — индикатор вместо иконки, кнопка заблокирована.
class _DeleteAttachmentButton extends StatelessWidget {
  const _DeleteAttachmentButton({required this.isDeleting, required this.onPressed});

  final bool isDeleting;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      shape: const CircleBorder(),
      elevation: 2,
      child: SizedBox(
        width: 48,
        height: 48,
        child: isDeleting
            ? const Padding(
                padding: EdgeInsets.all(14),
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : IconButton(
                tooltip: 'Удалить вложение',
                icon: const Icon(Icons.delete_outline, color: AppColors.danger),
                onPressed: onPressed,
              ),
      ),
    );
  }
}

class _ActionsRow extends StatelessWidget {
  const _ActionsRow({required this.screen});

  final Screen screen;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        OutlinedButton.icon(
          onPressed: () {
            Navigator.of(context).pop(); // закрываем карточку, чтобы не мешала диалогу
            ScreenFormDialog.show(context, existing: screen);
          },
          icon: const Icon(Icons.edit_outlined, size: 16),
          label: const Text('Редактировать'),
        ),
        // Активация доступна независимо от текущего статуса — можно и продлить
        // договор уже активного экрана новым периодом (бэк это не запрещает).
        FilledButton.tonalIcon(
          onPressed: () {
            Navigator.of(context).pop();
            ActivateScreenDialog.show(context, screenId: screen.id);
          },
          icon: const Icon(Icons.check_circle_outline, size: 16),
          label: Text(screen.status == ScreenStatus.active ? 'Продлить договор' : 'Активировать'),
        ),
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 150,
            child: Text(label, style: Theme.of(context).textTheme.bodySmall),
          ),
          Expanded(
            child: Text(value, style: Theme.of(context).textTheme.bodyMedium),
          ),
        ],
      ),
    );
  }
}
