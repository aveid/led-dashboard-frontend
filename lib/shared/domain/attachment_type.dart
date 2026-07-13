/// Тип вложения экрана (FR-3.12/3.13). Значения совпадают с бэком
/// (`AttachmentType` в `features/screens/domain/enums.py`).
enum AttachmentType {
  photo('photo', 'Фото'),
  contract('contract', 'Договор'),
  other('other', 'Документ');

  const AttachmentType(this.value, this.label);

  final String value;
  final String label;

  static AttachmentType fromValue(String value) {
    return AttachmentType.values.firstWhere(
      (type) => type.value == value,
      orElse: () => AttachmentType.other,
    );
  }
}
