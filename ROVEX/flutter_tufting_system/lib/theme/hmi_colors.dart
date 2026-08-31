import 'package:flutter/material.dart';

/// ROVEX Industrial HMI Design System.
///
/// Provides shared colors for both dark and light application modes.
/// Machine-state colors remain semantic across both modes.
class HmiColors {
  const HmiColors._();

  // ============================================================
  // DARK THEME
  // ============================================================

  /// Dark application background.
  static const Color darkBg = Color(0xFF111315);

  /// Dark main cards and panels.
  static const Color darkPanel = Color(0xFF191C1F);

  /// Dark secondary and elevated panels.
  static const Color darkPanelAlt = Color(0xFF202428);

  /// Dark highest elevation surface.
  static const Color darkPanelElevated = Color(0xFF292E33);

  /// Dark hover surface.
  static const Color darkSurfaceHover = Color(0xFF252A2F);

  /// Dark active surface.
  static const Color darkSurfaceActive = Color(0xFF30363C);

  // ============================================================
  // LIGHT THEME
  // ============================================================

  /// Light application background.
  static const Color lightBg = Color(0xFFF3F5F4);

  /// Light main cards and panels.
  static const Color lightPanel = Color(0xFFFFFFFF);

  /// Light secondary and elevated panels.
  static const Color lightPanelAlt = Color(0xFFE8ECEA);

  /// Light highest elevation surface.
  static const Color lightPanelElevated = Color(0xFFDDE3E0);

  /// Light hover surface.
  static const Color lightSurfaceHover = Color(0xFFE2E7E4);

  /// Light active surface.
  static const Color lightSurfaceActive = Color(0xFFD4DCD8);

  // ============================================================
  // BACKGROUND & SURFACES - CURRENT THEME COMPATIBILITY
  // ============================================================

  /// Current default application background.
  static const Color bg = darkBg;

  /// Current default main panel.
  static const Color panel = darkPanel;

  /// Current default secondary panel.
  static const Color panelAlt = darkPanelAlt;

  /// Current default elevated panel.
  static const Color panelElevated = darkPanelElevated;

  /// Current default hover surface.
  static const Color surfaceHover = darkSurfaceHover;

  /// Current default active surface.
  static const Color surfaceActive = darkSurfaceActive;

  // ============================================================
  // BORDERS & DIVIDERS
  // ============================================================

  /// Dark standard panel border.
  static const Color darkBorder = Color(0xFF30363B);

  /// Light standard panel border.
  static const Color lightBorder = Color(0xFFC8D0CC);

  /// Dark stronger border.
  static const Color darkBorderStrong = Color(0xFF485057);

  /// Light stronger border.
  static const Color lightBorderStrong = Color(0xFF9FAAA4);

  /// Dark subtle divider.
  static const Color darkDivider = Color(0xFF272C30);

  /// Light subtle divider.
  static const Color lightDivider = Color(0xFFD7DDDA);

  /// Accent border used for active controls.
  static const Color borderAccent = Color(0xFF318C59);

  /// Current default border.
  static const Color border = darkBorder;

  /// Current default strong border.
  static const Color borderStrong = darkBorderStrong;

  /// Current default divider.
  static const Color divider = darkDivider;

  // ============================================================
  // BUTTONS / SOFTKEYS
  // ============================================================

  /// Dark normal button surface.
  static const Color darkSoftkey = Color(0xFF252A2F);

  /// Light normal button surface.
  static const Color lightSoftkey = Color(0xFFE5E9E7);

  /// Dark hover button surface.
  static const Color darkSoftkeyHover = Color(0xFF30363C);

  /// Light hover button surface.
  static const Color lightSoftkeyHover = Color(0xFFD9DFDC);

  /// Dark pressed button surface.
  static const Color darkSoftkeyActive = Color(0xFF394148);

  /// Light pressed button surface.
  static const Color lightSoftkeyActive = Color(0xFFCBD4CF);

  /// Dark disabled button surface.
  static const Color darkSoftkeyDisabled = Color(0xFF1D2023);

  /// Light disabled button surface.
  static const Color lightSoftkeyDisabled = Color(0xFFDDE1DF);

  /// Main ROVEX interaction accent.
  static const Color accent = Color(0xFF32B86B);

  /// Stronger accent for important active controls.
  static const Color accentStrong = Color(0xFF43D27E);

  /// Dark accent surface.
  static const Color darkAccentSurface = Color(0xFF183A28);

  /// Light accent surface.
  static const Color lightAccentSurface = Color(0xFFDDF3E7);

  /// Current default button surface.
  static const Color softkey = darkSoftkey;

  /// Current default hover button surface.
  static const Color softkeyHover = darkSoftkeyHover;

  /// Current default active button surface.
  static const Color softkeyActive = darkSoftkeyActive;

  /// Current default disabled button surface.
  static const Color softkeyDisabled = darkSoftkeyDisabled;

  /// Current default accent surface.
  static const Color accentSurface = darkAccentSurface;

  /// Compatibility alias.
  static const Color gold = accent;

  /// Secondary neutral accent.
  static const Color sand = Color(0xFF858D94);

  // ============================================================
  // TEXT
  // ============================================================

  /// Dark primary text.
  static const Color darkText = Color(0xFFF4F6F7);

  /// Light primary text.
  static const Color lightText = Color(0xFF18201C);

  /// Dark secondary text.
  static const Color darkTextDim = Color(0xFFB2B9BF);

  /// Light secondary text.
  static const Color lightTextDim = Color(0xFF59645E);

  /// Dark muted text.
  static const Color darkTextMute = Color(0xFF747C83);

  /// Light muted text.
  static const Color lightTextMute = Color(0xFF7A8580);

  /// Dark disabled text.
  static const Color darkTextDisabled = Color(0xFF555C62);

  /// Light disabled text.
  static const Color lightTextDisabled = Color(0xFFA1AAA5);

  /// Text used on dark machine-state buttons.
  static const Color textOnDark = Color(0xFFFFFFFF);

  /// Current default primary text.
  static const Color text = darkText;

  /// Current default secondary text.
  static const Color textDim = darkTextDim;

  /// Current default muted text.
  static const Color textMute = darkTextMute;

  /// Current default disabled text.
  static const Color textDisabled = darkTextDisabled;

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

  /// Dark selection background.
  static const Color darkSelection = Color(0xFF30363C);

  /// Light selection background.
  static const Color lightSelection = Color(0xFFD5DDD8);

  /// Dark focus background.
  static const Color darkFocus = Color(0xFF353C42);

  /// Light focus background.
  static const Color lightFocus = Color(0xFFC9D3CD);

  /// Disabled overlay.
  static const Color disabledOverlay = Color(0x66000000);

  /// Dark modal / dialog background.
  static const Color darkDialog = Color(0xFF202428);

  /// Light modal / dialog background.
  static const Color lightDialog = Color(0xFFFFFFFF);

  /// Dark scrim behind dialogs.
  static const Color darkScrim = Color(0xB3000000);

  /// Light scrim behind dialogs.
  static const Color lightScrim = Color(0x66000000);

  /// Dark hover overlay.
  static const Color darkHoverOverlay = Color(0x0FFFFFFF);

  /// Light hover overlay.
  static const Color lightHoverOverlay = Color(0x0F000000);

  /// Dark pressed overlay.
  static const Color darkPressedOverlay = Color(0x18FFFFFF);

  /// Light pressed overlay.
  static const Color lightPressedOverlay = Color(0x18000000);

  /// Current default selection background.
  static const Color selection = darkSelection;

  /// Current default focus background.
  static const Color focus = darkFocus;

  /// Current default dialog background.
  static const Color dialog = darkDialog;

  /// Current default scrim.
  static const Color scrim = darkScrim;

  /// Current default hover overlay.
  static const Color hoverOverlay = darkHoverOverlay;

  /// Current default pressed overlay.
  static const Color pressedOverlay = darkPressedOverlay;

  // ============================================================
  // VISUALIZATION
  // ============================================================

  /// Dark 3D / toolpath preview background.
  static const Color darkPreviewBg = Color(0xFF0E1012);

  /// Light 3D / toolpath preview background.
  static const Color lightPreviewBg = Color(0xFFF7F9F8);

  /// Dark 3D preview grid.
  static const Color darkPreviewGrid = Color(0xFF252B30);

  /// Light 3D preview grid.
  static const Color lightPreviewGrid = Color(0xFFD9DFDC);

  /// Dark 3D preview axis.
  static const Color darkPreviewAxis = Color(0xFF626A72);

  /// Light 3D preview axis.
  static const Color lightPreviewAxis = Color(0xFF89958F);

  /// Neutral drawing / path color for dark mode.
  static const Color darkPreviewPath = Color(0xFFAEB6BC);

  /// Neutral drawing / path color for light mode.
  static const Color lightPreviewPath = Color(0xFF59645E);

  /// Selected / active path for dark mode.
  static const Color darkPreviewPathActive = Color(0xFFE5E9EB);

  /// Selected / active path for light mode.
  static const Color lightPreviewPathActive = Color(0xFF24332B);

  /// Active toolhead / needle.
  static const Color previewTool = Color(0xFF35C474);

  /// Completed toolpath.
  static const Color previewCompleted = Color(0xFF35B978);

  /// Remaining toolpath.
  static const Color previewRemaining = Color(0xFF687178);

  /// Current default preview background.
  static const Color previewBg = darkPreviewBg;

  /// Current default preview grid.
  static const Color previewGrid = darkPreviewGrid;

  /// Current default preview axis.
  static const Color previewAxis = darkPreviewAxis;

  /// Current default preview path.
  static const Color previewPath = darkPreviewPath;

  /// Current default active preview path.
  static const Color previewPathActive = darkPreviewPathActive;

  // ============================================================
  // STATUS SURFACES
  // ============================================================

  /// Dark ready status surface.
  static const Color darkReadySurface = Color(0xFF173A28);

  /// Light ready status surface.
  static const Color lightReadySurface = Color(0xFFDDF3E7);

  /// Dark warning status surface.
  static const Color darkWarnSurface = Color(0xFF3D3018);

  /// Light warning status surface.
  static const Color lightWarnSurface = Color(0xFFF8EBCB);

  /// Dark alarm status surface.
  static const Color darkAlarmSurface = Color(0xFF3E1D1B);

  /// Light alarm status surface.
  static const Color lightAlarmSurface = Color(0xFFF8DCD9);

  /// Dark emergency stop surface.
  static const Color darkEstopSurface = Color(0xFF431918);

  /// Light emergency stop surface.
  static const Color lightEstopSurface = Color(0xFFF5D5D2);

  /// Current default ready surface.
  static const Color readySurface = darkReadySurface;

  /// Current default warning surface.
  static const Color warnSurface = darkWarnSurface;

  /// Current default alarm surface.
  static const Color alarmSurface = darkAlarmSurface;

  /// Current default emergency stop surface.
  static const Color estopSurface = darkEstopSurface;

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