import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/machine_service.dart';
import '../theme/hmi_colors.dart';

class AlarmBar extends StatelessWidget {
  const AlarmBar({super.key});

  @override
  Widget build(BuildContext context) {
    final svc = context.watch<MachineService>();
    final alarm = svc.status.alarm;
    final hasAlarm = alarm.isNotEmpty;

    return Container(
      height: 36,
      color: hasAlarm
          ? HmiColors.estop.withValues(alpha: 0.25)
          : HmiColors.panelAlt,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          Icon(
            hasAlarm
                ? Icons.warning_amber_rounded
                : Icons.check_circle,
            size: 16,
            color: hasAlarm
                ? HmiColors.alarm
                : HmiColors.ready,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              hasAlarm ? 'ALARM: $alarm' : svc.message,
              style: TextStyle(
                color: hasAlarm
                    ? HmiColors.alarm
                    : HmiColors.textDim,
                fontSize: 12,
                fontWeight: hasAlarm
                    ? FontWeight.w700
                    : FontWeight.w500,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Text(
            'Feed ${svc.status.feedOverride}%',
            style: const TextStyle(
              color: HmiColors.textMute,
              fontSize: 11,
            ),
          ),
          SizedBox(
            width: 140,
            child: SliderTheme(
              data: SliderTheme.of(context).copyWith(
                trackHeight: 3,
                thumbShape: const RoundSliderThumbShape(
                  enabledThumbRadius: 7,
                ),
              ),
              child: Slider(
                value: svc.status.feedOverride
                    .toDouble()
                    .clamp(0, 120),
                min: 0,
                max: 120,
                onChanged: (v) {
                  svc.setFeedOverride(v.round());
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}