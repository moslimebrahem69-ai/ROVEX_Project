import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/machine_status.dart';
import '../services/machine_service.dart';
import '../theme/hmi_colors.dart';

class ModeSelector extends StatelessWidget {
  const ModeSelector({super.key});

  @override
  Widget build(BuildContext context) {
    final svc = context.watch<MachineService>();

    const modes = [
      MachineMode.jog,
      MachineMode.auto,
      MachineMode.mdi,
      MachineMode.ref,
    ];

    final state = svc.status.state;

    final stateColor = switch (state) {
      MachineState.alarm => HmiColors.alarm,
      MachineState.running => HmiColors.ready,
      _ => HmiColors.warn,
    };

    return Container(
      height: 40,
      color: HmiColors.panelAlt,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Row(
        children: [
          const Text(
            'MODE',
            style: TextStyle(
              color: HmiColors.textMute,
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(width: 12),
          for (final mode in modes)
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: _ModeChip(
                label: mode.name.toUpperCase(),
                active: svc.status.mode == mode,
                onTap: () => svc.setMode(mode),
              ),
            ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 10,
              vertical: 5,
            ),
            decoration: BoxDecoration(
              color: stateColor.withValues(alpha: 0.10),
              border: Border.all(
                color: stateColor.withValues(alpha: 0.45),
              ),
              borderRadius: BorderRadius.circular(5),
            ),
            child: Text(
              svc.status.stateLabel,
              style: TextStyle(
                color: stateColor,
                fontWeight: FontWeight.w800,
                fontSize: 11,
                letterSpacing: 0.3,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ModeChip extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _ModeChip({
    required this.label,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: active
          ? HmiColors.softkeyActive
          : HmiColors.softkey,
      borderRadius: BorderRadius.circular(5),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(5),
        splashColor: HmiColors.accent.withValues(alpha: 0.12),
        highlightColor: HmiColors.accent.withValues(alpha: 0.06),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          padding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 7,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(5),
            border: Border.all(
              color: active
                  ? HmiColors.accent
                  : HmiColors.border,
              width: active ? 1.2 : 1,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: active
                  ? HmiColors.text
                  : HmiColors.textDim,
              fontWeight: FontWeight.w800,
              fontSize: 11,
              letterSpacing: 0.3,
            ),
          ),
        ),
      ),
    );
  }
}