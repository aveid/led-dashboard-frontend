import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../../../features/cities/domain/entities/city.dart';
import '../../../../features/cities/presentation/providers/cities_providers.dart';
import '../../../../features/dashboard/presentation/providers/dashboard_providers.dart';
import '../../../../features/screen_types/domain/entities/screen_type.dart';
import '../../../../features/screen_types/presentation/providers/screen_types_providers.dart';
import '../../../../shared/domain/screen_status.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_text_field.dart';
import '../../domain/entities/screen.dart';
import '../providers/reference_providers.dart';
import '../providers/screens_providers.dart';

/// Диалог создания/редактирования экрана (FR-10.1/10.2).
///
/// Один виджет на оба сценария: [existing] == null → создание, иначе — правка.
/// Дропдаун статуса предлагает все значения `ScreenStatus` **кроме «Активный»**:
/// перевести экран в `active` можно только через `ActivateScreenDialog` (кнопка
/// «Активировать» в карточке — см. `screen_card_sheet.dart`), где обязательны
/// фото + цена + даты (FR-4). Исключение — уже-active экран: его текущий статус
/// остаётся в списке, чтобы отобразить и сохранить состояние без ложного
/// даунгрейда; переключить его на не-active (деактивация) через форму можно.
class ScreenFormDialog extends ConsumerStatefulWidget {
  const ScreenFormDialog({this.existing, this.initialLocation, super.key});

  final Screen? existing;

  /// Точка, в которой создаётся новый экран (FR-3.3): приходит из контекстного
  /// меню «Добавить экран» по клику/долгому тапу на карте. Полей ввода координат
  /// в диалоге больше нет. Игнорируется при редактировании — там локация вообще
  /// не меняется в диалоге (для смены есть жест «Поменять локацию» на карте).
  final LatLng? initialLocation;

  static Future<void> show(
    BuildContext context, {
    Screen? existing,
    LatLng? initialLocation,
  }) {
    return showDialog<void>(
      context: context,
      builder: (context) => ScreenFormDialog(
        existing: existing,
        initialLocation: initialLocation,
      ),
    );
  }

  @override
  ConsumerState<ScreenFormDialog> createState() => _ScreenFormDialogState();
}

class _ScreenFormDialogState extends ConsumerState<ScreenFormDialog> {
  final _formKey = GlobalKey<FormState>();

  late final _nameController = TextEditingController(text: widget.existing?.name);
  late final _sizeController = TextEditingController(text: widget.existing?.size);
  late final _commentController = TextEditingController(text: widget.existing?.comment);

  late ScreenStatus _status = widget.existing?.status ?? ScreenStatus.potential;
  late int? _selectedCityId = widget.existing?.city.id;
  late int? _selectedScreenTypeId = widget.existing?.screenTypeId;
  late String? _landlordId = widget.existing?.landlordId;
  late String? _campaignId = widget.existing?.currentCampaignId;

  /// Дата окончания аренды (FR-4.4). Необязательная, очищаемая. При сохранении
  /// уходит как `YYYY-MM-DD`; при `null` на редактировании отправляется явный
  /// null, чтобы бэк снял срок (см. `_submit`).
  late DateTime? _rentalEndDate = widget.existing?.rentalEndDate;

  bool _isSubmitting = false;
  String? _error;

  bool get _isEditing => widget.existing != null;

  @override
  void dispose() {
    _nameController.dispose();
    _sizeController.dispose();
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    // Валидирует поля-формы (город обязателен, см. валидатор дропдауна).
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final cityId = _selectedCityId;
    if (cityId == null) {
      setState(() => _error = 'Выберите город.');
      return;
    }

    // Размер обязателен и непуст (в т.ч. у мигрированного экрана с пустым size).
    final size = _sizeController.text.trim();
    if (size.isEmpty) {
      setState(() => _error = 'Введите размер экрана.');
      return;
    }
    if (size.length > 100) {
      setState(() => _error = 'Размер не длиннее 100 символов.');
      return;
    }

    // Тип экрана обязателен — без него сохранять нельзя (бэк вернёт 422).
    final screenTypeId = _selectedScreenTypeId;
    if (screenTypeId == null) {
      setState(() => _error = 'Выберите тип экрана.');
      return;
    }

    // Координаты при создании берутся из точки на карте (FR-3.3), а не из полей.
    // При редактировании локация в диалоге не трогается — меняется жестом на карте.
    final location = widget.initialLocation;
    if (!_isEditing && location == null) {
      setState(() => _error = 'Точка на карте не выбрана.');
      return;
    }

    setState(() {
      _isSubmitting = true;
      _error = null;
    });

    final campaignIds = _campaignId == null ? <String>[] : [_campaignId!];

    final result = _isEditing
        ? await ref.read(updateScreenUseCaseProvider).call(
              id: widget.existing!.id,
              name: _nameController.text,
              cityId: cityId,
              size: size,
              screenTypeId: screenTypeId,
              status: _status,
              landlordId: _landlordId,
              campaignIds: campaignIds,
              comment: _commentController.text,
              // Срок аренды (FR-4.4): дата → отправить, пусто → явный null (снять
              // срок). Форма всегда отражает текущее состояние, поэтому шлём его.
              rentalEndDate: _rentalEndDate,
              clearRentalEndDate: _rentalEndDate == null,
            )
        : await ref.read(createScreenUseCaseProvider).call(
              name: _nameController.text,
              cityId: cityId,
              size: size,
              screenTypeId: screenTypeId,
              latitude: location!.latitude,
              longitude: location.longitude,
              status: _status,
              landlordId: _landlordId,
              campaignIds: campaignIds,
              comment: _commentController.text,
              rentalEndDate: _rentalEndDate,
            );

    if (!mounted) return;

    result.when(
      onSuccess: (_) {
        ref.invalidate(screensProvider);
        // Создание/правка меняет статус, цену, арендодателя или срок аренды —
        // всё это входит в сводку дашборда (FR-9), поэтому она тоже устаревает.
        ref.invalidate(dashboardSummaryProvider);
        Navigator.of(context).pop();
      },
      onFailure: (failure) {
        setState(() {
          _isSubmitting = false;
          _error = failure.message;
        });
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final landlordNames = ref.watch(landlordNamesProvider).valueOrNull ?? const {};
    final campaignNames = ref.watch(campaignNamesProvider).valueOrNull ?? const {};
    final citiesAsync = ref.watch(activeCitiesProvider);
    final screenTypesAsync = ref.watch(screenTypesProvider);

    return AlertDialog(
      title: Text(_isEditing ? 'Редактировать экран' : 'Новый экран'),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AppTextField(label: 'Название', controller: _nameController, autofocus: true),
                const SizedBox(height: 12),
                AppTextField(
                  label: 'Размер экрана *',
                  controller: _sizeController,
                  hintText: 'Напр. 1920x1080 или 55"',
                ),
                const SizedBox(height: 12),
                _buildScreenTypeDropdown(screenTypesAsync),
                const SizedBox(height: 12),
                _buildCityDropdown(citiesAsync),
                const SizedBox(height: 12),
                _buildStatusDropdown(),
                const SizedBox(height: 12),
                _buildRentalEndDateRow(),
                const SizedBox(height: 12),
                _buildDropdown(
                  label: 'Арендодатель',
                  value: _landlordId,
                  options: landlordNames,
                  onChanged: (id) => setState(() => _landlordId = id),
                ),
                const SizedBox(height: 12),
                _buildDropdown(
                  label: 'Кампания',
                  value: _campaignId,
                  options: campaignNames,
                  onChanged: (id) => setState(() => _campaignId = id),
                ),
                const SizedBox(height: 12),
                AppTextField(label: 'Комментарий', controller: _commentController),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(_error!, style: const TextStyle(color: Colors.red, fontSize: 13)),
                ],
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
          child: const Text('Отмена'),
        ),
        SizedBox(
          width: 140,
          child: AppButton(
            label: _isEditing ? 'Сохранить' : 'Создать',
            isLoading: _isSubmitting,
            onPressed: _submit,
          ),
        ),
      ],
    );
  }

  /// Дропдаун выбора города из БД (`activeCitiesProvider`, только активные).
  ///
  /// Состояния: `loading` → неактивное поле со спиннером; `error` → сообщение +
  /// «Повторить»; `data` → список городов с обязательным выбором. При
  /// редактировании город экрана добавляется в список, даже если он стал
  /// неактивным, чтобы текущий выбор оставался валидным.
  Widget _buildCityDropdown(AsyncValue<List<City>> citiesAsync) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Город', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 6),
        citiesAsync.when(
          data: (cities) {
            final options = [...cities];
            final existingCity = widget.existing?.city;
            if (existingCity != null && !options.any((c) => c.id == existingCity.id)) {
              options.insert(0, existingCity);
            }
            return DropdownButtonFormField<int>(
              value: _selectedCityId,
              isExpanded: true,
              decoration: const InputDecoration(hintText: 'Выберите город'),
              items: [
                for (final city in options) DropdownMenuItem(value: city.id, child: Text(city.name)),
              ],
              validator: (value) => value == null ? 'Выберите город' : null,
              onChanged: (value) => setState(() => _selectedCityId = value),
            );
          },
          loading: () => const InputDecorator(
            decoration: InputDecoration(),
            child: Row(
              children: [
                Text('Загрузка городов…'),
                Spacer(),
                SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ],
            ),
          ),
          error: (_, __) => InputDecorator(
            decoration: const InputDecoration(),
            child: Row(
              children: [
                const Expanded(child: Text('Не удалось загрузить города')),
                TextButton(
                  onPressed: () => ref.invalidate(citiesProvider),
                  child: const Text('Повторить'),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// Дропдаун выбора типа экрана (`screenTypesProvider`, общий кэш с разделом
  /// «Тип экрана» и фильтром). Обязателен, без пустой опции «не выбрано».
  ///
  /// Состояния: `loading` → поле со спиннером; `error` → сообщение + «Повторить»;
  /// `data` → список типов. При редактировании текущий тип экрана добавляется в
  /// список, даже если его нет в свежей выборке, чтобы выбор оставался валидным.
  Widget _buildScreenTypeDropdown(AsyncValue<List<ScreenType>> typesAsync) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Тип экрана *', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 6),
        typesAsync.when(
          data: (types) {
            final options = [...types];
            final existingType = widget.existing?.screenType;
            if (existingType != null && !options.any((t) => t.id == existingType.id)) {
              options.insert(0, existingType);
            }
            return DropdownButtonFormField<int>(
              value: _selectedScreenTypeId,
              isExpanded: true,
              decoration: const InputDecoration(hintText: 'Выберите тип экрана'),
              items: [
                for (final type in options)
                  DropdownMenuItem(value: type.id, child: Text(type.name)),
              ],
              validator: (value) => value == null ? 'Выберите тип экрана' : null,
              onChanged: (value) => setState(() => _selectedScreenTypeId = value),
            );
          },
          loading: () => const InputDecorator(
            decoration: InputDecoration(),
            child: Row(
              children: [
                Text('Загрузка типов…'),
                Spacer(),
                SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ],
            ),
          ),
          error: (_, __) => InputDecorator(
            decoration: const InputDecoration(),
            child: Row(
              children: [
                const Expanded(child: Text('Не удалось загрузить типы')),
                TextButton(
                  onPressed: () => ref.invalidate(screenTypesProvider),
                  child: const Text('Повторить'),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStatusDropdown() {
    // Опции = все статусы, кроме `active`. Исключение: если редактируемый экран
    // уже `active`, оставляем `active` в списке (текущее значение, без ложного
    // даунгрейда). Активация не-active экрана — только через `ActivateScreenDialog`.
    final currentStatus = widget.existing?.status;
    final statusOptions = ScreenStatus.values
        .where((s) => s != ScreenStatus.active || s == currentStatus)
        .toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Статус', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 6),
        DropdownButtonFormField<ScreenStatus>(
          value: _status,
          items: [
            for (final status in statusOptions)
              DropdownMenuItem(value: status, child: Text(status.label)),
          ],
          onChanged: (value) {
            if (value != null) setState(() => _status = value);
          },
        ),
      ],
    );
  }

  /// Строка выбора даты окончания аренды (FR-4.4): текст даты + «Выбрать»/«Очистить».
  ///
  /// Поле необязательное. По истечении срока бэк сам архивирует экран при чтении
  /// — здесь только задаём/показываем дату. Нужно для правки срока у уже-active
  /// экранов и для реактивации (FR-4.4). Мягкого предупреждения про `active` без
  /// даты больше нет: `active` из формы не выбирается (см. `_buildStatusDropdown`).
  Widget _buildRentalEndDateRow() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Дата окончания аренды', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 6),
        Row(
          children: [
            Expanded(
              child: Text(
                _rentalEndDate == null ? 'Не задана' : _formatDate(_rentalEndDate!),
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
            ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 48), // тап-таргет ≥ 48px
              child: TextButton.icon(
                onPressed: _pickRentalEndDate,
                icon: const Icon(Icons.calendar_today_outlined, size: 16),
                label: const Text('Выбрать'),
              ),
            ),
            if (_rentalEndDate != null)
              ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 48),
                child: TextButton(
                  onPressed: () => setState(() => _rentalEndDate = null),
                  child: const Text('Очистить'),
                ),
              ),
          ],
        ),
      ],
    );
  }

  Future<void> _pickRentalEndDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      locale: const Locale('ru'),
      initialDate: _rentalEndDate ?? now,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => _rentalEndDate = picked);
  }

  /// `dd.MM.yyyy` без intl.DateFormat (см. пояснение в `screen_card_sheet.dart`).
  String _formatDate(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    return '$day.$month.${date.year}';
  }

  Widget _buildDropdown({
    required String label,
    required String? value,
    required Map<String, String> options,
    required ValueChanged<String?> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 6),
        DropdownButtonFormField<String?>(
          value: value,
          items: [
            const DropdownMenuItem(value: null, child: Text('Не указан')),
            for (final entry in options.entries) DropdownMenuItem(value: entry.key, child: Text(entry.value)),
          ],
          onChanged: onChanged,
        ),
      ],
    );
  }
}
