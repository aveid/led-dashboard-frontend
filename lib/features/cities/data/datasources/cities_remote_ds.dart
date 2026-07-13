import 'package:dio/dio.dart';

import '../../../../core/constants/api_constants.dart';
import '../../../../core/network/api_exception.dart';
import '../models/city_model.dart';

/// 409 при создании/изменении города — город с таким названием уже существует.
class CityConflictException implements Exception {
  const CityConflictException([this.message = 'Город с таким названием уже существует.']);
  final String message;

  @override
  String toString() => 'CityConflictException($message)';
}

/// 409 при удалении города — у города есть привязанные экраны.
class CityInUseException implements Exception {
  const CityInUseException([this.message = 'У города есть привязанные экраны.']);
  final String message;

  @override
  String toString() => 'CityInUseException($message)';
}

/// Удалённый источник данных городов: CRUD через `/api/cities`.
///
/// Конфликты (HTTP 409) переводятся в осмысленные доменные исключения, потому что
/// смысл 409 зависит от операции: на создании/изменении это дубликат имени, на
/// удалении — привязанные экраны. Репозиторий превращает их в `Failure`.
class CitiesRemoteDataSource {
  const CitiesRemoteDataSource(this._dio);

  final Dio _dio;

  Future<List<CityModel>> getCities({bool onlyActive = false}) async {
    try {
      final response = await _dio.get<List<dynamic>>(
        ApiConstants.cities,
        queryParameters: {'only_active': onlyActive},
      );
      return response.data!
          .map((e) => CityModel.fromJson(e as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  Future<CityModel> createCity(String name) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        ApiConstants.cities,
        data: {'name': name.trim()},
      );
      return CityModel.fromJson(response.data!);
    } on DioException catch (e) {
      if (e.response?.statusCode == 409) {
        throw CityConflictException(ApiException.fromDio(e).message);
      }
      throw ApiException.fromDio(e);
    }
  }

  Future<CityModel> updateCity(int id, {String? name, bool? isActive}) async {
    try {
      final response = await _dio.patch<Map<String, dynamic>>(
        '${ApiConstants.cities}/$id',
        data: {
          if (name != null) 'name': name.trim(),
          if (isActive != null) 'is_active': isActive,
        },
      );
      return CityModel.fromJson(response.data!);
    } on DioException catch (e) {
      if (e.response?.statusCode == 409) {
        throw CityConflictException(ApiException.fromDio(e).message);
      }
      throw ApiException.fromDio(e);
    }
  }

  Future<void> deleteCity(int id) async {
    try {
      await _dio.delete<void>('${ApiConstants.cities}/$id');
    } on DioException catch (e) {
      if (e.response?.statusCode == 409) {
        throw CityInUseException(ApiException.fromDio(e).message);
      }
      throw ApiException.fromDio(e);
    }
  }
}
