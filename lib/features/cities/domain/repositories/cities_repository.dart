import '../../../../core/error/result.dart';
import '../entities/city.dart';

/// Порт (интерфейс) репозитория городов.
abstract interface class CitiesRepository {
  /// Список городов. [onlyActive] — только активные (для выбора города экрана).
  Future<Result<List<City>>> getCities({bool onlyActive = false});

  /// Создаёт город. Дубликат имени → [CityDuplicateFailure].
  Future<Result<City>> createCity(String name);

  /// Частичное обновление: null-поля не меняются. Дубликат → [CityDuplicateFailure].
  Future<Result<City>> updateCity(int id, {String? name, bool? isActive});

  /// Удаляет город. Есть привязанные экраны → [CityInUseFailure].
  Future<Result<void>> deleteCity(int id);
}
