import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Режим выбора экранов на карте (FR-6.1): вкл — тап по маркеру выделяет/снимает
/// выделение вместо открытия карточки; выкл — обычный тап открывает карточку.
final selectModeProvider = StateProvider<bool>((ref) => false);

/// Контроллер множественного выбора экранов (id выбранных маркеров).
class SelectionController extends Notifier<Set<String>> {
  @override
  Set<String> build() => const {};

  /// Переключает выбор экрана: добавляет, если не было выбрано, убирает — если было.
  void toggle(String screenId) {
    final next = Set<String>.from(state);
    if (!next.remove(screenId)) {
      next.add(screenId);
    }
    state = next;
  }

  /// Добавляет пачку экранов к выделению (union). Используется выделением рамкой
  /// по Shift (FR-1.7): каждая рамка накапливает id в тот же набор, поэтому «box»
  /// поведенчески эквивалентен многократному [toggle] на добавление. No-op, если
  /// новых id нет (не дёргаем слушателей и `costSummaryProvider` зря).
  void addMany(Iterable<String> screenIds) {
    final next = Set<String>.from(state)..addAll(screenIds);
    if (next.length == state.length) return;
    state = next;
  }

  /// Снимает выделение со всех экранов.
  void clear() => state = const {};
}

/// Провайдер выбранных id экранов.
final selectedScreenIdsProvider = NotifierProvider<SelectionController, Set<String>>(
  SelectionController.new,
);
