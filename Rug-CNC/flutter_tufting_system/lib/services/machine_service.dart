import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../models/design.dart';
import '../models/machine_profile.dart';
import '../models/machine_status.dart';
import 'dxf_parser.dart';
import 'path_extractor.dart';
import 'runtime_link.dart';

/// Handles communications with the machine controller (Arduino/ESP via WiFi/LAN,
/// or C runtime on desktop) using line-based JSON protocol.
class MachineService extends ChangeNotifier {
  static const _localProfile = MachineProfile(
    id: 'local',
    name: 'Local runtime',
    host: '127.0.0.1',
    port: 9100,
  );

  final RuntimeLink _link = createRuntimeLink();
  Timer? _localTick;
  Timer? _reconnect;
  bool _disposed = false;

  MachineStatus _status = const MachineStatus();
  HmiArea _area = HmiArea.machine;
  String _message = 'Waiting for machine runtime...';
  bool _runtimeLinked = false;
  bool _useLocalSim = true;

  String _setupBackend = 'sim';
  String _setupPort = 'COM3';
  int _setupBaud = 115200;
  String _mdiLine = 'G1 X100 Y50 F1200';
  String? _loadedProgramName;
  List<TuftPoint> _programPoints = [];
  List<ColorGroup> _colorGroups = [];
  List<MachineProfile> _machines = [_localProfile];
  MachineProfile _activeMachine = _localProfile;
  bool _connectingMachine = false;
  Uint8List? _designImage;
  bool _isDxf = false;
  String? _designName;
  String _gCode = '';
  double _extractPitchMm = 10;
  bool _extracting = false;
  final List<PlcMacro> _plcMacros = List.from(PlcMacro.defaults);

  MachineStatus get status => _status;
  HmiArea get area => _area;
  String get message => _message;
  bool get runtimeLinked => _runtimeLinked;
  String get setupBackend => _setupBackend;
  String get setupPort => _setupPort;
  int get setupBaud => _setupBaud;
  String get mdiLine => _mdiLine;
  String? get loadedProgramName => _loadedProgramName;
  List<TuftPoint> get programPoints => _programPoints;
  List<ColorGroup> get colorGroups => List.unmodifiable(_colorGroups);
  int get colorCount => _colorGroups.length;

  int? get activeColorOrder {
    final idx = _status.pathIndex;
    if (idx < 0 || idx >= _programPoints.length) {
      return _programPoints.isNotEmpty ? _programPoints.last.colorOrder : null;
    }
    return _programPoints[idx].colorOrder;
  }

  Uint8List? get designImage => _designImage;
  String? get designName => _designName;
  bool get hasDesign => _designImage != null || _isDxf;
  bool get isDxfDesign => _isDxf;
  String get gCode => _gCode;
  double get extractPitchMm => _extractPitchMm;
  bool get isExtracting => _extracting;
  List<PlcMacro> get plcMacros => List.unmodifiable(_plcMacros);
  List<MachineProfile> get machines => List.unmodifiable(_machines);
  MachineProfile get activeMachine => _activeMachine;
  bool get isConnectingMachine => _connectingMachine;

  bool _started = false;

  Future<void> start() async {
    if (_started) return;
    _started = true;
    await _loadMachines();
    await _tryConnectRuntime();
    _reconnect = Timer.periodic(const Duration(seconds: 3), (_) {
      if (!_runtimeLinked) _tryConnectRuntime();
    });
    _startLocalSimIfNeeded();
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _reconnect?.cancel();
    _localTick?.cancel();
    _link.close();
    super.dispose();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  void setArea(HmiArea area) {
    _area = area;
    _notify();
  }

  void setSetup({String? backend, String? port, int? baud}) {
    if (backend != null) _setupBackend = backend;
    if (port != null) _setupPort = port;
    if (baud != null) _setupBaud = baud;
    _notify();
  }

  void setMdiLine(String line) {
    _mdiLine = line;
    _notify();
  }

  Future<void> _loadMachines() async {
    try {
      final raw = await _link.loadText('machines');
      if (raw == null) return;
      final decoded = jsonDecode(raw) as List<dynamic>;
      final loaded = decoded
          .map((e) => MachineProfile.fromJson(e as Map<String, dynamic>))
          .toList();
      if (loaded.isNotEmpty) {
        _machines = loaded;
        _activeMachine = loaded.first;
      }
    } catch (_) {}
  }

  Future<void> _saveMachines() async {
    try {
      await _link.saveText(
          'machines', jsonEncode(_machines.map((m) => m.toJson()).toList()));
    } catch (_) {}
  }

  Future<void> addMachine({
    required String name,
    required String host,
    int port = 9100,
  }) async {
    final m = MachineProfile(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      name: name.trim().isEmpty ? host : name.trim(),
      host: host.trim(),
      port: port,
    );
    _machines = [..._machines, m];
    await _saveMachines();
    _notify();
  }

  Future<void> removeMachine(String id) async {
    if (id == _localProfile.id) return;
    _machines = _machines.where((m) => m.id != id).toList();
    if (_machines.isEmpty) _machines = [_localProfile];
    if (_activeMachine.id == id) {
      await connectToMachine(_machines.first);
    }
    await _saveMachines();
    _notify();
  }

  Future<void> connectToMachine(MachineProfile m) async {
    _activeMachine = m;
    _connectingMachine = true;
    _runtimeLinked = false;
    _link.close();
    _message = 'Connecting to ${m.name} (${m.host}:${m.port})...';
    _notify();
    await _tryConnectRuntime();
  }

  Future<void> _tryConnectRuntime() async {
    if (kIsWeb) return;
    if (_link.isConnected) return;
    final ok = await _link.connect(
        _activeMachine.host, _activeMachine.port, _onLine, _onSocketGone);
    if (ok) {
      _runtimeLinked = true;
      _useLocalSim = false;
      _localTick?.cancel();
      _message = 'Linked to ${_activeMachine.name} — '
          '${_activeMachine.host}:${_activeMachine.port}';
      await sendCmd({'cmd': 'get_status'});
      _notify();
    } else {
      _runtimeLinked = false;
      _useLocalSim = true;
      _startLocalSimIfNeeded();
    }
    _connectingMachine = false;
    _notify();
  }

  void _onSocketGone() {
    _link.close();
    _runtimeLinked = false;
    _useLocalSim = true;
    _message = 'Runtime disconnected — local sim active';
    _startLocalSimIfNeeded();
    _notify();
  }

  void _onLine(String line) {
    if (line.trim().isEmpty) return;
    try {
      final j = jsonDecode(line) as Map<String, dynamic>;
      if (j['type'] == 'status') {
        _status = MachineStatus.fromJson(j);
        if (_status.alarm.isNotEmpty) {
          _message = _status.alarm;
        } else {
          _message =
              '${_status.modeLabel} | ${_status.stateLabel} | ${_status.backend.toUpperCase()}';
        }
        _notify();
      }
    } catch (_) {}
  }

  Future<void> sendCmd(Map<String, dynamic> cmd) async {
    if (_runtimeLinked && _link.isConnected) {
      await _link.send(jsonEncode(cmd));
      return;
    }
    _localHandle(cmd);
  }

  Future<void> connectMachine() async {
    await sendCmd({
      'cmd': 'connect',
      'backend': _setupBackend,
      'port': _setupBackend == 'sim' ? 'motor_commands.log' : _setupPort,
      'baud': _setupBaud,
    });
  }

  Future<void> disconnectMachine() => sendCmd({'cmd': 'disconnect'});

  Future<void> setMode(MachineMode mode) async {
    const map = {
      MachineMode.jog: 'JOG',
      MachineMode.auto: 'AUTO',
      MachineMode.mdi: 'MDI',
      MachineMode.ref: 'REF',
    };
    await sendCmd({'cmd': 'set_mode', 'mode': map[mode]});
  }

  Future<void> jog(String axis, int dir) =>
      sendCmd({'cmd': 'jog', 'axis': axis, 'dir': dir});

  Future<void> jogZ(int dir) async {
    if (_runtimeLinked) {
      await jog('Z', dir);
      return;
    }
    final s = _status;
    if (s.mode != MachineMode.jog) return;
    var z = s.z + s.jogStep * (dir >= 0 ? 1 : -1);
    z = z.clamp(0.0, 25.0);
    _status = _copy(s, z: z, needle: z < 2.5);
    _notify();
  }

  void setExtractPitch(double mm) {
    _extractPitchMm = mm.clamp(2, 20);
    _notify();
  }

  void regenerateGCode() {
    _gCode = generateAdvancedGCode(
      points: _programPoints,
      colorGroups: _colorGroups,
      programName: _designName ?? 'Generated_Path',
    );
    _notify();
  }

  void updatePlcMacro(int index, PlcMacro macro) {
    if (index < 0 || index >= _plcMacros.length) return;
    _plcMacros[index] = macro;
    _notify();
  }

  void addPlcMacro(PlcMacro macro) {
    _plcMacros.add(macro);
    _notify();
  }

  Future<void> runPlcMacro(PlcMacro macro) async {
    await setMode(MachineMode.mdi);
    setMdiLine(macro.code);
    await runMdi();
    _message = 'PLC macro: ${macro.name} → ${macro.code}';
    _notify();
  }

  Future<void> home() => sendCmd({'cmd': 'home'});
  Future<void> cycleStart() => sendCmd({'cmd': 'cycle_start'});
  Future<void> feedHold() => sendCmd({'cmd': 'feed_hold'});
  Future<void> cycleStop() => sendCmd({'cmd': 'cycle_stop'});
  Future<void> reset() => sendCmd({'cmd': 'reset'});
  Future<void> estop() => sendCmd({'cmd': 'estop'});

  Future<void> setFeedOverride(int pct) =>
      sendCmd({'cmd': 'set_feed_override', 'percent': pct});

  Future<void> setJogStep(double step) =>
      sendCmd({'cmd': 'set_jog_step', 'step': step.toStringAsFixed(3)});

  Future<void> runMdi() => sendCmd({'cmd': 'mdi', 'line': _mdiLine});

  Future<void> loadPathFile(String path) async {
    _loadedProgramName = _link.basename(path);
    await sendCmd({'cmd': 'load_path', 'path': path});
    final lines = await _link.readCsvLines(path);
    if (lines != null) {
      _programPoints = [];
      for (final line in lines.skip(1)) {
        final p = line.split(',');
        if (p.length >= 2) {
          _programPoints.add(TuftPoint(
              x: double.parse(p[0]), y: double.parse(p[1])));
        }
      }
    }
    _notify();
  }

  Future<String> buildAndLoadProgramFromDesign({
    required String name,
    required List<TuftPoint> points,
  }) async {
    if (points.length < 2) {
      _message = 'Need at least 2 tuft points';
      _notify();
      throw Exception('Empty design');
    }

    final ordered = _optimizeNearest(points);
    _programPoints = ordered;
    _gCode = generateAdvancedGCode(
      points: ordered,
      colorGroups: _colorGroups,
      programName: name,
    );

    final rows = <String>['x_mm,y_mm'];
    for (final p in ordered) {
      rows.add('${p.x.toStringAsFixed(3)},${p.y.toStringAsFixed(3)}');
    }
    final filePath = await _link.writeProgramCsv(name, rows);

    await setMode(MachineMode.auto);
    await loadPathFile(filePath);
    _loadedProgramName = _link.basename(filePath);
    _message = 'Program loaded: $_loadedProgramName (${ordered.length} pts)';
    _notify();
    return filePath;
  }

  Future<void> loadDesignImage(Uint8List bytes, String name) async {
    _designImage = bytes;
    _isDxf = false;
    _designName = name;
    _programPoints = [];
    _gCode = '';
    _message = 'Design loaded — extracting path...';
    _notify();
    await extractPathFromDesign();
  }

  Future<void> loadDesignFromDxf(Uint8List bytes, String name) async {
    _designImage = null;
    _isDxf = true;
    _designName = name;
    _programPoints = [];
    _colorGroups = [];
    _gCode = '';
    _message = 'DXF loaded — building exact path...';
    _notify();
    if (_extracting) return;
    _extracting = true;
    _notify();
    try {
      final args = <String, dynamic>{'bytes': bytes};
      final result = await compute(_dxfExtractIsolate, args).timeout(
        const Duration(seconds: 12),
        onTimeout: () => const ExtractResult(points: [], colors: []),
      );
      _programPoints = result.points;
      _colorGroups = result.colors;
      _gCode = generateAdvancedGCode(
        points: result.points,
        colorGroups: result.colors,
        programName: name,
      );
      _message = result.points.isEmpty
          ? 'No supported entities found (LINE/ARC/CIRCLE/LWPOLYLINE/POLYLINE)'
          : 'DXF: exact path — ${result.points.length} points across '
              '${result.colors.length} color(s), grouped by layer';
    } catch (e) {
      _message = 'DXF read failed: $e';
      _programPoints = [];
      _colorGroups = [];
      _gCode = '';
    }
    _extracting = false;
    _notify();
  }

  Future<void> loadSampleProject(String assetPath, String name) async {
    final data = await rootBundle.load(assetPath);
    final bytes = data.buffer.asUint8List();
    await loadDesignImage(bytes, name);
  }

  Future<void> extractPathFromDesign() async {
    if (_designImage == null || _extracting) return;
    _extracting = true;
    _message = 'Extracting path...';
    _notify();
    try {
      final args = <String, dynamic>{
        'bytes': _designImage!,
        'pitch': _extractPitchMm,
      };
      final result = await compute(_extractIsolate, args).timeout(
        const Duration(seconds: 12),
        onTimeout: () => const ExtractResult(points: [], colors: []),
      );
      _programPoints = result.points;
      _colorGroups = result.colors;
      _gCode = generateAdvancedGCode(
        points: result.points,
        colorGroups: result.colors,
        programName: _designName ?? 'Image_Design',
      );
      _message = result.points.isEmpty
          ? 'No path found — try lower pitch or another image'
          : 'Extracted ${result.points.length} points across '
              '${result.colors.length} color(s) '
              '(pitch ${_extractPitchMm.toStringAsFixed(0)} mm)';
    } catch (e) {
      _message = 'Extraction failed: $e';
      _programPoints = [];
      _colorGroups = [];
      _gCode = '';
    }
    _extracting = false;
    _notify();
  }

  void clearDesign() {
    _designImage = null;
    _isDxf = false;
    _designName = null;
    _gCode = '';
    _colorGroups = [];
    _notify();
  }

  List<TuftPoint> _optimizeNearest(List<TuftPoint> input) {
    if (input.isEmpty) return input;
    final left = List<TuftPoint>.from(input);
    final out = <TuftPoint>[left.removeAt(0)];
    while (left.isNotEmpty) {
      var bestI = 0;
      var bestD = double.infinity;
      final last = out.last;
      for (var i = 0; i < left.length; i++) {
        final dx = left[i].x - last.x;
        final dy = left[i].y - last.y;
        final d = dx * dx + dy * dy;
        if (d < bestD) {
          bestD = d;
          bestI = i;
        }
      }
      out.add(left.removeAt(bestI));
    }
    return out;
  }

  // Local Simulation logic...
  List<TuftPoint> _localPath = [];
  int _localIndex = 0;
  double _segT = 0;
  double _segDur = 0.01;
  double _fromX = 0, _fromY = 0, _toX = 0, _toY = 0;
  bool _haveSeg = false;

  void _startLocalSimIfNeeded() {
    if (!_useLocalSim) return;
    _localTick ??= Timer.periodic(const Duration(milliseconds: 50), (_) {
      if (!_useLocalSim) return;
      _localTickOnce(0.05);
    });
    if (!_status.connected) {
      _status = const MachineStatus(
        connected: true,
        backend: 'sim',
        port: 'local-sim',
        mode: MachineMode.jog,
        state: MachineState.idle,
      );
      _message = kIsWeb
          ? 'Web local sim (use Windows + machine_server for C runtime)'
          : 'Local sim (start machine_server.exe for C runtime)';
      _notify();
    }
  }

  void _localHandle(Map<String, dynamic> cmd) {
    final c = cmd['cmd'] as String? ?? '';
    var s = _status;
    void set(MachineStatus n) {
      _status = n;
      _notify();
    }

    switch (c) {
      case 'connect':
        set(MachineStatus(
          mode: s.mode,
          state: MachineState.idle,
          x: s.x,
          y: s.y,
          connected: true,
          feedOverride: s.feedOverride,
          backend: (cmd['backend'] as String?) ?? 'sim',
          port: (cmd['port'] as String?) ?? 'local',
          baud: (cmd['baud'] as num?)?.toInt() ?? 115200,
          jogStep: s.jogStep,
          pathLoaded: s.pathLoaded,
          pathCount: s.pathCount,
          referenced: s.referenced,
        ));
        _message = 'Connected (${_status.backend})';
        break;
      case 'disconnect':
        set(MachineStatus(
          mode: s.mode,
          connected: false,
          feedOverride: s.feedOverride,
          jogStep: s.jogStep,
        ));
        break;
      case 'set_mode':
        final m = MachineStatus.modeFrom(cmd['mode'] as String?);
        set(_copy(s, mode: m, alarm: ''));
        break;
      case 'jog':
        if (!s.connected || s.mode != MachineMode.jog) {
          set(_copy(s, state: MachineState.alarm, alarm: 'JOG mode required'));
          return;
        }
        final axis = (cmd['axis'] as String?) ?? 'X';
        final dir = (cmd['dir'] as num?)?.toInt() ?? 1;
        var x = s.x, y = s.y, z = s.z;
        final step = s.jogStep * (dir >= 0 ? 1 : -1);
        final a = axis.toUpperCase();
        if (a == 'X') {
          x += step;
        } else if (a == 'Y') {
          y += step;
        } else if (a == 'Z') {
          z = (z + step).clamp(0.0, 25.0);
          set(_copy(s, z: z, needle: z < 2.5, alarm: ''));
          return;
        }
        if (x < 0 || y < 0 || x > 1000 || y > 1000) {
          set(_copy(s, state: MachineState.alarm, alarm: 'Soft limit'));
          return;
        }
        set(_copy(s, x: x, y: y, alarm: ''));
        break;
      case 'home':
        set(_copy(s,
            x: 0,
            y: 0,
            z: 5,
            referenced: true,
            state: MachineState.idle,
            alarm: '',
            needle: false));
        break;
      case 'load_path':
        final path = cmd['path'] as String?;
        if (path == null) return;
        () async {
          final lines = await _link.readCsvLines(path);
          if (lines == null) {
            if (_programPoints.length >= 2) {
              _localPath = List<TuftPoint>.from(_programPoints);
              set(_copy(s,
                  pathLoaded: true,
                  pathCount: _localPath.length,
                  pathIndex: 0,
                  progPct: 0,
                  alarm: ''));
              _loadedProgramName = _link.basename(path);
            } else {
              set(_copy(s, alarm: 'Path empty', pathLoaded: false));
            }
            return;
          }
          _localPath = [];
          for (final line in lines.skip(1)) {
            final p = line.split(',');
            if (p.length >= 2) {
              _localPath.add(TuftPoint(
                  x: double.parse(p[0]), y: double.parse(p[1])));
            }
          }
          set(_copy(s,
              pathLoaded: _localPath.length >= 2,
              pathCount: _localPath.length,
              pathIndex: 0,
              progPct: 0,
              alarm: _localPath.length >= 2 ? '' : 'Path empty'));
          _loadedProgramName = _link.basename(path);
          _programPoints = List<TuftPoint>.from(_localPath);
        }();
        break;
      case 'cycle_start':
        if (s.mode == MachineMode.mdi) {
          _localMdi(s, _mdiLine);
          return;
        }
        if (s.mode != MachineMode.auto ||
            (!s.pathLoaded && _programPoints.length < 2) ||
            (_localPath.length < 2 && _programPoints.length < 2)) {
          if (_programPoints.length >= 2) {
            _localPath = List<TuftPoint>.from(_programPoints);
          } else {
            set(_copy(s, state: MachineState.alarm, alarm: 'Path empty'));
            return;
          }
        }
        if (_localPath.length < 2 && _programPoints.length >= 2) {
          _localPath = List<TuftPoint>.from(_programPoints);
        }
        if (s.state == MachineState.hold) {
          set(_copy(s, state: MachineState.running, alarm: ''));
          return;
        }
        _localIndex = 0;
        _beginLocalSeg();
        set(_copy(s,
            state: MachineState.running,
            x: _localPath[0].x,
            y: _localPath[0].y,
            pathLoaded: true,
            pathCount: _localPath.length,
            alarm: '',
            needle: true));
        break;
      case 'feed_hold':
        if (s.state == MachineState.running) {
          set(_copy(s, state: MachineState.hold, needle: false));
        }
        break;
      case 'cycle_stop':
        _haveSeg = false;
        set(_copy(s, state: MachineState.idle, needle: false));
        break;
      case 'reset':
        _haveSeg = false;
        set(_copy(s,
            state: MachineState.idle,
            progPct: 0,
            pathIndex: 0,
            alarm: '',
            needle: false));
        break;
      case 'estop':
        _haveSeg = false;
        set(_copy(s,
            state: MachineState.alarm,
            alarm: 'EMERGENCY STOP',
            needle: false));
        break;
      case 'set_feed_override':
        set(_copy(s, feedOverride: (cmd['percent'] as num?)?.toInt() ?? 100));
        break;
      case 'set_jog_step':
        set(_copy(s, jogStep: double.tryParse('${cmd['step']}') ?? 1.0));
        break;
      case 'mdi':
        _localMdi(s, (cmd['line'] as String?) ?? '');
        break;
    }
  }

  void _localMdi(MachineStatus s, String line) {
    if (s.mode != MachineMode.mdi) {
      _status = _copy(s, state: MachineState.alarm, alarm: 'MDI mode required');
      _notify();
      return;
    }
    var x = s.x, y = s.y;
    final rx = RegExp(r'[Xx]\s*([-\d.]+)');
    final ry = RegExp(r'[Yy]\s*([-\d.]+)');
    final mx = rx.firstMatch(line);
    final my = ry.firstMatch(line);
    if (mx != null) x = double.parse(mx.group(1)!);
    if (my != null) y = double.parse(my.group(1)!);
    if (x < 0 || y < 0 || x > 1000 || y > 1000) {
      _status = _copy(s, state: MachineState.alarm, alarm: 'Soft limit');
    } else {
      _status = _copy(s, x: x, y: y, alarm: '');
    }
    _notify();
  }

  void _beginLocalSeg() {
    if (_localIndex >= _localPath.length - 1) {
      _haveSeg = false;
      _status = _copy(_status,
          state: MachineState.idle, progPct: 100, needle: false);
      _notify();
      return;
    }
    _fromX = _localPath[_localIndex].x;
    _fromY = _localPath[_localIndex].y;
    _toX = _localPath[_localIndex + 1].x;
    _toY = _localPath[_localIndex + 1].y;
    final dx = _toX - _fromX, dy = _toY - _fromY;
    final dist = math.sqrt(dx * dx + dy * dy);
    final vmax = 250.0 * (_status.feedOverride / 100.0);
    _segDur = dist < 1e-6 ? 0.01 : dist / math.max(vmax, 1);
    _segT = 0;
    _haveSeg = true;
  }

  void _localTickOnce(double dt) {
    if (_status.state != MachineState.running || !_haveSeg) return;

    _segT += dt;

    var u = _segDur <= 0 ? 1.0 : _segT / _segDur;
    if (u > 1) u = 1;

    final x = _fromX + (_toX - _fromX) * u;
    final y = _fromY + (_toY - _fromY) * u;

    final pct = _localPath.length > 1
        ? 100.0 * (_localIndex + u) / (_localPath.length - 1)
        : 0.0;

    final isLastSegment =
        _localIndex >= _localPath.length - 2 && u >= 0.999;

    _status = _copy(
      _status,
      x: x,
      y: y,
      progPct: pct.clamp(0, 100),
      pathIndex: _localIndex,
      needle: !isLastSegment,
    );

    _notify();

    if (u >= 1) {
      _localIndex++;

      if (_localIndex >= _localPath.length - 1) {
        _haveSeg = false;

        _status = _copy(
          _status,
          x: _localPath.last.x,
          y: _localPath.last.y,
          progPct: 100,
          pathIndex: _localPath.length - 1,
          state: MachineState.idle,
          needle: false,
        );

        _notify();
        return;
      }

      _beginLocalSeg();
    }
  }

  MachineStatus _copy(
    MachineStatus s, {
    MachineMode? mode,
    MachineState? state,
    double? x,
    double? y,
    double? z,
    int? feedOverride,
    bool? connected,
    bool? referenced,
    bool? needle,
    String? alarm,
    double? progPct,
    bool? pathLoaded,
    int? pathCount,
    int? pathIndex,
    String? backend,
    String? port,
    int? baud,
    double? jogStep,
  }) {
    return MachineStatus(
      mode: mode ?? s.mode,
      state: state ?? s.state,
      x: x ?? s.x,
      y: y ?? s.y,
      z: z ?? s.z,
      wcsX: s.wcsX,
      wcsY: s.wcsY,
      wcsZ: s.wcsZ,
      feedOverride: feedOverride ?? s.feedOverride,
      connected: connected ?? s.connected,
      referenced: referenced ?? s.referenced,
      needle: needle ?? s.needle,
      alarm: alarm ?? s.alarm,
      progPct: progPct ?? s.progPct,
      pathLoaded: pathLoaded ?? s.pathLoaded,
      pathCount: pathCount ?? s.pathCount,
      pathIndex: pathIndex ?? s.pathIndex,
      backend: backend ?? s.backend,
      port: port ?? s.port,
      baud: baud ?? s.baud,
      jogStep: jogStep ?? s.jogStep,
    );
  }

  /// Advanced G-Code Engine with Modal commands, Arc Fitting (G2/G3),
  /// Retract logic, and color separation.
  static String generateAdvancedGCode({
    required List<TuftPoint> points,
    List<ColorGroup> colorGroups = const [],
    String programName = 'ROVEX_DESIGN',
    double safeZ = 5.0,
    double workZ = 0.0,
    double cutFeed = 3000.0,
    double travelFeed = 6000.0,
    double jumpThreshold = 12.0,
  }) {
    if (points.isEmpty) return '; ROVEX: Empty point set provided';

    final sb = StringBuffer();
    sb.writeln('; ============================================');
    sb.writeln('; ROVEX Advanced G-Code Generator');
    sb.writeln('; Program Name : $programName');
    sb.writeln('; Total Points : ${points.length}');
    sb.writeln('; Color Groups : ${colorGroups.length}');
    sb.writeln('; ============================================');
    sb.writeln('G21 ; Set units to millimeters');
    sb.writeln('G90 ; Set positioning to absolute mode');
    sb.writeln('G17 ; Select XY plane');
    sb.writeln('G0 Z${safeZ.toStringAsFixed(2)} ; Retract head to safe height');

    double? activeFeed;
    String activeMotionMode = '';
    TuftPoint? currentPt;
    int currentColorOrder = -1;

    void updateMotionMode(String mode) {
      activeMotionMode = mode;
    }

    void applyFeed(double targetFeed) {
      if (activeFeed != targetFeed) {
        sb.write(' F${targetFeed.toInt()}');
        activeFeed = targetFeed;
      }
    }

    void moveToPoint(TuftPoint target, {required bool isCutting}) {
      if (isCutting) {
        if (activeMotionMode != 'G1') {
          sb.write('G1');
          updateMotionMode('G1');
        }
        sb.write(' X${target.x.toStringAsFixed(2)} Y${target.y.toStringAsFixed(2)}');
        applyFeed(cutFeed);
        sb.writeln();
      } else {
        if (activeMotionMode != 'G0') {
          sb.write('G0');
          updateMotionMode('G0');
        }
        sb.write(' X${target.x.toStringAsFixed(2)} Y${target.y.toStringAsFixed(2)}');
        applyFeed(travelFeed);
        sb.writeln();
      }
      currentPt = target;
    }

    int i = 0;
    while (i < points.length) {
      final pt = points[i];

      // Detect Color Group Boundaries
      if (pt.colorOrder != currentColorOrder) {
        currentColorOrder = pt.colorOrder ?? 0;
        sb.writeln();
        sb.writeln('; --- Color Group #$currentColorOrder ---');
        sb.writeln('M9 ; Disengage needle/tool');
        sb.writeln('G0 Z${safeZ.toStringAsFixed(2)}');

        moveToPoint(pt, isCutting: false);
        sb.writeln('M8 ; Engage needle/tool');
        sb.writeln('G0 Z${workZ.toStringAsFixed(2)}');
        i++;
        continue;
      }

      // Detect jumps or gaps within the same color group
      if (currentPt != null) {
        final dist = math.sqrt(
          math.pow(pt.x - currentPt!.x, 2) + math.pow(pt.y - currentPt!.y, 2),
        );

        if (dist > jumpThreshold) {
          sb.writeln('; Travel Jump Detected (${dist.toStringAsFixed(1)}mm)');
          sb.writeln('M9 ; Disengage needle');
          sb.writeln('G0 Z${safeZ.toStringAsFixed(2)}');
          moveToPoint(pt, isCutting: false);
          sb.writeln('M8 ; Engage needle');
          sb.writeln('G0 Z${workZ.toStringAsFixed(2)}');
          i++;
          continue;
        }
      }

      // Arc Fitting Check (G2 / G3 optimization across 3 points)
      // Arc Fitting Check (G2 / G3 optimization across 3 points)
      if (i + 2 < points.length) {
        final p1 = pt;
        final p2 = points[i + 1];
        final p3 = points[i + 2];

        // التأكد من أن الألوان متطابقة لمنع القفز بين مجموعات الألوان
        if (p2.colorOrder == currentColorOrder && p3.colorOrder == currentColorOrder) {
          final arcData = _fitArc(p1, p2, p3);
          
          if (arcData != null && arcData.radius > 1.0 && arcData.radius < 500.0) {
            final String gCmd = arcData.isClockwise ? 'G2' : 'G3';
            
            if (activeMotionMode != gCmd) {
              sb.write(gCmd);
              updateMotionMode(gCmd);
            }
            
            sb.write(' X${p3.x.toStringAsFixed(2)} Y${p3.y.toStringAsFixed(2)} I${arcData.i.toStringAsFixed(2)} J${arcData.j.toStringAsFixed(2)}');
            applyFeed(cutFeed);
            sb.writeln();

            currentPt = p3;
            i += 3; // تخطي الـ 3 نقاط التي تم دمجها في القوس
            continue;
          }
        }
      }

      // Standard linear movement
      moveToPoint(pt, isCutting: true);
      i++;
    }

    // Program Footer
    sb.writeln();
    sb.writeln('; --- Program End Cleanup ---');
    sb.writeln('M9 ; Disengage tool');
    sb.writeln('G0 Z${safeZ.toStringAsFixed(2)} ; Retract to safe Z');
    sb.writeln('G0 X0.00 Y0.00 ; Return to origin');
    sb.writeln('M30 ; End of program');

    return sb.toString();
  }

  /// Calculates arc parameters (I, J offsets and direction) for 3 collinear or circular points.
  static ArcFittingResult? _fitArc(TuftPoint p1, TuftPoint p2, TuftPoint p3) {
    final d = 2 * (p1.x * (p2.y - p3.y) + p2.x * (p3.y - p1.y) + p3.x * (p1.y - p2.y));
    if (d.abs() < 1e-4) return null; // Points are linear, skip arc fitting

    final ux = ((p1.x * p1.x + p1.y * p1.y) * (p2.y - p3.y) +
            (p2.x * p2.x + p2.y * p2.y) * (p3.y - p1.y) +
            (p3.x * p3.x + p3.y * p3.y) * (p1.y - p2.y)) /
        d;

    final uy = ((p1.x * p1.x + p1.y * p1.y) * (p3.x - p2.x) +
            (p2.x * p2.x + p2.y * p2.y) * (p1.x - p3.x) +
            (p3.x * p3.x + p3.y * p3.y) * (p2.x - p1.x)) /
        d;

    final radius = math.sqrt(math.pow(p1.x - ux, 2) + math.pow(p1.y - uy, 2));
    final i = ux - p1.x;
    final j = uy - p1.y;

    // Cross product to determine arc direction (Clockwise vs Counter-Clockwise)
    final crossProduct = (p2.x - p1.x) * (p3.y - p1.y) - (p2.y - p1.y) * (p3.x - p1.x);
    final isClockwise = crossProduct < 0;

    return ArcFittingResult(
      i: i,
      j: j,
      radius: radius,
      isClockwise: isClockwise,
    );
  }
}

class ArcFittingResult {
  final double i;
  final double j;
  final double radius;
  final bool isClockwise;

  const ArcFittingResult({
    required this.i,
    required this.j,
    required this.radius,
    required this.isClockwise,
  });
}

class PlcMacro {
  final String name;
  final String code;
  final String note;

  const PlcMacro({
    required this.name,
    required this.code,
    this.note = '',
  });

  PlcMacro copyWith({String? name, String? code, String? note}) => PlcMacro(
        name: name ?? this.name,
        code: code ?? this.code,
        note: note ?? this.note,
      );

  static const defaults = [
    PlcMacro(name: 'Needle ON', code: 'M8', note: 'Engage needle / stitch'),
    PlcMacro(name: 'Needle OFF', code: 'M9', note: 'Retract needle'),
    PlcMacro(name: 'Coolant aux', code: 'M7', note: 'Optional aux output'),
    PlcMacro(name: 'Spindle stop', code: 'M5', note: 'Safe stop aux'),
    PlcMacro(name: 'Safe Z', code: 'G0 Z5', note: 'Raise embroidery head'),
    PlcMacro(
        name: 'Stitch depth',
        code: 'G1 Z0 F800',
        note: 'Needle down for embroidery'),
  ];
}

ExtractResult _extractIsolate(Map<String, dynamic> args) {
  return PathExtractor.extractMultiColor(
    args['bytes'] as Uint8List,
    pitchMm: (args['pitch'] as num).toDouble(),
  );
}

ExtractResult _dxfExtractIsolate(Map<String, dynamic> args) {
  return DxfExtractor.extractFromBytes(args['bytes'] as Uint8List);
}