/// Арендодатель (FR-8): название и контактные данные.
class Landlord {
  const Landlord({
    required this.id,
    required this.name,
    this.contactPerson = '',
    this.phone = '',
    this.email = '',
  });

  final String id;
  final String name;
  final String contactPerson;
  final String phone;
  final String email;
}
