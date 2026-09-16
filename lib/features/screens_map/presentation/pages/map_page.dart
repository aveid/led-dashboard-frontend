import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show BrowserContextMenu, HardwareKeyboard, KeyEvent;
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_cancellable_tile_provider/flutter_map_cancellable_tile_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../features/dashboard/presentation/providers/dashboard_providers.dart';
import '../../../../shared/widgets/admin_only.dart';
import '../../../auth/presentation/controllers/auth_providers.dart';
import '../../domain/entities/kg_boundary.dart';
import '../../domain/entities/screen.dart';
import '../kg_geo.dart';
import '../providers/geo_providers.dart';
import '../providers/relocation_notifier.dart';
import '../providers/screens_providers.dart';
import '../providers/selection_providers.dart';
import '../widgets/box_selection_overlay.dart';
import '../widgets/cost_summary_panel.dart';
import '../widgets/filters_bar.dart';
import '../widgets/screen_card_sheet.dart';
import '../widgets/screen_form_dialog.dart';
import '../widgets/screen_marker_layer.dart';

/// Страница «Карта» (FR-1): фильтры, маркеры по статусу, карточка по тапу,
/// режим выбора с расчётом стоимости и выгрузкой в Excel (FR-5, FR-6, FR-7.4).
///
/// FR-3.3: локация экранов ставится жестом по карте, а не текстом.
/// * Правый клик (web/desktop) / долгий тап (mobile) по пустому месту → меню
///   «Добавить экран» у курсора → форма с зафиксированной точкой.
/// * Правый клик / долгий тап по маркеру → «Поменять локацию» → режим
///   перемещения (центр-пин + нижняя панель «Сохранить»/«Отмена»).
/// * Левый тап по маркеру по-прежнему открывает `ScreenCardSheet`.
///
/// FR-1.7 (web/desktop-only): пока зажат Shift — drag рисует «резиновую» рамку
/// (`BoxSelectionOverlay` поверх карты), и попавшие экраны через обратную проекцию
/// камеры `addMany` в общий `selectedScreenIdsProvider`; Shift+клик по маркеру
/// делает `toggle` того же набора. На время Shift пан/поворот карты выключены
/// (`InteractionOptions.flags`), чтобы рамка = точный bbox. На мобилке Shift нет →
/// `_shiftHeld` всегда false → оверлей не монтируется. Выделение (рамкой, Shift+кликом
/// или прежним режимом выбора) едино и питает ту же панель стоимости/экспорта (FR-7.4).
///
/// Без собственного `Scaffold`/`AppBar` — они общие для всех разделов и живут в
/// `AppShell` (core/router/app_shell.dart). Локальные действия (обновить, режим
/// выбора) — в верхней панели самой страницы, а не в общем AppBar, чтобы не
/// перегружать `AppShell` знанием о деталях конкретных разделов.
class MapPage extends ConsumerStatefulWidget {
  const MapPage({super.key});

  @override
  ConsumerState<MapPage> createState() => _MapPageState();
}

class _MapPageState extends ConsumerState<MapPage> {
  final MapController _mapController = MapController();

  /// Зажат ли Shift (FR-1.7). На мобилке остаётся false → рамка не монтируется,
  /// поштучный Shift+клик недоступен, обычные тап/long-press без изменений.
  bool _shiftHeld = false;

  @override
  void initState() {
    super.initState();
    // На вебе браузер по правому клику показывает своё системное меню, которое
    // перекрывает наше `showMenu` («Добавить экран»/«Поменять локацию»). Гасим
    // нативное меню, пока открыта карта, — тогда правый клик доходит до
    // flutter_map (`onSecondaryTap`). Восстанавливаем при уходе со страницы.
    if (kIsWeb) BrowserContextMenu.disableContextMenu();
    // Глобальный слушатель клавиатуры для отслеживания Shift (FR-1.7). На платформах
    // без клавиатуры просто никогда не сработает (isShiftPressed == false).
    HardwareKeyboard.instance.addHandler(_onKey);
  }

  @override
  void dispose() {
    if (kIsWeb) BrowserContextMenu.enableContextMenu();
    HardwareKeyboard.instance.removeHandler(_onKey);
    _mapController.dispose();
    super.dispose();
  }

  /// Держим `_shiftHeld` в актуальном состоянии; событие не «съедаем» (return false),
  /// чтобы не ломать прочую обработку клавиатуры.
  bool _onKey(KeyEvent event) {
    final held = HardwareKeyboard.instance.isShiftPressed;
    if (held != _shiftHeld && mounted) setState(() => _shiftHeld = held);
    return false;
  }

  /// Пиксельная рамка → id экранов (FR-1.7, Способ A — без вращения точен).
  /// Углы рамки обратной проекцией камеры → `LatLng` → `LatLngBounds`; поскольку на
  /// время Shift поворот карты выключен, экранный прямоугольник = точный lat/lng-bbox.
  /// Тестируем СЫРЫЕ координаты экранов из screens-провайдера, поэтому в набор
  /// попадают и «спрятанные» в кластерах экраны (FR-1.5). Пишем в общий провайдер
  /// выделения — поведение идентично поштучному выбору by design.
  void _selectByRect(Rect rect, List<Screen> screens) {
    final MapCamera cam;
    try {
      cam = _mapController.camera;
    } catch (_) {
      return; // камера ещё не готова (до первой отрисовки) — рамки быть не может
    }
    final a = cam.offsetToCrs(rect.topLeft);
    final b = cam.offsetToCrs(rect.bottomRight);
    final bounds = LatLngBounds.fromPoints([a, b]);
    final ids = screens
        .where((s) => bounds.contains(LatLng(s.latitude, s.longitude)))
        .map((s) => s.id);
    ref.read(selectedScreenIdsProvider.notifier).addMany(ids);
  }

  /// Текущий центр видимой карты (для кнопки «Добавить экран» в тулбаре).
  /// До первой отрисовки карты `camera` кидает — тогда берём центр страны.
  LatLng _currentCenter() {
    try {
      return _mapController.camera.center;
    } catch (_) {
      return kKgCenter;
    }
  }

  /// Контекстное меню по пустому месту карты (FR-3.3): «Добавить экран».
  /// В режиме перемещения не показываем — там пользователь двигает центр-пин.
  /// RBAC: создание — admin only; для не-admin меню не открываем (единственный
  /// пункт был бы скрыт → меню пустое).
  Future<void> _showAddMenu(Offset globalPos, LatLng at) async {
    if (!ref.read(isAdminProvider)) return;
    if (ref.read(relocationNotifierProvider).isActive) return;
    final picked = await showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(globalPos.dx, globalPos.dy, globalPos.dx, globalPos.dy),
      items: const [
        PopupMenuItem(
          value: 'add',
          height: 48, // tap target ≥ 48px
          child: Text('Добавить экран'),
        ),
      ],
    );
    if (picked == 'add' && mounted) {
      ScreenFormDialog.show(context, initialLocation: at);
    }
  }

  /// Контекстное меню по существующему маркеру (FR-3.3): «Поменять локацию» /
  /// «Удалить экран». RBAC: обе записывающие операции — admin only; для
  /// не-admin меню не открываем.
  Future<void> _showMoveMenu(Offset globalPos, Screen screen) async {
    if (!ref.read(isAdminProvider)) return;
    final picked = await showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(globalPos.dx, globalPos.dy, globalPos.dx, globalPos.dy),
      items: const [
        PopupMenuItem(
          value: 'move',
          height: 48, // tap target ≥ 48px
          child: Text('Поменять локацию'),
        ),
        PopupMenuItem(
          value: 'delete',
          height: 48, // tap target ≥ 48px
          child: Text('Удалить экран', style: TextStyle(color: AppColors.danger)),
        ),
      ],
    );
    if (!mounted) return;
    if (picked == 'move') {
      ref.read(relocationNotifierProvider.notifier).beginRelocation(screen);
      // Ставим центр карты на текущую точку экрана, чтобы пин стартовал на маркере.
      _mapController.move(LatLng(screen.latitude, screen.longitude), _mapController.camera.zoom);
    } else if (picked == 'delete') {
      await _confirmAndDeleteScreen(screen);
    }
  }

  /// Подтверждение + удаление экрана (жест на карте). Необратимое действие —
  /// центральный диалог-подтверждение (правило UI), как у удаления вложения
  /// в `screen_card_sheet.dart`.
  Future<void> _confirmAndDeleteScreen(Screen screen) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Удалить экран'),
        content: Text('Удалить экран «${screen.name}»? Это действие необратимо.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Удалить', style: TextStyle(color: AppColors.danger)),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final result = await ref.read(deleteScreenUseCaseProvider).call(screen.id);
    if (!mounted) return;

    result.when(
      onSuccess: (_) {
        ref.invalidate(screensProvider);
        // Удаление меняет счётчики/суммы сводки (FR-9) — тоже устаревает.
        ref.invalidate(dashboardSummaryProvider);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Экран удалён.')),
        );
      },
      onFailure: (failure) => ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Не удалось удалить экран: ${failure.message}')),
      ),
    );
  }

  /// «Сохранить» в режиме перемещения: центр карты → `PATCH /location` → refetch.
  Future<void> _saveRelocation() async {
    final center = _mapController.camera.center;
    final result = await ref.read(relocationNotifierProvider.notifier).saveRelocation(
          lng: center.longitude,
          lat: center.latitude,
        );
    if (!mounted) return;
    result.when(
      onSuccess: (_) => ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Локация обновлена.')),
      ),
      onFailure: (failure) => ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            // 404 = экран удалён: список уже обновлён нотификатором, сообщаем мягко.
            failure is NotFoundFailure
                ? 'Экран был удалён. Список обновлён.'
                : 'Не удалось сохранить локацию: ${failure.message}',
          ),
        ),
      ),
    );
  }

  /// Слои маски-затемнения (FR-1.6, Вариант 2): полигон «весь мир с дыркой по
  /// контуру КР» + обводка границы. Жесты не перехватываются: у слоёв нет
  /// `hitNotifier`, поэтому pan/tap и right-click/long-press (FR-3.3) проходят
  /// сквозь маску. Свап `[lng,lat]→LatLng(lat,lng)` — в `kgRingToLatLng`.
  List<Widget> _boundaryOverlay(KgBoundary boundary) {
    final holes = boundary.rings.map(kgRingToLatLng).toList(growable: false);
    return [
      PolygonLayer(
        polygons: [
          Polygon(
            points: kWorldRing,
            holePointsList: holes, // дырки по контуру КР
            color: AppColors.mapMaskDim,
            borderStrokeWidth: 0,
          ),
        ],
      ),
      PolylineLayer(
        polylines: [
          for (final ring in holes)
            Polyline(points: ring, strokeWidth: 2, color: AppColors.primary),
        ],
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final screensAsync = ref.watch(screensProvider);
    // Граница КР для маски-затемнения (FR-1.6, Вариант 2). Грузится лениво один
    // раз; пока грузится/при ошибке — маску просто не рисуем (graceful).
    final boundaryAsync = ref.watch(kgBoundaryProvider);
    final selectMode = ref.watch(selectModeProvider);
    final selectedIds = ref.watch(selectedScreenIdsProvider);
    final relocation = ref.watch(relocationNotifierProvider);
    // Сырые экраны для выделения рамкой (FR-1.7) — те же, что и в маркерах.
    final screens = screensAsync.valueOrNull ?? const <Screen>[];

    return Column(
      children: [
        Container(
          color: AppColors.surface,
          padding: const EdgeInsets.fromLTRB(16, 12, 12, 0),
          child: Row(
            children: [
              Expanded(
                child: Text('Карта экранов', style: Theme.of(context).textTheme.titleLarge),
              ),
              // RBAC: добавление экрана — admin only (просмотр карты — всем).
              AdminOnly(
                child: FilledButton.icon(
                  // Кладём новый экран в текущий центр карты; точную точку можно
                  // также задать правым кликом/долгим тапом по карте (FR-3.3).
                  onPressed: () =>
                      ScreenFormDialog.show(context, initialLocation: _currentCenter()),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Добавить экран'),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                tooltip: selectMode ? 'Завершить выбор' : 'Выбрать экраны',
                icon: Icon(selectMode ? Icons.check_box : Icons.check_box_outline_blank),
                color: selectMode ? AppColors.primary : null,
                onPressed: () {
                  final next = !selectMode;
                  ref.read(selectModeProvider.notifier).state = next;
                  if (!next) ref.read(selectedScreenIdsProvider.notifier).clear();
                },
              ),
              IconButton(
                tooltip: 'Обновить',
                icon: const Icon(Icons.refresh),
                onPressed: () => ref.invalidate(screensProvider),
              ),
            ],
          ),
        ),
        const FiltersBar(),
        const Divider(height: 1),
        Expanded(
          child: Stack(
            children: [
              FlutterMap(
                mapController: _mapController,
                options: MapOptions(
                  initialCenter: kKgCenter,
                  initialZoom: kKgInitialZoom,
                  minZoom: kKgMinZoom,
                  maxZoom: kKgMaxZoom,
                  // FR-1.6 (Вариант 1): держим карту над КР. `containCenter` —
                  // мягкий вариант: центр всегда над страной, за край можно
                  // заглянуть. Работает офлайн (bbox локальный) и не зависит от
                  // фетча границы. `initialCenter` лежит внутри рамки → нет
                  // assert «MapCamera is no longer within the cameraConstraint».
                  cameraConstraint: CameraConstraint.containCenter(bounds: kKgBounds),
                  // FR-1.7: пока зажат Shift — выключаем drag/rotate/fling, чтобы
                  // жест рисовал рамку выделения, а не панорамировал карту (и чтобы
                  // экранный прямоугольник = точный lat/lng-bbox без поворота). Зум
                  // (колесо/дабл-тап) остаётся — рамке не мешает.
                  interactionOptions: InteractionOptions(
                    flags: _shiftHeld
                        ? (InteractiveFlag.all &
                            ~InteractiveFlag.drag &
                            ~InteractiveFlag.rotate &
                            ~InteractiveFlag.flingAnimation)
                        : InteractiveFlag.all,
                  ),
                  // Кроссплатформенно: правый клик (web/desktop) и долгий тап
                  // (mobile) по пустому месту — контекстное меню «Добавить экран».
                  onSecondaryTap: (tapPos, latLng) => _showAddMenu(tapPos.global, latLng),
                  onLongPress: (tapPos, latLng) => _showAddMenu(tapPos.global, latLng),
                ),
                children: [
                  TileLayer(
                    urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'kg.mega.led_dashboard',
                    // На вебе отменяет запросы тайлов, ушедших из области видимости
                    // (панорамирование/зум), — меньше лишнего трафика и плавнее.
                    tileProvider: CancellableNetworkTileProvider(),
                  ),
                  // FR-1.6 (Вариант 2): маска «затемнить всё, кроме КР» + обводка
                  // границы. Строго НИЖЕ маркеров, иначе затемнит их. Рисуем
                  // только когда граница загружена; пока грузится/при ошибке —
                  // пусто (рамку Варианта 1 это не трогает).
                  ...boundaryAsync.maybeWhen(
                    data: _boundaryOverlay,
                    orElse: () => const <Widget>[],
                  ),
                  screensAsync.when(
                    data: (screens) => ScreenMarkerLayer(
                      // В режиме перемещения прячем маркер целевого экрана — его
                      // роль играет центр-пин, чтобы не было двух точек сразу.
                      screens: relocation.isActive
                          ? screens.where((s) => s.id != relocation.target!.id).toList()
                          : screens,
                      selectedIds: selectedIds,
                      onTap: (screen) {
                        // Поштучный toggle в общий набор — в режиме выбора (FR-6.1)
                        // ИЛИ по Shift+клику (FR-1.7); иначе обычный тап открывает
                        // карточку. Оба пути пишут в один провайдер → «Shift+клик ==
                        // рамка по одному».
                        if (selectMode || HardwareKeyboard.instance.isShiftPressed) {
                          ref.read(selectedScreenIdsProvider.notifier).toggle(screen.id);
                        } else {
                          ScreenCardSheet.show(context, screen);
                        }
                      },
                      onContextMenu: (screen, globalPos) => _showMoveMenu(globalPos, screen),
                    ),
                    loading: () => const SizedBox.shrink(),
                    error: (_, __) => const SizedBox.shrink(),
                  ),
                ],
              ),
              // Рамка выделения по Shift (FR-1.7, web/desktop-only): монтируется
              // поверх карты только пока зажат Shift и вне режима перемещения.
              // Translucent-жест пропускает Shift+клик к маркерам; пан карты уже
              // выключен флагами, поэтому конфликта нет.
              if (_shiftHeld && !relocation.isActive)
                Positioned.fill(
                  child: BoxSelectionOverlay(
                    onSelected: (rect) => _selectByRect(rect, screens),
                  ),
                ),
              // Центр-пин режима перемещения: фиксирован по центру карты, событий
              // не ловит (IgnorePointer) — пользователь панорамирует карту под ним.
              if (relocation.isActive) const _CenterPin(),
              screensAsync.when(
                data: (_) => const SizedBox.shrink(),
                loading: () => const _LoadingOverlay(),
                error: (error, _) => _ErrorOverlay(
                  error: error,
                  onRetry: () => ref.invalidate(screensProvider),
                ),
              ),
              if (relocation.isActive)
                _RelocationPanel(
                  saving: relocation.saving,
                  onSave: _saveRelocation,
                  onCancel: () => ref.read(relocationNotifierProvider.notifier).cancelRelocation(),
                )
              // Панель стоимости/экспорта (FR-7.4) — единый downstream для любого
              // способа выделения: режим выбора, Shift+клик и рамка (FR-1.7) пишут
              // в один набор, поэтому показываем её, как только выбор непустой.
              else if (selectedIds.isNotEmpty)
                const Align(
                  alignment: Alignment.bottomCenter,
                  child: CostSummaryPanel(),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Фиксированный пин по центру карты для режима «Поменять локацию» (FR-3.3).
///
/// Кончик иконки указывает точно в центр карты: `location_on` рисуется остриём
/// вниз, поэтому смещаем её вверх на половину высоты. `IgnorePointer` — чтобы пин
/// не перехватывал жесты панорамирования карты.
class _CenterPin extends StatelessWidget {
  const _CenterPin();

  static const double _size = 48;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Center(
        child: Transform.translate(
          offset: const Offset(0, -_size / 2),
          child: const Icon(
            Icons.location_on,
            size: _size,
            color: AppColors.primary,
            shadows: [Shadow(color: Colors.black38, blurRadius: 4, offset: Offset(0, 2))],
          ),
        ),
      ),
    );
  }
}

/// Нижняя закреплённая панель режима перемещения: «Отмена» и «Сохранить»
/// (FR-3.3). Не bottom sheet со скроллом — просто панель; кнопки ≥ 48px.
class _RelocationPanel extends StatelessWidget {
  const _RelocationPanel({required this.saving, required this.onSave, required this.onCancel});

  final bool saving;
  final VoidCallback onSave;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.bottomCenter,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: const BoxDecoration(
          color: AppColors.surface,
          border: Border(top: BorderSide(color: AppColors.border)),
          boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0, -2))],
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Переместите карту так, чтобы пин встал в нужную точку.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 48,
                      child: OutlinedButton(
                        onPressed: saving ? null : onCancel,
                        child: const Text('Отмена'),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: SizedBox(
                      height: 48,
                      child: FilledButton(
                        onPressed: saving ? null : onSave,
                        child: saving
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : const Text('Сохранить'),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LoadingOverlay extends StatelessWidget {
  const _LoadingOverlay();

  @override
  Widget build(BuildContext context) {
    return const Align(
      alignment: Alignment.topCenter,
      child: Padding(
        padding: EdgeInsets.only(top: 16),
        child: _Pill(
          child: SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      ),
    );
  }
}

class _ErrorOverlay extends StatelessWidget {
  const _ErrorOverlay({required this.error, required this.onRetry});

  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final message = error is Failure ? (error as Failure).message : 'Не удалось загрузить экраны';

    return Align(
      alignment: Alignment.topCenter,
      child: Padding(
        padding: const EdgeInsets.only(top: 16),
        child: _Pill(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, color: AppColors.danger, size: 16),
              const SizedBox(width: 8),
              Flexible(child: Text(message, style: const TextStyle(fontSize: 13))),
              const SizedBox(width: 8),
              TextButton(onPressed: onRetry, child: const Text('Повторить')),
            ],
          ),
        ),
      ),
    );
  }
}

/// Небольшая «пилюля»-контейнер для оверлеев поверх карты (единый стиль).
class _Pill extends StatelessWidget {
  const _Pill({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.border),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0, 2))],
      ),
      child: child,
    );
  }
}
