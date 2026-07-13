import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/presentation/controllers/auth_providers.dart';
import '../../features/auth/presentation/pages/login_page.dart';
// (auth_providers даёт currentUserProvider для guard раздела «Пользователи»)
import '../../features/campaigns/presentation/pages/campaigns_page.dart';
import '../../features/cities/presentation/pages/cities_page.dart';
import '../../features/dashboard/presentation/pages/dashboard_page.dart';
import '../../features/landlords/presentation/pages/landlords_page.dart';
import '../../features/screen_types/presentation/pages/screen_types_page.dart';
import '../../features/screens_map/presentation/pages/map_page.dart';
import '../../features/users/domain/entities/user_role.dart';
import '../../features/users/presentation/pages/users_page.dart';
import 'app_shell.dart';

/// Пути приложения (в одном месте, без «магических» строк по коду).
abstract final class AppRoutes {
  static const login = '/login';
  static const map = '/';
  static const dashboard = '/dashboard';
  static const landlords = '/landlords';
  static const cities = '/cities';
  static const screenTypes = '/screen-types';
  static const campaigns = '/campaigns';
  static const users = '/users';
}

/// Провайдер go_router с защитой маршрутов по состоянию авторизации.
///
/// Логика редиректа (frontend/CONTEXT.md §6): нет сессии → всегда на /login;
/// есть сессия, но пользователь на /login → на карту. Признак сессии берётся из
/// [isAuthenticatedProvider]; при входе/выходе он инвалидируется, роутер
/// перечитывает состояние и перенаправляет.
///
/// Разделы после входа (карта/дашборд/арендодатели/кампании) обёрнуты в
/// `ShellRoute` — общая навигация (`AppShell`) не пересоздаётся при переходах
/// между ними, пересоздаётся только содержимое (`child`). /login — вне шелла
/// (у экрана входа нет боковой навигации).
final routerProvider = Provider<GoRouter>((ref) {
  final refresh = RouterRefreshNotifier(ref);
  ref.onDispose(refresh.dispose);

  return GoRouter(
    initialLocation: AppRoutes.map,
    refreshListenable: refresh,
    redirect: (context, state) {
      // Пока идёт первая проверка токена — не редиректим (покажется /login или
      // splash по initialLocation; для внутренней тулзы этого достаточно).
      final authAsync = ref.read(isAuthenticatedProvider);
      final isAuthenticated = authAsync.valueOrNull ?? false;
      final goingToLogin = state.matchedLocation == AppRoutes.login;

      if (!isAuthenticated && !goingToLogin) return AppRoutes.login;
      if (isAuthenticated && goingToLogin) return AppRoutes.map;

      // Guard раздела «Пользователи» (RBAC): только admin. Прямой заход по URL
      // (web) для не-admin → на карту. Учитываем загрузку роли: пока `/auth/me`
      // грузится — НЕ редиректим преждевременно (ждём значения; роутер слушает
      // currentUserProvider и пересчитает redirect, когда роль придёт). При
      // ошибке/`null` считаем не-admin → redirect.
      if (state.matchedLocation == AppRoutes.users) {
        final userAsync = ref.read(currentUserProvider);
        if (userAsync.isLoading) return null; // роль ещё грузится — ждём
        final isAdmin = userAsync.valueOrNull?.role == UserRole.admin;
        if (!isAdmin) return AppRoutes.map;
      }

      // Guard раздела «Дашборд» (RBAC): скрыт для guest (зеркало бэкового 403
      // `GUEST_FORBIDDEN`). Deep-link/сохранённый URL guest'а отбиваем на карту.
      // Как и с `/users`: пока роль грузится — НЕ редиректим (ждём значения;
      // роутер слушает currentUserProvider и пересчитает). При ошибке/`null`
      // роль != guest (fail-safe) → доступ остаётся, авторитетен бэкенд (403).
      if (state.matchedLocation == AppRoutes.dashboard) {
        final userAsync = ref.read(currentUserProvider);
        if (userAsync.isLoading) return null; // роль ещё грузится — ждём
        final isGuest = userAsync.valueOrNull?.role == UserRole.guest;
        if (isGuest) return AppRoutes.map;
      }
      return null; // редирект не нужен
    },
    routes: [
      GoRoute(
        path: AppRoutes.login,
        builder: (context, state) => const LoginPage(),
      ),
      ShellRoute(
        builder: (context, state, child) {
          return AppShell(currentLocation: state.matchedLocation, child: child);
        },
        routes: [
          GoRoute(path: AppRoutes.map, builder: (context, state) => const MapPage()),
          GoRoute(path: AppRoutes.dashboard, builder: (context, state) => const DashboardPage()),
          GoRoute(path: AppRoutes.landlords, builder: (context, state) => const LandlordsPage()),
          GoRoute(path: AppRoutes.cities, builder: (context, state) => const CitiesPage()),
          GoRoute(path: AppRoutes.screenTypes, builder: (context, state) => const ScreenTypesPage()),
          GoRoute(path: AppRoutes.campaigns, builder: (context, state) => const CampaignsPage()),
          GoRoute(path: AppRoutes.users, builder: (context, state) => const UsersPage()),
        ],
      ),
    ],
  );
});

/// Мост между Riverpod и go_router: заставляет роутер пересчитать redirect,
/// когда меняется состояние авторизации.
///
/// go_router слушает `refreshListenable`; мы уведомляем его при каждом изменении
/// [isAuthenticatedProvider] (вход/выход).
class RouterRefreshNotifier extends ChangeNotifier {
  RouterRefreshNotifier(Ref ref) {
    ref.listen(isAuthenticatedProvider, (_, __) => notifyListeners());
    // Роль влияет на guard раздела «Пользователи»: когда `/auth/me` догрузится
    // (loading → data), пересчитываем redirect, чтобы не-admin ушёл с /users.
    ref.listen(currentUserProvider, (_, __) => notifyListeners());
  }
}
