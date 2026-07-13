import 'dart:html' as html;

/// Скачивает байты как файл в браузере (для выгрузки Excel, FR-7).
///
/// Использует `dart:html` — проект целиком Flutter Web (без мобильных/десктоп
/// таргетов, см. frontend/CONTEXT.md §1), поэтому условных импортов под другие
/// платформы не делаем. Работает при обычной сборке (`flutter build web`,
/// компилятор dart2js/dartdevc); для WASM-таргета (`--wasm`) потребовалась бы
/// миграция на `package:web` — сейчас этот таргет не используется.
void saveBytesAsFile(List<int> bytes, String filename) {
  final blob = html.Blob([bytes]);
  final url = html.Url.createObjectUrlFromBlob(blob);
  html.AnchorElement(href: url)
    ..setAttribute('download', filename)
    ..click();
  html.Url.revokeObjectUrl(url);
}
