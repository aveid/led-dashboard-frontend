import '../../../../shared/domain/attachment_type.dart';
import '../../domain/entities/attachment.dart';

/// DTO вложения (зеркалит `AttachmentRead` на бэке).
///
/// Схема бэка: `{id, type, filename, content_type, size_bytes, url, uploaded_at}`.
/// Ссылка приходит в поле `url` уже presigned (не `file_url`).
class AttachmentDto {
  const AttachmentDto({
    required this.type,
    required this.url,
    this.id,
    this.filename = '',
    this.contentType = '',
    this.sizeBytes = 0,
    this.uploadedAt,
  });

  final String? id;
  final String type;
  final String filename;
  final String contentType;
  final int sizeBytes;
  final String url;
  final DateTime? uploadedAt;

  factory AttachmentDto.fromJson(Map<String, dynamic> json) {
    return AttachmentDto(
      id: json['id'] as String?,
      type: json['type'] as String,
      filename: json['filename'] as String? ?? '',
      contentType: json['content_type'] as String? ?? '',
      sizeBytes: (json['size_bytes'] as num?)?.toInt() ?? 0,
      url: json['url'] as String,
      uploadedAt: json['uploaded_at'] == null
          ? null
          : DateTime.parse(json['uploaded_at'] as String),
    );
  }

  Attachment toDomain() => Attachment(
        id: id,
        type: AttachmentType.fromValue(type),
        fileUrl: url,
        filename: filename,
        contentType: contentType,
        sizeBytes: sizeBytes,
        uploadedAt: uploadedAt,
      );
}
