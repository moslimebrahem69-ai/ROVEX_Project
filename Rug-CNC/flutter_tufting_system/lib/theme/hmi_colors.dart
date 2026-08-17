import 'package:flutter/material.dart';

/// ROVEX Industrial HMI — Gray / Graphite Theme
/// Neutral gray UI with semantic colors for machine states.
class HmiColors {
  // ============================================================
  // BACKGROUND
  // ============================================================

  /// Main application background
  static const Color bg = Color(0xFF202124);

  /// Main cards / panels
  static const Color panel = Color(0xFF2B2D30);

  /// Alternative panel surface
  static const Color panelAlt = Color(0xFF34373A);

  // ============================================================
  // BORDERS & BUTTONS
  // ============================================================

  /// Standard panel border
  static const Color border = Color(0xFF484B4F);

  /// Normal soft button
  static const Color softkey = Color(0xFF3A3D41);

  /// Active / pressed soft button
  static const Color softkeyActive = Color(0xFF555A60);

  /// Main UI accent — neutral steel gray
  static const Color accent = Color(0xFF8C9299);

  /// Kept for compatibility with existing code
  static const Color gold = Color(0xFF8C9299);

  /// Secondary neutral color
  static const Color sand = Color(0xFF737980);

  // ============================================================
  // TEXT
  // ============================================================

  /// Main text
  static const Color text = Color(0xFFF1F3F4);

  /// Secondary text
  static const Color textDim = Color(0xFFB8BDC3);

  /// Disabled / muted text
  static const Color textMute = Color(0xFF7F858C);

  // ============================================================
  // MACHINE STATUS COLORS
  // Keep these semantic colors — important for HMI safety.
  // ============================================================

  /// Machine ready / running
  static const Color ready = Color(0xFF35B86B);

  /// Warning
  static const Color warn = Color(0xFFE0A52B);

  /// Alarm / fault
  static const Color alarm = Color(0xFFE04B42);

  /// Emergency stop
  static const Color estop = Color(0xFFC93630);

  // ============================================================
  // MACHINE CONTROLS
  // ============================================================

  /// Start
  static const Color start = Color(0xFF2E9B5F);

  /// Hold / pause
  static const Color hold = Color(0xFFD69A25);

  /// Stop
  static const Color stop = Color(0xFFD15B35);

  /// DRO / coordinates
  static const Color dro = Color(0xFF36B69A);

  /// Active operating mode
  static const Color modeActive = Color(0xFF35B86B);
}