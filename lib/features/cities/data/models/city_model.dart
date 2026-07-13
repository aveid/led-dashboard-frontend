import '../../domain/entities/city.dart';

/// DTO города (зеркалит `CityRead` на бэке). Без кодогена — `fromJson` вручную.
///
/// Наследуется от [City] (как договорено Архитектором для этого справочника):
/// модель данных *является* доменной сущностью, отдельный `toDomain` не нужен.
class CityModel extends City {
  const CityModel({
    required super.id,
    required super.name,
    required super.isActive,
    required super.screensCount,
  });

  factory CityModel.fromJson(Map<String, dynamic> json) => CityModel(
        id: json['id'] as int,
        name: json['name'] as String,
        isActive: json['is_active'] as bool? ?? true,
        screensCount: (json['screens_count'] as int?) ?? 0,
      );
}
