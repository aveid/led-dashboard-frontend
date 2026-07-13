import '../../../../core/error/failure.dart';
import '../../../../core/error/result.dart';
import '../../../../core/network/api_exception.dart';
import '../../domain/entities/screen_type.dart';
import '../../domain/repositories/screen_types_repository.dart';
import '../datasources/screen_types_remote_ds.dart';

/// Реализация [ScreenTypesRepository]: датасорс → доменные сущности, исключения
/// → [Failure].
///
/// «Тип занят» ([ScreenTypeInUseException]) переводится в типизированный
/// [ScreenTypeInUseFailure], чтобы UI показал сообщение с числом экранов и
/// оставил тип в списке (это не баг, а бизнес-правило). Дубликат имени приходит
/// как `422` → общий [ValidationFailure] с сообщением сервера (показываем инлайн
/// у поля).
class ScreenTypesRepositoryImpl implements ScreenTypesRepository {
  const ScreenTypesRepositoryImpl(this._remote);

  final ScreenTypesRemoteDataSource _remote;

  @override
  Future<Result<List<ScreenType>>> getScreenTypes() async {
    try {
      final types = await _remote.getScreenTypes();
      return Result.success(types);
    } on ApiException catch (e) {
      return Result.failure(e.toFailure());
    }
  }

  @override
  Future<Result<ScreenType>> createScreenType({required String name, String? code}) async {
    try {
      final type = await _remote.createScreenType(name: name, code: code);
      return Result.success(type);
    } on ApiException catch (e) {
      return Result.failure(e.toFailure());
    }
  }

  @override
  Future<Result<ScreenType>> updateScreenType(int id, {String? name, String? code}) async {
    try {
      final type = await _remote.updateScreenType(id, name: name, code: code);
      return Result.success(type);
    } on ApiException catch (e) {
      return Result.failure(e.toFailure());
    }
  }

  @override
  Future<Result<void>> deleteScreenType(int id) async {
    try {
      await _remote.deleteScreenType(id);
      return const Result.success(null);
    } on ScreenTypeInUseException catch (e) {
      return Result.failure(ScreenTypeInUseFailure(e.message, usedByCount: e.usedByCount));
    } on ApiException catch (e) {
      return Result.failure(e.toFailure());
    }
  }
}
