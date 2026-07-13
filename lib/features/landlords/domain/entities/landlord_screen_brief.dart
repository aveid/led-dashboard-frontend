import '../../../../features/cities/domain/entities/city.dart';
import '../../../../features/screen_types/domain/entities/screen_type.dart';
import '../../../../shared/domain/money.dart';
import '../../../../shared/domain/screen_status.dart';

/// Компактный бриф экрана арендодателя (FR-8.5).
///
/// Приходит из `GET /api/landlords/{landlord_id}/screens` — это НЕ полный
/// [Screen](../../../screens_map/domain/entities/screen.dart), а лёгкий срез для
/// раскрывающегося списка на карточке арендодателя: без attachments, договоров
/// и цены. Не рассчитывай на поля тяжёлого `Screen`.
///
/// PURE-доменная сущность: без кодогена (`freezed`/`json_serializable`
/// запрещены), `fromJson`/`toJson`/`copyWith` написаны вручную. Вложенные `city`
/// и `screen_type` переиспользуют лёгкие справочные сущности [City]/[ScreenType]
/// (парсим их прямо здесь, чтобы domain не зависел от data-слоя).
class LandlordScreenBrief {
  const LandlordScreenBrief({
    required this.id,
    required this.name,
    required this.status,
    required this.cityId,
    required this.city,
    this.size = '',
    this.screenTypeId,
    this.screenType,
    this.monthlyPrice,
    this.longitude,
    this.latitude,
  });

  final String id;
  final String name;

  /// Статус экрана — маппится в общий [ScreenStatus] (цвета берутся из него).
  final ScreenStatus status;

  /// Размер экрана (напр. `3x2`). У старых экранов может прийти пустой строкой.
  final String size;

  final int cityId;

  /// Город размещения (мини-справочник `{id, name}` из ответа).
  final City city;

  /// Id типа экрана, либо null, если тип не пришёл.
  final int? screenTypeId;

  /// Тип экрана (мини-справочник). Парсим защитно — может отсутствовать.
  final ScreenType? screenType;

  /// Ежемесячная аренда экрана (`monthly_price` — `{amount, currency}`). Nullable:
  /// бэкенд может не присылать цену в компактном брифе — тогда сумму по этому
  /// экрану не показываем и в общий итог по арендодателю не включаем.
  final Money? monthlyPrice;

  /// Координаты. Nullable: для опциональной навигации на карту нужен обе.
  final double? longitude;
  final double? latitude;

  /// Есть ли координаты для центрирования карты (опциональная навигация).
  bool get hasLocation => latitude != null && longitude != null;

  factory LandlordScreenBrief.fromJson(Map<String, dynamic> json) {
    final cityJson = json['city'] as Map<String, dynamic>;
    final typeJson = json['screen_type'];
    final priceJson = json['monthly_price'];
    return LandlordScreenBrief(
      id: json['id'] as String,
      name: json['name'] as String,
      status: ScreenStatus.fromValue(json['status'] as String),
      size: json['size'] as String? ?? '',
      cityId: json['city_id'] as int,
      city: City(
        id: cityJson['id'] as int,
        name: cityJson['name'] as String,
      ),
      screenTypeId: json['screen_type_id'] as int?,
      screenType: typeJson is Map<String, dynamic>
          ? ScreenType(
              id: typeJson['id'] as int,
              name: typeJson['name'] as String,
              code: typeJson['code'] as String?,
            )
          : null,
      monthlyPrice: priceJson is Map<String, dynamic>
          ? Money(
              amount: (priceJson['amount'] is num)
                  ? (priceJson['amount'] as num).toDouble()
                  : double.tryParse('${priceJson['amount']}') ?? 0,
              currency: priceJson['currency'] as String? ?? 'KGS',
            )
          : null,
      longitude: (json['lng'] as num?)?.toDouble(),
      latitude: (json['lat'] as num?)?.toDouble(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'status': status.value,
        'size': size,
        'city_id': cityId,
        'city': {'id': city.id, 'name': city.name},
        'screen_type_id': screenTypeId,
        'screen_type': screenType == null
            ? null
            : {
                'id': screenType!.id,
                'name': screenType!.name,
                'code': screenType!.code,
              },
        'monthly_price': monthlyPrice == null
            ? null
            : {'amount': monthlyPrice!.amount, 'currency': monthlyPrice!.currency},
        'lng': longitude,
        'lat': latitude,
      };

  LandlordScreenBrief copyWith({
    String? id,
    String? name,
    ScreenStatus? status,
    String? size,
    int? cityId,
    City? city,
    int? screenTypeId,
    ScreenType? screenType,
    Money? monthlyPrice,
    double? longitude,
    double? latitude,
  }) {
    return LandlordScreenBrief(
      id: id ?? this.id,
      name: name ?? this.name,
      status: status ?? this.status,
      size: size ?? this.size,
      cityId: cityId ?? this.cityId,
      city: city ?? this.city,
      screenTypeId: screenTypeId ?? this.screenTypeId,
      screenType: screenType ?? this.screenType,
      monthlyPrice: monthlyPrice ?? this.monthlyPrice,
      longitude: longitude ?? this.longitude,
      latitude: latitude ?? this.latitude,
    );
  }
}
