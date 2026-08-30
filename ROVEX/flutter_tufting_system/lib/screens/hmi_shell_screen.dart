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
  MachineService? _machineService;
  bool _dialogVisible = false;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      final service = context.read<MachineService>();

      _machineService = service;
      service.addListener(_handleMachineUpdate);
      service.start();
    });
  }

  @override
  void dispose() {
    _machineService?.removeListener(_handleMachineUpdate);
    super.dispose();
  }

  void _handleMachineUpdate() {
    if (!mounted || _dialogVisible) return;

    final service = _machineService;
    if (service == null) return;

    if (!service.colorCompletionPending) return;

    _showColorCompletionDialog(service);
  }

  Future<void> _showColorCompletionDialog(
    MachineService service,
  ) async {
    if (!mounted || _dialogVisible) return;

    final completedColor = service.completedColorName;
    final nextColor = service.nextColorName;
    final hasNextColor = service.nextColorGroup != null;

    _dialogVisible = true;

    final shouldContinue = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          title: const Text('Color Completed'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                hasNextColor
                    ? 'The machine has finished drawing the current color.'
                    : 'The machine has finished the final color.',
              ),
              const SizedBox(height: 16),
              Text(
                'Completed color: $completedColor',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (hasNextColor) ...[
                const SizedBox(height: 8),
                Text('Next color: $nextColor'),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(false);
              },
              child: const Text('Cancel'),
            ),
            if (hasNextColor)
              FilledButton(
                onPressed: () {
                  Navigator.of(context).pop(true);
                },
                child: const Text('Start Next Color'),
              ),
          ],
        );
      },
    );

    _dialogVisible = false;

    if (!mounted) return;

    if (shouldContinue == true) {
      await service.continueNextColor();
    } else {
      await service.cancelColorRun();
    }
  }

  @override
  Widget build(BuildContext context) {
    final machineService = context.watch<MachineService>();
    final localeController = context.watch<LocaleController>();

    return Directionality(
      textDirection: localeController.textDirection,
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
                  Expanded(
                    child: _buildAreaBody(machineService.area),
                  ),
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

  Widget _buildAreaBody(HmiArea area) {
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