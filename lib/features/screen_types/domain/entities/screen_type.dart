/// Тип экрана (справочник): напр. «Вертикальный», «Горизонтальный».
///
/// ДОМЕННАЯ модель (не DTO): без сериализации, только данные. Зеркалит ответ
/// бэкенда (`GET /api/screen-types`). Разбор JSON — в
/// `data/models/screen_type_model.dart`.
class ScreenType {
  const ScreenType({
    required this.id,
    required this.name,
    this.code,
  });

  final int id;
  final String name;

  /// Машинный код типа (напр. `vertical`). Опционален — может отсутствовать.
  final String? code;
}
