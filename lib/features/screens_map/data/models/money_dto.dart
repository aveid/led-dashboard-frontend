import '../../../../shared/domain/money.dart';

/// DTO суммы (зеркалит `MoneySchema` на бэке: `{"amount": ..., "currency": "KGS"}`).
///
/// `amount` у FastAPI/Pydantic (Decimal) в JSON приходит числом — но на всякий
/// случай разбираем и строку тоже (`num.parse`), чтобы не упасть на граничных
/// случаях сериализации.
class MoneyDto {
  const MoneyDto({required this.amount, required this.currency});

  final double amount;
  final String currency;

  factory MoneyDto.fromJson(Map<String, dynamic> json) {
    final rawAmount = json['amount'];
    final amount = rawAmount is num ? rawAmount.toDouble() : double.parse(rawAmount as String);
    return MoneyDto(amount: amount, currency: json['currency'] as String? ?? 'KGS');
  }

  Money toDomain() => Money(amount: amount, currency: currency);
}
