import '../../../../shared/domain/attachment_type.dart';

/// Вложение экрана: фото, договор или документ (FR-3.12/3.13).
class Attachment {
  const Attachment({
    required this.type,
    required this.fileUrl,
    this.id,
    this.filename = '',
    this.contentType = '',
    this.sizeBytes = 0,
    this.uploadedAt,
  });

  final String? id;
  final AttachmentType type;
  final String fileUrl;
  final String filename;
  final String contentType; // MIME с бэка (может быть application/octet-stream)
  final int sizeBytes;
  final DateTime? uploadedAt;

  /// Расширение файла: из имени, если оно есть, иначе из пути presigned-ссылки
  /// (без учёта query-строки подписи).
  String get _extension {
    final source = filename.isNotEmpty
        ? filename
        : (Uri.tryParse(fileUrl)?.path ?? fileUrl);
    final dot = source.lastIndexOf('.');
    return dot == -1 ? '' : source.substring(dot + 1).toLowerCase();
  }

  /// Является ли вложение изображением. Судим по типу вложения, MIME и
  /// расширению — бэк нередко отдаёт `application/octet-stream`, поэтому
  /// расширение из ссылки остаётся надёжным фоллбэком (скан договора/документа
  /// ведёт себя как фото).
  bool get isImage =>
      type == AttachmentType.photo ||
      contentType.startsWith('image/') ||
      const {'jpg', 'jpeg', 'png', 'gif', 'webp', 'bmp', 'heic'}.contains(_extension);

  /// PDF-документ — открывается во внешнем вьювере, инлайн не рендерится.
  bool get isPdf => contentType == 'application/pdf' || _extension == 'pdf';

  /// Имя файла для карточки документа: `filename` с бэка, иначе последний
  /// сегмент пути presigned-ссылки.
  String get displayName {
    if (filename.isNotEmpty) return filename;
    final path = Uri.tryParse(fileUrl)?.path ?? fileUrl;
    final segments = path.split('/').where((s) => s.isNotEmpty);
    if (segments.isEmpty) return type.label;
    return Uri.decodeComponent(segments.last);
  }

  /// Человекочитаемый размер (`X.Y MB`) или null, если бэк не прислал размер.
  String? get humanSize =>
      sizeBytes <= 0 ? null : '${(sizeBytes / 1048576).toStringAsFixed(1)} MB';
}
