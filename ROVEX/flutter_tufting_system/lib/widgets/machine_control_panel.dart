import 'package:flutter/material.dart';

import 'package:provider/provider.dart';

import '../l10n/l10n.dart';
import '../models/machine_status.dart';
import '../services/machine_service.dart';
import '../theme/hmi_colors.dart';
import 'hmi_button.dart';

class MachineControlPanel extends StatelessWidget {
  const MachineControlPanel({super.key});

  @override
  Widget build(BuildContext context) {
    final svc = context.watch<MachineService>();
    final t = context.watch<LocaleController>().l10n;
    final s = svc.status;

    return Container(
      width: 220,
      color: HmiColors.panel,
      padding: const EdgeInsets.all(12),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  width: 4,
                  height: 18,
                  decoration: BoxDecoration(
                    color: HmiColors.accent,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    t.t('machine'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: HmiColors.accent,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            HmiButton(
              label: t.t('cycle_start'),
              icon: Icons.play_arrow_rounded,
              type: HmiButtonType.start,
              height: 46,
              fullWidth: true,
              onPressed: svc.cycleStart,
            ),
            const SizedBox(height: 8),

            HmiButton(
              label: t.t('feed_hold'),
              icon: Icons.pause_rounded,
              type: HmiButtonType.hold,
              height: 46,
              fullWidth: true,
              onPressed: svc.feedHold,
            ),
            const SizedBox(height: 8),

            HmiButton(
              label: t.t('cycle_stop'),
              icon: Icons.stop_rounded,
              type: HmiButtonType.stop,
              height: 46,
              fullWidth: true,
              onPressed: svc.cycleStop,
            ),
            const SizedBox(height: 8),

            HmiButton(
              label: t.t('reset'),
              icon: Icons.refresh_rounded,
              type: HmiButtonType.normal,
              height: 46,
              fullWidth: true,
              onPressed: svc.reset,
            ),
            const SizedBox(height: 8),

            HmiButton(
              label: t.t('estop'),
              icon: Icons.warning_rounded,
              type: HmiButtonType.estop,
              height: 58,
              fullWidth: true,
              onPressed: svc.estop,
            ),
            const SizedBox(height: 14),

            HmiButton(
              label: t.t('home'),
              icon: Icons.home_rounded,
              type: HmiButtonType.active,
              height: 46,
              fullWidth: true,
              onPressed: svc.home,
            ),
            const SizedBox(height: 8),

            HmiButton(
              label: s.connected ? t.t('disc') : t.t('connect'),
              icon: s.connected
                  ? Icons.link_off_rounded
                  : Icons.link_rounded,
              type: s.connected
                  ? HmiButtonType.hold
                  : HmiButtonType.connect,
              height: 46,
              fullWidth: true,
              onPressed: s.connected
                  ? svc.disconnectMachine
                  : svc.connectMachine,
            ),
            const SizedBox(height: 16),

            if (s.mode == MachineMode.jog) ...[
              _sectionHeader(
                title: t.t('jog'),
                icon: Icons.open_with_rounded,
              ),
              const SizedBox(height: 10),

              _jogButton(
                svc,
                axis: 'Y',
                dir: 1,
                icon: Icons.keyboard_arrow_up_rounded,
              ),
              const SizedBox(height: 6),

              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _jogButton(
                    svc,
                    axis: 'X',
                    dir: -1,
                    icon: Icons.keyboard_arrow_left_rounded,
                  ),
                  const SizedBox(width: 8),
                  _jogCenter(),
                  const SizedBox(width: 8),
                  _jogButton(
                    svc,
                    axis: 'X',
                    dir: 1,
                    icon: Icons.keyboard_arrow_right_rounded,
                  ),
                ],
              ),
              const SizedBox(height: 6),

              _jogButton(
                svc,
                axis: 'Y',
                dir: -1,
                icon: Icons.keyboard_arrow_down_rounded,
              ),
              const SizedBox(height: 12),

              _sectionHeader(
                title: t.t('needle_axis'),
                icon: Icons.height_rounded,
                compact: true,
              ),
              const SizedBox(height: 8),

              Row(
                children: [
                  Expanded(
                    child: _zButton(
                      svc,
                      dir: 1,
                      label: 'Z+',
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _zButton(
                      svc,
                      dir: -1,
                      label: 'Z−',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              const Text(
                'JOG STEP',
                style: TextStyle(
                  color: HmiColors.textMute,
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.8,
                ),
              ),
              const SizedBox(height: 7),

              Row(
                children: [
                  Expanded(
                    child: _stepButton(
                      svc,
                      s.jogStep,
                      0.1,
                    ),
                  ),
                  const SizedBox(width: 5),
                  Expanded(
                    child: _stepButton(
                      svc,
                      s.jogStep,
                      1.0,
                    ),
                  ),
                  const SizedBox(width: 5),
                  Expanded(
                    child: _stepButton(
                      svc,
                      s.jogStep,
                      10.0,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _sectionHeader({
    required String title,
    required IconData icon,
    bool compact = false,
  }) {
    return Row(
      children: [
        Icon(
          icon,
          size: compact ? 14 : 16,
          color: HmiColors.accent,
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: compact
                  ? HmiColors.accent
                  : HmiColors.textDim,
              fontSize: compact ? 10 : 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.5,
            ),
          ),
        ),
      ],
    );
  }

  Widget _jogButton(
    MachineService svc, {
    required String axis,
    required int dir,
    required IconData icon,
  }) {
    return Material(
      color: HmiColors.softkey,
      borderRadius: BorderRadius.circular(9),
      child: InkWell(
        onTap: () => svc.jog(axis, dir),
        borderRadius: BorderRadius.circular(9),
        splashColor: HmiColors.accent.withValues(alpha: 0.12),
        highlightColor: HmiColors.accent.withValues(alpha: 0.06),
        child: Container(
          width: 48,
          height: 42,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(9),
            border: Border.all(
              color: HmiColors.border,
            ),
          ),
          child: Icon(
            icon,
            size: 24,
            color: HmiColors.text,
          ),
        ),
      ),
    );
  }

  Widget _jogCenter() {
    return Container(
      width: 48,
      height: 42,
      decoration: BoxDecoration(
        color: HmiColors.panelAlt,
        borderRadius: BorderRadius.circular(9),
        border: Border.all(
          color: HmiColors.border,
        ),
      ),
      child: const Center(
        child: Icon(
          Icons.add_rounded,
          size: 18,
          color: HmiColors.textMute,
        ),
      ),
    );
  }

  Widget _zButton(
    MachineService svc, {
    required int dir,
    required String label,
  }) {
    return Material(
      color: HmiColors.softkeyActive,
      borderRadius: BorderRadius.circular(9),
      child: InkWell(
        onTap: () => svc.jogZ(dir),
        borderRadius: BorderRadius.circular(9),
        splashColor: HmiColors.accent.withValues(alpha: 0.14),
        highlightColor: HmiColors.accent.withValues(alpha: 0.07),
        child: Container(
          height: 40,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(9),
            border: Border.all(
              color: HmiColors.border,
            ),
          ),
          child: Center(
            child: Text(
              label,
              style: const TextStyle(
                color: HmiColors.text,
                fontSize: 12,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.4,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _stepButton(
    MachineService svc,
    double currentStep,
    double value,
  ) {
    final selected = currentStep == value;

    return Material(
      color: selected
          ? HmiColors.modeActive
          : HmiColors.softkey,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: () => svc.setJogStep(value),
        borderRadius: BorderRadius.circular(8),
        splashColor: HmiColors.accent.withValues(alpha: 0.12),
        child: Container(
          height: 34,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: selected
                  ? HmiColors.modeActive
                  : HmiColors.border,
            ),
          ),
          child: Center(
            child: Text(
              '${value}mm',
              style: TextStyle(
                color: selected
                    ? HmiColors.text
                    : HmiColors.textDim,
                fontSize: 10,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ),
      ),
    );
  }
}