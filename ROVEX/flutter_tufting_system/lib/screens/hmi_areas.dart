import 'dart:typed_data';

import 'package:desktop_drop/desktop_drop.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:provider/provider.dart';

import '../l10n/l10n.dart';
import '../models/machine_status.dart';
import '../services/machine_service.dart';
import '../theme/hmi_colors.dart';
import '../widgets/hmi_button.dart';
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
              child: _DesignDropArea(
                dragging: _dragging,
                service: service,
                localization: t,
                onBrowse: () => _pick(service),
              ),
            ),
            const SizedBox(width: 12),
            SizedBox(
              width: 320,
              child: _DesignControls(
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

  String _label(String key, String fallback) {
    final value = localization.t(key);
    return value == key ? fallback : value;
  }

  @override
  Widget build(BuildContext context) {
    final t = localization;
    final extracting = service.isExtracting;
    final canExtract = service.hasDesign && !extracting;
    final canOptimize =
        service.programPoints.length >= 2 && !extracting;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  service.designName ?? '—',
                  style: const TextStyle(
                    color: HmiColors.text,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${t.t('path_points')}: '
                  '${service.programPoints.length}'
                  '${extracting ? ' …' : ''}',
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
                SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    activeTrackColor: HmiColors.accent,
                    inactiveTrackColor: HmiColors.border,
                    thumbColor: HmiColors.accentStrong,
                    overlayColor: HmiColors.accent.withValues(
                      alpha: 0.16,
                    ),
                  ),
                  child: Slider(
                    value: service.extractPitchMm,
                    min: 2,
                    max: 20,
                    divisions: 18,
                    onChanged: extracting
                        ? null
                        : service.setExtractPitch,
                  ),
                ),
                HmiButton(
                  label: extracting
                      ? '…'
                      : t.t('extract_path'),
                  icon: Icons.auto_fix_high,
                  fullWidth: true,
                  type: HmiButtonType.start,
                  enabled: canExtract,
                  onPressed: canExtract
                      ? service.extractPathFromDesign
                      : null,
                ),
                const SizedBox(height: 8),
                HmiButton(
                  label: t.t('optimize_load'),
                  icon: Icons.route,
                  fullWidth: true,
                  enabled: canOptimize,
                  onPressed: canOptimize
                      ? () =>
                          service.buildAndLoadProgramFromDesign(
                            name: service.designName ??
                                'design',
                            points: service.programPoints,
                          )
                      : null,
                ),
                const SizedBox(height: 8),
                HmiButton(
                  label: _label('view_code', 'VIEW CODE'),
                  icon: Icons.terminal,
                  fullWidth: true,
                  type: HmiButtonType.active,
                  onPressed: () {
                    showProgramCodeStudio(
                      context: context,
                      service: service,
                      localization: localization,
                    );
                  },
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
                  style: OutlinedButton.styleFrom(
                    foregroundColor: HmiColors.text,
                    side: const BorderSide(
                      color: HmiColors.border,
                    ),
                    minimumSize: const Size.fromHeight(46),
                  ),
                  child: Text(
                    t.t('machine'),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        const Expanded(
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

Future<void> showProgramCodeStudio({
  required BuildContext context,
  required MachineService service,
  required L10n localization,
}) {
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Dismiss',
    barrierColor: HmiColors.scrim,
    transitionDuration: HmiColors.motionStandard,
    pageBuilder: (context, animation, secondaryAnimation) {
      return const SizedBox.shrink();
    },
    transitionBuilder: (context, animation, secondaryAnimation, child) {
      return FadeTransition(
        opacity: animation,
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.98, end: 1).animate(
            CurvedAnimation(
              parent: animation,
              curve: HmiColors.entranceCurve,
            ),
          ),
          child: _ProgramCodeStudio(
            service: service,
            localization: localization,
          ),
        ),
      );
    },
  );
}

class _ProgramCodeStudio extends StatefulWidget {
  final MachineService service;
  final L10n localization;

  const _ProgramCodeStudio({
    required this.service,
    required this.localization,
  });

  @override
  State<_ProgramCodeStudio> createState() =>
      _ProgramCodeStudioState();
}

class _ProgramCodeStudioState extends State<_ProgramCodeStudio> {
  static const int _maxPreviewLength = 8000;

  int _tab = 0;

  String _label(String key, String fallback) {
    final value = widget.localization.t(key);
    return value == key ? fallback : value;
  }

  String get _displayedGCode {
    final code = widget.service.gCode;

    if (code.isEmpty) {
      return '; Extract path to generate G-code';
    }

    if (code.length <= _maxPreviewLength) {
      return code;
    }

    return '${code.substring(0, _maxPreviewLength)}\n'
        '; … truncated for UI speed';
  }

  List<_MCodeRow> get _mCodeRows {
    final used = <String>{};
    final match = RegExp(r'\bM\d+\b');

    for (final found in match.allMatches(widget.service.gCode)) {
      used.add(found.group(0)!);
    }

    const known = <String, String>{
      'M8': 'Engage needle / tool',
      'M9': 'Disengage needle / tool',
      'M30': 'End of program',
    };

    final rows = <_MCodeRow>[];

    for (final code in used.toList()..sort()) {
      rows.add(
        _MCodeRow(
          code: code,
          name: known[code] ?? 'Program M-code',
          note: used.contains(code)
              ? 'Used in current program'
              : '',
          runnable: false,
        ),
      );
    }

    for (final macro in widget.service.plcMacros) {
      rows.add(
        _MCodeRow(
          code: macro.code,
          name: macro.name,
          note: macro.note,
          runnable: true,
          macro: macro,
        ),
      );
    }

    return rows;
  }

  Future<void> _copy(String text) async {
    await Clipboard.setData(ClipboardData(text: text));

    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(_label('copied', 'Copied to clipboard')),
        backgroundColor: HmiColors.accentSurface,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final service = widget.service;
    final size = MediaQuery.sizeOf(context);

    return Center(
      child: Material(
        color: Colors.transparent,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: (size.width * 0.78).clamp(720, 1100),
            maxHeight: (size.height * 0.82).clamp(480, 860),
          ),
          child: Container(
            decoration: BoxDecoration(
              color: HmiColors.dialog,
              borderRadius: BorderRadius.circular(
                HmiColors.radiusXLarge,
              ),
              border: Border.all(color: HmiColors.border),
              boxShadow: const [
                BoxShadow(
                  color: HmiColors.shadowStrong,
                  blurRadius: 28,
                  offset: Offset(0, 12),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 14, 8, 10),
                  child: Row(
                    children: [
                      Container(
                        width: 4,
                        height: 22,
                        decoration: BoxDecoration(
                          color: HmiColors.accent,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment:
                              CrossAxisAlignment.start,
                          children: [
                            Text(
                              _label(
                                'code_studio_title',
                                'PROGRAM CODE',
                              ),
                              style: const TextStyle(
                                color: HmiColors.text,
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.4,
                              ),
                            ),
                            Text(
                              '${service.designName ?? 'ROVEX'}  ·  '
                              '${service.programPoints.length} pts',
                              style: const TextStyle(
                                color: HmiColors.textMute,
                                fontSize: 11.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                      TextButton(
                        onPressed: service.regenerateGCode,
                        child: Text(
                          _label('regenerate', '↻ REGENERATE'),
                          style: const TextStyle(
                            color: HmiColors.accent,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Close',
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(
                          Icons.close,
                          color: HmiColors.textDim,
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                  child: Row(
                    children: [
                      _CodeTab(
                        label: _label('gcode', 'G-CODE'),
                        selected: _tab == 0,
                        onTap: () => setState(() => _tab = 0),
                      ),
                      const SizedBox(width: 8),
                      _CodeTab(
                        label: _label('mcode', 'M-CODE'),
                        selected: _tab == 1,
                        onTap: () => setState(() => _tab = 1),
                      ),
                      const Spacer(),
                      TextButton.icon(
                        onPressed: () => _copy(
                          _tab == 0
                              ? service.gCode
                              : _mCodeRows
                                  .map((row) =>
                                      '${row.code}  ${row.name}')
                                  .join('\n'),
                        ),
                        icon: const Icon(
                          Icons.copy,
                          size: 16,
                          color: HmiColors.textDim,
                        ),
                        label: Text(
                          _label('copy_code', 'COPY'),
                          style: const TextStyle(
                            color: HmiColors.textDim,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: HmiColors.previewBg,
                        borderRadius: BorderRadius.circular(
                          HmiColors.radiusLarge,
                        ),
                        border: Border.all(color: HmiColors.border),
                      ),
                      child: _tab == 0
                          ? _GCodeEditor(text: _displayedGCode)
                          : _MCodeTable(
                              rows: _mCodeRows,
                              onRun: (macro) {
                                service.runPlcMacro(macro);
                              },
                            ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CodeTab extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _CodeTab({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: HmiColors.motionFast,
        padding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 8,
        ),
        decoration: BoxDecoration(
          color: selected
              ? HmiColors.accentSurface
              : HmiColors.softkey,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: selected
                ? HmiColors.borderAccent
                : HmiColors.border,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? HmiColors.accentStrong : HmiColors.textDim,
            fontSize: 12,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.4,
          ),
        ),
      ),
    );
  }
}

class _GCodeEditor extends StatelessWidget {
  final String text;

  const _GCodeEditor({required this.text});

  @override
  Widget build(BuildContext context) {
    final lines = text.split('\n');

    return Scrollbar(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(14),
        child: SelectableText.rich(
          TextSpan(
            children: [
              for (final line in lines) _spanForLine(line),
            ],
          ),
        ),
      ),
    );
  }

  TextSpan _spanForLine(String line) {
    const base = TextStyle(
      fontFamily: 'Consolas',
      fontSize: 12,
      height: 1.4,
    );

    final trimmed = line.trimLeft();
    Color color = HmiColors.previewPath;

    if (trimmed.startsWith(';')) {
      color = HmiColors.textMute;
    } else if (RegExp(r'^M\d+').hasMatch(trimmed)) {
      color = HmiColors.warn;
    } else if (RegExp(r'^G\d+').hasMatch(trimmed)) {
      color = HmiColors.dro;
    }

    return TextSpan(
      text: '$line\n',
      style: base.copyWith(color: color),
    );
  }
}

class _MCodeRow {
  final String code;
  final String name;
  final String note;
  final bool runnable;
  final PlcMacro? macro;

  const _MCodeRow({
    required this.code,
    required this.name,
    required this.note,
    required this.runnable,
    this.macro,
  });
}

class _MCodeTable extends StatelessWidget {
  final List<_MCodeRow> rows;
  final ValueChanged<PlcMacro> onRun;

  const _MCodeTable({
    required this.rows,
    required this.onRun,
  });

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) {
      return const Center(
        child: Text(
          'No M-codes in the current program.',
          style: TextStyle(color: HmiColors.textMute),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(10),
      itemCount: rows.length,
      separatorBuilder: (_, __) => const Divider(
        height: 1,
        color: HmiColors.divider,
      ),
      itemBuilder: (context, index) {
        final row = rows[index];

        return ListTile(
          dense: true,
          leading: Container(
            width: 56,
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(
              horizontal: 6,
              vertical: 4,
            ),
            decoration: BoxDecoration(
              color: HmiColors.warnSurface,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(
                color: HmiColors.warn.withValues(alpha: 0.45),
              ),
            ),
            child: Text(
              row.code,
              style: const TextStyle(
                color: HmiColors.warn,
                fontWeight: FontWeight.w800,
                fontFamily: 'Consolas',
                fontSize: 12,
              ),
            ),
          ),
          title: Text(
            row.name,
            style: const TextStyle(
              color: HmiColors.text,
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
          ),
          subtitle: row.note.isEmpty
              ? null
              : Text(
                  row.note,
                  style: const TextStyle(
                    color: HmiColors.textMute,
                    fontSize: 11,
                  ),
                ),
          trailing: row.runnable && row.macro != null
              ? HmiButton(
                  label: 'RUN',
                  width: 72,
                  height: 36,
                  type: HmiButtonType.start,
                  onPressed: () => onRun(row.macro!),
                )
              : null,
        );
      },
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
              selected: service.setupBackend == 'sim',
              onSelected: (_) {
                service.setSetup(
                  backend: 'sim',
                );
              },
            ),
            ChoiceChip(
              label: const Text('SERIAL (GRBL)'),
              selected: service.setupBackend == 'serial',
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