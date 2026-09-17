import 'package:dio/dio.dart';

import '../../../../core/constants/api_constants.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../shared/domain/attachment_type.dart';
import '../../../../shared/domain/screen_status.dart';
import '../../domain/entities/screen_filters.dart';
import '../models/cost_summary_dto.dart';
import '../models/screen_dto.dart';

/// Удалённый источник данных экранов: список (с фильтрами), расчёт стоимости,
/// выгрузка в Excel.
class ScreensRemoteDataSource {
  const ScreensRemoteDataSource(this._dio);

  final Dio _dio;

  /// Возвращает список экранов с учётом фильтров (FR-5). Бросает [ApiException].
  Future<List<ScreenDto>> getScreens({ScreenFilters filters = const ScreenFilters.empty()}) async {
    try {
      final response = await _dio.get<List<dynamic>>(
        ApiConstants.screens,
        queryParameters: _filtersToQuery(filters),
      );
      return response.data!
          .map((e) => ScreenDto.fromJson(e as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  /// Считает стоимость выбранных экранов (FR-6). Бросает [ApiException].
  Future<CostSummaryDto> getCostSummary(List<String> screenIds) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        ApiConstants.costSummary,
        data: {'screen_ids': screenIds},
      );
      return CostSummaryDto.fromJson(response.data!);
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  /// Выгружает .xlsx и возвращает его байты (FR-7). Бросает [ApiException].
  ///
  /// [screenIds] — если непустой, выгружаются именно эти экраны (FR-7.4) и
  /// [filters] игнорируются сервером (см. `export_screens.py` на бэке).
  Future<List<int>> exportScreens({
    List<String> screenIds = const [],
    ScreenFilters filters = const ScreenFilters.empty(),
  }) async {
    try {
      final query = _filtersToQuery(filters);
      if (screenIds.isNotEmpty) {
        query['screen_ids'] = screenIds;
      }
      final response = await _dio.get<List<int>>(
        ApiConstants.export,
        queryParameters: query,
        options: Options(responseType: ResponseType.bytes),
      );
      return response.data!;
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  /// Создаёт новый экран (FR-10.1). Бросает [ApiException].
  Future<ScreenDto> createScreen({
    required String name,
    required int cityId,
    required String size,
    required int screenTypeId,
    required double latitude,
    required double longitude,
    required ScreenStatus status,
    String? landlordId,
    String? contactId,
    required List<String> campaignIds,
    required String comment,
    DateTime? rentalEndDate,
  }) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        ApiConstants.screens,
        data: {
          'name': name,
          'city_id': cityId,
          // snake_case — как весь бэкенд (camelCase бэк видит пропущенным → 422).
          'size': size,
          'screen_type_id': screenTypeId,
          'latitude': latitude,
          'longitude': longitude,
          'status': status.value,
          if (landlordId != null) 'landlord_id': landlordId,
          if (contactId != null) 'contact_id': contactId,
          'campaign_ids': campaignIds,
          'comment': comment,
          // Срок аренды (FR-4.4): только дата `YYYY-MM-DD`, без времени/таймзоны.
          if (rentalEndDate != null) 'rental_end_date': _formatIsoDate(rentalEndDate),
        },
      );
      return ScreenDto.fromJson(response.data!);
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  /// Частично обновляет экран (FR-10.2). Бросает [ApiException].
  Future<ScreenDto> updateScreen({
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
      final response = await _dio.patch<Map<String, dynamic>>(
        '${ApiConstants.screens}/$id',
        data: {
          if (name != null) 'name': name,
          if (cityId != null) 'city_id': cityId,
          // snake_case — как весь бэкенд (camelCase бэк видит пропущенным → 422).
          if (size != null) 'size': size,
          if (screenTypeId != null) 'screen_type_id': screenTypeId,
          if (latitude != null) 'latitude': latitude,
          if (longitude != null) 'longitude': longitude,
          if (status != null) 'status': status.value,
          if (landlordId != null) 'landlord_id': landlordId,
          if (contactId != null) 'contact_id': contactId,
          if (campaignIds != null) 'campaign_ids': campaignIds,
          if (comment != null) 'comment': comment,
          // Срок аренды (FR-4.4): дата `YYYY-MM-DD`, либо явный null при очистке
          // (снять срок). Без обоих — поле не трогаем (частичный PATCH).
          if (rentalEndDate != null) 'rental_end_date': _formatIsoDate(rentalEndDate),
          if (clearRentalEndDate) 'rental_end_date': null,
        },
      );
      return ScreenDto.fromJson(response.data!);
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  /// Меняет только координаты экрана (FR-3.3): `PATCH /api/screens/{id}/location`.
  ///
  /// Локация задаётся жестом на карте (центр-пин), поэтому тело — ровно `lng`/`lat`
  /// в WGS84. Идёт через `dio` с JWT-интерсептором, как остальные `/api/screens/*`.
  /// Бросает [ApiException] (в т.ч. 404 — репозиторий трактует его как «экран удалён»).
  Future<ScreenDto> patchLocation(String screenId, {required double lng, required double lat}) async {
    try {
      final response = await _dio.patch<Map<String, dynamic>>(
        '${ApiConstants.screens}/$screenId/location',
        data: {'lng': lng, 'lat': lat},
      );
      return ScreenDto.fromJson(response.data!);
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  /// Активирует экран (FR-4). Бросает [ApiException] (в т.ч. 409 при нарушении
  /// правила FR-4.2 — нет арендодателя/договора/фото).
  Future<ScreenDto> activateScreen({
    required String id,
    required double rentPrice,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '${ApiConstants.screens}/$id/activate',
        data: {
          'rent_price': rentPrice,
          'start_date': _formatIsoDate(startDate),
          'end_date': _formatIsoDate(endDate),
          'currency': 'KGS',
        },
      );
      return ScreenDto.fromJson(response.data!);
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  /// Загружает файл и прикрепляет к экрану (FR-3.12/3.13). Бросает [ApiException].
  ///
  /// Multipart-форма: `attachment_type` (строка) + `file` (байты). Так же, как
  /// ждёт бэк (`upload_attachment` в `features/screens/presentation/router.py`).
  Future<ScreenDto> uploadAttachment({
    required String screenId,
    required AttachmentType attachmentType,
    required List<int> fileBytes,
    required String filename,
  }) async {
    try {
      final formData = FormData.fromMap({
        'attachment_type': attachmentType.value,
        'file': MultipartFile.fromBytes(fileBytes, filename: filename),
      });
      final response = await _dio.post<Map<String, dynamic>>(
        '${ApiConstants.screens}/$screenId/attachments',
        data: formData,
      );
      return ScreenDto.fromJson(response.data!);
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  /// Удаляет вложение экрана (`DELETE /api/screens/{screenId}/attachments/{id}`).
  ///
  /// Обычный авторизованный вызов через `dio` с JWT — в отличие от GET медиа,
  /// который бьёт по presigned URL напрямую в обход dio. Успех — `204 No Content`.
  /// Бросает [ApiException] (в т.ч. 404 — репозиторий трактует его как успех).
  Future<void> deleteAttachment({
    required String screenId,
    required String attachmentId,
  }) async {
    try {
      await _dio.delete<void>(
        '${ApiConstants.screens}/$screenId/attachments/$attachmentId',
      );
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  /// Удаляет экран (`DELETE /api/screens/{id}`). Бросает [ApiException].
  Future<void> deleteScreen(String id) async {
    try {
      await _dio.delete<void>('${ApiConstants.screens}/$id');
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  /// Переводит доменные фильтры в query-параметры бэка (имена — как в
  /// `GET /api/screens`: `landlord_id`, `status_filter`, `city_id`, `campaign_id`,
  /// `contract_end_before` в формате `YYYY-MM-DD`). Строковый `city` больше не
  /// отправляется — бэк перешёл на `city_id` (CONTRACT PATCH v2).
  Map<String, dynamic> _filtersToQuery(ScreenFilters filters) {
    final query = <String, dynamic>{};
    if (filters.landlordId != null) query['landlord_id'] = filters.landlordId;
    if (filters.status != null) query['status_filter'] = filters.status!.value;
    if (filters.cityId != null) query['city_id'] = filters.cityId;
    // snake_case `screen_type_id` — как весь бэкенд (см. форму экрана).
    if (filters.screenTypeId != null) query['screen_type_id'] = filters.screenTypeId;
    if (filters.campaignId != null) query['campaign_id'] = filters.campaignId;
    if (filters.contractEndBefore != null) {
      query['contract_end_before'] = _formatIsoDate(filters.contractEndBefore!);
    }
    return query;
  }

  /// `YYYY-MM-DD` без intl — то, что ждёт FastAPI для параметра типа `date`.
  String _formatIsoDate(DateTime date) {
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '${date.year}-$month-$day';
  }
}
