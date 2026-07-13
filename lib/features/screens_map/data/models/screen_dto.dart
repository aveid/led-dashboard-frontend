import '../../../../features/cities/data/models/city_model.dart';
import '../../../../features/cities/domain/entities/city.dart';
import '../../../../features/screen_types/data/models/screen_type_model.dart';
import '../../../../features/screen_types/domain/entities/screen_type.dart';
import '../../../../shared/domain/screen_status.dart';
import '../../domain/entities/screen.dart';
import 'attachment_dto.dart';
import 'money_dto.dart';
import 'rental_contract_dto.dart';

/// DTO экрана (зеркалит `ScreenRead` на бэке — `features/screens/presentation/schemas.py`).
///
/// Без кодогена: `fromJson` написан вручную по точной схеме бэкенда. Если схема
/// на бэке изменится — этот файл нужно обновить синхронно (см. `backend/CONTEXT.md` §5).
class ScreenDto {
  const ScreenDto({
    required this.id,
    required this.name,
    required this.city,
    required this.latitude,
    required this.longitude,
    required this.status,
    required this.campaignIds,
    required this.monthlyPrice,
    required this.rentals,
    required this.attachments,
    required this.comment,
    this.size = '',
    this.screenType,
    this.landlordId,
    this.contactId,
    this.currentCampaignId,
    this.rentalEndDate,
  });

  final String id;
  final String name;
  final City city;

  /// Размер экрана (`size`). У старых экранов после миграции — пустая строка.
  final String size;

  /// Тип экрана (`screen_type` в ответе). Парсим защитно (может быть `null`),
  /// хотя по контракту после миграции присутствует всегда.
  final ScreenType? screenType;
  final double latitude;
  final double longitude;
  final String status;
  final String? landlordId;
  final String? contactId;
  final List<String> campaignIds;
  final String? currentCampaignId;
  final MoneyDto monthlyPrice;
  final List<RentalContractDto> rentals;
  final List<AttachmentDto> attachments;
  final String comment;

  /// `rental_end_date` — дата окончания аренды (FR-4.4), `YYYY-MM-DD` без времени.
  /// Может отсутствовать или быть `null` — парсим защитно.
  final DateTime? rentalEndDate;

  factory ScreenDto.fromJson(Map<String, dynamic> json) {
    return ScreenDto(
      id: json['id'] as String,
      name: json['name'] as String,
      city: CityModel.fromJson(json['city'] as Map<String, dynamic>),
      size: json['size'] as String? ?? '',
      screenType: json['screen_type'] is Map<String, dynamic>
          ? ScreenTypeModel.fromJson(json['screen_type'] as Map<String, dynamic>)
          : null,
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      status: json['status'] as String,
      landlordId: json['landlord_id'] as String?,
      contactId: json['contact_id'] as String?,
      campaignIds: (json['campaign_ids'] as List<dynamic>? ?? [])
          .map((e) => e as String)
          .toList(),
      currentCampaignId: json['current_campaign_id'] as String?,
      monthlyPrice: MoneyDto.fromJson(json['monthly_price'] as Map<String, dynamic>),
      rentals: (json['rentals'] as List<dynamic>? ?? [])
          .map((e) => RentalContractDto.fromJson(e as Map<String, dynamic>))
          .toList(),
      attachments: (json['attachments'] as List<dynamic>? ?? [])
          .map((e) => AttachmentDto.fromJson(e as Map<String, dynamic>))
          .toList(),
      comment: json['comment'] as String? ?? '',
      // Защитный парсинг: поле может отсутствовать/быть null (контракт snake_case).
      rentalEndDate: json['rental_end_date'] == null
          ? null
          : DateTime.tryParse(json['rental_end_date'] as String),
    );
  }

  Screen toDomain() => Screen(
        id: id,
        name: name,
        city: city,
        size: size,
        screenType: screenType,
        latitude: latitude,
        longitude: longitude,
        status: ScreenStatus.fromValue(status),
        landlordId: landlordId,
        contactId: contactId,
        campaignIds: campaignIds,
        currentCampaignId: currentCampaignId,
        monthlyPrice: monthlyPrice.toDomain(),
        rentals: rentals.map((e) => e.toDomain()).toList(),
        attachments: attachments.map((e) => e.toDomain()).toList(),
        comment: comment,
        rentalEndDate: rentalEndDate,
      );
}
