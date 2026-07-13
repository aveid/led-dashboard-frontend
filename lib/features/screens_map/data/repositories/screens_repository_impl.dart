import '../../../../core/error/failure.dart';
import '../../../../core/error/result.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../shared/domain/attachment_type.dart';
import '../../../../shared/domain/screen_status.dart';
import '../../domain/attachment_policy.dart';
import '../../domain/entities/cost_summary.dart';
import '../../domain/entities/screen.dart';
import '../../domain/entities/screen_filters.dart';
import '../../domain/repositories/screens_repository.dart';
import '../datasources/screens_remote_ds.dart';

/// Реализация [ScreensRepository]: датасорс → доменные сущности, ошибки → [Failure].
class ScreensRepositoryImpl implements ScreensRepository {
  const ScreensRepositoryImpl(this._remote);

  final ScreensRemoteDataSource _remote;

  @override
  Future<Result<List<Screen>>> getScreens({
    ScreenFilters filters = const ScreenFilters.empty(),
  }) async {
    try {
      final dtos = await _remote.getScreens(filters: filters);
      return Result.success(dtos.map((dto) => dto.toDomain()).toList());
    } on ApiException catch (e) {
      return Result.failure(e.toFailure());
    }
  }

  @override
  Future<Result<CostSummary>> getCostSummary(List<String> screenIds) async {
    try {
      final dto = await _remote.getCostSummary(screenIds);
      return Result.success(dto.toDomain());
    } on ApiException catch (e) {
      return Result.failure(e.toFailure());
    }
  }

  @override
  Future<Result<List<int>>> exportScreens({
    List<String> screenIds = const [],
    ScreenFilters filters = const ScreenFilters.empty(),
  }) async {
    try {
      final bytes = await _remote.exportScreens(screenIds: screenIds, filters: filters);
      return Result.success(bytes);
    } on ApiException catch (e) {
      return Result.failure(e.toFailure());
    }
  }

  @override
  Future<Result<Screen>> createScreen({
    required String name,
    required int cityId,
    required String size,
    required int screenTypeId,
    required double latitude,
    required double longitude,
    ScreenStatus status = ScreenStatus.potential,
    String? landlordId,
    String? contactId,
    List<String> campaignIds = const [],
    String comment = '',
    DateTime? rentalEndDate,
  }) async {
    try {
      final dto = await _remote.createScreen(
        name: name,
        cityId: cityId,
        size: size,
        screenTypeId: screenTypeId,
        latitude: latitude,
        longitude: longitude,
        status: status,
        landlordId: landlordId,
        contactId: contactId,
        campaignIds: campaignIds,
        comment: comment,
        rentalEndDate: rentalEndDate,
      );
      return Result.success(dto.toDomain());
    } on ApiException catch (e) {
      return Result.failure(e.toFailure());
    }
  }

  @override
  Future<Result<Screen>> updateScreen({
    required String id,
    String? name,
    int? cityId,
    String? size,
    int? screenTypeId,
    double? latitude,
    double? longitude,
    ScreenStatus? status,
    String? landlordId,
    String? contactId,
    List<String>? campaignIds,
    String? comment,
    DateTime? rentalEndDate,
    bool clearRentalEndDate = false,
  }) async {
    try {
      final dto = await _remote.updateScreen(
        id: id,
        name: name,
        cityId: cityId,
        size: size,
        screenTypeId: screenTypeId,
        latitude: latitude,
        longitude: longitude,
        status: status,
        landlordId: landlordId,
        contactId: contactId,
        campaignIds: campaignIds,
        comment: comment,
        rentalEndDate: rentalEndDate,
        clearRentalEndDate: clearRentalEndDate,
      );
      return Result.success(dto.toDomain());
    } on ApiException catch (e) {
      return Result.failure(e.toFailure());
    }
  }

  @override
  Future<Result<Screen>> moveScreenLocation(String id, {required double lng, required double lat}) async {
    try {
      final dto = await _remote.patchLocation(id, lng: lng, lat: lat);
      return Result.success(dto.toDomain());
    } on ApiException catch (e) {
      // 404 → NotFoundFailure (см. ApiException.toFailure) — UI трактует как
      // «экран удалён»: мягкий snackbar + refetch, без краша (контракт FR-3.3).
      return Result.failure(e.toFailure());
    }
  }

  @override
  Future<Result<Screen>> activateScreen({
    required String id,
    required double rentPrice,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    try {
      final dto = await _remote.activateScreen(
        id: id,
        rentPrice: rentPrice,
        startDate: startDate,
        endDate: endDate,
      );
      return Result.success(dto.toDomain());
    } on ApiException catch (e) {
      return Result.failure(e.toFailure());
    }
  }

  @override
  Future<Result<Screen>> uploadAttachment({
    required String screenId,
    required AttachmentType attachmentType,
    required List<int> fileBytes,
    required String filename,
  }) async {
    try {
      final dto = await _remote.uploadAttachment(
        screenId: screenId,
        attachmentType: attachmentType,
        fileBytes: fileBytes,
        filename: filename,
      );
      return Result.success(dto.toDomain());
    } on ApiException catch (e) {
      // 409 при загрузке = переполнен лимит вида (фото/документ) → отдельный
      // Failure, чтобы UI показал понятный «лимитный» snackbar. Клиент знает,
      // что грузил, поэтому вид берём из attachmentType (не парсим detail.kind).
      if (e.statusCode == 409) {
        return Result.failure(_limitFailure(attachmentType));
      }
      return Result.failure(e.toFailure());
    }
  }

  @override
  Future<Result<void>> deleteAttachment({
    required String screenId,
    required String attachmentId,
  }) async {
    try {
      await _remote.deleteAttachment(screenId: screenId, attachmentId: attachmentId);
      return const Result.success(null);
    } on ApiException catch (e) {
      // 404 = вложение уже удалено/не найдено → трактуем как успех, чтобы UI
      // спокойно обновил список (контракт API).
      if (e.statusCode == 404) return const Result.success(null);
      return Result.failure(e.toFailure());
    }
  }

  /// Сообщение лимита с учётом вида: фото vs документ (contract/other).
  Failure _limitFailure(AttachmentType type) {
    final isPhoto = type == AttachmentType.photo;
    return AttachmentLimitFailure(
      type,
      'Достигнут лимит: максимум $kMaxAttachmentsPerKind ${isPhoto ? 'фото' : 'документов'}.',
    );
  }
}
