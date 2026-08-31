import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/l10n.dart';
import '../models/machine_status.dart';
import '../services/machine_service.dart';
import '../theme/hmi_colors.dart';

class HmiSoftkeyBar extends StatelessWidget {
  const HmiSoftkeyBar({super.key});

  @override
  Widget build(BuildContext context) {
    final svc = context.watch<MachineService>();
    final loc = context.watch<LocaleController>();
    

    final t = loc.l10n;

    final items = [
      (HmiArea.machine, t.t('machine')),
      (HmiArea.program, t.t('program')),
      (HmiArea.design, t.t('design')),
      (HmiArea.needle3d, t.t('needle3d')),
      (HmiArea.errors, t.t('errors')),
      (HmiArea.plc, t.t('plc')),
      (HmiArea.diagnosis, t.t('diagnosis')),
      (HmiArea.setup, t.t('setup')),
    ];

    return Container(
      height: 48,
      color: HmiColors.panel,
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Row(
        children: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Text(
              t.t('brand'),
              style: const TextStyle(
                color: HmiColors.accent,
                fontSize: 15,
                fontWeight: FontWeight.w800,
                letterSpacing: 1,
              ),
            ),
          ),

          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (final (area, label) in items)
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 2,
                        vertical: 6,
                      ),
                      child: _AreaButton(
                        label: label,
                        active: svc.area == area,
                        onTap: () => svc.setArea(area),
                      ),
                    ),
                ],
              ),
            ),
          ),

          _langBtn(loc),

          const SizedBox(width: 6),

          

          _linkBadge(svc),
        ],
      ),
    );
  }

  Widget _langBtn(LocaleController loc) {
    return Material(
      color: HmiColors.softkey,
      borderRadius: BorderRadius.circular(5),
      child: InkWell(
        borderRadius: BorderRadius.circular(5),
        onTap: loc.cycleLang,
        hoverColor: HmiColors.softkeyActive.withValues(alpha: 0.45),
        splashColor: HmiColors.accent.withValues(alpha: 0.10),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: 10,
            vertical: 8,
          ),
          child: Text(
            '${loc.l10n.t('language')}: ${loc.l10n.code}',
            style: const TextStyle(
              color: HmiColors.textDim,
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ),
    );
  }

  

  Widget _linkBadge(MachineService svc) {
    final connected = svc.runtimeLinked || svc.status.connected;

    return Container(
      height: 32,
      padding: const EdgeInsets.symmetric(horizontal: 9),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: connected
            ? HmiColors.ready.withValues(alpha: 0.08)
            : HmiColors.alarm.withValues(alpha: 0.08),
        border: Border.all(
          color: connected
              ? HmiColors.ready.withValues(alpha: 0.65)
              : HmiColors.alarm.withValues(alpha: 0.65),
        ),
        borderRadius: BorderRadius.circular(5),
      ),
      child: Text(
        svc.runtimeLinked
            ? 'C'
            : (svc.status.connected ? 'SIM' : 'OFF'),
        style: TextStyle(
          color: connected
              ? HmiColors.ready
              : HmiColors.alarm,
          fontSize: 10,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

class _AreaButton extends StatefulWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _AreaButton({
    required this.label,
    required this.active,
    required this.onTap,
  });

  @override
  State<_AreaButton> createState() => _AreaButtonState();
}

class _AreaButtonState extends State<_AreaButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final active = widget.active;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) {
        setState(() {
          _hovered = true;
        });
      },
      onExit: (_) {
        setState(() {
          _hovered = false;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 100),
        decoration: BoxDecoration(
          color: active
              ? HmiColors.softkeyActive
              : _hovered
                  ? HmiColors.panelAlt
                  : HmiColors.softkey,
          borderRadius: BorderRadius.circular(5),
          border: Border.all(
            color: active
                ? HmiColors.accent
                : _hovered
                    ? HmiColors.border
                    : Colors.transparent,
            width: active ? 1 : 1,
          ),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(5),
            onTap: widget.onTap,
            splashColor: HmiColors.accent.withValues(alpha: 0.10),
            highlightColor: HmiColors.accent.withValues(alpha: 0.05),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 10,
                vertical: 8,
              ),
              child: Text(
                widget.label,
                style: TextStyle(
                  color: active
                      ? HmiColors.text
                      : _hovered
                          ? HmiColors.text
                          : HmiColors.textDim,
                  fontSize: 11,
                  fontWeight: active
                      ? FontWeight.w800
                      : FontWeight.w700,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}