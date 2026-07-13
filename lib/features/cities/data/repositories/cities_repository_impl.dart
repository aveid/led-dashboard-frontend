import '../../../../core/error/failure.dart';
import '../../../../core/error/result.dart';
import '../../../../core/network/api_exception.dart';
import '../../domain/entities/city.dart';
import '../../domain/repositories/cities_repository.dart';
import '../datasources/cities_remote_ds.dart';

/// Реализация [CitiesRepository]: датасорс → доменные сущности, исключения → [Failure].
///
/// Доменные конфликты городов ([CityConflictException]/[CityInUseException])
/// переводятся в типизированные [Failure], чтобы UI мог показать точное
/// сообщение для дубликата и для «города в использовании».
class CitiesRepositoryImpl implements CitiesRepository {
  const CitiesRepositoryImpl(this._remote);

  final CitiesRemoteDataSource _remote;

  @override
  Future<Result<List<City>>> getCities({bool onlyActive = false}) async {
    try {
      final cities = await _remote.getCities(onlyActive: onlyActive);
      return Result.success(cities);
    } on ApiException catch (e) {
      return Result.failure(e.toFailure());
    }
  }

  @override
  Future<Result<City>> createCity(String name) async {
    try {
      final city = await _remote.createCity(name);
      return Result.success(city);
    } on CityConflictException catch (e) {
      return Result.failure(CityDuplicateFailure(e.message));
    } on ApiException catch (e) {
      return Result.failure(e.toFailure());
    }
  }

  @override
  Future<Result<City>> updateCity(int id, {String? name, bool? isActive}) async {
    try {
      final city = await _remote.updateCity(id, name: name, isActive: isActive);
      return Result.success(city);
    } on CityConflictException catch (e) {
      return Result.failure(CityDuplicateFailure(e.message));
    } on ApiException catch (e) {
      return Result.failure(e.toFailure());
    }
  }

  @override
  Future<Result<void>> deleteCity(int id) async {
    try {
      await _remote.deleteCity(id);
      return const Result.success(null);
    } on CityInUseException catch (e) {
      return Result.failure(CityInUseFailure(e.message));
    } on ApiException catch (e) {
      return Result.failure(e.toFailure());
    }
  }
}
