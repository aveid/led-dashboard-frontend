import '../../../../core/error/result.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../core/network/token_storage.dart';
import '../../../users/domain/entities/app_user.dart';
import '../../domain/repositories/auth_repository.dart';
import '../datasources/auth_remote_ds.dart';

/// Реализация [AuthRepository]: связывает датасорс (сеть) и хранилище токена.
///
/// Логика: получить токен по логину/паролю → сохранить его. Наружу отдаёт
/// [Result], пряча детали сети (исключения датасорса превращаются в [Failure]).
class AuthRepositoryImpl implements AuthRepository {
  const AuthRepositoryImpl({
    required AuthRemoteDataSource remote,
    required TokenStorage tokenStorage,
  })  : _remote = remote,
        _tokenStorage = tokenStorage;

  final AuthRemoteDataSource _remote;
  final TokenStorage _tokenStorage;

  @override
  Future<Result<void>> login({required String username, required String password}) async {
    try {
      final token = await _remote.login(username: username, password: password);
      await _tokenStorage.saveAccessToken(token.accessToken);
      return const Result.success(null);
    } on ApiException catch (e) {
      return Result.failure(e.toFailure());
    }
  }

  @override
  Future<void> logout() => _tokenStorage.clear();

  @override
  Future<Result<AppUser>> getCurrentUser() async {
    try {
      final user = await _remote.getMe();
      return Result.success(user);
    } on ApiException catch (e) {
      return Result.failure(e.toFailure());
    }
  }

  @override
  Future<bool> isAuthenticated() async {
    final token = await _tokenStorage.readAccessToken();
    return token != null && token.isNotEmpty;
  }
}
