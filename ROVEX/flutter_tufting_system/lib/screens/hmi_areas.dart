import 'dart:typed_data';

import 'package:desktop_drop/desktop_drop.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:provider/provider.dart';

import '../l10n/l10n.dart';
import '../models/machine_status.dart';
import '../services/machine_service.dart';
import '../theme/hmi_colors.dart';
import '../widgets/path_preview.dart';

class MachineAreaBody extends StatelessWidget {
  const MachineAreaBody({super.key});

  @override
  Widget build(BuildContext context) {
    final service = context.watch<MachineService>();

    if (service.status.mode == MachineMode.mdi) {
      return Column(
        children: [
          const Expanded(
            child: PathPreview(),
          ),
          _MdiBar(service: service),
        ],
      );
    }

    return const PathPreview();
  }
}

class _MdiBar extends StatelessWidget {
  final MachineService service;

  const _MdiBar({
    required this.service,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: HmiColors.panelAlt,
      padding: const EdgeInsets.all(10),
      child: Row(
        children: [
          const Text(
            'MDI',
            style: TextStyle(
              color: HmiColors.modeActive,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: TextFormField(
              initialValue: service.mdiLine,
              style: const TextStyle(
                color: HmiColors.text,
                fontSize: 14,
              ),
              decoration: const InputDecoration(
                isDense: true,
                border: OutlineInputBorder(),
                hintText: 'G1 X100 Y50 F1200',
              ),
              onChanged: service.setMdiLine,
            ),
          ),
          const SizedBox(width: 10),
          ElevatedButton(
            onPressed: service.runMdi,
            child: const Text('EXECUTE'),
          ),
        ],
      ),
    );
  }
}

class ProgramAreaBody extends StatelessWidget {
  const ProgramAreaBody({super.key});

  @override
  Widget build(BuildContext context) {
    final service = context.watch<MachineService>();

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'PROGRAM MANAGER',
            style: TextStyle(
              color: HmiColors.text,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            service.loadedProgramName == null
                ? 'No program loaded'
                : 'Loaded: ${service.loadedProgramName} '
                    '(${service.status.pathCount} points)',
            style: const TextStyle(
              color: HmiColors.textDim,
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              ElevatedButton.icon(
                onPressed: () => _openProgram(context, service),
                icon: const Icon(Icons.folder_open),
                label: const Text('Open CSV path'),
              ),
              ElevatedButton.icon(
                onPressed: service.status.pathLoaded
                    ? () => _startProgram(service)
                    : null,
                icon: const Icon(Icons.play_arrow),
                label: const Text('Load to AUTO & Start'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Expanded(
            child: PathPreview(),
          ),
        ],
      ),
    );
  }

  Future<void> _openProgram(
    BuildContext context,
    MachineService service,
  ) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['csv'],
    );

    if (result == null || result.files.isEmpty) {
      return;
    }

    final path = result.files.single.path;

    if (path == null) {
      return;
    }

    await service.setMode(MachineMode.auto);
    await service.loadPathFile(path);
  }

  Future<void> _startProgram(MachineService service) async {
    await service.setMode(MachineMode.auto);
    await service.cycleStart();
    service.setArea(HmiArea.machine);
  }
}

class DesignAreaBody extends StatefulWidget {
  const DesignAreaBody({super.key});

  @override
  State<DesignAreaBody> createState() => _DesignAreaBodyState();
}

class _DesignAreaBodyState extends State<DesignAreaBody> {
  static const double _targetAspectRatio = 1.5 / 2.0;

  bool _dragging = false;

  Uint8List _cropToTargetRatio(List<int> bytes) {
    final image = img.decodeImage(
      Uint8List.fromList(bytes),
    );

    if (image == null) {
      return Uint8List.fromList(bytes);
    }

    final sourceRatio = image.width / image.height;

    if (sourceRatio > _targetAspectRatio) {
      final cropWidth =
          (image.height * _targetAspectRatio).round();

      final offsetX =
          ((image.width - cropWidth) / 2).round();

      final cropped = img.copyCrop(
        image,
        x: offsetX,
        y: 0,
        width: cropWidth,
        height: image.height,
      );

      return Uint8List.fromList(
  img.encodePng(cropped),
);
    }

    final cropHeight =
        (image.width / _targetAspectRatio).round();

    final offsetY =
        ((image.height - cropHeight) / 2).round();

    final cropped = img.copyCrop(
      image,
      x: 0,
      y: offsetY,
      width: image.width,
      height: cropHeight,
    );

    return Uint8List.fromList(
  img.encodePng(cropped),
);
  }

  Future<void> _pick(MachineService service) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: [
          'png',
          'jpg',
          'jpeg',
          'bmp',
          'gif',
          'webp',
          'dxf',
        ],
        withData: true,
      );

      if (result == null || result.files.isEmpty) {
        return;
      }

      final file = result.files.first;
      final bytes = file.bytes;

      if (bytes == null) {
        _showError(
          'Could not read file bytes for "${file.name}".',
        );
        return;
      }

      await _loadDesign(
        service,
        bytes,
        file.name,
      );
    } catch (error) {
      _showError('Upload failed: $error');
    }
  }

  Future<void> _loadDesign(
    MachineService service,
    List<int> bytes,
    String fileName,
  ) async {
    if (fileName.toLowerCase().endsWith('.dxf')) {
      await service.loadDesignFromDxf(
        Uint8List.fromList(bytes),
        fileName,
      );
      return;
    }

    final croppedBytes = Uint8List.fromList(
      _cropToTargetRatio(bytes),
    );

    await service.loadDesignImage(
      croppedBytes,
      fileName,
    );
  }

  void _showError(String message) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: HmiColors.alarm,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final service = context.watch<MachineService>();
    final localization = context.watch<LocaleController>();
    final t = localization.l10n;

    return DropTarget(
      onDragEntered: (_) {
        setState(() {
          _dragging = true;
        });
      },
      onDragExited: (_) {
        setState(() {
          _dragging = false;
        });
      },
      onDragDone: (details) async {
        setState(() {
          _dragging = false;
        });

        if (details.files.isEmpty) {
          return;
        }

        final file = details.files.first;

        try {
          final bytes = await file.readAsBytes();

          await _loadDesign(
            service,
            bytes,
            file.name,
          );
        } catch (error) {
          _showError('Upload failed: $error');
        }
      },
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Expanded(
              flex: 3,
              child: _DesignDropArea(
                dragging: _dragging,
                service: service,
                localization: t,
                onBrowse: () => _pick(service),
              ),
            ),
            const SizedBox(width: 12),
            SizedBox(
              width: 300,
              child: _DesignControls(
                service: service,
                localization: t,
              ),
            ),
            const SizedBox(width: 12),
            SizedBox(
              width: 280,
              child: _GCodePanel(
                service: service,
                localization: t,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DesignDropArea extends StatelessWidget {
  final bool dragging;
  final MachineService service;
  final L10n localization;
  final VoidCallback onBrowse;

  const _DesignDropArea({
    required this.dragging,
    required this.service,
    required this.localization,
    required this.onBrowse,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onBrowse,
      child: AnimatedContainer(
        duration: const Duration(
          milliseconds: 150,
        ),
        decoration: BoxDecoration(
          color: HmiColors.panelAlt,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: dragging
                ? HmiColors.gold
                : HmiColors.border,
            width: 2,
          ),
        ),
        child: _buildContent(),
      ),
    );
  }

  Widget _buildContent() {
    if (service.isDxfDesign) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.architecture,
              color: HmiColors.accent,
              size: 40,
            ),
            const SizedBox(height: 8),
            Text(
              service.designName ?? 'DXF',
              style: const TextStyle(
                color: HmiColors.text,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Exact vector path (DXF)',
              style: TextStyle(
                color: HmiColors.textDim,
                fontSize: 11.5,
              ),
            ),
          ],
        ),
      );
    }

    if (service.hasDesign) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Image.memory(
          service.designImage!,
          fit: BoxFit.contain,
        ),
      );
    }

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.upload_file,
            color: HmiColors.textDim,
            size: 34,
          ),
          const SizedBox(height: 10),
          Text(
            localization.t('drop_image'),
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: HmiColors.textDim,
            ),
          ),
          const SizedBox(height: 14),
          ElevatedButton.icon(
            onPressed: onBrowse,
            icon: const Icon(Icons.folder_open),
            label: const Text('Browse files…'),
          ),
        ],
      ),
    );
  }
}

class _DesignControls extends StatelessWidget {
  final MachineService service;
  final L10n localization;

  const _DesignControls({
    required this.service,
    required this.localization,
  });

  @override
  Widget build(BuildContext context) {
    final t = localization;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.stretch,
              children: [
                Text(
                  service.designName ?? '—',
                  style: const TextStyle(
                    color: HmiColors.text,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  '${t.t('path_points')}: '
                  '${service.programPoints.length}'
                  '${service.isExtracting ? ' …' : ''}',
                  style: const TextStyle(
                    color: HmiColors.textDim,
                  ),
                ),
                if (service.colorGroups.isNotEmpty)
                  _ColorSummary(
                    service: service,
                    localization: t,
                  ),
                const SizedBox(height: 16),
                Text(
                  'Pitch '
                  '${service.extractPitchMm.toStringAsFixed(0)} mm',
                  style: const TextStyle(
                    color: HmiColors.accent,
                    fontSize: 11,
                  ),
                ),
                Slider(
                  value: service.extractPitchMm,
                  min: 2,
                  max: 20,
                  divisions: 18,
                  onChanged: service.isExtracting
                      ? null
                      : service.setExtractPitch,
                ),
                ElevatedButton(
                  onPressed: service.hasDesign &&
                          !service.isExtracting
                      ? service.extractPathFromDesign
                      : null,
                  child: Text(
                    service.isExtracting
                        ? '…'
                        : t.t('extract_path'),
                  ),
                ),
                const SizedBox(height: 8),
                ElevatedButton(
                  onPressed:
                      service.programPoints.length < 2 ||
                              service.isExtracting
                          ? null
                          : () => service
                              .buildAndLoadProgramFromDesign(
                                name:
                                    service.designName ??
                                        'design',
                                points:
                                    service.programPoints,
                              ),
                  child: Text(
                    t.t('optimize_load'),
                  ),
                ),
                const SizedBox(height: 8),
                OutlinedButton(
                  onPressed: () {
                    service.setArea(
                      HmiArea.machine,
                    );
                    service.setMode(
                      MachineMode.auto,
                    );
                  },
                  child: Text(
                    t.t('machine'),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        const SizedBox(
          height: 150,
          child: PathPreview(),
        ),
      ],
    );
  }
}

class _ColorSummary extends StatelessWidget {
  final MachineService service;
  final L10n localization;

  const _ColorSummary({
    required this.service,
    required this.localization,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        children: [
          Text(
            '${localization.t('colors_detected')}: '
            '${service.colorCount}',
            style: const TextStyle(
              color: HmiColors.textDim,
            ),
          ),
          const SizedBox(width: 8),
          ...service.colorGroups.map(
            (group) => Padding(
              padding: const EdgeInsets.only(
                right: 4,
              ),
              child: Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: Color(group.colorValue),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: HmiColors.border,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GCodePanel extends StatelessWidget {
  final MachineService service;
  final L10n localization;

  const _GCodePanel({
    required this.service,
    required this.localization,
  });

  static const int _maxPreviewLength = 8000;

  String get _displayedGCode {
    if (service.gCode.isEmpty) {
      return '; Extract path to generate G-code';
    }

    if (service.gCode.length <= _maxPreviewLength) {
      return service.gCode;
    }

    return '${service.gCode.substring(0, _maxPreviewLength)}\n'
        '; … truncated for UI speed';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment:
          CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Text(
              localization.t('gcode'),
              style: const TextStyle(
                color: HmiColors.accent,
                fontWeight: FontWeight.w800,
              ),
            ),
            const Spacer(),
            TextButton(
              onPressed: service.regenerateGCode,
              child: const Text(
                '↻',
                style: TextStyle(
                  color: HmiColors.accent,
                ),
              ),
            ),
          ],
        ),
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF0D141C),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: HmiColors.border,
              ),
            ),
            child: SingleChildScrollView(
              child: SelectableText(
                _displayedGCode,
                style: const TextStyle(
                  color: Color(0xFF7CF5C8),
                  fontFamily: 'Consolas',
                  fontSize: 11,
                  height: 1.35,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class DiagnosisAreaBody extends StatelessWidget {
  const DiagnosisAreaBody({super.key});

  @override
  Widget build(BuildContext context) {
    final service = context.watch<MachineService>();
    final status = service.status;

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const Text(
          'DIAGNOSIS',
          style: TextStyle(
            color: HmiColors.text,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 12),
        _infoRow(
          'Runtime link',
          service.runtimeLinked
              ? 'C :9100'
              : 'Local fallback',
        ),
        _infoRow(
          'Backend',
          status.backend,
        ),
        _infoRow(
          'Port',
          status.port,
        ),
        _infoRow(
          'Baud',
          '${status.baud}',
        ),
        _infoRow(
          'Mode',
          status.modeLabel,
        ),
        _infoRow(
          'State',
          status.stateLabel,
        ),
        _infoRow(
          'Alarm',
          status.alarm.isEmpty
              ? '—'
              : status.alarm,
        ),
        _infoRow(
          'X / Y',
          '${status.x.toStringAsFixed(3)} / '
          '${status.y.toStringAsFixed(3)} mm',
        ),
        _infoRow(
          'Program %',
          status.progPct.toStringAsFixed(1),
        ),
        const SizedBox(height: 16),
        const Text(
          'Alarms: Soft limit · Not connected · Path empty · '
          'EMERGENCY STOP · Serial lost',
          style: TextStyle(
            color: HmiColors.textMute,
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Widget _infoRow(
    String label,
    String value,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        vertical: 6,
      ),
      child: Row(
        children: [
          SizedBox(
            width: 140,
            child: Text(
              label,
              style: const TextStyle(
                color: HmiColors.textDim,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: HmiColors.text,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class SetupAreaBody extends StatelessWidget {
  const SetupAreaBody({super.key});

  @override
  Widget build(BuildContext context) {
    final service = context.watch<MachineService>();

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const Text(
          'SETUP',
          style: TextStyle(
            color: HmiColors.text,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          'Hardware backend',
          style: TextStyle(
            color: HmiColors.textDim,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: [
            ChoiceChip(
              label: const Text('SIM'),
              selected:
                  service.setupBackend == 'sim',
              onSelected: (_) {
                service.setSetup(
                  backend: 'sim',
                );
              },
            ),
            ChoiceChip(
              label: const Text('SERIAL (GRBL)'),
              selected:
                  service.setupBackend == 'serial',
              onSelected: (_) {
                service.setSetup(
                  backend: 'serial',
                );
              },
            ),
          ],
        ),
        const SizedBox(height: 16),
        TextFormField(
          initialValue: service.setupPort,
          decoration: const InputDecoration(
            labelText: 'COM port (Windows)',
            hintText: 'COM3',
            border: OutlineInputBorder(),
          ),
          style: const TextStyle(
            color: HmiColors.text,
          ),
          onChanged: (value) {
            service.setSetup(
              port: value,
            );
          },
        ),
        const SizedBox(height: 12),
        TextFormField(
          initialValue: '${service.setupBaud}',
          decoration: const InputDecoration(
            labelText: 'Baud',
            border: OutlineInputBorder(),
          ),
          style: const TextStyle(
            color: HmiColors.text,
          ),
          keyboardType: TextInputType.number,
          onChanged: (value) {
            final baud = int.tryParse(value);

            if (baud != null) {
              service.setSetup(
                baud: baud,
              );
            }
          },
        ),
        const SizedBox(height: 20),
        ElevatedButton(
          onPressed: service.connectMachine,
          child: const Text(
            'APPLY & CONNECT',
          ),
        ),
        const SizedBox(height: 12),
        const Text(
          'Start C runtime first:\n'
          r'  firmware\bin\machine_server.exe'
          '\nThen CONNECT with SIM or SERIAL.',
          style: TextStyle(
            color: HmiColors.textMute,
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}