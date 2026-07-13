/// Константы API: базовый URL и пути эндпоинтов бэкенда (FastAPI).
///
/// Пути соответствуют таблице API в `backend/CONTEXT.md` §5. Базовый URL берётся
/// из `--dart-define=API_URL=...`, по умолчанию — локальный бэкенд на 8000 порту
/// (как договорились: бэкенд запускается на хосте через docker compose).
abstract final class ApiConstants {
  /// Базовый URL API. Переопределяется при сборке:
  /// `flutter run --dart-define=API_URL=http://мой-сервер:8000`.
  static const String baseUrl = String.fromEnvironment(
    'API_URL',
    defaultValue: 'http://localhost:8000',
  );

  // --- Аутентификация ---
  static const String authToken = '/api/auth/token';
  static const String authMe = '/api/auth/me';

  // --- Пользователи (раздел «Пользователи», admin only) ---
  static const String users = '/api/users';

  // --- Экраны ---
  static const String screens = '/api/screens';
  static const String costSummary = '/api/screens/cost-summary';
  static const String dashboardSummary = '/api/screens/dashboard-summary';
  static const String export = '/api/screens/export';

  // --- Справочники ---
  static const String landlords = '/api/landlords';
  static const String campaigns = '/api/campaigns';
  static const String cities = '/api/cities';
  static const String screenTypes = '/api/screen-types';

  // --- География (FR-1.6: карта только КР) ---
  static const String geoKyrgyzstan = '/api/geo/kyrgyzstan';

  // --- Служебное ---
  static const String health = '/api/health';
}
