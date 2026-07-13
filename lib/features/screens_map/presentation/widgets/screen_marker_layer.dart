import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_marker_cluster/flutter_map_marker_cluster.dart';
import 'package:latlong2/latlong.dart';

import '../../../../core/theme/app_colors.dart';
import '../../domain/entities/screen.dart';

/// Строит слой маркеров экранов для `FlutterMap` (FR-1.2/1.3, FR-1.5, FR-6.1).
///
/// Каждый маркер — точка экрана, цвет которой берётся из его статуса
/// (`ScreenStatus.color`, единый источник цвета — см. `shared/domain/screen_status.dart`).
/// Тап по маркеру вызывает [onTap] с самим экраном; что именно происходит по тапу
/// (открыть карточку или переключить выбор) решает вызывающий код (`map_page.dart`)
/// в зависимости от режима выбора — слой маркеров сам режим не знает.
/// [selectedIds] — только для отрисовки кольца вокруг выбранных маркеров.
///
/// Близко стоящие/перекрывающиеся маркеры объединяются в кластер-бабл с числом
/// экранов (FR-1.5): чисто клиентская агрегация (`markers.length`), бэкенд ничего
/// не считает. При приближении карты кластеры распадаются на одиночные маркеры,
/// сохраняющие статусную раскраску. Тап по одиночному маркеру по-прежнему идёт
/// через `GestureDetector` внутри его `child` (см. [_ScreenMarkerIcon]).
class ScreenMarkerLayer extends StatelessWidget {
  const ScreenMarkerLayer({
    required this.screens,
    required this.onTap,
    required this.onContextMenu,
    this.selectedIds = const {},
    super.key,
  });

  final List<Screen> screens;
  final ValueChanged<Screen> onTap;

  /// Контекстное меню маркера (FR-3.3): правый клик / долгий тап по одиночному
  /// маркеру. Передаёт экран и глобальную позицию курсора для позиционирования
  /// `showMenu`. Жест «съедается» самим маркером, чтобы карта не поймала его как
  /// secondary tap по пустому месту (иначе всплыло бы меню «Добавить экран»).
  final void Function(Screen screen, Offset globalPosition) onContextMenu;
  final Set<String> selectedIds;

  static const double _markerSize = 34;

  @override
  Widget build(BuildContext context) {
    return MarkerClusterLayerWidget(
      options: MarkerClusterLayerOptions(
        markers: [
          for (final screen in screens)
            Marker(
              point: LatLng(screen.latitude, screen.longitude),
              width: _markerSize + 10,
              height: _markerSize + 10,
              alignment: Alignment.topCenter,
              child: _ScreenMarkerIcon(
                screen: screen,
                isSelected: selectedIds.contains(screen.id),
                onTap: () => onTap(screen),
                onContextMenu: (globalPos) => onContextMenu(screen, globalPos),
              ),
            ),
        ],
        // Радиус объединения в ПИКСЕЛЯХ: сливаются только реально перекрывающиеся
        // / очень близкие маркеры. При zoom in те же экраны расходятся по пикселям
        // и выходят за радиус → кластер распадается сам (спец-кода не нужно).
        maxClusterRadius: 50,
        size: const Size(48, 48), // tap target бабла ≥ 48px
        alignment: Alignment.center,
        padding: const EdgeInsets.all(50),
        maxZoom: 17, // при зуме ≥ этого значения кластеров нет
        // Тап по кластеру приближает карту к границам дочерних маркеров.
        zoomToBoundsOnClick: true,
        // Экраны в почти одной координате не разъедутся даже на макс. зуме —
        // spiderfy «распушивает» их веером, чтобы тапнуть по каждому отдельно.
        spiderfyCluster: true,
        builder: (context, clusterMarkers) => _ClusterBubble(count: clusterMarkers.length),
      ),
    );
  }
}

/// Бабл кластера: нейтральный/брендовый кружок с числом экранов внутри (FR-1.5).
///
/// Кластер намеренно НЕ красим по `ScreenStatus` — внутри могут быть экраны разных
/// статусов. Статусная раскраска остаётся у одиночных маркеров ([_ScreenMarkerIcon]).
class _ClusterBubble extends StatelessWidget {
  const _ClusterBubble({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.primary, // бренд MEGA, без хардкода — из app_colors.dart
        border: Border.all(color: AppColors.surface, width: 2),
        boxShadow: const [
          BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 2)),
        ],
      ),
      child: Text(
        '$count',
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: 14,
        ),
      ),
    );
  }
}

class _ScreenMarkerIcon extends StatelessWidget {
  const _ScreenMarkerIcon({
    required this.screen,
    required this.isSelected,
    required this.onTap,
    required this.onContextMenu,
  });

  final Screen screen;
  final bool isSelected;
  final VoidCallback onTap;
  final ValueChanged<Offset> onContextMenu;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      // opaque: маркер «съедает» правый клик/долгий тап, чтобы MapOptions карты не
      // получил secondary tap и не открыл меню «Добавить экран» поверх маркера.
      behavior: HitTestBehavior.opaque,
      onTap: onTap, // левый тап — прежнее поведение (карточка/выбор)
      onSecondaryTapDown: (d) => onContextMenu(d.globalPosition), // web/desktop
      onLongPressStart: (d) => onContextMenu(d.globalPosition), // mobile
      child: Tooltip(
        message: screen.name,
        child: Stack(
          alignment: Alignment.center,
          clipBehavior: Clip.none,
          children: [
            if (isSelected)
              Container(
                width: ScreenMarkerLayer._markerSize + 10,
                height: ScreenMarkerLayer._markerSize + 10,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.primary, width: 2.5),
                ),
              ),
            Icon(
              Icons.location_on,
              color: screen.status.color,
              size: ScreenMarkerLayer._markerSize,
              shadows: const [Shadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 2))],
            ),
            if (isSelected)
              const Positioned(
                bottom: 4,
                child: Icon(Icons.check_circle, color: AppColors.primary, size: 14),
              ),
          ],
        ),
      ),
    );
  }
}
