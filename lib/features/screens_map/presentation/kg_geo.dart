import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../domain/entities/kg_boundary.dart';

/// Гео-константы и хелперы карты «только Кыргызстан» (FR-1.6). Чистая
/// presentation-обвязка вокруг `flutter_map`/`latlong2`.

/// Fallback-рамка КР (совпадает с backend bbox). Работает офлайн/до фетча
/// границы, поэтому «жёсткое» ограничение камеры не зависит от сети (Вариант 1).
/// `LatLng(lat, lng)`: SW — минимальные, NE — максимальные координаты.
final LatLngBounds kKgBounds = LatLngBounds(
  const LatLng(39.17, 69.24), // SW (lat, lng)
  const LatLng(43.27, 80.28), // NE (lat, lng)
);

/// Ниже — уже видно пол-Азии; тюнить 6..7 при необходимости.
const double kKgMinZoom = 6.0;

/// Как в остальной карте/кластерах.
const double kKgMaxZoom = 18.0;

/// Стартовый центр карты (примерно центр КР). Лежит внутри [kKgBounds], поэтому
/// `initialCenter`+`initialZoom` не нарушают cameraConstraint (assert flutter_map
/// «MapCamera is no longer within the cameraConstraint»).
const LatLng kKgCenter = LatLng(41.20, 74.60);

/// Стартовый зум обзора страны (внутри [kKgMinZoom]..[kKgMaxZoom]).
const double kKgInitialZoom = 7.0;

/// «Весь мир» как внешний контур маски-затемнения (Вариант 2). Дырки по контуру
/// КР вырезаются через `Polygon.holePointsList`.
const List<LatLng> kWorldRing = [
  LatLng(85, -180),
  LatLng(85, 180),
  LatLng(-85, 180),
  LatLng(-85, -180),
];

/// Свап `[lng, lat] → LatLng(lat, lng)`: доменные [GeoPoint] контура → точки
/// `flutter_map`. Держим свап здесь, чтобы источник багов был в одном месте.
List<LatLng> kgRingToLatLng(List<GeoPoint> ring) =>
    ring.map((p) => LatLng(p.lat, p.lng)).toList(growable: false);
