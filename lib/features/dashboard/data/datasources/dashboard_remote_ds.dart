import 'package:dio/dio.dart';

import '../../../../core/constants/api_constants.dart';
import '../../../../core/network/api_exception.dart';
import '../models/dashboard_summary_dto.dart';

/// Удалённый источник данных сводки дашборда: `GET /api/screens/dashboard-summary`.
class DashboardRemoteDataSource {
  const DashboardRemoteDataSource(this._dio);

  final Dio _dio;

  Future<DashboardSummaryDto> getSummary({int thresholdDays = 30}) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        ApiConstants.dashboardSummary,
        queryParameters: {'threshold_days': thresholdDays},
      );
      return DashboardSummaryDto.fromJson(response.data!);
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }
}
