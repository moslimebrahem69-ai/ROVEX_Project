import 'package:desktop_drop/desktop_drop.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/l10n.dart';
import '../models/machine_status.dart';
import '../models/sample_project.dart';
import '../services/machine_service.dart';
import '../theme/hmi_colors.dart';
import '../widgets/path_preview.dart';

class MachineAreaBody extends StatelessWidget {
  const MachineAreaBody({super.key});

  @override
  Widget build(BuildContext context) {
    final svc = context.watch<MachineService>();
    if (svc.status.mode == MachineMode.mdi) {
      return Column(
        children: [
          Expanded(child: const PathPreview()),
          _MdiBar(svc: svc),
        ],
      );
    }
    return const PathPreview();
  }
}

class _MdiBar extends StatelessWidget {
  final MachineService svc;
  const _MdiBar({required this.svc});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: HmiColors.panelAlt,
      padding: const EdgeInsets.all(10),
      child: Row(
        children: [
          const Text('MDI',
              style: TextStyle(
                  color: HmiColors.modeActive,
                  fontWeight: FontWeight.w800)),
          const SizedBox(width: 12),
          Expanded(
            child: TextFormField(
              initialValue: svc.mdiLine,
              style: const TextStyle(color: HmiColors.text, fontSize: 14),
              decoration: const InputDecoration(
                isDense: true,
                border: OutlineInputBorder(),
                hintText: 'G1 X100 Y50 F1200',
              ),
              onChanged: svc.setMdiLine,
            ),
          ),
          const SizedBox(width: 10),
          ElevatedButton(
            onPressed: svc.runMdi,
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
    final svc = context.watch<MachineService>();
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('PROGRAM MANAGER',
              style: TextStyle(
                  color: HmiColors.text,
                  fontSize: 18,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Text(
            svc.loadedProgramName == null
                ? 'No program loaded'
                : 'Loaded: ${svc.loadedProgramName}  (${svc.status.pathCount} points)',
            style: const TextStyle(color: HmiColors.textDim),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              ElevatedButton.icon(
                onPressed: () async {
                  final r = await FilePicker.platform.pickFiles(
                    type: FileType.custom,
                    allowedExtensions: ['csv'],
                  );
                  if (r == null || r.files.isEmpty) return;
                  final path = r.files.single.path;
                  if (path == null) return;
                  await svc.setMode(MachineMode.auto);
                  await svc.loadPathFile(path);
                },
                icon: const Icon(Icons.folder_open),
                label: const Text('Open CSV path'),
              ),
              ElevatedButton.icon(
                onPressed: svc.status.pathLoaded
                    ? () async {
                        await svc.setMode(MachineMode.auto);
                        await svc.cycleStart();
                        svc.setArea(HmiArea.machine);
                      }
                    : null,
                icon: const Icon(Icons.play_arrow),
                label: const Text('Load to AUTO & Start'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Expanded(child: PathPreview()),
        ],
      ),
    );
  }
}

class DesignAreaBody extends StatefulWidget {
  const DesignAreaBody({super.key});

  @override
  State<DesignAreaBody> createState() => _DesignAreaBodyState();
}

class _DesignAreaBodyState extends State<DesignAreaBody> {
  bool _dragging = false;

  Future<void> _pick(MachineService svc) async {
    try {
      final r = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: const [
          'png', 'jpg', 'jpeg', 'bmp', 'gif', 'webp', 'dxf'
        ],
        withData: true,
      );
      if (r == null || r.files.isEmpty) return; // user cancelled
      final f = r.files.first;
      if (f.bytes == null) {
        _showError('Could not read file bytes for "${f.name}".');
        return;
      }
      if (f.name.toLowerCase().endsWith('.dxf')) {
        await svc.loadDesignFromDxf(f.bytes!, f.name);
      } else {
        await svc.loadDesignImage(f.bytes!, f.name);
      }
    } catch (e) {
      _showError('Upload failed: $e');
    }
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: HmiColors.alarm),
    );
  }

  @override
  Widget build(BuildContext context) {
    final svc = context.watch<MachineService>();
    final loc = context.watch<LocaleController>();
    final t = loc.l10n;

    return DropTarget(
      onDragEntered: (_) => setState(() => _dragging = true),
      onDragExited: (_) => setState(() => _dragging = false),
      onDragDone: (d) async {
        setState(() => _dragging = false);
        if (d.files.isEmpty) return;
        final f = d.files.first;
        final bytes = await f.readAsBytes();
        if (f.name.toLowerCase().endsWith('.dxf')) {
          await svc.loadDesignFromDxf(bytes, f.name);
        } else {
          await svc.loadDesignImage(bytes, f.name);
        }
      },
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Expanded(
              flex: 3,
              child: GestureDetector(
                onTap: () => _pick(svc),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  decoration: BoxDecoration(
                    color: HmiColors.panelAlt,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _dragging ? HmiColors.gold : HmiColors.border,
                      width: 2,
                    ),
                  ),
                  child: svc.isDxfDesign
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.architecture,
                                  color: HmiColors.accent, size: 40),
                              const SizedBox(height: 8),
                              Text(
                                svc.designName ?? 'DXF',
                                style: const TextStyle(
                                    color: HmiColors.text,
                                    fontWeight: FontWeight.w700),
                              ),
                              const SizedBox(height: 4),
                              const Text(
                                'Exact vector path (DXF)',
                                style: TextStyle(
                                    color: HmiColors.textDim, fontSize: 11.5),
                              ),
                            ],
                          ),
                        )
                      : svc.hasDesign
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: Image.memory(svc.designImage!,
                              fit: BoxFit.contain),
                        )
                      : Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.upload_file,
                                  color: HmiColors.textDim, size: 34),
                              const SizedBox(height: 10),
                              Text(
                                t.t('drop_image'),
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                    color: HmiColors.textDim),
                              ),
                              const SizedBox(height: 14),
                              ElevatedButton.icon(
                                onPressed: () => _pick(svc),
                                icon: const Icon(Icons.folder_open),
                                label: const Text('Browse files…'),
                              ),
                            ],
                          ),
                        ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            SizedBox(
              width: 300,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(svc.designName ?? '—',
                              style: const TextStyle(
                                  color: HmiColors.text,
                                  fontWeight: FontWeight.w700)),
                          Text(
                              '${t.t('path_points')}: ${svc.programPoints.length}'
                              '${svc.isExtracting ? ' …' : ''}',
                              style: const TextStyle(
                                  color: HmiColors.textDim)),
                          if (svc.colorGroups.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Row(
                                children: [
                                  Text(
                                      '${t.t('colors_detected')}: ${svc.colorCount}',
                                      style: const TextStyle(
                                          color: HmiColors.textDim)),
                                  const SizedBox(width: 8),
                                  ...svc.colorGroups.map((g) => Padding(
                                        padding:
                                            const EdgeInsets.only(right: 4),
                                        child: Container(
                                          width: 12,
                                          height: 12,
                                          decoration: BoxDecoration(
                                            color: Color(g.colorValue),
                                            shape: BoxShape.circle,
                                            border: Border.all(
                                                color: HmiColors.border),
                                          ),
                                        ),
                                      )),
                                ],
                              ),
                            ),
                          const SizedBox(height: 10),
                          Text(t.t('internal_sample'),
                              style: const TextStyle(
                                  color: HmiColors.accent,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700)),
                          const SizedBox(height: 6),
                          ...SampleProject.catalog.map((p) {
                            final title = p.title;
                            return Material(
                              color: HmiColors.panel,
                              borderRadius: BorderRadius.circular(8),
                              child: InkWell(
                                onTap: svc.isExtracting
                                    ? null
                                    : () => svc.loadSampleProject(
                                        p.assetPath, title),
                                borderRadius: BorderRadius.circular(8),
                                child: Container(
                                  height: 88,
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: svc.designName == title
                                          ? HmiColors.accent
                                          : HmiColors.border,
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Image.asset(p.assetPath,
                                          width: 72, fit: BoxFit.contain),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Text(
                                          '${p.title}\n${p.blurb}',
                                          style: const TextStyle(
                                              color: HmiColors.textDim,
                                              fontSize: 11,
                                              height: 1.35),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          }),
                          const SizedBox(height: 10),
                          Text(
                              'Pitch ${svc.extractPitchMm.toStringAsFixed(0)} mm',
                              style: const TextStyle(
                                  color: HmiColors.accent, fontSize: 11)),
                          Slider(
                            value: svc.extractPitchMm,
                            min: 2,
                            max: 20,
                            divisions: 18,
                            onChanged: svc.isExtracting
                                ? null
                                : svc.setExtractPitch,
                          ),
                          ElevatedButton(
                            onPressed: (svc.hasDesign && !svc.isExtracting)
                                ? svc.extractPathFromDesign
                                : null,
                            child: Text(svc.isExtracting
                                ? '…'
                                : t.t('extract_path')),
                          ),
                          const SizedBox(height: 8),
                          ElevatedButton(
                            onPressed: svc.programPoints.length < 2 ||
                                    svc.isExtracting
                                ? null
                                : () async {
                                    await svc.buildAndLoadProgramFromDesign(
                                      name: svc.designName ?? 'design',
                                      points: svc.programPoints,
                                    );
                                  },
                            child: Text(t.t('optimize_load')),
                          ),
                          const SizedBox(height: 8),
                          OutlinedButton(
                            onPressed: () {
                              svc.setArea(HmiArea.machine);
                              svc.setMode(MachineMode.auto);
                            },
                            child: Text(t.t('machine')),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  const SizedBox(height: 150, child: PathPreview()),
                ],
              ),
            ),
            const SizedBox(width: 12),
            SizedBox(
              width: 280,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Text(t.t('gcode'),
                          style: const TextStyle(
                              color: HmiColors.accent,
                              fontWeight: FontWeight.w800)),
                      const Spacer(),
                      TextButton(
                        onPressed: svc.regenerateGCode,
                        child: const Text('↻',
                            style: TextStyle(color: HmiColors.accent)),
                      ),
                    ],
                  ),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0D141C),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: HmiColors.border),
                      ),
                      child: SingleChildScrollView(
                        child: SelectableText(
                          svc.gCode.isEmpty
                              ? '; Extract path to generate G-code'
                              : (svc.gCode.length > 8000
                                  ? '${svc.gCode.substring(0, 8000)}\n; … truncated for UI speed'
                                  : svc.gCode),
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
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class DiagnosisAreaBody extends StatelessWidget {
  const DiagnosisAreaBody({super.key});

  @override
  Widget build(BuildContext context) {
    final svc = context.watch<MachineService>();
    final s = svc.status;
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const Text('DIAGNOSIS',
            style: TextStyle(
                color: HmiColors.text,
                fontSize: 18,
                fontWeight: FontWeight.w700)),
        const SizedBox(height: 12),
        _row('Runtime link', svc.runtimeLinked ? 'C :9100' : 'Local fallback'),
        _row('Backend', s.backend),
        _row('Port', s.port),
        _row('Baud', '${s.baud}'),
        _row('Mode', s.modeLabel),
        _row('State', s.stateLabel),
        _row('Alarm', s.alarm.isEmpty ? '—' : s.alarm),
        _row('X / Y',
            '${s.x.toStringAsFixed(3)} / ${s.y.toStringAsFixed(3)} mm'),
        _row('Program %', s.progPct.toStringAsFixed(1)),
        const SizedBox(height: 16),
        const Text(
          'Alarms: Soft limit · Not connected · Path empty · EMERGENCY STOP · Serial lost',
          style: TextStyle(color: HmiColors.textMute, fontSize: 12),
        ),
      ],
    );
  }

  Widget _row(String k, String v) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          SizedBox(
              width: 140,
              child: Text(k,
                  style: const TextStyle(color: HmiColors.textDim))),
          Expanded(
              child: Text(v,
                  style: const TextStyle(
                      color: HmiColors.text, fontWeight: FontWeight.w600))),
        ],
      ),
    );
  }
}

class SetupAreaBody extends StatelessWidget {
  const SetupAreaBody({super.key});

  @override
  Widget build(BuildContext context) {
    final svc = context.watch<MachineService>();
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const Text('SETUP',
            style: TextStyle(
                color: HmiColors.text,
                fontSize: 18,
                fontWeight: FontWeight.w700)),
        const SizedBox(height: 16),
        const Text('Hardware backend',
            style: TextStyle(color: HmiColors.textDim)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: [
            ChoiceChip(
              label: const Text('SIM'),
              selected: svc.setupBackend == 'sim',
              onSelected: (_) => svc.setSetup(backend: 'sim'),
            ),
            ChoiceChip(
              label: const Text('SERIAL (GRBL)'),
              selected: svc.setupBackend == 'serial',
              onSelected: (_) => svc.setSetup(backend: 'serial'),
            ),
          ],
        ),
        const SizedBox(height: 16),
        TextFormField(
          initialValue: svc.setupPort,
          decoration: const InputDecoration(
            labelText: 'COM port (Windows)',
            hintText: 'COM3',
            border: OutlineInputBorder(),
          ),
          style: const TextStyle(color: HmiColors.text),
          onChanged: (v) => svc.setSetup(port: v),
        ),
        const SizedBox(height: 12),
        TextFormField(
          initialValue: '${svc.setupBaud}',
          decoration: const InputDecoration(
            labelText: 'Baud',
            border: OutlineInputBorder(),
          ),
          style: const TextStyle(color: HmiColors.text),
          keyboardType: TextInputType.number,
          onChanged: (v) =>
              svc.setSetup(baud: int.tryParse(v) ?? 115200),
        ),
        const SizedBox(height: 20),
        ElevatedButton(
          onPressed: svc.connectMachine,
          child: const Text('APPLY & CONNECT'),
        ),
        const SizedBox(height: 12),
        const Text(
          'Start C runtime first:\n'
          '  firmware\\bin\\machine_server.exe\n'
          'Then CONNECT with SIM or SERIAL.',
          style: TextStyle(color: HmiColors.textMute, fontSize: 12),
        ),
      ],
    );
  }
}
