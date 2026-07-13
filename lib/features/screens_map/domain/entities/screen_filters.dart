import '../../../../shared/domain/screen_status.dart';

/// Фильтры списка экранов (FR-5). Поля соответствуют query-параметрам
/// `GET /api/screens` на бэке: `landlord_id`, `status_filter`, `city_id`,
/// `campaign_id`, `contract_end_before`.
///
/// Иммутабельный value object без кодогена — сравнение по значению нужно,
/// чтобы Riverpod корректно понимал, что фильтры изменились (и перезапрашивал
/// список), только когда реально что-то поменялось.
class ScreenFilters {
  const ScreenFilters({
    this.landlordId,
    this.status,
    this.cityId,
    this.screenTypeId,
    this.campaignId,
    this.contractEndBefore,
  });

  /// Пустые фильтры — эквивалент «показать все экраны».
  const ScreenFilters.empty()
      : landlordId = null,
        status = null,
        cityId = null,
        screenTypeId = null,
        campaignId = null,
        contractEndBefore = null;

  final String? landlordId;
  final ScreenStatus? status;

  /// Идентификатор города (справочник `cities`). Бэк перешёл на `city_id` —
  /// свободный текст в фильтре больше не поддерживается (CONTRACT PATCH v2).
  final int? cityId;

  /// Идентификатор типа экрана (справочник `screen-types`). В query уходит как
  /// `screen_type_id`; без него — все типы.
  final int? screenTypeId;
  final String? campaignId;
  final DateTime? contractEndBefore;

  /// Есть ли хоть один активный фильтр (для бейджа «N фильтров» в UI).
  bool get isEmpty =>
      landlordId == null &&
      status == null &&
      cityId == null &&
      screenTypeId == null &&
      campaignId == null &&
      contractEndBefore == null;

  int get activeCount => [
        landlordId,
        status,
        cityId,
        screenTypeId,
        campaignId,
        contractEndBefore,
      ].where((v) => v != null).length;

  ScreenFilters copyWith({
    String? landlordId,
    bool clearLandlordId = false,
    ScreenStatus? status,
    bool clearStatus = false,
    int? cityId,
    bool clearCityId = false,
    int? screenTypeId,
    bool clearScreenTypeId = false,
    String? campaignId,
    bool clearCampaignId = false,
    DateTime? contractEndBefore,
    bool clearContractEndBefore = false,
  }) {
    return ScreenFilters(
      landlordId: clearLandlordId ? null : (landlordId ?? this.landlordId),
      status: clearStatus ? null : (status ?? this.status),
      cityId: clearCityId ? null : (cityId ?? this.cityId),
      screenTypeId: clearScreenTypeId ? null : (screenTypeId ?? this.screenTypeId),
      campaignId: clearCampaignId ? null : (campaignId ?? this.campaignId),
      contractEndBefore:
          clearContractEndBefore ? null : (contractEndBefore ?? this.contractEndBefore),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is ScreenFilters &&
      other.landlordId == landlordId &&
      other.status == status &&
      other.cityId == cityId &&
      other.screenTypeId == screenTypeId &&
      other.campaignId == campaignId &&
      other.contractEndBefore == contractEndBefore;

  @override
  int get hashCode =>
      Object.hash(landlordId, status, cityId, screenTypeId, campaignId, contractEndBefore);
}
