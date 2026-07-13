import '../../../../features/cities/domain/entities/city.dart';
import '../../../../features/screen_types/domain/entities/screen_type.dart';
import '../../../../shared/domain/attachment_type.dart';
import '../../../../shared/domain/money.dart';
import '../../../../shared/domain/screen_status.dart';
import 'attachment.dart';
import 'rental_contract.dart';

/// LED-экран — центральная сущность приложения (FR-3).
///
/// Поля зеркалят ответ бэкенда `ScreenRead` (`features/screens/presentation/schemas.py`).
/// Это ДОМЕННАЯ модель (не DTO): без сериализации, только данные и мелкие удобные
/// геттеры для UI. Разбор JSON — в `data/models/screen_dto.dart`.
class Screen {
  const Screen({
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

  /// Размер экрана — произвольное значение (напр. `1920x1080` или `55"`). После
  /// миграции у старых экранов приходит пустой строкой; поле обязательно при
  /// сохранении (пустое сохранить нельзя, см. форму экрана).
  final String size;

  /// Тип экрана из справочника. В ответе бэка присутствует всегда (после
  /// миграции), но парсим защитно (`null` при отсутствии), чтобы UI не падал,
  /// если развёртывание бэка отстаёт — см. `screen_dto.dart`.
  final ScreenType? screenType;
  // Координаты (широта/долгота) остаются в модели — они нужны маркерам карты.
  // FR-3.3 убрал только их ТЕКСТОВЫЙ ввод/показ, локация ставится жестом по карте.
  final double latitude;
  final double longitude;
  final ScreenStatus status;
  final String? landlordId;
  final String? contactId;
  final List<String> campaignIds;
  final String? currentCampaignId;
  final Money monthlyPrice;
  final List<RentalContract> rentals;
  final List<Attachment> attachments;
  final String comment;

  /// Дата окончания аренды (FR-4.4). Дата без времени, последний день включительно.
  /// По истечении бэк сам переводит экран в `archived` при чтении (sweep), клиент
  /// лишь задаёт и показывает срок. Может отсутствовать (`null`) — тогда экран
  /// активен бессрочно, пока срок не задан. Парсится защитно (см. `screen_dto.dart`).
  final DateTime? rentalEndDate;

  /// Id текущего типа экрана (для предзаполнения дропдауна в форме), либо null,
  /// если тип по какой-то причине не пришёл.
  int? get screenTypeId => screenType?.id;

  /// Подпись местоположения для карточки/маркера — название города.
  /// Район/улица убраны из модели (FR-3.3): точка задаётся координатами на карте.
  String get addressLine => city.name;

  /// Текущий договор (первый в списке — бэк уже отдаёт актуальный текущий, если
  /// он есть; полная история пока не отображается в этом срезе UI).
  RentalContract? get currentRental => rentals.isEmpty ? null : rentals.first;

  /// Есть ли прикреплённый договор (для индикатора в карточке, FR-4.2).
  bool get hasContract =>
      attachments.any((a) => a.type == AttachmentType.contract);

  /// Есть ли прикреплённое фото (для индикатора в карточке, FR-4.2).
  bool get hasPhoto => attachments.any((a) => a.type == AttachmentType.photo);
}
