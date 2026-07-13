import '../../domain/entities/campaign.dart';

/// DTO кампании (зеркалит `CampaignRead` на бэке).
class CampaignDto {
  const CampaignDto({required this.id, required this.name});

  final String id;
  final String name;

  factory CampaignDto.fromJson(Map<String, dynamic> json) {
    return CampaignDto(id: json['id'] as String, name: json['name'] as String);
  }

  Campaign toDomain() => Campaign(id: id, name: name);
}
