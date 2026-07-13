import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/screen_filters.dart';

/// Текущие фильтры списка экранов (FR-5).
///
/// `StateProvider` — фильтры это просто данные без асинхронной логики, полный
/// `Notifier` был бы избыточен. `screensProvider` следит за этим провайдером
/// (`ref.watch`) и автоматически перезапрашивает список при любом изменении.
final screenFiltersProvider = StateProvider<ScreenFilters>((ref) => const ScreenFilters.empty());
