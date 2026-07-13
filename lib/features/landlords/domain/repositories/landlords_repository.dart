import '../../../../core/error/result.dart';
import '../entities/landlord.dart';
import '../entities/landlord_screen_brief.dart';

/// Порт (интерфейс) репозитория арендодателей (FR-8).
abstract interface class LandlordsRepository {
  Future<Result<List<Landlord>>> getLandlords();

  /// Список экранов арендодателя (FR-8.5) — компактный бриф каждого экрана.
  /// `NotFoundFailure` означает «арендодателя уже нет» (404 LANDLORD_NOT_FOUND).
  Future<Result<List<LandlordScreenBrief>>> getLandlordScreens(String landlordId);

  Future<Result<Landlord>> createLandlord({
    required String name,
    String contactPerson = '',
    String phone = '',
    String email = '',
  });

  /// Частичное обновление: null-поля не меняются (см. `LandlordUpdate` на бэке).
  Future<Result<Landlord>> updateLandlord({
    required String id,
    String? name,
    String? contactPerson,
    String? phone,
    String? email,
  });

  Future<Result<void>> deleteLandlord(String id);
}
