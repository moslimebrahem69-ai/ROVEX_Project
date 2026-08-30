import 'package:flutter/material.dart';

/// ROVEX Industrial HMI design tokens.
///
/// Keep machine-state colors semantic. UI surfaces should use the neutral
/// graphite palette so status colors remain visually meaningful.
class HmiColors {
  const HmiColors._();

  // ============================================================
  // GRAPHITE SURFACES
  // ============================================================

  /// Application background.
  static const Color bg = Color(0xFF17191C);

  /// Primary panels and cards.
  static const Color panel = Color(0xFF202327);

  /// Raised panels and secondary surfaces.
  static const Color panelAlt = Color(0xFF292D32);

  /// Highest surface level used for menus and focused controls.
  static const Color surfaceRaised = Color(0xFF30353B);

  /// Subtle surface used for hover and selected states.
  static const Color surfaceHover = Color(0xFF353A40);

  // ============================================================
  // BORDERS & UI CONTROLS
  // ============================================================

  /// Standard divider and panel border.
  static const Color border = Color(0xFF3B4046);

  /// Stronger border for focused or important controls.
  static const Color borderStrong = Color(0xFF50565D);

  /// Default soft button surface.
  static const Color softkey = Color(0xFF2C3035);

  /// Active / pressed soft button surface.
  static const Color softkeyActive = Color(0xFF3A4046);

  /// Main ROVEX interaction accent.
  static const Color accent = Color(0xFF35B86B);

  /// Kept for compatibility with existing code.
  static const Color gold = accent;

  /// Secondary neutral accent kept for compatibility.
  static const Color sand = Color(0xFF8A9199);

  // ============================================================
  // TEXT
  // ============================================================

  /// Primary text.
  static const Color text = Color(0xFFF2F4F5);

  /// Secondary text.
  static const Color textDim = Color(0xFFB0B6BD);

  /// Muted / disabled text.
  static const Color textMute = Color(0xFF727980);

  // ============================================================
  // MACHINE STATUS COLORS
  // ============================================================

  /// Machine ready / running.
  static const Color ready = Color(0xFF35B86B);

  /// Warning / hold.
  static const Color warn = Color(0xFFE0A52B);

  /// Alarm / fault.
  static const Color alarm = Color(0xFFE04B42);

  /// Emergency stop.
  static const Color estop = Color(0xFFC93630);

  // ============================================================
  // MACHINE CONTROLS
  // ============================================================

  /// Cycle start.
  static const Color start = Color(0xFF2E9B5F);

  /// Feed hold / pause.
  static const Color hold = Color(0xFFD69A25);

  /// Cycle stop.
  static const Color stop = Color(0xFFD15B35);

  /// Live axis coordinates.
  static const Color dro = Color(0xFF36B69A);

  /// Active operating mode.
  static const Color modeActive = Color(0xFF35B86B);

  // ============================================================
  // LAYOUT TOKENS
  // ============================================================

  static const double radiusSmall = 4;
  static const double radiusMedium = 6;
  static const double radiusLarge = 8;

  static const double space1 = 4;
  static const double space2 = 8;
  static const double space3 = 12;
  static const double space4 = 16;
  static const double space5 = 24;
  static const double space6 = 32;

  // ============================================================
  // MOTION TOKENS
  // ============================================================

  static const Duration motionFast = Duration(milliseconds: 100);
  static const Duration motionStandard = Duration(milliseconds: 160);
  static const Duration motionSlow = Duration(milliseconds: 220);

  static const Curve motionCurve = Curves.easeOutCubic;
}
