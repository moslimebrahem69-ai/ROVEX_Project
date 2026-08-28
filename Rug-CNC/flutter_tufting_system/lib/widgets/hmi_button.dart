import 'package:flutter/material.dart';

import '../theme/hmi_colors.dart';

enum HmiButtonType {
  normal,
  start,
  hold,
  stop,
  estop,
  connect,
  active,
}

class HmiButton extends StatefulWidget {
  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final HmiButtonType type;
  final bool enabled;
  final bool fullWidth;
  final double? width;
  final double height;

  const HmiButton({
    super.key,
    required this.label,
    this.icon,
    this.onPressed,
    this.type = HmiButtonType.normal,
    this.enabled = true,
    this.fullWidth = false,
    this.width,
    this.height = 46,
  });

  @override
  State<HmiButton> createState() => _HmiButtonState();
}

class _HmiButtonState extends State<HmiButton> {
  bool _hovered = false;
  bool _pressed = false;

  bool get _isEnabled => widget.enabled && widget.onPressed != null;

  Color get _baseColor {
    switch (widget.type) {
      case HmiButtonType.start:
        return HmiColors.start;
      case HmiButtonType.hold:
        return HmiColors.hold;
      case HmiButtonType.stop:
        return HmiColors.stop;
      case HmiButtonType.estop:
        return HmiColors.estop;
      case HmiButtonType.connect:
        return HmiColors.ready;
      case HmiButtonType.active:
        return HmiColors.softkeyActive;
      case HmiButtonType.normal:
        return HmiColors.softkey;
    }
  }

  Color get _backgroundColor {
    if (!_isEnabled) {
      return HmiColors.panelAlt;
    }

    if (_pressed) {
      return _darken(_baseColor, 0.12);
    }

    if (_hovered) {
      return _lighten(_baseColor, 0.08);
    }

    return _baseColor;
  }

  Color get _borderColor {
    if (!_isEnabled) {
      return HmiColors.border;
    }

    if (_hovered || _pressed) {
      return HmiColors.accent;
    }

    return HmiColors.border;
  }

  Color get _textColor {
    return _isEnabled ? HmiColors.text : HmiColors.textMute;
  }

  double get _elevation {
    if (!_isEnabled || _pressed) {
      return 0;
    }

    return _hovered ? 5 : 2;
  }

  Color _darken(Color color, double amount) {
    final hsl = HSLColor.fromColor(color);

    return hsl
        .withLightness(
          (hsl.lightness - amount).clamp(0.0, 1.0),
        )
        .toColor();
  }

  Color _lighten(Color color, double amount) {
    final hsl = HSLColor.fromColor(color);

    return hsl
        .withLightness(
          (hsl.lightness + amount).clamp(0.0, 1.0),
        )
        .toColor();
  }

  @override
  Widget build(BuildContext context) {
    final button = MouseRegion(
      cursor: _isEnabled
          ? SystemMouseCursors.click
          : SystemMouseCursors.basic,
      onEnter: (_) {
        if (!_isEnabled) return;

        setState(() {
          _hovered = true;
        });
      },
      onExit: (_) {
        if (!_isEnabled) return;

        setState(() {
          _hovered = false;
        });
      },
      child: GestureDetector(
        onTap: _isEnabled ? widget.onPressed : null,
        onTapDown: _isEnabled
            ? (_) {
                setState(() {
                  _pressed = true;
                });
              }
            : null,
        onTapUp: _isEnabled
            ? (_) {
                setState(() {
                  _pressed = false;
                });
              }
            : null,
        onTapCancel: _isEnabled
            ? () {
                setState(() {
                  _pressed = false;
                });
              }
            : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          curve: Curves.easeOutCubic,
          height: widget.height,
          width: widget.fullWidth ? double.infinity : widget.width,
          transform: Matrix4.identity()
            ..scale(_pressed ? 0.985 : 1.0),
          decoration: BoxDecoration(
            color: _backgroundColor,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: _borderColor,
              width: _hovered || _pressed ? 1.2 : 1,
            ),
            boxShadow: _isEnabled
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(
                        alpha: _hovered ? 0.32 : 0.20,
                      ),
                      blurRadius: _hovered ? 8 : 4,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: _isEnabled ? widget.onPressed : null,
              splashColor: HmiColors.accent.withValues(alpha: 0.12),
              highlightColor: HmiColors.accent.withValues(alpha: 0.06),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                ),
                child: Center(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (widget.icon != null) ...[
                        Icon(
                          widget.icon,
                          size: 19,
                          color: _textColor,
                        ),
                        const SizedBox(width: 7),
                      ],
                      Flexible(
                        child: Text(
                          widget.label,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: _textColor,
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.25,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    return SizedBox(
      width: widget.fullWidth ? double.infinity : widget.width,
      height: widget.height,
      child: button,
    );
  }
}