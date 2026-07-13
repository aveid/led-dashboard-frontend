import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../features/campaigns/presentation/providers/campaigns_providers.dart';
import '../../../../features/landlords/presentation/providers/landlords_providers.dart';

/// Провайдеры справочных данных (имена арендодателей/кампаний для карточки экрана
/// и дропдаунов формы).
///
/// Строятся поверх канонических списков `landlordsListProvider` /
/// `campaignsListProvider` (тех же, что питают разделы «Арендодатели»/«Кампании»),
/// а не отдельного датасорса — единый источник правды: имена всегда синхронны с
/// управлением справочниками и обновляются вместе с ними после CRUD-мутаций.
///
/// Ошибка загрузки не должна ломать карту/форму: потребители читают эти провайдеры
/// через `.valueOrNull ?? {}`, поэтому при сбое просто не будет подписей/пунктов,
/// а не краш.

/// Карта id→название арендодателей.
final landlordNamesProvider = FutureProvider<Map<String, String>>((ref) async {
  final list = await ref.watch(landlordsListProvider.future);
  return {for (final item in list) item.id: item.name};
});

/// Карта id→название кампаний (тот же принцип, что и для арендодателей).
final campaignNamesProvider = FutureProvider<Map<String, String>>((ref) async {
  final list = await ref.watch(campaignsListProvider.future);
  return {for (final item in list) item.id: item.name};
});
