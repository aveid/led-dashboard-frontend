import 'package:flutter/material.dart';

/// Карточка-контейнер с единым оформлением (рамка/радиус из темы).
///
/// Используется как обёртка для форм, панелей, блоков карточки экрана. Убирает
/// повторение `Card` + `Padding` в каждом месте.
class AppCard extends StatelessWidget {
  const AppCard({
    required this.child,
    this.padding = const EdgeInsets.all(20),
    super.key,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(padding: padding, child: child),
    );
  }
}
