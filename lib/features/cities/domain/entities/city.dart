/// Город/регион размещения экранов (справочник).
///
/// ДОМЕННАЯ модель (не DTO): без сериализации, только данные. Зеркалит ответ
/// бэкенда `CityRead` (`GET /api/v1/cities`). Разбор JSON — в
/// `data/models/city_model.dart`.
class City {
  const City({
    required this.id,
    required this.name,
    this.isActive = true,
    this.screensCount = 0,
  });

  final int id;
  final String name;

  /// Активен ли город (неактивные не предлагаются при выборе города экрана).
  final bool isActive;

  /// Сколько экранов привязано к городу (для подписи «Экранов: N» и запрета
  /// удаления города с привязанными экранами).
  final int screensCount;
}
