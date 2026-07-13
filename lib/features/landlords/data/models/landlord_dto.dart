import '../../domain/entities/landlord.dart';

/// DTO арендодателя (зеркалит `LandlordRead` на бэке).
class LandlordDto {
  const LandlordDto({
    required this.id,
    required this.name,
    required this.contactPerson,
    required this.phone,
    required this.email,
  });

  final String id;
  final String name;
  final String contactPerson;
  final String phone;
  final String email;

  factory LandlordDto.fromJson(Map<String, dynamic> json) {
    return LandlordDto(
      id: json['id'] as String,
      name: json['name'] as String,
      contactPerson: json['contact_person'] as String? ?? '',
      phone: json['phone'] as String? ?? '',
      email: json['email'] as String? ?? '',
    );
  }

  Landlord toDomain() => Landlord(
        id: id,
        name: name,
        contactPerson: contactPerson,
        phone: phone,
        email: email,
      );
}
