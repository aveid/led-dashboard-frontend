import 'package:dio/dio.dart';

import '../../../../core/constants/api_constants.dart';
import '../../../../core/network/api_exception.dart';
import '../models/campaign_dto.dart';

/// Удалённый источник данных кампаний: CRUD через `/api/campaigns`.
class CampaignsRemoteDataSource {
  const CampaignsRemoteDataSource(this._dio);

  final Dio _dio;

  Future<List<CampaignDto>> getCampaigns() async {
    try {
      final response = await _dio.get<List<dynamic>>(ApiConstants.campaigns);
      return response.data!
          .map((e) => CampaignDto.fromJson(e as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  Future<CampaignDto> createCampaign(String name) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        ApiConstants.campaigns,
        data: {'name': name},
      );
      return CampaignDto.fromJson(response.data!);
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  Future<CampaignDto> updateCampaign({required String id, required String name}) async {
    try {
      final response = await _dio.patch<Map<String, dynamic>>(
        '${ApiConstants.campaigns}/$id',
        data: {'name': name},
      );
      return CampaignDto.fromJson(response.data!);
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  Future<void> deleteCampaign(String id) async {
    try {
      await _dio.delete<void>('${ApiConstants.campaigns}/$id');
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }
}
