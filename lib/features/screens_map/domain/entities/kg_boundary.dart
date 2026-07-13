/// Точка контура границы в WGS84. Порядок полей — как отдаёт бэкенд (`[lng, lat]`).
///
/// ⚠️ Свап при рендере: `LatLng(latitude, longitude)`, а здесь хранится `lng`
/// перед `lat`. В presentation конвертируем как `LatLng(p.lat, p.lng)` (см.
/// `kg_geo.dart`). Классический источник багов — держим свап в одном месте.
class GeoPoint {
  final double lng;
  final double lat;
  const GeoPoint(this.lng, this.lat);
}

/// Граница Кыргызстана (FR-1.6): bbox + полигональные кольца контура.
///
/// Чистый Dart, без `flutter_map`/`latlong2` — домен ничего не знает о рендере.
/// [rings] `[0]` — внешний контур; кольцо может быть не замкнуто (замыкать при
/// отрисовке не требуется — `PolygonLayer`/`PolylineLayer` замыкают сами).
class KgBoundary {
  final double minLng, minLat, maxLng, maxLat;
  final List<List<GeoPoint>> rings;

  const KgBoundary({
    required this.minLng,
    required this.minLat,
    required this.maxLng,
    required this.maxLat,
    required this.rings,
  });
}
