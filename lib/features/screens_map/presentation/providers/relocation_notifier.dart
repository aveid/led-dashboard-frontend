import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/error/result.dart';
import '../../domain/entities/screen.dart';
import 'screens_providers.dart';

/// Состояние режима «поменять локацию» (FR-3.3).
///
/// [target] — экран, который сейчас перетаскивают (null = режим выключен).
/// [saving] — идёт запрос `PATCH /location`, кнопка «Сохранить» блокируется.
class RelocationState {
  const RelocationState({this.target, this.saving = false});

  final Screen? target;
  final bool saving;

  /// Активен ли режим перемещения (показывать центр-пин и нижнюю панель).
  bool get isActive => target != null;
}

/// Управляет режимом перемещения локации экрана жестом по карте (FR-3.3).
///
/// UI (`map_page.dart`) держит `MapController` и на «Сохранить» читает
/// `camera.center`, передавая координаты в [saveRelocation] — так нотификатор
/// остаётся без зависимости от виджет-слоя. Имена методов без reserved words
/// (`update`/`state`/`future`/`ref`): [beginRelocation]/[cancelRelocation]/[saveRelocation].
class RelocationNotifier extends Notifier<RelocationState> {
  @override
  RelocationState build() => const RelocationState();

  /// Включает режим перемещения для экрана [screen].
  void beginRelocation(Screen screen) => state = RelocationState(target: screen);

  /// Выключает режим без запроса (кнопка «Отмена»).
  void cancelRelocation() => state = const RelocationState();

  /// Сохраняет новую точку центр-пина (`PATCH /api/screens/{id}/location`).
  ///
  /// На успех — инвалидирует список экранов (маркер переедет после refetch) и
  /// выходит из режима. `404` (NotFoundFailure) трактуется как «экран удалён»:
  /// тоже refetch + выход из режима, а UI покажет мягкий snackbar. Прочие ошибки
  /// оставляют режим включённым, чтобы можно было повторить.
  Future<Result<Screen>> saveRelocation({required double lng, required double lat}) async {
    final target = state.target;
    if (target == null) {
      return const Result.failure(ValidationFailure('Нет экрана для перемещения.'));
    }

    state = RelocationState(target: target, saving: true);
    final result = await ref.read(screensRepositoryProvider).moveScreenLocation(
          target.id,
          lng: lng,
          lat: lat,
        );

    result.when(
      onSuccess: (_) {
        ref.invalidate(screensProvider);
        state = const RelocationState();
      },
      onFailure: (failure) {
        if (failure is NotFoundFailure) {
          // Экран уже удалён — обновляем список и выходим из режима.
          ref.invalidate(screensProvider);
          state = const RelocationState();
        } else {
          // Оставляем режим активным (без saving), чтобы дать повторить.
          state = RelocationState(target: target);
        }
      },
    );
    return result;
  }
}

/// Провайдер режима перемещения локации (FR-3.3).
final relocationNotifierProvider =
    NotifierProvider<RelocationNotifier, RelocationState>(RelocationNotifier.new);
