import 'package:dio/dio.dart';

import '../../../../core/constants/api_constants.dart';
import '../../../../core/network/api_exception.dart';
import '../../domain/entities/landlord_screen_brief.dart';
import '../models/landlord_dto.dart';

/// Удалённый источник данных арендодателей: CRUD через `/api/landlords`.
class LandlordsRemoteDataSource {
  const LandlordsRemoteDataSource(this._dio);

  final Dio _dio;

  Future<List<LandlordDto>> getLandlords() async {
    try {
      final response = await _dio.get<List<dynamic>>(ApiConstants.landlords);
      return response.data!
          .map((e) => LandlordDto.fromJson(e as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  /// Экраны арендодателя (FR-8.5). Ответ — плоский JSON-массив брифов (НЕ
  /// конверт `{data, meta}`). Идёт через глобальный `dio` (JWT).
  Future<List<LandlordScreenBrief>> fetchLandlordScreens(String landlordId) async {
    try {
      final response = await _dio.get<List<dynamic>>(
        '${ApiConstants.landlords}/$landlordId/screens',
      );
      return response.data!
          .map((e) => LandlordScreenBrief.fromJson(e as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  Future<LandlordDto> createLandlord({
    required String name,
    required String contactPerson,
    required String phone,
    required String email,
  }) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        ApiConstants.landlords,
        data: {
          'name': name,
          'contact_person': contactPerson,
          'phone': phone,
          'email': email,
        },
      );
      return LandlordDto.fromJson(response.data!);
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  Future<LandlordDto> updateLandlord({
    required String id,
    String? name,
    String? contactPerson,
    String? phone,
    String? email,
  }) async {
    try {
      final response = await _dio.patch<Map<String, dynamic>>(
        '${ApiConstants.landlords}/$id',
        data: {
          if (name != null) 'name': name,
          if (contactPerson != null) 'contact_person': contactPerson,
          if (phone != null) 'phone': phone,
          if (email != null) 'email': email,
        },
      );
      return LandlordDto.fromJson(response.data!);
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  Future<void> deleteLandlord(String id) async {
    try {
      await _dio.delete<void>('${ApiConstants.landlords}/$id');
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }
}
