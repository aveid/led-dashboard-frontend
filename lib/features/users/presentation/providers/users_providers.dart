import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error/result.dart';
import '../../../../core/providers.dart';
import '../../data/datasources/users_remote_ds.dart';
import '../../data/repositories/users_repository_impl.dart';
import '../../domain/entities/app_user.dart';
import '../../domain/entities/user_role.dart';
import '../../domain/repositories/users_repository.dart';

/// Провайдеры раздела «Пользователи»: сборка зависимостей, список и мутации.

final _usersRemoteDataSourceProvider = Provider<UsersRemoteDataSource>((ref) {
  return UsersRemoteDataSource(ref.watch(dioClientProvider).dio);
});

final usersRepositoryProvider = Provider<UsersRepository>((ref) {
  return UsersRepositoryImpl(ref.watch(_usersRemoteDataSourceProvider));
});

/// Список пользователей. Мутации в [UsersController] инвалидируют этот провайдер,
/// поэтому список перезапрашивается целиком (проще и надёжнее точечного обновления
/// — как в фичах городов/арендодателей).
final usersProvider = FutureProvider<List<AppUser>>((ref) async {
  final result = await ref.watch(usersRepositoryProvider).list();
  return result.when(onSuccess: (v) => v, onFailure: (f) => throw f);
});

/// Мутации пользователей: создание/редактирование/удаление + рефетч [usersProvider].
///
/// `AsyncNotifier<void>` — сам список живёт в [usersProvider]; контроллер лишь
/// выполняет мутацию и инвалидирует список при успехе. Методы возвращают [Result],
/// чтобы UI показал типизированную ошибку (LAST_ADMIN/дубль/уже удалён/403), не ловя
/// исключений. Имена методов (`createUser`/`editUser`/`removeUser`/`refresh`) не
/// пересекаются с зарезервированными (`update`/`state`/`future`/`ref`).
class UsersController extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<Result<AppUser>> createUser({
    required String username,
    required String password,
    required UserRole role,
    bool? isActive,
  }) async {
    final result = await ref.read(usersRepositoryProvider).create(
          username: username,
          password: password,
          role: role,
          isActive: isActive,
        );
    if (result.isSuccess) ref.invalidate(usersProvider);
    return result;
  }

  Future<Result<AppUser>> editUser(
    String id, {
    UserRole? role,
    bool? isActive,
    String? password,
  }) async {
    final result = await ref.read(usersRepositoryProvider).edit(
          id,
          role: role,
          isActive: isActive,
          password: password,
        );
    if (result.isSuccess) ref.invalidate(usersProvider);
    return result;
  }

  Future<Result<void>> removeUser(String id) async {
    final result = await ref.read(usersRepositoryProvider).remove(id);
    if (result.isSuccess) ref.invalidate(usersProvider);
    return result;
  }

  void refresh() => ref.invalidate(usersProvider);
}

final usersControllerProvider = AsyncNotifierProvider<UsersController, void>(
  UsersController.new,
);
