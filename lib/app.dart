import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';

/// Корневой виджет приложения.
///
/// Настраивает тему, локализацию (русский) и роутер. Через `MaterialApp.router`
/// навигация полностью управляется go_router (URL-адреса на вебе работают из
/// коробки). Роутер берётся из провайдера, поэтому знает про состояние сессии.
class LedDashboardApp extends ConsumerWidget {
  const LedDashboardApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      title: 'LED Dashboard KG',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      routerConfig: router,
      // Локализация: русский как основной язык интерфейса (NFR-4).
      locale: const Locale('ru'),
      supportedLocales: const [Locale('ru'), Locale('en')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
    );
  }
}
