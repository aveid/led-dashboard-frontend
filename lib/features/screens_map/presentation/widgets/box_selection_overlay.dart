import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

/// Оверлей «резиновой» рамки выделения по Shift (FR-1.7, web/desktop-only).
///
/// Монтируется в `Stack` ПОВЕРХ `FlutterMap` (см. `map_page.dart`) только пока
/// зажат Shift и не идёт relocation. Заполняет ту же коробку, что и карта, поэтому
/// `localPosition` жеста == экранные пиксели камеры → обратную проекцию в гео
/// делает страница (`camera.offsetToCrs`, см. `_selectByRect`).
///
/// ⚠️ `HitTestBehavior.translucent` (а не `opaque`): пан карты уже отключён флагами
/// `InteractionOptions` на время Shift, поэтому «съедать» жест у карты не нужно, а
/// прозрачность пропускает Shift+клик к самим маркерам (их `GestureDetector`
/// обрабатывает поштучный toggle). Стационарный тап рамку не рисует — пан-рекогнайзер
/// уступает тапу маркера в арене жестов.
class BoxSelectionOverlay extends StatefulWidget {
  const BoxSelectionOverlay({required this.onSelected, super.key});

  /// Отдаёт наружу нарисованный прямоугольник в локальных пикселях оверлея
  /// (== экранные пиксели камеры). Вызывается на отпускании, если рамка не микро.
  final void Function(Rect rectInLocalPx) onSelected;

  @override
  State<BoxSelectionOverlay> createState() => _BoxSelectionOverlayState();
}

class _BoxSelectionOverlayState extends State<BoxSelectionOverlay> {
  Offset? _start;
  Offset? _current;

  @override
  Widget build(BuildContext context) {
    final start = _start;
    final current = _current;
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onPanStart: (d) => setState(() {
        _start = d.localPosition;
        _current = d.localPosition;
      }),
      onPanUpdate: (d) => setState(() => _current = d.localPosition),
      onPanEnd: (_) {
        if (_start != null && _current != null) {
          final r = Rect.fromPoints(_start!, _current!);
          // Игнорируем микро-дёрганья (случайный клик, а не рамка).
          if (r.width > 4 && r.height > 4) widget.onSelected(r);
        }
        setState(() {
          _start = null;
          _current = null;
        });
      },
      child: CustomPaint(
        size: Size.infinite,
        painter: (start == null || current == null)
            ? null
            : _RubberBandPainter(Rect.fromPoints(start, current)),
      ),
    );
  }
}

/// Рисует прямоугольник выделения: лёгкая заливка + брендовая обводка.
class _RubberBandPainter extends CustomPainter {
  const _RubberBandPainter(this.rect);

  final Rect rect;

  @override
  void paint(Canvas canvas, Size size) {
    final fill = Paint()..color = AppColors.primary.withValues(alpha: 0.12);
    final stroke = Paint()
      ..color = AppColors.primary
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawRect(rect, fill);
    canvas.drawRect(rect, stroke);
  }

  @override
  bool shouldRepaint(covariant _RubberBandPainter old) => old.rect != rect;
}
