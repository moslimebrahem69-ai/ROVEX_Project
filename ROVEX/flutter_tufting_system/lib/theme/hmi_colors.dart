import 'package:flutter/material.dart';

/// ROVEX Industrial HMI — Graphite / Neutral Gray Theme
///
/// A professional industrial HMI palette built around graphite gray.
/// Semantic machine-state colors are intentionally preserved for safety
/// and immediate visual recognition.

class HmiColors {
  // ============================================================
  // BACKGROUND
  // ============================================================

  /// Main application background.
  /// Deep graphite — prevents pure black appearance.
  static const Color bg = Color(0xFF1C1E21);

  /// Main cards / panels.
  static const Color panel = Color(0xFF25282C);

  /// Secondary / elevated panel surface.
  static const Color panelAlt = Color(0xFF2E3237);

  /// Highest elevation surface.
  static const Color panelElevated = Color(0xFF363A40);

  // ============================================================
  // BORDERS & DIVIDERS
  // ============================================================

  /// Standard panel border.
  static const Color border = Color(0xFF454A50);

  /// Stronger border for selected / focused controls.
  static const Color borderStrong = Color(0xFF5A6067);

  /// Very subtle divider.
  static const Color divider = Color(0xFF34383D);

  // ============================================================
  // BUTTONS / SOFTKEYS
  // ============================================================

  /// Normal button.
  static const Color softkey = Color(0xFF33373C);

  /// Hover / focused button.
  static const Color softkeyHover = Color(0xFF41464C);

  /// Pressed / active button.
  static const Color softkeyActive = Color(0xFF50565D);

  /// Disabled button.
  static const Color softkeyDisabled = Color(0xFF292C30);

  /// Main neutral accent.
  /// Steel gray used for selections and neutral highlights.
  static const Color accent = Color(0xFF9AA0A7);

  /// Compatibility alias.
  static const Color gold = Color(0xFF9AA0A7);

  /// Secondary neutral accent.
  static const Color sand = Color(0xFF747A81);

  // ============================================================
  // TEXT
  // ============================================================

  /// Main / primary text.
  static const Color text = Color(0xFFF2F3F4);

  /// Secondary text.
  static const Color textDim = Color(0xFFB9BEC4);

  /// Muted text.
  static const Color textMute = Color(0xFF858B92);

  /// Disabled text.
  static const Color textDisabled = Color(0xFF62676D);

  /// Text used on dark machine-state buttons.
  static const Color textOnDark = Color(0xFFFFFFFF);

  // ============================================================
  // MACHINE STATUS COLORS
  //
  // These colors intentionally remain semantic.
  // Green = ready/running
  // Amber = warning/hold
  // Red = alarm/stop
  // ============================================================

  /// Machine ready / running.
  static const Color ready = Color(0xFF3DBB72);

  /// Warning.
  static const Color warn = Color(0xFFE0A936);

  /// Alarm / fault.
  static const Color alarm = Color(0xFFE0524A);

  /// Emergency stop.
  static const Color estop = Color(0xFFC93630);

  // ============================================================
  // MACHINE CONTROLS
  // ============================================================

  /// Start / cycle start.
  static const Color start = Color(0xFF329A60);

  /// Hold / pause.
  static const Color hold = Color(0xFFD39A2C);

  /// Stop.
  static const Color stop = Color(0xFFC95A3A);

  /// DRO / coordinates.
  /// Kept slightly cyan/teal so coordinates are visually distinct
  /// without breaking the graphite theme.
  static const Color dro = Color(0xFF4AAE9A);

  /// Active operating mode.
  static const Color modeActive = Color(0xFF3DBB72);

  // ============================================================
  // MACHINE / CNC SPECIFIC
  // ============================================================

  /// CNC path / toolpath neutral highlight.
  static const Color toolpath = Color(0xFF9EA4AA);

  /// Selected coordinate / position.
  static const Color coordinate = Color(0xFFB0B5BA);

  /// Machine inactive.
  static const Color machineIdle = Color(0xFF777D84);

  /// Machine disconnected.
  static const Color disconnected = Color(0xFF666B71);

  /// Machine locked.
  static const Color locked = Color(0xFF555A60);

  // ============================================================
  // OVERLAYS / INTERACTION
  // ============================================================

  /// Selection background.
  static const Color selection = Color(0xFF41464C);

  /// Focus background.
  static const Color focus = Color(0xFF4A5056);

  /// Disabled overlay.
  static const Color disabledOverlay = Color(0x66000000);

  /// Modal / dialog background.
  static const Color dialog = Color(0xFF292C30);

  /// Scrim behind dialogs.
  static const Color scrim = Color(0x99000000);

  // ============================================================
  // VISUALIZATION
  // ============================================================

  /// 3D preview background.
  static const Color previewBg = Color(0xFF181A1D);

  /// 3D preview grid.
  static const Color previewGrid = Color(0xFF30343A);

  /// 3D preview axis.
  static const Color previewAxis = Color(0xFF686E75);

  /// Neutral drawing / path color.
  static const Color previewPath = Color(0xFFB2B7BC);

  /// Selected path.
  static const Color previewPathActive = Color(0xFFE0E3E5);

  // ============================================================
  // COMMON SHADOWS
  // ============================================================

  /// Subtle industrial panel shadow.
  static const Color shadow = Color(0x55000000);
}