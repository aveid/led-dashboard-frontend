import '../../../../core/error/result.dart';
import '../repositories/screens_repository.dart';

/// Сценарий «Удалить вложение экрана» (FR-3.12/3.13).
///
/// Тонкая обёртка над репозиторием: 404 (уже удалено) там уже трактуется как
/// успех, поэтому UI получает `Result.success` и просто рефетчит список.
class DeleteAttachmentUseCase {
  const DeleteAttachmentUseCase(this._repository);

  final ScreensRepository _repository;

  Future<Result<void>> call({
    required String screenId,
    required String attachmentId,
  }) {
    return _repository.deleteAttachment(
      screenId: screenId,
      attachmentId: attachmentId,
    );
  }
}
