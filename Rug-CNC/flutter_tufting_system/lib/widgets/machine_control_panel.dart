import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/l10n.dart';
import '../models/machine_status.dart';
import '../services/machine_service.dart';
import '../theme/hmi_colors.dart';

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
            Text(t.t('machine'),
                style: const TextStyle(
                    color: HmiColors.gold,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1)),
            const SizedBox(height: 10),
            _btn(t.t('cycle_start'), HmiColors.start, svc.cycleStart),
            const SizedBox(height: 8),
            _btn(t.t('feed_hold'), HmiColors.hold, svc.feedHold),
            const SizedBox(height: 8),
            _btn(t.t('cycle_stop'), HmiColors.stop, svc.cycleStop),
            const SizedBox(height: 8),
            _btn(t.t('reset'), HmiColors.accent, svc.reset),
            const SizedBox(height: 8),
            _btn(t.t('estop'), HmiColors.estop, svc.estop, tall: true),
            const SizedBox(height: 14),
            _btn(t.t('home'), HmiColors.softkeyActive, svc.home),
            const SizedBox(height: 8),
            _btn(
                s.connected ? t.t('disc') : t.t('connect'),
                s.connected ? HmiColors.warn : HmiColors.ready,
                s.connected ? svc.disconnectMachine : svc.connectMachine),
            const SizedBox(height: 16),
            if (s.mode == MachineMode.jog) ...[
              Text(t.t('jog'),
                  style: const TextStyle(
                      color: HmiColors.textMute,
                      fontSize: 11,
                      fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [_jog(svc, 'Y', 1, Icons.keyboard_arrow_up)],
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _jog(svc, 'X', -1, Icons.keyboard_arrow_left),
                  const SizedBox(width: 8),
                  _jog(svc, 'X', 1, Icons.keyboard_arrow_right),
                ],
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [_jog(svc, 'Y', -1, Icons.keyboard_arrow_down)],
              ),
              const SizedBox(height: 10),
              Text(t.t('needle_axis'),
                  style: const TextStyle(
                      color: HmiColors.gold, fontSize: 10)),
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _zBtn(svc, 1, 'Z+'),
                  const SizedBox(width: 8),
                  _zBtn(svc, -1, 'Z−'),
                ],
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 6,
                children: [0.1, 1.0, 10.0]
                    .map((v) => ActionChip(
                          label: Text('${v}mm',
                              style: const TextStyle(fontSize: 11)),
                          onPressed: () => svc.setJogStep(v),
                          backgroundColor: s.jogStep == v
                              ? HmiColors.modeActive
                              : HmiColors.softkey,
                        ))
                    .toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _zBtn(MachineService svc, int dir, String label) {
    return Material(
      color: HmiColors.softkeyActive,
      borderRadius: BorderRadius.circular(6),
      child: InkWell(
        onTap: () => svc.jogZ(dir),
        child: SizedBox(
          width: 56,
          height: 36,
          child: Center(
            child: Text(label,
                style: const TextStyle(
                    color: HmiColors.sand, fontWeight: FontWeight.w800)),
          ),
        ),
      ),
    );
  }

  Widget _jog(MachineService svc, String axis, int dir, IconData icon) {
    return Material(
      color: HmiColors.softkey,
      borderRadius: BorderRadius.circular(6),
      child: InkWell(
        onTap: () => svc.jog(axis, dir),
        child: SizedBox(
          width: 48,
          height: 40,
          child: Icon(icon, color: HmiColors.text),
        ),
      ),
    );
  }

  Widget _btn(String label, Color color, VoidCallback onTap,
      {bool tall = false}) {
    return Material(
      color: color,
      borderRadius: BorderRadius.circular(6),
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          height: tall ? 56 : 40,
          child: Center(
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 12,
                letterSpacing: 0.3,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
