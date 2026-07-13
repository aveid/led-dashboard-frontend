import '../../../../shared/domain/money.dart';

/// Договор аренды экрана за период (Q3 — элемент истории аренды на бэке).
///
/// На фронте видим только текущее состояние (список `rentals` от API уже
/// содержит то, что нужно показать — сейчас практически всегда один текущий
/// договор при активном статусе, полная история — задел на будущий UI).
class RentalContract {
  const RentalContract({
    required this.rentPrice,
    required this.startDate,
    required this.endDate,
    this.id,
  });

  final String? id;
  final Money rentPrice;
  final DateTime startDate;
  final DateTime endDate;
}
