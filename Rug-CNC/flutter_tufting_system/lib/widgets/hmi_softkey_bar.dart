import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/l10n.dart';
import '../models/machine_status.dart';
import '../services/ambient_audio.dart';
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
                fontWeight: FontWeight.w800,
                fontSize: 15,
                letterSpacing: 1.0,
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
                          horizontal: 2, vertical: 6),
                      child: Material(
                        color: svc.area == area
                            ? HmiColors.softkeyActive
                            : HmiColors.softkey,
                        borderRadius: BorderRadius.circular(4),
                        child: InkWell(
                          onTap: () => svc.setArea(area),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 8),
                            child: Text(
                              label,
                              style: TextStyle(
                                color: svc.area == area
                                    ? HmiColors.text
                                    : HmiColors.textDim,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          IconButton(
            tooltip: 'صوت النظام',
            onPressed: () => AmbientAudio.instance.toggleMute(),
            icon: const Icon(Icons.volume_up, size: 18, color: HmiColors.textDim),
          ),
          const SizedBox(width: 4),
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
      borderRadius: BorderRadius.circular(4),
      child: InkWell(
        onTap: loc.cycleLang,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: Text(
            '${loc.l10n.t('language')}: ${loc.l10n.code}',
            style: const TextStyle(
              color: HmiColors.accent,
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ),
    );
  }

  Widget _linkBadge(MachineService svc) {
    final ok = svc.runtimeLinked || svc.status.connected;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        border: Border.all(color: ok ? HmiColors.ready : HmiColors.alarm),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        svc.runtimeLinked
            ? 'C'
            : (svc.status.connected ? 'SIM' : 'OFF'),
        style: TextStyle(
          color: ok ? HmiColors.ready : HmiColors.alarm,
          fontSize: 10,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}
