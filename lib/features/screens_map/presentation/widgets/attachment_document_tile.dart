import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/theme/app_colors.dart';
import '../../domain/entities/attachment.dart';
import 'attachment_photo_preview.dart';

/// Плитка вложения-документа (договор/прочее, FR-3.12/3.13).
///
/// Скан-изображение ведёт себя как фото → рендерим [AttachmentPhotoPreview]
/// (инлайн + зум). PDF/прочее → карточка «Открыть», которая открывает файл во
/// внешнем вьювере устройства/новой вкладке через `url_launcher` напрямую по
/// presigned-ссылке (без dio-интерцептора, JWT не нужен).
class AttachmentDocumentTile extends StatelessWidget {
  const AttachmentDocumentTile({
    required this.attachment,
    this.onExpired,
    super.key,
  });

  final Attachment attachment;

  /// Вызывается, когда ссылка не открылась/не загрузилась (вероятно, протухла).
  final VoidCallback? onExpired;

  @override
  Widget build(BuildContext context) {
    // Документ-скан — это картинка: показываем так же, как фото.
    if (attachment.isImage) {
      return AttachmentPhotoPreview(attachment: attachment, onExpired: onExpired);
    }
    return _DocumentCard(attachment: attachment, onExpired: onExpired);
  }
}

class _DocumentCard extends StatelessWidget {
  const _DocumentCard({required this.attachment, this.onExpired});

  final Attachment attachment;
  final VoidCallback? onExpired;

  Future<void> _open() async {
    final ok = await launchUrl(
      Uri.parse(attachment.fileUrl),
      mode: LaunchMode.externalApplication,
    );
    if (!ok) onExpired?.call(); // не открылось -> обновить экран за свежей ссылкой
  }

  @override
  Widget build(BuildContext context) {
    final icon = attachment.isPdf ? Icons.picture_as_pdf_outlined : Icons.insert_drive_file_outlined;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppColors.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  attachment.displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                Text(
                  attachment.humanSize == null
                      ? attachment.type.label
                      : '${attachment.type.label} · ${attachment.humanSize}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // Тап-таргет ≥ 48px (правило UI для мобильных).
          ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 48),
            child: FilledButton.tonalIcon(
              onPressed: _open,
              icon: const Icon(Icons.open_in_new, size: 16),
              label: const Text('Открыть'),
            ),
          ),
        ],
      ),
    );
  }
}
