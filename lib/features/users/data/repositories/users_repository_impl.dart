import '../../../../core/error/failure.dart';
import '../../../../core/error/result.dart';
import '../../../../core/network/api_exception.dart';
import '../../domain/entities/app_user.dart';
import '../../domain/entities/user_role.dart';
import '../../domain/repositories/users_repository.dart';
import '../datasources/users_remote_ds.dart';

/// Реализация [UsersRepository]: датасорс → доменные сущности, исключения → [Failure].
///
/// Маппинг статусов (контракт от Архитектора):
/// * `LastAdminException` (409 LAST_ADMIN) → [LastAdminFailure];
/// * 401 → [UnauthorizedFailure]; 403 (ADMIN_ONLY) → [ForbiddenFailure];
/// * 404 (USER_NOT_FOUND) → [NotFoundFailure] («уже удалён»);
/// * 422 дубль имени → [ValidationFailure] («Имя занято»);
/// * прочее → [ServerFailure]/[NetworkFailure] (через [ApiException.toFailure]).
class UsersRepositoryImpl implements UsersRepository {
  const UsersRepositoryImpl(this._remote);

  final UsersRemoteDataSource _remote;

  @override
  Future<Result<List<AppUser>>> list() async {
    try {
      final users = await _remote.list();
      return Result.success(users);
    } on ApiException catch (e) {
      return Result.failure(e.toFailure());
    }
  }

  @override
  Future<Result<AppUser>> create({
    required String username,
    required String password,
    required UserRole role,
    bool? isActive,
  }) async {
    try {
      final user = await _remote.create(
        username: username,
        password: password,
        role: role,
        isActive: isActive,
      );
      return Result.success(user);
    } on LastAdminException catch (e) {
      return Result.failure(LastAdminFailure(e.message));
    } on ApiException catch (e) {
      return Result.failure(e.toFailure());
    }
  }

  @override
  Future<Result<AppUser>> edit(
    String id, {
    UserRole? role,
    bool? isActive,
    String? password,
  }) async {
    try {
      final user = await _remote.update(
        id,
        role: role,
        isActive: isActive,
        password: password,
      );
      return Result.success(user);
    } on LastAdminException catch (e) {
      return Result.failure(LastAdminFailure(e.message));
    } on ApiException catch (e) {
      return Result.failure(e.toFailure());
    }
  }

  @override
  Future<Result<void>> remove(String id) async {
    try {
      await _remote.delete(id);
      return const Result.success(null);
    } on LastAdminException catch (e) {
      return Result.failure(LastAdminFailure(e.message));
    } on ApiException catch (e) {
      return Result.failure(e.toFailure());
    }
  }
}
