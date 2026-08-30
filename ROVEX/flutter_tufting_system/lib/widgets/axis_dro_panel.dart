import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/l10n.dart';
import '../services/machine_service.dart';
import '../theme/hmi_colors.dart';

class AxisDroPanel extends StatelessWidget {
  const AxisDroPanel({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<MachineService>().status;
    final t = context.watch<LocaleController>().l10n;

    return Container(
      width: 260,
      color: HmiColors.panel,
      padding: const EdgeInsets.all(14),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              t.t('actual_pos'),
              style: const TextStyle(
                color: HmiColors.gold,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 1,
              ),
            ),
            const SizedBox(height: 10),

            _axis('X', s.x),
            const SizedBox(height: 8),

            _axis('Y', s.y),
            const SizedBox(height: 8),

            _axis('Z', s.z, highlight: true),
            const SizedBox(height: 6),

            Text(
              t.t('needle_axis'),
              style: const TextStyle(
                color: HmiColors.accent,
                fontSize: 10,
              ),
            ),
            const SizedBox(height: 12),

            _kv('WCS X', s.wcsX.toStringAsFixed(3)),
            _kv('WCS Y', s.wcsY.toStringAsFixed(3)),
            _kv('WCS Z', s.wcsZ.toStringAsFixed(3)),

            const Divider(
              color: HmiColors.border,
              height: 28,
            ),

            _kv('Feed ovrd', '${s.feedOverride}%'),
            _kv(
              'Jog step',
              '${s.jogStep.toStringAsFixed(2)} mm',
            ),
            _kv(
              'Needle',
              s.needle ? 'DOWN' : 'UP',
            ),
            _kv(
              'Referenced',
              s.referenced ? 'YES' : 'NO',
            ),
            _kv(
              'Program',
              '${s.progPct.toStringAsFixed(1)}%',
            ),
            _kv(
              'Points',
              '${s.pathIndex}/${s.pathCount}',
            ),

            const SizedBox(height: 16),

            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                border: Border.all(
                  color: s.connected
                      ? HmiColors.ready
                      : HmiColors.alarm,
                ),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    s.connected
                        ? 'MACHINE LINKED'
                        : 'MACHINE OFFLINE',
                    style: TextStyle(
                      color: s.connected
                          ? HmiColors.ready
                          : HmiColors.alarm,
                      fontWeight: FontWeight.w800,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${s.backend.toUpperCase()}  ${s.port}',
                    style: const TextStyle(
                      color: HmiColors.textDim,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _axis(
    String name,
    double value, {
    bool highlight = false,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 10,
      ),
      decoration: BoxDecoration(
        color: HmiColors.panelAlt,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: highlight
              ? HmiColors.gold
              : HmiColors.border,
        ),
      ),
      child: Row(
        children: [
          Text(
            name,
            style: TextStyle(
              color: highlight
                  ? HmiColors.gold
                  : HmiColors.accent,
              fontSize: 22,
              fontWeight: FontWeight.w800,
            ),
          ),
          const Spacer(),
          Text(
            value.toStringAsFixed(3),
            style: const TextStyle(
              color: HmiColors.dro,
              fontSize: 24,
              fontWeight: FontWeight.w700,
              fontFeatures: [
                FontFeature.tabularFigures(),
              ],
            ),
          ),
          const SizedBox(width: 6),
          const Text(
            'mm',
            style: TextStyle(
              color: HmiColors.textMute,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _kv(String key, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(
            child: Text(
              key,
              style: const TextStyle(
                color: HmiColors.textDim,
                fontSize: 12,
              ),
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              color: HmiColors.text,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}