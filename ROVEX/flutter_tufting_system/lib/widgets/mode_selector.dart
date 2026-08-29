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
    final modes = [
      MachineMode.jog,
      MachineMode.auto,
      MachineMode.mdi,
      MachineMode.ref,
    ];

    return Container(
      height: 40,
      color: HmiColors.panelAlt,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Row(
        children: [
          const Text('MODE',
              style: TextStyle(
                  color: HmiColors.textMute,
                  fontSize: 11,
                  fontWeight: FontWeight.w700)),
          const SizedBox(width: 12),
          for (final m in modes)
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: _ModeChip(
                label: m.name.toUpperCase(),
                active: svc.status.mode == m,
                onTap: () => svc.setMode(m),
              ),
            ),
          const Spacer(),
          Text(
            svc.status.stateLabel,
            style: TextStyle(
              color: svc.status.state == MachineState.alarm
                  ? HmiColors.alarm
                  : svc.status.state == MachineState.running
                      ? HmiColors.ready
                      : HmiColors.warn,
              fontWeight: FontWeight.w800,
              fontSize: 13,
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
  const _ModeChip(
      {required this.label, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: active ? HmiColors.modeActive : HmiColors.softkey,
      borderRadius: BorderRadius.circular(4),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          child: Text(
            label,
            style: TextStyle(
              color: active ? Colors.black : HmiColors.textDim,
              fontWeight: FontWeight.w800,
              fontSize: 12,
            ),
          ),
        ),
      ),
    );
  }
}
