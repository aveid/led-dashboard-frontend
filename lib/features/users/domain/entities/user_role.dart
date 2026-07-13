/// Роль пользователя (RBAC, NFR-8).
///
/// Три роли: [admin] — полный доступ (раздел «Пользователи» + любые изменения
/// экранов и справочников); [user] — только просмотр/экспорт, без кнопок записи;
/// [guest] — как [user] по доступу, но с доп-ограничениями UX (скрыт договор,
/// цены рендерятся пустой строкой — см. `isGuestProvider`/`guestPriceText`).
///
/// Парсинг из строки безопасный: неизвестное значение трактуем как [user] —
/// это самый ограниченный «полноценный» доступ (fail-safe: по умолчанию НЕ
/// показываем admin-контролы). Неизвестное НЕ трактуем как [guest], чтобы
/// случайно не спрятать цены/договор у обычного наблюдателя.
enum UserRole {
  admin,
  user,
  guest;

  /// Строка бэкенда (`"admin"`/`"user"`/`"guest"`) → [UserRole]. Неизвестное → [user].
  static UserRole fromApi(String? raw) {
    return switch (raw) {
      'admin' => UserRole.admin,
      'guest' => UserRole.guest,
      _ => UserRole.user,
    };
  }

  /// Значение для тела запроса (`role`): `"admin"`/`"user"`/`"guest"`.
  String get asApi => name;

  /// Человекочитаемая подпись для UI (бейджи, дропдаун).
  String get label => switch (this) {
        UserRole.admin => 'Администратор',
        UserRole.user => 'Наблюдатель',
        UserRole.guest => 'Гость',
      };
}
