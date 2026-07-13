import '../../domain/entities/screen_type.dart';

/// DTO типа экрана (зеркалит `ScreenType` на бэке). Без кодогена — `fromJson`
/// вручную.
///
/// Наследуется от [ScreenType] (как и `CityModel` от `City`): модель данных
/// *является* доменной сущностью, отдельный `toDomain` не нужен.
class ScreenTypeModel extends ScreenType {
  const ScreenTypeModel({
    required super.id,
    required super.name,
    super.code,
  });

  factory ScreenTypeModel.fromJson(Map<String, dynamic> json) => ScreenTypeModel(
        id: json['id'] as int,
        name: json['name'] as String,
        code: json['code'] as String?,
      );
}
