import '../../../../core/error/result.dart';
import '../../../../core/network/api_exception.dart';
import '../../domain/entities/landlord.dart';
import '../../domain/entities/landlord_screen_brief.dart';
import '../../domain/repositories/landlords_repository.dart';
import '../datasources/landlords_remote_ds.dart';

/// Реализация [LandlordsRepository]: датасорс → доменные сущности, ошибки → [Failure].
class LandlordsRepositoryImpl implements LandlordsRepository {
  const LandlordsRepositoryImpl(this._remote);

  final LandlordsRemoteDataSource _remote;

  @override
  Future<Result<List<Landlord>>> getLandlords() async {
    try {
      final dtos = await _remote.getLandlords();
      return Result.success(dtos.map((dto) => dto.toDomain()).toList());
    } on ApiException catch (e) {
      return Result.failure(e.toFailure());
    }
  }

  @override
  Future<Result<List<LandlordScreenBrief>>> getLandlordScreens(String landlordId) async {
    try {
      final screens = await _remote.fetchLandlordScreens(landlordId);
      return Result.success(screens);
    } on ApiException catch (e) {
      // 404 → NotFoundFailure (арендодатель пропал), сеть/сервер → соответствующий Failure.
      return Result.failure(e.toFailure());
    }
  }

  @override
  Future<Result<Landlord>> createLandlord({
    required String name,
    String contactPerson = '',
    String phone = '',
    String email = '',
  }) async {
    try {
      final dto = await _remote.createLandlord(
        name: name,
        contactPerson: contactPerson,
        phone: phone,
        email: email,
      );
      return Result.success(dto.toDomain());
    } on ApiException catch (e) {
      return Result.failure(e.toFailure());
    }
  }

  @override
  Future<Result<Landlord>> updateLandlord({
    required String id,
    String? name,
    String? contactPerson,
    String? phone,
    String? email,
  }) async {
    try {
      final dto = await _remote.updateLandlord(
        id: id,
        name: name,
        contactPerson: contactPerson,
        phone: phone,
        email: email,
      );
      return Result.success(dto.toDomain());
    } on ApiException catch (e) {
      return Result.failure(e.toFailure());
    }
  }

  @override
  Future<Result<void>> deleteLandlord(String id) async {
    try {
      await _remote.deleteLandlord(id);
      return const Result.success(null);
    } on ApiException catch (e) {
      return Result.failure(e.toFailure());
    }
  }
}
