/// Зеркало серверного правила лимита вложений (SSOT — авторитет за бэкендом).
///
/// Максимум вложений КАЖДОГО вида на экран: фото и документы считаются
/// РАЗДЕЛЬНО (до 10 всего). Клиентская проверка — только для UX; финальную
/// валидацию всегда делает бэкенд (см. обработку HTTP 409 в
/// `ScreensRepositoryImpl.uploadAttachment` → `AttachmentLimitFailure`).
const int kMaxAttachmentsPerKind = 5; // mirror of backend SSOT (server is authoritative)
