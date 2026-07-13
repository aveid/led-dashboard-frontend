import '../../domain/entities/kg_boundary.dart';

/// DTO границы КР (FR-1.6). Ручной парсинг, без кодогена (frontend/CONTEXT.md §1).
///
/// Зеркалит ответ `GET /api/geo/kyrgyzstan`:
/// `{ name, iso3, bbox:{min_lng,min_lat,max_lng,max_lat}, rings:[[[lng,lat],...]] }`.
/// Координаты в `rings` — пары `[lng, lat]` (float): `GeoPoint(pair[0], pair[1])`.
abstract final class KgBoundaryDto {
  static KgBoundary fromJson(Map<String, dynamic> json) {
    final bbox = json['bbox'] as Map<String, dynamic>;
    final rings = (json['rings'] as List<dynamic>).map((ring) {
      return (ring as List<dynamic>).map((pair) {
        final p = pair as List<dynamic>;
        return GeoPoint((p[0] as num).toDouble(), (p[1] as num).toDouble());
      }).toList(growable: false);
    }).toList(growable: false);

    return KgBoundary(
      minLng: (bbox['min_lng'] as num).toDouble(),
      minLat: (bbox['min_lat'] as num).toDouble(),
      maxLng: (bbox['max_lng'] as num).toDouble(),
      maxLat: (bbox['max_lat'] as num).toDouble(),
      rings: rings,
    );
  }
}
