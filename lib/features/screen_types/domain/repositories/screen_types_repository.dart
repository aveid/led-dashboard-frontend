import '../../../../core/error/result.dart';
import '../entities/screen_type.dart';

/// Порт (интерфейс) репозитория типов экрана.
abstract interface class ScreenTypesRepository {
  /// Список всех типов экрана (для раздела «Тип экрана», формы экрана и фильтра).
  Future<Result<List<ScreenType>>> getScreenTypes();

  /// Создаёт тип. Ошибка валидации/дубликат имени → [ValidationFailure].
  Future<Result<ScreenType>> createScreenType({required String name, String? code});

  /// Частичное обновление: null-поля не меняются. Дубликат → [ValidationFailure].
  Future<Result<ScreenType>> updateScreenType(int id, {String? name, String? code});

  /// Удаляет тип. Если тип используется экранами → [ScreenTypeInUseFailure].
  Future<Result<void>> deleteScreenType(int id);
}
