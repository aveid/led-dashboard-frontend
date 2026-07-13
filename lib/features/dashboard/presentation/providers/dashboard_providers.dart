import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers.dart';
import '../../data/datasources/dashboard_remote_ds.dart';
import '../../data/repositories/dashboard_repository_impl.dart';
import '../../domain/entities/dashboard_summary.dart';
import '../../domain/repositories/dashboard_repository.dart';
import '../../domain/usecases/get_dashboard_summary_usecase.dart';

/// Провайдеры фичи «дашборд»: сборка зависимостей, порог и сводка.

final _dashboardRemoteDataSourceProvider = Provider<DashboardRemoteDataSource>((ref) {
  return DashboardRemoteDataSource(ref.watch(dioClientProvider).dio);
});

final dashboardRepositoryProvider = Provider<DashboardRepository>((ref) {
  return DashboardRepositoryImpl(ref.watch(_dashboardRemoteDataSourceProvider));
});

final _getDashboardSummaryUseCaseProvider = Provider<GetDashboardSummaryUseCase>((ref) {
  return GetDashboardSummaryUseCase(ref.watch(dashboardRepositoryProvider));
});

/// Порог «скоро заканчивается» в днях (FR-9.5). По умолчанию 30 — как на бэке.
/// `StateProvider`: простое значение без побочной логики, меняется дропдауном в UI.
final thresholdDaysProvider = StateProvider<int>((ref) => 30);

/// Сводка для главного экрана (FR-9). Следит за [thresholdDaysProvider] — при
/// смене порога сам перезапрашивает данные с бэка.
final dashboardSummaryProvider = FutureProvider<DashboardSummary>((ref) async {
  final thresholdDays = ref.watch(thresholdDaysProvider);
  final result = await ref.watch(_getDashboardSummaryUseCaseProvider).call(
        thresholdDays: thresholdDays,
      );
  return result.when(
    onSuccess: (summary) => summary,
    // throw (Never) — совместимо с R любой ветки when, см. пояснение в
    // screens_providers.dart (тот же паттерн, тот же класс потенциального бага).
    onFailure: (failure) => throw failure,
  );
});
