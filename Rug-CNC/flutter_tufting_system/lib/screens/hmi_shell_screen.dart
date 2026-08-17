import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/l10n.dart';
import '../models/machine_status.dart';
import '../services/machine_service.dart';
import '../theme/hmi_colors.dart';
import '../widgets/alarm_bar.dart';
import '../widgets/axis_dro_panel.dart';
import '../widgets/hmi_softkey_bar.dart';
import '../widgets/machine_control_panel.dart';
import '../widgets/mode_selector.dart';
import 'extra_areas.dart';
import 'hmi_areas.dart';

class HmiShellScreen extends StatefulWidget {
  const HmiShellScreen({super.key});

  @override
  State<HmiShellScreen> createState() => _HmiShellScreenState();
}

class _HmiShellScreenState extends State<HmiShellScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<MachineService>().start();
    });
  }

  @override
  Widget build(BuildContext context) {
    final area = context.watch<MachineService>().area;
    final loc = context.watch<LocaleController>();

    return Directionality(
      textDirection: loc.textDirection,
      child: Scaffold(
        backgroundColor: HmiColors.bg,
        body: Column(
          children: [
            const HmiSoftkeyBar(),
            const ModeSelector(),
            Expanded(
              child: Row(
                children: [
                  const AxisDroPanel(),
                  Expanded(child: _areaBody(area)),
                  const MachineControlPanel(),
                ],
              ),
            ),
            const AlarmBar(),
          ],
        ),
      ),
    );
  }

  Widget _areaBody(HmiArea area) {
    switch (area) {
      case HmiArea.machine:
        return const MachineAreaBody();
      case HmiArea.program:
        return const ProgramAreaBody();
      case HmiArea.design:
        return const DesignAreaBody();
      case HmiArea.needle3d:
        return const Needle3dAreaBody();
      case HmiArea.errors:
        return const ErrorsAreaBody();
      case HmiArea.plc:
        return const PlcAreaBody();
      case HmiArea.diagnosis:
        return const DiagnosisAreaBody();
      case HmiArea.setup:
        return const SetupAreaBody();
    }
  }
}
