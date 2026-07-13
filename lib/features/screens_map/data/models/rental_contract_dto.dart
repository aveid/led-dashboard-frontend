import '../../domain/entities/rental_contract.dart';
import 'money_dto.dart';

/// DTO договора аренды (зеркалит `RentalContractSchema` на бэке).
class RentalContractDto {
  const RentalContractDto({
    required this.rentPrice,
    required this.startDate,
    required this.endDate,
    this.id,
  });

  final String? id;
  final MoneyDto rentPrice;
  final DateTime startDate;
  final DateTime endDate;

  factory RentalContractDto.fromJson(Map<String, dynamic> json) {
    return RentalContractDto(
      id: json['id'] as String?,
      rentPrice: MoneyDto.fromJson(json['rent_price'] as Map<String, dynamic>),
      startDate: DateTime.parse(json['start_date'] as String),
      endDate: DateTime.parse(json['end_date'] as String),
    );
  }

  RentalContract toDomain() => RentalContract(
        id: id,
        rentPrice: rentPrice.toDomain(),
        startDate: startDate,
        endDate: endDate,
      );
}
