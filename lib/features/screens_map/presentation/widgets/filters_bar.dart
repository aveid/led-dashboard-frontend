import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../features/cities/domain/entities/city.dart';
import '../../../../features/cities/presentation/providers/cities_providers.dart';
import '../../../../features/screen_types/domain/entities/screen_type.dart';
import '../../../../features/screen_types/presentation/providers/screen_types_providers.dart';
import '../../../../shared/domain/screen_status.dart';
import '../../domain/entities/screen_filters.dart';
import '../providers/filters_providers.dart';
import '../providers/reference_providers.dart';

/// Панель фильтров экранов (FR-5): статус, арендодатель, кампания, город, срок
/// договора. Меняет [screenFiltersProvider] — `screensProvider` следит за ним и
/// сам перезапрашивает список, поэтому здесь нет прямых вызовов API.
class FiltersBar extends ConsumerWidget {
  const FiltersBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filters = ref.watch(screenFiltersProvider);
    final notifier = ref.read(screenFiltersProvider.notifier);
    final landlordNames = ref.watch(landlordNamesProvider).valueOrNull ?? const {};
    final campaignNames = ref.watch(campaignNamesProvider).valueOrNull ?? const {};
    final cities = ref.watch(activeCitiesProvider).valueOrNull ?? const <City>[];
    final screenTypes = ref.watch(screenTypesProvider).valueOrNull ?? const <ScreenType>[];

    return Container(
      color: AppColors.surface,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _StatusFilterChip(
              value: filters.status,
              onChanged: (status) => notifier.state = filters.copyWith(
                status: status,
                clearStatus: status == null,
              ),
            ),
            const SizedBox(width: 8),
            _DropdownFilterChip(
              label: 'Арендодатель',
              value: filters.landlordId,
              options: landlordNames,
              onChanged: (id) => notifier.state = filters.copyWith(
                landlordId: id,
                clearLandlordId: id == null,
              ),
            ),
            const SizedBox(width: 8),
            _DropdownFilterChip(
              label: 'Кампания',
              value: filters.campaignId,
              options: campaignNames,
              onChanged: (id) => notifier.state = filters.copyWith(
                campaignId: id,
                clearCampaignId: id == null,
              ),
            ),
            const SizedBox(width: 8),
            _CityFilterChip(
              value: filters.cityId,
              cities: cities,
              onChanged: (cityId) => notifier.state = filters.copyWith(
                cityId: cityId,
                clearCityId: cityId == null,
              ),
            ),
            const SizedBox(width: 8),
            _ScreenTypeFilterChip(
              value: filters.screenTypeId,
              types: screenTypes,
              onChanged: (typeId) => notifier.state = filters.copyWith(
                screenTypeId: typeId,
                clearScreenTypeId: typeId == null,
              ),
            ),
            const SizedBox(width: 8),
            _DateFilterChip(
              value: filters.contractEndBefore,
              onChanged: (date) => notifier.state = filters.copyWith(
                contractEndBefore: date,
                clearContractEndBefore: date == null,
              ),
            ),
            if (!filters.isEmpty) ...[
              const SizedBox(width: 8),
              TextButton.icon(
                onPressed: () => notifier.state = const ScreenFilters.empty(),
                icon: const Icon(Icons.close, size: 16),
                label: Text('Сбросить (${filters.activeCount})'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Базовый вид фильтра-чипа: подпись + текущее значение, тап открывает меню.
class _FilterChipShell extends StatelessWidget {
  const _FilterChipShell({required this.child, this.active = false});

  final Widget child;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: active ? AppColors.primarySoft : AppColors.bg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: active ? AppColors.primary : AppColors.border),
      ),
      child: DefaultTextStyle(
        style: TextStyle(
          fontSize: 13,
          color: active ? AppColors.primary : AppColors.textSecondary,
          fontWeight: FontWeight.w500,
        ),
        child: child,
      ),
    );
  }
}

class _StatusFilterChip extends StatelessWidget {
  const _StatusFilterChip({required this.value, required this.onChanged});

  final ScreenStatus? value;
  final ValueChanged<ScreenStatus?> onChanged;

  @override
  Widget build(BuildContext context) {
    return _FilterChipShell(
      active: value != null,
      child: DropdownButtonHideUnderline(
        child: DropdownButton<ScreenStatus?>(
          value: value,
          hint: const Text('Статус'),
          isDense: true,
          items: [
            const DropdownMenuItem(value: null, child: Text('Все статусы')),
            for (final status in ScreenStatus.values)
              DropdownMenuItem(value: status, child: Text(status.label)),
          ],
          onChanged: onChanged,
        ),
      ),
    );
  }
}

/// Универсальный чип-дропдаун по карте id→название (арендодатель/кампания).
class _DropdownFilterChip extends StatelessWidget {
  const _DropdownFilterChip({
    required this.label,
    required this.value,
    required this.options,
    required this.onChanged,
  });

  final String label;
  final String? value;
  final Map<String, String> options;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    return _FilterChipShell(
      active: value != null,
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String?>(
          value: value,
          hint: Text(label),
          isDense: true,
          items: [
            DropdownMenuItem(value: null, child: Text('Все ($label)')),
            for (final entry in options.entries)
              DropdownMenuItem(value: entry.key, child: Text(entry.value)),
          ],
          onChanged: onChanged,
        ),
      ),
    );
  }
}

/// Фильтр по городу: дропдаун активных городов из справочника (`activeCitiesProvider`).
///
/// В query уходит `city_id` (не имя) — бэк перешёл на идентификатор
/// (CONTRACT PATCH v2). Подпись активного фильтра берётся из `city.name` по
/// выбранному id. Пустой список (города ещё грузятся) → показываем только «Все».
class _CityFilterChip extends StatelessWidget {
  const _CityFilterChip({
    required this.value,
    required this.cities,
    required this.onChanged,
  });

  final int? value;
  final List<City> cities;
  final ValueChanged<int?> onChanged;

  @override
  Widget build(BuildContext context) {
    // Показываем текущее значение, только если такой город есть в списке —
    // иначе DropdownButton упадёт на assert (value без совпадающего item).
    final safeValue = cities.any((c) => c.id == value) ? value : null;

    return _FilterChipShell(
      active: value != null,
      child: DropdownButtonHideUnderline(
        child: DropdownButton<int?>(
          value: safeValue,
          hint: const Text('Город'),
          isDense: true,
          items: [
            const DropdownMenuItem(value: null, child: Text('Все (Город)')),
            for (final city in cities)
              DropdownMenuItem(value: city.id, child: Text(city.name)),
          ],
          onChanged: onChanged,
        ),
      ),
    );
  }
}

/// Фильтр по типу экрана: дропдаун типов из общего кэша (`screenTypesProvider`),
/// плюс опция «Все типы» (сброс). В query уходит `screen_type_id` (см. remote_ds).
/// Пустой список (типы ещё грузятся) → показываем только «Все типы».
class _ScreenTypeFilterChip extends StatelessWidget {
  const _ScreenTypeFilterChip({
    required this.value,
    required this.types,
    required this.onChanged,
  });

  final int? value;
  final List<ScreenType> types;
  final ValueChanged<int?> onChanged;

  @override
  Widget build(BuildContext context) {
    // Показываем текущее значение, только если такой тип есть в списке — иначе
    // DropdownButton упадёт на assert (value без совпадающего item).
    final safeValue = types.any((t) => t.id == value) ? value : null;

    return _FilterChipShell(
      active: value != null,
      child: DropdownButtonHideUnderline(
        child: DropdownButton<int?>(
          value: safeValue,
          hint: const Text('Тип экрана'),
          isDense: true,
          items: [
            const DropdownMenuItem(value: null, child: Text('Все типы')),
            for (final type in types)
              DropdownMenuItem(value: type.id, child: Text(type.name)),
          ],
          onChanged: onChanged,
        ),
      ),
    );
  }
}

class _DateFilterChip extends StatelessWidget {
  const _DateFilterChip({required this.value, required this.onChanged});

  final DateTime? value;
  final ValueChanged<DateTime?> onChanged;

  @override
  Widget build(BuildContext context) {
    return _FilterChipShell(
      active: value != null,
      child: InkWell(
        onTap: () async {
          final picked = await showDatePicker(
            context: context,
            initialDate: value ?? DateTime.now(),
            firstDate: DateTime(2020),
            lastDate: DateTime(2100),
          );
          if (picked != null) onChanged(picked);
        },
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.calendar_today_outlined, size: 14),
            const SizedBox(width: 6),
            Text(value == null ? 'Договор до' : _formatDate(value!)),
            if (value != null) ...[
              const SizedBox(width: 4),
              GestureDetector(
                onTap: () => onChanged(null),
                child: const Icon(Icons.close, size: 14),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // Ручное форматирование без intl.DateFormat — см. пояснение в screen_card_sheet.dart.
  String _formatDate(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    return '$day.$month.${date.year}';
  }
}
