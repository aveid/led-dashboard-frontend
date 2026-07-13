/// Денежная сумма: величина + валюта (зеркалит `Money` на бэке — только KGS сейчас).
///
/// Иммутабельный value object без кодогена (`final`-поля, ручное сравнение).
/// Форматирование для отображения — в `core/utils/money_formatter.dart`, чтобы
/// сам тип оставался «глупым» контейнером данных, а не знал про intl/локаль.
class Money {
  const Money({required this.amount, this.currency = 'KGS'});

  final double amount;
  final String currency;

  @override
  bool operator ==(Object other) =>
      other is Money && other.amount == amount && other.currency == currency;

  @override
  int get hashCode => Object.hash(amount, currency);

  @override
  String toString() => '$amount $currency';
}
