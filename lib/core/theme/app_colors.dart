import 'package:flutter/material.dart';

/// Цветовые токены проекта (бренд MEGA), см. `docs/DESIGN.md`.
///
/// Единственный источник цвета для всего приложения: виджеты и фичи берут цвета
/// только отсюда (или из темы), без «магических» Color-литералов. Это правило
/// из frontend/CONTEXT.md §8 — так дизайн остаётся согласованным и его легко
/// поменять в одном месте.
abstract final class AppColors {
  // --- Бренд MEGA ---
  static const primary = Color(0xFF4C12A1);
  static const primaryHover = Color(0xFF3D0E82);
  static const primarySoft = Color(0xFFF3EEFB);
  static const accent = Color(0xFF7C3AED);

  // --- Нейтральные ---
  static const bg = Color(0xFFF8FAFC);
  static const surface = Color(0xFFFFFFFF);
  static const border = Color(0xFFE2E8F0);
  static const textPrimary = Color(0xFF0F172A);
  static const textSecondary = Color(0xFF475569);
  static const textMuted = Color(0xFF94A3B8);

  // --- Статусы экрана (цвета маркеров на карте, FR-1.3/2.3) ---
  static const statusActive = Color(0xFF16A34A);
  static const statusInactive = Color(0xFF64748B);
  static const statusPotential = Color(0xFF2563EB);
  static const statusArchived = Color(0xFF78716C);

  // --- Карта (FR-1.6: маска «только Кыргызстан») ---
  /// Полупрозрачное затемнение всего, что вне КР (~0.35 alpha чёрного). Обводку
  /// границы рисуем брендовым [primary].
  static const mapMaskDim = Color(0x59000000);

  // --- Семантика ---
  static const success = Color(0xFF16A34A);
  static const warning = Color(0xFFF59E0B);
  static const danger = Color(0xFFDC2626);
  static const info = Color(0xFF2563EB);
}
