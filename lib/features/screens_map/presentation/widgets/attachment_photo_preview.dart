import 'package:flutter/material.dart';

import '../../domain/entities/attachment.dart';

/// Инлайн-превью фото вложения (FR-3.12/3.13) с полноэкранным зумом по тапу.
///
/// Ссылка [Attachment.fileUrl] приходит из API уже presigned и грузится напрямую
/// в [Image.network], минуя dio-интерцептор (JWT не нужен). Presigned-ссылка
/// короткоживущая: если она протухла, [Image.network] бросит ошибку загрузки —
/// тогда дёргаем [onExpired], чтобы вышестоящий слой перезапросил экран за
/// свежими ссылками (см. `ScreenCardSheet`).
class AttachmentPhotoPreview extends StatelessWidget {
  const AttachmentPhotoPreview({
    required this.attachment,
    this.onExpired,
    super.key,
  });

  final Attachment attachment;

  /// Вызывается при ошибке загрузки (вероятно, протухла presigned-ссылка).
  final VoidCallback? onExpired;

  static const double _previewHeight = 180;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _openFullScreen(context),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.network(
          attachment.fileUrl,
          height: _previewHeight,
          width: double.infinity,
          fit: BoxFit.cover,
          loadingBuilder: (context, child, progress) => progress == null
              ? child
              : const SizedBox(
                  height: _previewHeight,
                  child: Center(child: CircularProgressIndicator()),
                ),
          errorBuilder: (context, error, stack) {
            onExpired?.call(); // ссылка могла протухнуть -> обновить экран
            return const SizedBox(
              height: _previewHeight,
              child: Center(child: Icon(Icons.broken_image_outlined, size: 32)),
            );
          },
        ),
      ),
    );
  }

  /// Полноэкранный просмотр с зумом через встроенный [InteractiveViewer]
  /// (без сторонних пакетов).
  void _openFullScreen(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.black,
            foregroundColor: Colors.white,
          ),
          body: Center(
            child: InteractiveViewer(
              minScale: 1,
              maxScale: 5,
              child: Image.network(
                attachment.fileUrl,
                errorBuilder: (context, error, stack) {
                  onExpired?.call();
                  return const Icon(
                    Icons.broken_image_outlined,
                    size: 48,
                    color: Colors.white54,
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}
