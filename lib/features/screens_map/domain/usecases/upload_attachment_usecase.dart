import '../../../../core/error/failure.dart';
import '../../../../core/error/result.dart';
import '../../../../shared/domain/attachment_type.dart';
import '../entities/screen.dart';
import '../repositories/screens_repository.dart';

/// Сценарий «Прикрепить файл к экрану» (FR-3.12/3.13).
class UploadAttachmentUseCase {
  const UploadAttachmentUseCase(this._repository);

  final ScreensRepository _repository;

  Future<Result<Screen>> call({
    required String screenId,
    required AttachmentType attachmentType,
    required List<int> fileBytes,
    required String filename,
  }) {
    if (fileBytes.isEmpty) {
      return Future.value(const Result.failure(ValidationFailure('Файл пустой или не выбран.')));
    }
    return _repository.uploadAttachment(
      screenId: screenId,
      attachmentType: attachmentType,
      fileBytes: fileBytes,
      filename: filename,
    );
  }
}
