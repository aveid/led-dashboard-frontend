import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';

/// Точка входа приложения.
///
/// Оборачиваем всё в [ProviderScope] — это корень дерева Riverpod, без него
/// провайдеры (DI, состояние) не работают. Дальше всё собирает [LedDashboardApp].
void main() {
  runApp(const ProviderScope(child: LedDashboardApp()));
}
