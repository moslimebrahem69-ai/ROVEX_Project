import 'package:flutter/material.dart';

/// ROVEX Industrial HMI Design System.
///
/// Premium graphite surfaces with restrained green machine accents.
/// Machine-state colors remain semantic for fast and safe recognition.
class HmiColors {
  const HmiColors._();

  // ============================================================
  // BACKGROUND & SURFACES
  // ============================================================

  /// Main application background.
  static const Color bg = Color(0xFF111315);

  /// Main cards and panels.
  static const Color panel = Color(0xFF191C1F);

  /// Secondary and elevated panels.
  static const Color panelAlt = Color(0xFF202428);

  /// Highest elevation surface.
  static const Color panelElevated = Color(0xFF292E33);

  /// Subtle surface used for hover and secondary interaction.
  static const Color surfaceHover = Color(0xFF252A2F);

  /// Strong surface used for selected controls.
  static const Color surfaceActive = Color(0xFF30363C);

  // ============================================================
  // BORDERS & DIVIDERS
  // ============================================================

  /// Standard panel border.
  static const Color border = Color(0xFF30363B);

  /// Stronger border for selected and focused controls.
  static const Color borderStrong = Color(0xFF485057);

  /// Very subtle divider.
  static const Color divider = Color(0xFF272C30);

  /// Accent border used for active controls.
  static const Color borderAccent = Color(0xFF318C59);

  // ============================================================
  // BUTTONS / SOFTKEYS
  // ============================================================

  /// Normal button surface.
  static const Color softkey = Color(0xFF252A2F);

  /// Hover / focused button surface.
  static const Color softkeyHover = Color(0xFF30363C);

  /// Pressed / active button surface.
  static const Color softkeyActive = Color(0xFF394148);

  /// Disabled button surface.
  static const Color softkeyDisabled = Color(0xFF1D2023);

  /// Main ROVEX interaction accent.
  static const Color accent = Color(0xFF32B86B);

  /// Stronger accent for important active controls.
  static const Color accentStrong = Color(0xFF43D27E);

  /// Dark accent surface.
  static const Color accentSurface = Color(0xFF183A28);

  /// Compatibility alias.
  static const Color gold = accent;

  /// Secondary neutral accent.
  static const Color sand = Color(0xFF858D94);

  // ============================================================
  // TEXT
  // ============================================================

  /// Main / primary text.
  static const Color text = Color(0xFFF4F6F7);

  /// Secondary text.
  static const Color textDim = Color(0xFFB2B9BF);

  /// Muted text.
  static const Color textMute = Color(0xFF747C83);

  /// Disabled text.
  static const Color textDisabled = Color(0xFF555C62);

  /// Text used on dark machine-state buttons.
  static const Color textOnDark = Color(0xFFFFFFFF);

  // ============================================================
  // MACHINE STATUS COLORS
  // ============================================================

  /// Machine ready / running.
  static const Color ready = Color(0xFF35C474);

  /// Warning / hold.
  static const Color warn = Color(0xFFE4AA35);

  /// Alarm / fault.
  static const Color alarm = Color(0xFFE5534B);

  /// Emergency stop.
  static const Color estop = Color(0xFFD43832);

  // ============================================================
  // MACHINE CONTROLS
  // ============================================================

  /// Start / cycle start.
  static const Color start = Color(0xFF2FA765);

  /// Hold / pause.
  static const Color hold = Color(0xFFD39B2C);

  /// Stop.
  static const Color stop = Color(0xFFD05C3D);

  /// DRO / live coordinates.
  static const Color dro = Color(0xFF3FB49E);

  /// Active operating mode.
  static const Color modeActive = Color(0xFF35C474);

  // ============================================================
  // MACHINE / CNC SPECIFIC
  // ============================================================

  /// CNC path / toolpath neutral highlight.
  static const Color toolpath = Color(0xFF9FA7AE);

  /// Selected coordinate / position.
  static const Color coordinate = Color(0xFFB9C0C5);

  /// Machine inactive.
  static const Color machineIdle = Color(0xFF747C83);

  /// Machine disconnected.
  static const Color disconnected = Color(0xFF646B72);

  /// Machine locked.
  static const Color locked = Color(0xFF50575D);

  // ============================================================
  // OVERLAYS / INTERACTION
  // ============================================================

  /// Selection background.
  static const Color selection = Color(0xFF30363C);

  /// Focus background.
  static const Color focus = Color(0xFF353C42);

  /// Disabled overlay.
  static const Color disabledOverlay = Color(0x66000000);

  /// Modal / dialog background.
  static const Color dialog = Color(0xFF202428);

  /// Scrim behind dialogs.
  static const Color scrim = Color(0xB3000000);

  /// Hover overlay.
  static const Color hoverOverlay = Color(0x0FFFFFFF);

  /// Pressed overlay.
  static const Color pressedOverlay = Color(0x18FFFFFF);

  // ============================================================
  // VISUALIZATION
  // ============================================================

  /// 3D / toolpath preview background.
  static const Color previewBg = Color(0xFF0E1012);

  /// 3D preview grid.
  static const Color previewGrid = Color(0xFF252B30);

  /// 3D preview axis.
  static const Color previewAxis = Color(0xFF626A72);

  /// Neutral drawing / path color.
  static const Color previewPath = Color(0xFFAEB6BC);

  /// Selected / active path.
  static const Color previewPathActive = Color(0xFFE5E9EB);

  /// Active toolhead / needle.
  static const Color previewTool = Color(0xFF35C474);

  /// Completed toolpath.
  static const Color previewCompleted = Color(0xFF35B978);

  /// Remaining toolpath.
  static const Color previewRemaining = Color(0xFF687178);

  // ============================================================
  // STATUS SURFACES
  // ============================================================

  /// Ready status surface.
  static const Color readySurface = Color(0xFF173A28);

  /// Warning status surface.
  static const Color warnSurface = Color(0xFF3D3018);

  /// Alarm status surface.
  static const Color alarmSurface = Color(0xFF3E1D1B);

  /// Emergency stop surface.
  static const Color estopSurface = Color(0xFF431918);

  // ============================================================
  // COMMON SHADOWS
  // ============================================================

  /// Subtle industrial panel shadow.
  static const Color shadow = Color(0x66000000);

  /// Strong modal shadow.
  static const Color shadowStrong = Color(0x99000000);

  // ============================================================
  // SPACING
  // ============================================================

  static const double space1 = 4;
  static const double space2 = 8;
  static const double space3 = 12;
  static const double space4 = 16;
  static const double space5 = 20;
  static const double space6 = 24;
  static const double space7 = 32;
  static const double space8 = 40;

  // ============================================================
  // CORNER RADIUS
  // ============================================================

  /// Small radius for compact controls.
  static const double radiusSmall = 4;

  /// Standard control radius.
  static const double radiusMedium = 6;

  /// Panel radius.
  static const double radiusLarge = 8;

  /// Large surface radius.
  static const double radiusXLarge = 10;

  // ============================================================
  // BORDERS
  // ============================================================

  static const double borderThin = 1;
  static const double borderMedium = 1.5;

  // ============================================================
  // MOTION
  // ============================================================

  /// Immediate interaction feedback.
  static const Duration motionFast = Duration(milliseconds: 100);

  /// Standard UI transition.
  static const Duration motionStandard = Duration(milliseconds: 160);

  /// Larger panel transition.
  static const Duration motionSlow = Duration(milliseconds: 220);

  /// Standard ROVEX interaction curve.
  static const Curve motionCurve = Curves.easeOutCubic;

  /// Very subtle entrance animation.
  static const Curve entranceCurve = Curves.easeOutQuart;

  // ============================================================
  // OPACITY
  // ============================================================

  static const double opacityDisabled = 0.45;
  static const double opacityMuted = 0.65;
  static const double opacitySecondary = 0.80;
  static const double opacityFull = 1.0;
}