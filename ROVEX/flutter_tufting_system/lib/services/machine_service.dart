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

/// Handles communication with the machine controller.
///
/// Supports:
/// - Arduino / ESP through WiFi/LAN
/// - Local C runtime on desktop
/// - Local simulation fallback
///
/// Communication uses a line-based JSON protocol.
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
  bool _started = false;

  MachineStatus _status = const MachineStatus();
  HmiArea _area = HmiArea.machine;

  String _message = 'Waiting for machine runtime...';

  bool _runtimeLinked = false;
  bool _useLocalSim = true;
  bool _connectingMachine = false;

  String _setupBackend = 'sim';
  String _setupPort = 'COM3';
  int _setupBaud = 115200;

  String _mdiLine = 'G1 X100 Y50 F1200';

  String? _loadedProgramName;
  String? _designName;

  Uint8List? _designImage;

  bool _isDxf = false;
  bool _extracting = false;

  String _gCode = '';

  double _extractPitchMm = 10;

  List<TuftPoint> _programPoints = [];
  List<ColorGroup> _colorGroups = [];
  List<MachineProfile> _machines = [_localProfile];

  MachineProfile _activeMachine = _localProfile;

  final List<PlcMacro> _plcMacros = List.from(PlcMacro.defaults);

  // ---------------------------------------------------------------------------
  // Getters
  // ---------------------------------------------------------------------------

  MachineStatus get status => _status;

  HmiArea get area => _area;

  String get message => _message;

  bool get runtimeLinked => _runtimeLinked;

  bool get isConnectingMachine => _connectingMachine;

  String get setupBackend => _setupBackend;

  String get setupPort => _setupPort;

  int get setupBaud => _setupBaud;

  String get mdiLine => _mdiLine;

  String? get loadedProgramName => _loadedProgramName;

  List<TuftPoint> get programPoints => _programPoints;

  List<ColorGroup> get colorGroups => List.unmodifiable(_colorGroups);

  int get colorCount => _colorGroups.length;

  int? get activeColorOrder {
    final index = _status.pathIndex;

    if (index < 0 || index >= _programPoints.length) {
      return _programPoints.isNotEmpty
          ? _programPoints.last.colorOrder
          : null;
    }

    return _programPoints[index].colorOrder;
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

  // ---------------------------------------------------------------------------
  // Lifecycle
  // ---------------------------------------------------------------------------

  Future<void> start() async {
    if (_started) return;

    _started = true;

    await _loadMachines();
    await _tryConnectRuntime();

    _reconnect = Timer.periodic(
      const Duration(seconds: 3),
      (_) {
        if (!_runtimeLinked) {
          _tryConnectRuntime();
        }
      },
    );

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
    if (!_disposed) {
      notifyListeners();
    }
  }

  // ---------------------------------------------------------------------------
  // UI / Setup
  // ---------------------------------------------------------------------------

  void setArea(HmiArea area) {
    _area = area;
    _notify();
  }

  void setSetup({
    String? backend,
    String? port,
    int? baud,
  }) {
    if (backend != null) {
      _setupBackend = backend;
    }

    if (port != null) {
      _setupPort = port;
    }

    if (baud != null) {
      _setupBaud = baud;
    }

    _notify();
  }

  void setMdiLine(String line) {
    _mdiLine = line;
    _notify();
  }

  // ---------------------------------------------------------------------------
  // Machine Profiles
  // ---------------------------------------------------------------------------

  Future<void> _loadMachines() async {
    try {
      final raw = await _link.loadText('machines');

      if (raw == null) return;

      final decoded = jsonDecode(raw) as List<dynamic>;

      final loaded = decoded
          .map(
            (item) => MachineProfile.fromJson(
              item as Map<String, dynamic>,
            ),
          )
          .toList();

      if (loaded.isNotEmpty) {
        _machines = loaded;
        _activeMachine = loaded.first;
      }
    } catch (_) {
      // Ignore invalid or unavailable machine configuration.
    }
  }

  Future<void> _saveMachines() async {
    try {
      await _link.saveText(
        'machines',
        jsonEncode(
          _machines.map((machine) => machine.toJson()).toList(),
        ),
      );
    } catch (_) {
      // Ignore storage errors.
    }
  }

  Future<void> addMachine({
    required String name,
    required String host,
    int port = 9100,
  }) async {
    final machine = MachineProfile(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      name: name.trim().isEmpty ? host : name.trim(),
      host: host.trim(),
      port: port,
    );

    _machines = [..._machines, machine];

    await _saveMachines();
    _notify();
  }

  Future<void> removeMachine(String id) async {
    if (id == _localProfile.id) return;

    _machines = _machines.where((machine) => machine.id != id).toList();

    if (_machines.isEmpty) {
      _machines = [_localProfile];
    }

    if (_activeMachine.id == id) {
      await connectToMachine(_machines.first);
    }

    await _saveMachines();
    _notify();
  }

  Future<void> connectToMachine(MachineProfile machine) async {
    _activeMachine = machine;
    _connectingMachine = true;
    _runtimeLinked = false;

    _link.close();

    _message =
        'Connecting to ${machine.name} '
        '(${machine.host}:${machine.port})...';

    _notify();

    await _tryConnectRuntime();
  }

  // ---------------------------------------------------------------------------
  // Runtime Connection
  // ---------------------------------------------------------------------------

  Future<void> _tryConnectRuntime() async {
    if (kIsWeb) return;
    if (_link.isConnected) return;

    final connected = await _link.connect(
      _activeMachine.host,
      _activeMachine.port,
      _onLine,
      _onSocketGone,
    );

    if (connected) {
      _runtimeLinked = true;
      _useLocalSim = false;

      _localTick?.cancel();

      _message =
          'Linked to ${_activeMachine.name} — '
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
      final json = jsonDecode(line) as Map<String, dynamic>;

      if (json['type'] != 'status') return;

      _status = MachineStatus.fromJson(json);

      if (_status.alarm.isNotEmpty) {
        _message = _status.alarm;
      } else {
        _message =
            '${_status.modeLabel} | '
            '${_status.stateLabel} | '
            '${_status.backend.toUpperCase()}';
      }

      _notify();
    } catch (_) {
      // Ignore malformed runtime messages.
    }
  }

  Future<void> sendCmd(Map<String, dynamic> command) async {
    if (_runtimeLinked && _link.isConnected) {
      await _link.send(jsonEncode(command));
      return;
    }

    _localHandle(command);
  }

  // ---------------------------------------------------------------------------
  // Machine Commands
  // ---------------------------------------------------------------------------

  Future<void> connectMachine() async {
    await sendCmd({
      'cmd': 'connect',
      'backend': _setupBackend,
      'port': _setupBackend == 'sim'
          ? 'motor_commands.log'
          : _setupPort,
      'baud': _setupBaud,
    });
  }

  Future<void> disconnectMachine() {
    return sendCmd({'cmd': 'disconnect'});
  }

  Future<void> setMode(MachineMode mode) async {
    const modeMap = {
      MachineMode.jog: 'JOG',
      MachineMode.auto: 'AUTO',
      MachineMode.mdi: 'MDI',
      MachineMode.ref: 'REF',
    };

    await sendCmd({
      'cmd': 'set_mode',
      'mode': modeMap[mode],
    });
  }

  Future<void> jog(String axis, int direction) {
    return sendCmd({
      'cmd': 'jog',
      'axis': axis,
      'dir': direction,
    });
  }

  Future<void> jogZ(int direction) async {
    if (_runtimeLinked) {
      await jog('Z', direction);
      return;
    }

    final status = _status;

    if (status.mode != MachineMode.jog) return;

    var z = status.z +
        status.jogStep *
            (direction >= 0 ? 1 : -1);

    z = z.clamp(0.0, 25.0);

    _status = _copy(
      status,
      z: z,
      needle: z < 2.5,
    );

    _notify();
  }

  Future<void> home() {
    return sendCmd({'cmd': 'home'});
  }

  Future<void> cycleStart() {
    return sendCmd({'cmd': 'cycle_start'});
  }

  Future<void> feedHold() {
    return sendCmd({'cmd': 'feed_hold'});
  }

  Future<void> cycleStop() {
    return sendCmd({'cmd': 'cycle_stop'});
  }

  Future<void> reset() {
    return sendCmd({'cmd': 'reset'});
  }

  Future<void> estop() {
    return sendCmd({'cmd': 'estop'});
  }

  Future<void> setFeedOverride(int percent) {
    return sendCmd({
      'cmd': 'set_feed_override',
      'percent': percent,
    });
  }

  Future<void> setJogStep(double step) {
    return sendCmd({
      'cmd': 'set_jog_step',
      'step': step.toStringAsFixed(3),
    });
  }

  Future<void> runMdi() {
    return sendCmd({
      'cmd': 'mdi',
      'line': _mdiLine,
    });
  }

  // ---------------------------------------------------------------------------
  // Path / G-Code
  // ---------------------------------------------------------------------------

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

  Future<void> loadPathFile(String path) async {
    _loadedProgramName = _link.basename(path);

    await sendCmd({
      'cmd': 'load_path',
      'path': path,
    });

    final lines = await _link.readCsvLines(path);

    if (lines != null) {
      _programPoints = [];

      for (final line in lines.skip(1)) {
        final parts = line.split(',');

        if (parts.length < 2) continue;

        _programPoints.add(
          TuftPoint(
            x: double.parse(parts[0]),
            y: double.parse(parts[1]),
          ),
        );
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

    for (final point in ordered) {
      rows.add(
        '${point.x.toStringAsFixed(3)},'
        '${point.y.toStringAsFixed(3)}',
      );
    }

    final filePath = await _link.writeProgramCsv(
      name,
      rows,
    );

    await setMode(MachineMode.auto);
    await loadPathFile(filePath);

    _loadedProgramName = _link.basename(filePath);

    _message =
        'Program loaded: $_loadedProgramName '
        '(${ordered.length} pts)';

    _notify();

    return filePath;
  }

  // ---------------------------------------------------------------------------
  // Design Loading
  // ---------------------------------------------------------------------------

  Future<void> loadDesignImage(
    Uint8List bytes,
    String name,
  ) async {
    _designImage = bytes;
    _isDxf = false;
    _designName = name;

    _programPoints = [];
    _gCode = '';

    _message = 'Design loaded — extracting path...';

    _notify();

    await extractPathFromDesign();
  }

  Future<void> loadDesignFromDxf(
    Uint8List bytes,
    String name,
  ) async {
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
      final args = <String, dynamic>{
        'bytes': bytes,
      };

      final result = await compute(
        _dxfExtractIsolate,
        args,
      ).timeout(
        const Duration(seconds: 12),
        onTimeout: () => const ExtractResult(
          points: [],
          colors: [],
        ),
      );

      _programPoints = result.points;
      _colorGroups = result.colors;

      _gCode = generateAdvancedGCode(
        points: result.points,
        colorGroups: result.colors,
        programName: name,
      );

      _message = result.points.isEmpty
          ? 'No supported entities found '
              '(LINE/ARC/CIRCLE/LWPOLYLINE/POLYLINE)'
          : 'DXF: exact path — '
              '${result.points.length} points across '
              '${result.colors.length} color(s), '
              'grouped by layer';
    } catch (error) {
      _message = 'DXF read failed: $error';

      _programPoints = [];
      _colorGroups = [];
      _gCode = '';
    }

    _extracting = false;
    _notify();
  }

  Future<void> loadSampleProject(
    String assetPath,
    String name,
  ) async {
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

      final result = await compute(
        _extractIsolate,
        args,
      ).timeout(
        const Duration(seconds: 12),
        onTimeout: () => const ExtractResult(
          points: [],
          colors: [],
        ),
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
    } catch (error) {
      _message = 'Extraction failed: $error';

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

  List<TuftPoint> _optimizeNearest(
    List<TuftPoint> input,
  ) {
    if (input.isEmpty) return input;

    final remaining = List<TuftPoint>.from(input);
    final result = <TuftPoint>[
      remaining.removeAt(0),
    ];

    while (remaining.isNotEmpty) {
      var bestIndex = 0;
      var bestDistance = double.infinity;

      final last = result.last;

      for (var i = 0; i < remaining.length; i++) {
        final dx = remaining[i].x - last.x;
        final dy = remaining[i].y - last.y;

        final distance = dx * dx + dy * dy;

        if (distance < bestDistance) {
          bestDistance = distance;
          bestIndex = i;
        }
      }

      result.add(
        remaining.removeAt(bestIndex),
      );
    }

    return result;
  }

  // ---------------------------------------------------------------------------
  // Local Simulation
  // ---------------------------------------------------------------------------

  List<TuftPoint> _localPath = [];

  int _localIndex = 0;

  double _segT = 0;
  double _segDur = 0.08;

  double _fromX = 0;
  double _fromY = 0;
  double _toX = 0;
  double _toY = 0;

  bool _haveSeg = false;

  void _startLocalSimIfNeeded() {
    if (!_useLocalSim) return;

    _localTick ??= Timer.periodic(
      const Duration(milliseconds: 50),
      (_) {
        if (!_useLocalSim) return;

        _localTickOnce(0.05);
      },
    );

    if (!_status.connected) {
      _status = const MachineStatus(
        connected: true,
        backend: 'sim',
        port: 'local-sim',
        mode: MachineMode.jog,
        state: MachineState.idle,
      );

      _message = kIsWeb
          ? 'Web local sim '
              '(use Windows + machine_server for C runtime)'
          : 'Local sim '
              '(start machine_server.exe for C runtime)';

      _notify();
    }
  }

  void _localHandle(Map<String, dynamic> command) {
    final cmd = command['cmd'] as String? ?? '';
    final status = _status;

    void updateStatus(MachineStatus newStatus) {
      _status = newStatus;
      _notify();
    }

    switch (cmd) {
      case 'connect':
        updateStatus(
          MachineStatus(
            mode: status.mode,
            state: MachineState.idle,
            x: status.x,
            y: status.y,
            connected: true,
            feedOverride: status.feedOverride,
            backend:
                command['backend'] as String? ?? 'sim',
            port:
                command['port'] as String? ?? 'local',
            baud:
                (command['baud'] as num?)?.toInt() ??
                    115200,
            jogStep: status.jogStep,
            pathLoaded: status.pathLoaded,
            pathCount: status.pathCount,
            referenced: status.referenced,
          ),
        );

        _message =
            'Connected (${_status.backend})';
        break;

      case 'disconnect':
        updateStatus(
          MachineStatus(
            mode: status.mode,
            connected: false,
            feedOverride: status.feedOverride,
            jogStep: status.jogStep,
          ),
        );
        break;

      case 'set_mode':
        final mode = MachineStatus.modeFrom(
          command['mode'] as String?,
        );

        updateStatus(
          _copy(
            status,
            mode: mode,
            alarm: '',
          ),
        );
        break;

      case 'jog':
        if (!status.connected ||
            status.mode != MachineMode.jog) {
          updateStatus(
            _copy(
              status,
              state: MachineState.alarm,
              alarm: 'JOG mode required',
            ),
          );
          return;
        }

        final axis =
            command['axis'] as String? ?? 'X';

        final direction =
            (command['dir'] as num?)?.toInt() ?? 1;

        var x = status.x;
        var y = status.y;
        var z = status.z;

        final step = status.jogStep *
            (direction >= 0 ? 1 : -1);

        final normalizedAxis = axis.toUpperCase();

        if (normalizedAxis == 'X') {
          x += step;
        } else if (normalizedAxis == 'Y') {
          y += step;
        } else if (normalizedAxis == 'Z') {
          z = (z + step).clamp(0.0, 25.0);

          updateStatus(
            _copy(
              status,
              z: z,
              needle: z < 2.5,
              alarm: '',
            ),
          );

          return;
        }

        if (x < 0 ||
            y < 0 ||
            x > 1000 ||
            y > 1000) {
          updateStatus(
            _copy(
              status,
              state: MachineState.alarm,
              alarm: 'Soft limit',
            ),
          );
          return;
        }

        updateStatus(
          _copy(
            status,
            x: x,
            y: y,
            alarm: '',
          ),
        );
        break;

      case 'home':
        updateStatus(
          _copy(
            status,
            x: 0,
            y: 0,
            z: 5,
            referenced: true,
            state: MachineState.idle,
            alarm: '',
            needle: false,
          ),
        );
        break;

      case 'load_path':
        final path = command['path'] as String?;

        if (path == null) return;

        () async {
          final lines =
              await _link.readCsvLines(path);

          if (lines == null) {
            if (_programPoints.length >= 2) {
              _localPath =
                  List<TuftPoint>.from(_programPoints);

              updateStatus(
                _copy(
                  status,
                  pathLoaded: true,
                  pathCount: _localPath.length,
                  pathIndex: 0,
                  progPct: 0,
                  alarm: '',
                ),
              );

              _loadedProgramName =
                  _link.basename(path);
            } else {
              updateStatus(
                _copy(
                  status,
                  alarm: 'Path empty',
                  pathLoaded: false,
                ),
              );
            }

            return;
          }

          _localPath = [];

          for (final line in lines.skip(1)) {
            final parts = line.split(',');

            if (parts.length < 2) continue;

            _localPath.add(
              TuftPoint(
                x: double.parse(parts[0]),
                y: double.parse(parts[1]),
              ),
            );
          }

          updateStatus(
            _copy(
              status,
              pathLoaded: _localPath.length >= 2,
              pathCount: _localPath.length,
              pathIndex: 0,
              progPct: 0,
              alarm: _localPath.length >= 2
                  ? ''
                  : 'Path empty',
            ),
          );

          _loadedProgramName =
              _link.basename(path);

          _programPoints =
              List<TuftPoint>.from(_localPath);
        }();

        break;

      case 'cycle_start':
        if (status.mode == MachineMode.mdi) {
          _localMdi(status, _mdiLine);
          return;
        }

        final hasProgram =
            _programPoints.length >= 2;

        final hasLocalPath =
            _localPath.length >= 2;

        if (status.mode != MachineMode.auto ||
            (!status.pathLoaded && !hasProgram) ||
            (!hasLocalPath && !hasProgram)) {
          if (hasProgram) {
            _localPath =
                List<TuftPoint>.from(_programPoints);
          } else {
            updateStatus(
              _copy(
                status,
                state: MachineState.alarm,
                alarm: 'Path empty',
              ),
            );
            return;
          }
        }

        if (_localPath.length < 2 && hasProgram) {
          _localPath =
              List<TuftPoint>.from(_programPoints);
        }

        if (status.state == MachineState.hold) {
          updateStatus(
            _copy(
              status,
              state: MachineState.running,
              alarm: '',
            ),
          );
          return;
        }

        _localIndex = 0;
        _beginLocalSeg();

        updateStatus(
          _copy(
            status,
            state: MachineState.running,
            x: _localPath[0].x,
            y: _localPath[0].y,
            pathLoaded: true,
            pathCount: _localPath.length,
            alarm: '',
            needle: true,
          ),
        );
        break;

      case 'feed_hold':
        if (status.state == MachineState.running) {
          updateStatus(
            _copy(
              status,
              state: MachineState.hold,
              needle: false,
            ),
          );
        }
        break;

      case 'cycle_stop':
        _haveSeg = false;

        updateStatus(
          _copy(
            status,
            state: MachineState.idle,
            needle: false,
          ),
        );
        break;

      case 'reset':
        _haveSeg = false;

        updateStatus(
          _copy(
            status,
            state: MachineState.idle,
            progPct: 0,
            pathIndex: 0,
            alarm: '',
            needle: false,
          ),
        );
        break;

      case 'estop':
        _haveSeg = false;

        updateStatus(
          _copy(
            status,
            state: MachineState.alarm,
            alarm: 'EMERGENCY STOP',
            needle: false,
          ),
        );
        break;

      case 'set_feed_override':
        updateStatus(
          _copy(
            status,
            feedOverride:
                (command['percent'] as num?)
                        ?.toInt() ??
                    100,
          ),
        );
        break;

      case 'set_jog_step':
        updateStatus(
          _copy(
            status,
            jogStep: double.tryParse(
                  '${command['step']}',
                ) ??
                1.0,
          ),
        );
        break;

      case 'mdi':
        _localMdi(
          status,
          command['line'] as String? ?? '',
        );
        break;
    }
  }

  void _localMdi(
    MachineStatus status,
    String line,
  ) {
    if (status.mode != MachineMode.mdi) {
      _status = _copy(
        status,
        state: MachineState.alarm,
        alarm: 'MDI mode required',
      );

      _notify();
      return;
    }

    var x = status.x;
    var y = status.y;

    final xMatch =
        RegExp(r'[Xx]\s*([-\d.]+)').firstMatch(line);

    final yMatch =
        RegExp(r'[Yy]\s*([-\d.]+)').firstMatch(line);

    if (xMatch != null) {
      x = double.parse(xMatch.group(1)!);
    }

    if (yMatch != null) {
      y = double.parse(yMatch.group(1)!);
    }

    if (x < 0 ||
        y < 0 ||
        x > 1000 ||
        y > 1000) {
      _status = _copy(
        status,
        state: MachineState.alarm,
        alarm: 'Soft limit',
      );
    } else {
      _status = _copy(
        status,
        x: x,
        y: y,
        alarm: '',
      );
    }

    _notify();
  }

  void _beginLocalSeg() {
    if (_localIndex >= _localPath.length - 1) {
      _haveSeg = false;

      _status = _copy(
        _status,
        state: MachineState.idle,
        progPct: 100,
        needle: false,
      );

      _notify();
      return;
    }

    _fromX = _localPath[_localIndex].x;
    _fromY = _localPath[_localIndex].y;

    _toX = _localPath[_localIndex + 1].x;
    _toY = _localPath[_localIndex + 1].y;

    final dx = _toX - _fromX;
    final dy = _toY - _fromY;

    final distance = math.sqrt(
      dx * dx + dy * dy,
    );

    // Simulation speed in mm/second.
    const simulationSpeed = 45.0;

    _segDur = distance < 1e-6
        ? 0.04
        : math.max(
            0.04,
            distance / simulationSpeed,
          );

    _segT = 0;
    _haveSeg = true;
  }

  void _localTickOnce(double dt) {
    if (_status.state != MachineState.running ||
        !_haveSeg) {
      return;
    }

    _segT += dt;

    var progress =
        _segDur <= 0 ? 1.0 : _segT / _segDur;

    if (progress > 1) {
      progress = 1;
    }

    final x =
        _fromX + (_toX - _fromX) * progress;

    final y =
        _fromY + (_toY - _fromY) * progress;

    final percentage = _localPath.length > 1
        ? 100.0 *
            (_localIndex + progress) /
            (_localPath.length - 1)
        : 0.0;

    final isLastSegment =
        _localIndex >= _localPath.length - 2 &&
            progress >= 0.999;

    _status = _copy(
      _status,
      x: x,
      y: y,
      progPct: percentage.clamp(0, 100),
      pathIndex: _localIndex,
      needle: !isLastSegment,
    );

    _notify();

    if (progress >= 1) {
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

  // ---------------------------------------------------------------------------
  // Machine Status Copy
  // ---------------------------------------------------------------------------

  MachineStatus _copy(
    MachineStatus status, {
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
      mode: mode ?? status.mode,
      state: state ?? status.state,
      x: x ?? status.x,
      y: y ?? status.y,
      z: z ?? status.z,
      wcsX: status.wcsX,
      wcsY: status.wcsY,
      wcsZ: status.wcsZ,
      feedOverride:
          feedOverride ?? status.feedOverride,
      connected:
          connected ?? status.connected,
      referenced:
          referenced ?? status.referenced,
      needle:
          needle ?? status.needle,
      alarm:
          alarm ?? status.alarm,
      progPct:
          progPct ?? status.progPct,
      pathLoaded:
          pathLoaded ?? status.pathLoaded,
      pathCount:
          pathCount ?? status.pathCount,
      pathIndex:
          pathIndex ?? status.pathIndex,
      backend:
          backend ?? status.backend,
      port:
          port ?? status.port,
      baud:
          baud ?? status.baud,
      jogStep:
          jogStep ?? status.jogStep,
    );
  }

  // ---------------------------------------------------------------------------
  // PLC Macros
  // ---------------------------------------------------------------------------

  void updatePlcMacro(
    int index,
    PlcMacro macro,
  ) {
    if (index < 0 ||
        index >= _plcMacros.length) {
      return;
    }

    _plcMacros[index] = macro;
    _notify();
  }

  void addPlcMacro(PlcMacro macro) {
    _plcMacros.add(macro);
    _notify();
  }

  Future<void> runPlcMacro(
    PlcMacro macro,
  ) async {
    await setMode(MachineMode.mdi);

    setMdiLine(macro.code);
    await runMdi();

    _message =
        'PLC macro: ${macro.name} → ${macro.code}';

    _notify();
  }

  // ---------------------------------------------------------------------------
  // Advanced G-Code Generator
  // ---------------------------------------------------------------------------

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
    if (points.isEmpty) {
      return '; ROVEX: Empty point set provided';
    }

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
    sb.writeln(
      'G0 Z${safeZ.toStringAsFixed(2)} '
      '; Retract head to safe height',
    );

    double? activeFeed;
    String activeMotionMode = '';

    TuftPoint? currentPoint;
    int currentColorOrder = -1;

    void updateMotionMode(String mode) {
      activeMotionMode = mode;
    }

    void applyFeed(double targetFeed) {
      if (activeFeed == targetFeed) return;

      sb.write(' F${targetFeed.toInt()}');
      activeFeed = targetFeed;
    }

    void moveToPoint(
      TuftPoint target, {
      required bool isCutting,
    }) {
      final motionMode = isCutting ? 'G1' : 'G0';
      final feed = isCutting ? cutFeed : travelFeed;

      if (activeMotionMode != motionMode) {
        sb.write(motionMode);
        updateMotionMode(motionMode);
      }

      sb.write(
        ' X${target.x.toStringAsFixed(2)} '
        'Y${target.y.toStringAsFixed(2)}',
      );

      applyFeed(feed);
      sb.writeln();

      currentPoint = target;
    }

    var index = 0;

    while (index < points.length) {
      final point = points[index];

      // Color group boundary.
      if (point.colorOrder != currentColorOrder) {
        currentColorOrder = point.colorOrder ?? 0;

        sb.writeln();
        sb.writeln(
          '; --- Color Group #$currentColorOrder ---',
        );

        sb.writeln(
          'M9 ; Disengage needle/tool',
        );

        sb.writeln(
          'G0 Z${safeZ.toStringAsFixed(2)}',
        );

        moveToPoint(
          point,
          isCutting: false,
        );

        sb.writeln(
          'M8 ; Engage needle/tool',
        );

        sb.writeln(
          'G0 Z${workZ.toStringAsFixed(2)}',
        );

        index++;
        continue;
      }

      // Detect jumps or gaps inside the same color group.
      if (currentPoint != null) {
        final dx = point.x - currentPoint!.x;
        final dy = point.y - currentPoint!.y;

        final distance = math.sqrt(
          dx * dx + dy * dy,
        );

        if (distance > jumpThreshold) {
          sb.writeln(
            '; Travel Jump Detected '
            '(${distance.toStringAsFixed(1)}mm)',
          );

          sb.writeln(
            'M9 ; Disengage needle',
          );

          sb.writeln(
            'G0 Z${safeZ.toStringAsFixed(2)}',
          );

          moveToPoint(
            point,
            isCutting: false,
          );

          sb.writeln(
            'M8 ; Engage needle',
          );

          sb.writeln(
            'G0 Z${workZ.toStringAsFixed(2)}',
          );

          index++;
          continue;
        }
      }

      // Arc fitting using three consecutive points.
      if (index + 2 < points.length) {
        final p1 = point;
        final p2 = points[index + 1];
        final p3 = points[index + 2];

        if (p2.colorOrder == currentColorOrder &&
            p3.colorOrder == currentColorOrder) {
          final arc = _fitArc(p1, p2, p3);

          if (arc != null &&
              arc.radius > 1.0 &&
              arc.radius < 500.0) {
            final command =
                arc.isClockwise ? 'G2' : 'G3';

            if (activeMotionMode != command) {
              sb.write(command);
              updateMotionMode(command);
            }

            sb.write(
              ' X${p3.x.toStringAsFixed(2)} '
              'Y${p3.y.toStringAsFixed(2)} '
              'I${arc.i.toStringAsFixed(2)} '
              'J${arc.j.toStringAsFixed(2)}',
            );

            applyFeed(cutFeed);
            sb.writeln();

            currentPoint = p3;
            index += 3;

            continue;
          }
        }
      }

      // Standard linear movement.
      moveToPoint(
        point,
        isCutting: true,
      );

      index++;
    }

    // Program footer.
    sb.writeln();
    sb.writeln('; --- Program End Cleanup ---');
    sb.writeln('M9 ; Disengage tool');

    sb.writeln(
      'G0 Z${safeZ.toStringAsFixed(2)} '
      '; Retract to safe Z',
    );

    sb.writeln(
      'G0 X0.00 Y0.00 ; Return to origin',
    );

    sb.writeln('M30 ; End of program');

    return sb.toString();
  }

  // ---------------------------------------------------------------------------
  // Arc Fitting
  // ---------------------------------------------------------------------------

  static ArcFittingResult? _fitArc(
    TuftPoint p1,
    TuftPoint p2,
    TuftPoint p3,
  ) {
    final denominator = 2 *
        (p1.x * (p2.y - p3.y) +
            p2.x * (p3.y - p1.y) +
            p3.x * (p1.y - p2.y));

    if (denominator.abs() < 1e-4) {
      return null;
    }

    final centerX =
        ((p1.x * p1.x + p1.y * p1.y) *
                (p2.y - p3.y) +
            (p2.x * p2.x + p2.y * p2.y) *
                (p3.y - p1.y) +
            (p3.x * p3.x + p3.y * p3.y) *
                (p1.y - p2.y)) /
            denominator;

    final centerY =
        ((p1.x * p1.x + p1.y * p1.y) *
                (p3.x - p2.x) +
            (p2.x * p2.x + p2.y * p2.y) *
                (p1.x - p3.x) +
            (p3.x * p3.x + p3.y * p3.y) *
                (p2.x - p1.x)) /
            denominator;

    final radius = math.sqrt(
      math.pow(p1.x - centerX, 2) +
          math.pow(p1.y - centerY, 2),
    );

    final i = centerX - p1.x;
    final j = centerY - p1.y;

    final crossProduct =
        (p2.x - p1.x) * (p3.y - p1.y) -
            (p2.y - p1.y) * (p3.x - p1.x);

    final isClockwise = crossProduct < 0;

    return ArcFittingResult(
      i: i,
      j: j,
      radius: radius,
      isClockwise: isClockwise,
    );
  }
}

// -----------------------------------------------------------------------------
// Arc Fitting Result
// -----------------------------------------------------------------------------

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

// -----------------------------------------------------------------------------
// PLC Macro
// -----------------------------------------------------------------------------

class PlcMacro {
  final String name;
  final String code;
  final String note;

  const PlcMacro({
    required this.name,
    required this.code,
    this.note = '',
  });

  PlcMacro copyWith({
    String? name,
    String? code,
    String? note,
  }) {
    return PlcMacro(
      name: name ?? this.name,
      code: code ?? this.code,
      note: note ?? this.note,
    );
  }

  static const defaults = [
    PlcMacro(
      name: 'Needle ON',
      code: 'M8',
      note: 'Engage needle / stitch',
    ),
    PlcMacro(
      name: 'Needle OFF',
      code: 'M9',
      note: 'Retract needle',
    ),
    PlcMacro(
      name: 'Coolant aux',
      code: 'M7',
      note: 'Optional aux output',
    ),
    PlcMacro(
      name: 'Spindle stop',
      code: 'M5',
      note: 'Safe stop aux',
    ),
    PlcMacro(
      name: 'Safe Z',
      code: 'G0 Z5',
      note: 'Raise embroidery head',
    ),
    PlcMacro(
      name: 'Stitch depth',
      code: 'G1 Z0 F800',
      note: 'Needle down for embroidery',
    ),
  ];
}

// -----------------------------------------------------------------------------
// Top-Level Isolate Functions
// -----------------------------------------------------------------------------

ExtractResult _dxfExtractIsolate(
  Map<String, dynamic> args,
) {
  final bytes = args['bytes'] as Uint8List;

  return parseDxfEntities(bytes);
}

ExtractResult _extractIsolate(
  Map<String, dynamic> args,
) {
  try {
    final bytes = args['bytes'] as Uint8List;

    final pitch =
        (args['pitch'] as num?)?.toDouble() ?? 10.0;

    return extractPathFromImageBytes(
      bytes,
      pitch: pitch,
    );
  } catch (_) {
    return const ExtractResult(
      points: [],
      colors: [],
    );
  }
}