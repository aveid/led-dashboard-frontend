import '../../../../core/error/result.dart';
import '../../../../shared/domain/attachment_type.dart';
import '../../../../shared/domain/screen_status.dart';
import '../entities/cost_summary.dart';
import '../entities/screen.dart';
import '../entities/screen_filters.dart';

/// Порт (интерфейс) репозитория экранов.
abstract interface class ScreensRepository {
  /// Возвращает экраны с учётом фильтров (FR-5). Пустые фильтры — все экраны.
  Future<Result<List<Screen>>> getScreens({ScreenFilters filters = const ScreenFilters.empty()});

  /// Считает стоимость выбранных экранов (FR-6): количество, итог, разбивка по
  /// арендодателям.
  Future<Result<CostSummary>> getCostSummary(List<String> screenIds);

  /// Выгружает экраны в Excel (FR-7) и возвращает содержимое файла (.xlsx) как
  /// байты. Если [screenIds] непустой — выгружаются они (FR-7.4), иначе —
  /// [filters] (FR-7.1–7.3; пустые фильтры = все экраны).
  Future<Result<List<int>>> exportScreens({
    List<String> screenIds = const [],
    ScreenFilters filters = const ScreenFilters.empty(),
  });

  /// Создаёт новый экран (FR-10.1). Координаты приходят из точки на карте
  /// (контекстное меню «Добавить экран», FR-3.3), а не из текстовых полей.
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
  });

  /// Частично обновляет экран (FR-10.2). null-поля не меняются. Перевод в статус
  /// «активный» через этот метод запрещён на бэке — для этого [activateScreen].
  /// Локация экрана здесь НЕ редактируется — для неё есть [moveScreenLocation].
  ///
  /// Срок аренды (FR-4.4): [rentalEndDate] задаёт дату, а [clearRentalEndDate]
  /// = `true` отправляет явный `null`, чтобы снять срок (иначе поле не меняется).
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
  });

  /// Меняет только координаты экрана (FR-3.3) — `PATCH /api/screens/{id}/location`.
  /// Локация задаётся жестом «поменять локацию» на карте (центр-пин + «Сохранить»).
  /// HTTP 404 маппится в [NotFoundFailure] — UI трактует его как «экран удалён».
  Future<Result<Screen>> moveScreenLocation(String id, {required double lng, required double lat});

  /// Активирует экран, фиксируя договор аренды (FR-4). Требует, чтобы у экрана
  /// уже были арендодатель и прикреплены договор и фото (правило FR-4.2 — сервер
  /// вернёт `ConflictFailure`, если условия не выполнены).
  Future<Result<Screen>> activateScreen({
    required String id,
    required double rentPrice,
    required DateTime startDate,
    required DateTime endDate,
  });

  /// Загружает файл (фото/договор/документ) и прикрепляет к экрану (FR-3.12/3.13).
  ///
  /// При переполнении лимита (максимум `kMaxAttachmentsPerKind` на вид) бэк
  /// отвечает HTTP 409 — репозиторий маппит его в `AttachmentLimitFailure`.
  Future<Result<Screen>> uploadAttachment({
    required String screenId,
    required AttachmentType attachmentType,
    required List<int> fileBytes,
    required String filename,
  });

  /// Удаляет вложение экрана. Идёт обычным авторизованным вызовом через `dio`
  /// с JWT (в отличие от GET медиа, который бьёт по presigned URL в обход dio).
  /// HTTP 404 трактуется как успех (вложение уже удалено/не найдено).
  Future<Result<void>> deleteAttachment({
    required String screenId,
    required String attachmentId,
  });

  /// Удаляет экран целиком (`DELETE /api/screens/{id}`) — жест на карте (правый
  /// клик/долгий тап по маркеру → «Удалить экран»). Возврата экрана нет — сервер
  /// отвечает `204`, вызывающий сам инвалидирует [screensProvider] и сводку.
  Future<Result<void>> deleteScreen(String id);
}
