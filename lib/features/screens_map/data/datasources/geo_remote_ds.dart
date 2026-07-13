import 'package:dio/dio.dart';

import '../../../../core/constants/api_constants.dart';
import '../../../../core/network/api_exception.dart';
import '../models/kg_boundary_dto.dart';
import '../../domain/entities/kg_boundary.dart';

/// Удалённый источник границы КР (FR-1.6): `GET /api/geo/kyrgyzstan` через
/// глобальный dio (JWT-интерсептор). Бросает [ApiException].
class GeoRemoteDataSource {
  const GeoRemoteDataSource(this._dio);

  final Dio _dio;

  Future<KgBoundary> fetchKgBoundary() async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(ApiConstants.geoKyrgyzstan);
      return KgBoundaryDto.fromJson(response.data!);
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }
}
