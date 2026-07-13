import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/presentation/controllers/auth_providers.dart';
import '../theme/app_colors.dart';
import 'app_router.dart';

/// Оболочка приложения после входа: боковая навигация (`NavigationRail`) +
/// общий AppBar (заголовок раздела + выход) + область содержимого раздела.
///
/// Используется как `builder` в `ShellRoute` (см. `app_router.dart`) — сама
/// страница-раздел (`MapPage`, `DashboardPage`, ...) знает только про свой body,
/// а рамку (навигацию, выход) даёт эта оболочка. `currentLocation` определяет,
/// какой пункт навигации подсвечен и какой заголовок показать.
class AppShell extends ConsumerWidget {
  const AppShell({required this.currentLocation, required this.child, super.key});

  final String currentLocation;
  final Widget child;

  /// Разделы, видимые всем ролям (включая `user` и `guest` — просмотр/отчётность),
  /// идущие ДО пункта «Дашборд».
  static const _baseDestinationsBeforeDashboard = [
    _NavDestination(route: AppRoutes.map, icon: Icons.map_outlined, selectedIcon: Icons.map, label: 'Карта'),
    _NavDestination(
      route: AppRoutes.screenTypes,
      icon: Icons.aspect_ratio_outlined,
      selectedIcon: Icons.aspect_ratio,
      label: 'Тип экрана',
    ),
  ];

  /// Пункт «Дашборд» — скрыт для `guest` (RBAC, зеркало бэкового 403
  /// `GUEST_FORBIDDEN`): добавляется в меню лишь при `!isGuest`, иначе destination
  /// вообще не строим (не `Visibility`/`SizedBox` с местом). Для `admin`/`user` — как есть.
  static const _dashboardDestination = _NavDestination(
    route: AppRoutes.dashboard,
    icon: Icons.dashboard_outlined,
    selectedIcon: Icons.dashboard,
    label: 'Дашборд',
  );

  /// Разделы, видимые всем ролям, идущие ПОСЛЕ пункта «Дашборд».
  static const _baseDestinationsAfterDashboard = [
    _NavDestination(
      route: AppRoutes.landlords,
      icon: Icons.business_outlined,
      selectedIcon: Icons.business,
      label: 'Арендодатели',
    ),
    _NavDestination(
      route: AppRoutes.cities,
      icon: Icons.location_city_outlined,
      selectedIcon: Icons.location_city,
      label: 'Города',
    ),
    _NavDestination(
      route: AppRoutes.campaigns,
      icon: Icons.campaign_outlined,
      selectedIcon: Icons.campaign,
      label: 'Кампании',
    ),
  ];

  /// Раздел «Пользователи» — только для admin (RBAC): пункт добавляется в меню
  /// лишь при `isAdmin`, иначе его вообще не строим (не `Visibility` с местом).
  static const _usersDestination = _NavDestination(
    route: AppRoutes.users,
    icon: Icons.people_outline,
    selectedIcon: Icons.people,
    label: 'Пользователи',
  );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isAdmin = ref.watch(isAdminProvider);
    final isGuest = ref.watch(isGuestProvider);
    // Условная сборка списка: убранный destination сдвинул бы позиции, но и
    // подсветка (indexWhere по route), и навигация (destinations[index].route)
    // считаются от ЭТОГО же списка — индексы не «поедут».
    final destinations = [
      ..._baseDestinationsBeforeDashboard,
      if (!isGuest) _dashboardDestination,
      ..._baseDestinationsAfterDashboard,
      if (isAdmin) _usersDestination,
    ];
    final selectedIndex = () {
      final index = destinations.indexWhere((d) => d.route == currentLocation);
      return index == -1 ? 0 : index;
    }();

    return Scaffold(
      appBar: AppBar(
        title: Text(destinations[selectedIndex].label),
        actions: [
          IconButton(
            tooltip: 'Выйти',
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await ref.read(authRepositoryProvider).logout();
              // Роль сбрасывается вместе с сессией (RBAC): чистим и признак сессии
              // (роутер уведёт на /login), и текущего пользователя.
              ref.invalidate(isAuthenticatedProvider);
              ref.invalidate(currentUserProvider);
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Row(
        children: [
          NavigationRail(
            selectedIndex: selectedIndex,
            labelType: NavigationRailLabelType.all,
            backgroundColor: AppColors.surface,
            onDestinationSelected: (index) => context.go(destinations[index].route),
            destinations: [
              for (final d in destinations)
                NavigationRailDestination(
                  icon: Icon(d.icon),
                  selectedIcon: Icon(d.selectedIcon),
                  label: Text(d.label),
                ),
            ],
          ),
          const VerticalDivider(width: 1),
          Expanded(child: child),
        ],
      ),
    );
  }
}

class _NavDestination {
  const _NavDestination({
    required this.route,
    required this.icon,
    required this.selectedIcon,
    required this.label,
  });

  final String route;
  final IconData icon;
  final IconData selectedIcon;
  final String label;
}
