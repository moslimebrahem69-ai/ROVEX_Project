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
      return _lighten(_baseColor, 0.07);
    }

    return _baseColor;
  }

  Color get _borderColor {
    if (!_isEnabled) {
      return HmiColors.border;
    }

    if (_pressed) {
      return HmiColors.textDim;
    }

    if (_hovered) {
      return HmiColors.accent;
    }

    return HmiColors.border;
  }

  Color get _textColor {
    if (!_isEnabled) {
      return HmiColors.textMute;
    }

    switch (widget.type) {
      case HmiButtonType.normal:
      case HmiButtonType.active:
        return HmiColors.text;

      case HmiButtonType.start:
      case HmiButtonType.hold:
      case HmiButtonType.stop:
      case HmiButtonType.estop:
      case HmiButtonType.connect:
        return Colors.white;
    }
  }

  double get _elevation {
    if (!_isEnabled || _pressed) {
      return 0;
    }

    return _hovered ? 4 : 1.5;
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

  void _setPressed(bool value) {
    if (!_isEnabled || _pressed == value) {
      return;
    }

    setState(() {
      _pressed = value;
    });
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.fullWidth ? double.infinity : widget.width,
      height: widget.height,
      child: MouseRegion(
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
            _pressed = false;
          });
        },
        child: GestureDetector(
          onTap: _isEnabled ? widget.onPressed : null,
          onTapDown: _isEnabled ? (_) => _setPressed(true) : null,
          onTapUp: _isEnabled ? (_) => _setPressed(false) : null,
          onTapCancel: _isEnabled ? () => _setPressed(false) : null,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 110),
            curve: Curves.easeOutCubic,
            transformAlignment: Alignment.center,
            transform: Matrix4.identity()
              ..scaleByDouble(
                _pressed ? 0.985 : 1.0,
                _pressed ? 0.985 : 1.0,
                1.0,
                1.0,
              ),
            decoration: BoxDecoration(
              color: _backgroundColor,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: _borderColor,
                width: _hovered || _pressed ? 1.2 : 1,
              ),
              boxShadow: _isEnabled && _elevation > 0
                  ? [
                      BoxShadow(
                        color: Colors.black.withValues(
                          alpha: _hovered ? 0.28 : 0.16,
                        ),
                        blurRadius: _hovered ? 7 : 3,
                        offset: Offset(
                          0,
                          _elevation * 0.6,
                        ),
                      ),
                    ]
                  : null,
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: _isEnabled ? widget.onPressed : null,
                splashColor: HmiColors.accent.withValues(
                  alpha: 0.10,
                ),
                highlightColor: HmiColors.accent.withValues(
                  alpha: 0.05,
                ),
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
                            size: 18,
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
                              letterSpacing: 0.2,
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
      ),
    );
  }
}