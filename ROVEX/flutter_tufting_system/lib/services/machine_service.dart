import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../models/design.dart';
import '../models/machine_profile.dart';
import '../models/machine_status.dart';
import 'dxf_parser.dart';
import 'path_extractor.dart';
import 'runtime_link.dart';

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

  bool _colorRunMode = false;
  bool _colorCompletionPending = false;
  int? _activeColorRunOrder;
  int? _completedColorOrder;

  List<TuftPoint> _allDesignPoints = [];
  List<int> _colorRunOrders = [];

  bool _colorRunExecuting = false;
  bool _colorRunCancelled = false;
  bool _colorRunStarting = false;

  List<TuftPoint> _localPath = [];

  int _localIndex = 0;

  double _segT = 0;
  double _segDur = 0.08;

  double _fromX = 0;
  double _fromY = 0;
  double _toX = 0;
  double _toY = 0;

  bool _haveSeg = false;

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

  bool get colorRunMode => _colorRunMode;

  bool get colorCompletionPending => _colorCompletionPending;

  int? get activeColorRunOrder => _activeColorRunOrder;

  int? get completedColorOrder => _completedColorOrder;

  int get completedColorNumber {
    if (_completedColorOrder == null) {
      return 0;
    }

    final index =
        _colorRunOrders.indexOf(_completedColorOrder!);

    return index < 0 ? 0 : index + 1;
  }

  int get totalColorRunCount => _colorRunOrders.length;

  int get nextColorNumber {
    final order = nextColorOrder;

    if (order == null) {
      return 0;
    }

    final index = _colorRunOrders.indexOf(order);

    return index < 0 ? 0 : index + 1;
  }

  int? get nextColorOrder {
    if (_activeColorRunOrder == null) {
      return null;
    }

    final index =
        _colorRunOrders.indexOf(_activeColorRunOrder!);

    if (index < 0 ||
        index + 1 >= _colorRunOrders.length) {
      return null;
    }

    return _colorRunOrders[index + 1];
  }

  ColorGroup? get completedColorGroup {
    final order = _completedColorOrder;

    if (order == null) {
      return null;
    }

    for (final group in _colorGroups) {
      if (group.order == order) {
        return group;
      }
    }

    return null;
  }

  ColorGroup? get nextColorGroup {
    final order = nextColorOrder;

    if (order == null) {
      return null;
    }

    for (final group in _colorGroups) {
      if (group.order == order) {
        return group;
      }
    }

    return null;
  }

  String get completedColorName {
    final group = completedColorGroup;

    return group == null
        ? 'Unknown'
        : _colorName(group.colorValue);
  }

  String get nextColorName {
    final group = nextColorGroup;

    return group == null
        ? 'Unknown'
        : _colorName(group.colorValue);
  }

  int? get activeColorOrder {
    if (_colorRunMode &&
        _activeColorRunOrder != null) {
      return _activeColorRunOrder;
    }

    final index = _status.pathIndex;

    if (index < 0 ||
        index >= _programPoints.length) {
      return _programPoints.isNotEmpty
          ? _programPoints.last.colorOrder
          : null;
    }

    return _programPoints[index].colorOrder;
  }

  Uint8List? get designImage => _designImage;

  String? get designName => _designName;

  bool get hasDesign =>
      _designImage != null || _isDxf;

  bool get isDxfDesign => _isDxf;

  String get gCode => _gCode;

  double get extractPitchMm => _extractPitchMm;

  bool get isExtracting => _extracting;

  List<PlcMacro> get plcMacros =>
      List.unmodifiable(_plcMacros);

  List<MachineProfile> get machines =>
      List.unmodifiable(_machines);

  MachineProfile get activeMachine => _activeMachine;

  Future<void> start() async {
    if (_started) {
      return;
    }

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
    if (_disposed) {
      return;
    }

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

  Future<void> _loadMachines() async {
    try {
      final raw = await _link.loadText('machines');

      if (raw == null) {
        return;
      }

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
    } catch (_) {}
  }

  Future<void> _saveMachines() async {
    try {
      await _link.saveText(
        'machines',
        jsonEncode(
          _machines
              .map((machine) => machine.toJson())
              .toList(),
        ),
      );
    } catch (_) {}
  }

  Future<void> addMachine({
    required String name,
    required String host,
    int port = 9100,
  }) async {
    final machine = MachineProfile(
      id: DateTime.now()
          .microsecondsSinceEpoch
          .toString(),
      name: name.trim().isEmpty
          ? host
          : name.trim(),
      host: host.trim(),
      port: port,
    );

    _machines = [
      ..._machines,
      machine,
    ];

    await _saveMachines();

    _notify();
  }

  Future<void> removeMachine(String id) async {
    if (id == _localProfile.id) {
      return;
    }

    _machines = _machines
        .where(
          (machine) => machine.id != id,
        )
        .toList();

    if (_machines.isEmpty) {
      _machines = [_localProfile];
    }

    if (_activeMachine.id == id) {
      await connectToMachine(_machines.first);
    }

    await _saveMachines();

    _notify();
  }

  Future<void> connectToMachine(
    MachineProfile machine,
  ) async {
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

  Future<void> _tryConnectRuntime() async {
    if (kIsWeb) {
      return;
    }

    if (_link.isConnected) {
      return;
    }

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

      await sendCmd({
        'cmd': 'get_status',
      });

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

    _message =
        'Runtime disconnected — local sim active';

    _startLocalSimIfNeeded();

    _notify();
  }

  void _onLine(String line) {
    if (line.trim().isEmpty) {
      return;
    }

    try {
      final json =
          jsonDecode(line) as Map<String, dynamic>;

      if (json['type'] != 'status') {
        return;
      }

      final previousState = _status.state;

      _status = MachineStatus.fromJson(json);

      if (_colorRunExecuting &&
          previousState == MachineState.running &&
          _status.state == MachineState.idle) {
        _handleColorRunCompletion();
      }

      if (_status.alarm.isNotEmpty) {
        _message = _status.alarm;
      } else if (!_colorCompletionPending) {
        _message =
            '${_status.modeLabel} | '
            '${_status.stateLabel} | '
            '${_status.backend.toUpperCase()}';
      }

      _notify();
    } catch (_) {}
  }

  Future<void> sendCmd(
    Map<String, dynamic> command,
  ) async {
    if (_runtimeLinked &&
        _link.isConnected) {
      await _link.send(
        jsonEncode(command),
      );

      return;
    }

    _localHandle(command);
  }

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
    return sendCmd({
      'cmd': 'disconnect',
    });
  }

  Future<void> setMode(
    MachineMode mode,
  ) async {
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

  Future<void> jog(
    String axis,
    int direction,
  ) {
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

    if (status.mode != MachineMode.jog) {
      return;
    }

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
    return sendCmd({
      'cmd': 'home',
    });
  }

  Future<void> cycleStart() async {
    if (_colorRunMode) {
      if (_colorCompletionPending) {
        return;
      }

      if (_activeColorRunOrder == null) {
        await startColorRun();
      } else if (!_colorRunExecuting) {
        await _runActiveColor();
      }

      return;
    }

    if (_colorGroups.length > 1 &&
        _programPoints.any(
          (point) => point.colorOrder != null,
        )) {
      await startColorRun();
      return;
    }

    await sendCmd({
      'cmd': 'cycle_start',
    });
  }

  Future<void> feedHold() {
    return sendCmd({
      'cmd': 'feed_hold',
    });
  }

  Future<void> cycleStop() async {
    _colorRunExecuting = false;
    _haveSeg = false;

    await sendCmd({
      'cmd': 'cycle_stop',
    });

    if (_colorRunMode) {
      _message = 'Color run stopped';
      _notify();
    }
  }

  Future<void> reset() async {
    _colorRunExecuting = false;
    _haveSeg = false;

    await sendCmd({
      'cmd': 'reset',
    });

    if (_colorRunMode) {
      _resetColorRunState();
    }
  }

  Future<void> estop() async {
    _colorRunExecuting = false;
    _haveSeg = false;

    await sendCmd({
      'cmd': 'estop',
    });
  }

  Future<void> setFeedOverride(
    int percent,
  ) {
    return sendCmd({
      'cmd': 'set_feed_override',
      'percent': percent,
    });
  }

  Future<void> setJogStep(
    double step,
  ) {
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

  void setExtractPitch(double mm) {
    _extractPitchMm = mm.clamp(2, 20);
    _notify();
  }

  void regenerateGCode() {
    _gCode = generateAdvancedGCode(
      points: _programPoints,
      colorGroups: _colorGroups,
      programName:
          _designName ?? 'Generated_Path',
    );

    _notify();
  }

  Future<void> loadPathFile(
    String path,
  ) async {
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

        if (parts.length < 2) {
          continue;
        }

        final x = double.tryParse(parts[0]);
        final y = double.tryParse(parts[1]);

        if (x == null || y == null) {
          continue;
        }

        _programPoints.add(
          TuftPoint(
            x: x,
            y: y,
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

    _allDesignPoints =
        List<TuftPoint>.from(ordered);

    _programPoints = ordered;

    _prepareColorRunOrders();

    _gCode = generateAdvancedGCode(
      points: ordered,
      colorGroups: _colorGroups,
      programName: name,
    );

    final rows = <String>[
      'x_mm,y_mm',
    ];

    for (final point in ordered) {
      rows.add(
        '${point.x.toStringAsFixed(3)},'
        '${point.y.toStringAsFixed(3)}',
      );
    }

    final filePath =
        await _link.writeProgramCsv(
      name,
      rows,
    );

    await setMode(MachineMode.auto);

    await loadPathFile(filePath);

    _allDesignPoints =
        List<TuftPoint>.from(ordered);

    _loadedProgramName =
        _link.basename(filePath);

    _message =
        'Program loaded: $_loadedProgramName '
        '(${ordered.length} pts)';

    _notify();

    return filePath;
  }

  Future<void> loadDesignImage(
    Uint8List bytes,
    String name,
  ) async {
    _designImage = bytes;
    _isDxf = false;
    _designName = name;

    _programPoints = [];
    _allDesignPoints = [];
    _colorGroups = [];
    _colorRunOrders = [];

    _resetColorRunState();

    _gCode = '';

    _message =
        'Design loaded — extracting path...';

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
    _allDesignPoints = [];
    _colorGroups = [];
    _colorRunOrders = [];

    _resetColorRunState();

    _gCode = '';

    _message =
        'DXF loaded — building exact path...';

    _notify();

    if (_extracting) {
      return;
    }

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

      _allDesignPoints =
          List<TuftPoint>.from(
        result.points,
      );

      _colorGroups = result.colors;

      _prepareColorRunOrders();

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
      _allDesignPoints = [];
      _colorGroups = [];
      _colorRunOrders = [];
      _gCode = '';
    }

    _extracting = false;
    _notify();
  }

  Future<void> loadSampleProject(
    String assetPath,
    String name,
  ) async {
    final data =
        await rootBundle.load(assetPath);

    final bytes =
        data.buffer.asUint8List();

    await loadDesignImage(
      bytes,
      name,
    );
  }

  Future<void> extractPathFromDesign() async {
    if (_designImage == null ||
        _extracting) {
      return;
    }

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

      _allDesignPoints =
          List<TuftPoint>.from(
        result.points,
      );

      _colorGroups = result.colors;

      _prepareColorRunOrders();

      _gCode = generateAdvancedGCode(
        points: result.points,
        colorGroups: result.colors,
        programName:
            _designName ?? 'Image_Design',
      );

      _message = result.points.isEmpty
          ? 'No path found — try lower pitch or another image'
          : 'Extracted ${result.points.length} points across '
              '${result.colors.length} color(s) '
              '(pitch ${_extractPitchMm.toStringAsFixed(0)} mm)';
    } catch (error) {
      _message = 'Extraction failed: $error';

      _programPoints = [];
      _allDesignPoints = [];
      _colorGroups = [];
      _colorRunOrders = [];
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

    _programPoints = [];
    _allDesignPoints = [];
    _colorGroups = [];
    _colorRunOrders = [];

    _resetColorRunState();

    _notify();
  }

  void _prepareColorRunOrders() {
    final orders = <int>{};

    for (final point in _allDesignPoints) {
      final order = point.colorOrder;

      if (order != null) {
        orders.add(order);
      }
    }

    for (final group in _colorGroups) {
      orders.add(group.order);
    }

    _colorRunOrders =
        orders.toList()..sort();
  }

  List<TuftPoint> _pointsForColor(
    int colorOrder,
  ) {
    return _allDesignPoints
        .where(
          (point) =>
              point.colorOrder == colorOrder,
        )
        .toList();
  }

  ColorGroup? _groupForOrder(
    int order,
  ) {
    for (final group in _colorGroups) {
      if (group.order == order) {
        return group;
      }
    }

    return null;
  }

  String _colorName(
    int colorValue,
  ) {
    final rgb =
        colorValue & 0x00FFFFFF;

    const names = <int, String>{
      0x000000: 'Black',
      0xFFFFFF: 'White',
      0xFF0000: 'Red',
      0x00FF00: 'Green',
      0x0000FF: 'Blue',
      0xFFFF00: 'Yellow',
      0xFFA500: 'Orange',
      0x800080: 'Purple',
      0xFFC0CB: 'Pink',
      0x00FFFF: 'Cyan',
      0xFF00FF: 'Magenta',
      0x808080: 'Gray',
      0xA52A2A: 'Brown',
    };

    final exact = names[rgb];

    if (exact != null) {
      return exact;
    }

    final r = (rgb >> 16) & 0xFF;
    final g = (rgb >> 8) & 0xFF;
    final b = rgb & 0xFF;

    if (r > 220 && g < 90 && b < 90) {
      return 'Red';
    }

    if (r < 90 && g > 170 && b < 90) {
      return 'Green';
    }

    if (r < 90 && g < 150 && b > 170) {
      return 'Blue';
    }

    if (r > 200 &&
        g > 170 &&
        b < 100) {
      return 'Yellow';
    }

    if (r > 220 &&
        g > 100 &&
        g < 190 &&
        b < 100) {
      return 'Orange';
    }

    if (r > 180 &&
        g < 130 &&
        b > 150) {
      return 'Pink';
    }

    if (r > 170 &&
        g < 100 &&
        b > 170) {
      return 'Magenta';
    }

    if (r < 100 &&
        g > 170 &&
        b > 170) {
      return 'Cyan';
    }

    if (r > 180 &&
        g > 180 &&
        b > 180) {
      return 'White';
    }

    if (r < 70 &&
        g < 70 &&
        b < 70) {
      return 'Black';
    }

    if ((r - g).abs() < 20 &&
        (g - b).abs() < 20) {
      return 'Gray';
    }

    return 'Color #${rgb.toRadixString(16).padLeft(6, '0').toUpperCase()}';
  }

  Future<void> startColorRun() async {
    if (_colorRunStarting ||
        _colorRunExecuting ||
        _colorRunOrders.isEmpty) {
      return;
    }

    _colorRunStarting = true;
    _colorRunCancelled = false;
    _colorCompletionPending = false;
    _completedColorOrder = null;

    _activeColorRunOrder =
        _colorRunOrders.first;

    _colorRunMode = true;

    _message =
        'Preparing ${_colorNameForOrder(_activeColorRunOrder!)}...';

    _notify();

    try {
      await _runActiveColor();
    } finally {
      _colorRunStarting = false;
    }
  }

  Future<void> continueNextColor() async {
    if (!_colorRunMode ||
        !_colorCompletionPending ||
        _colorRunCancelled) {
      return;
    }

    final nextOrder = nextColorOrder;

    if (nextOrder == null) {
      _finishColorRun();
      return;
    }

    _colorCompletionPending = false;
    _completedColorOrder = null;

    _activeColorRunOrder = nextOrder;

    _message =
        'Preparing ${_colorNameForOrder(nextOrder)}...';

    _notify();

    await _runActiveColor();
  }

  Future<void> cancelColorRun() async {
    if (!_colorRunMode) {
      return;
    }

    _colorRunCancelled = true;
    _colorCompletionPending = false;
    _colorRunExecuting = false;
    _haveSeg = false;

    if (_status.state == MachineState.running) {
      await sendCmd({
        'cmd': 'cycle_stop',
      });
    }

    _message = 'Color run cancelled';

    _resetColorRunState();

    _notify();
  }

  Future<void> _runActiveColor() async {
    final order = _activeColorRunOrder;

    if (!_colorRunMode ||
        order == null ||
        _colorRunCancelled ||
        _colorRunExecuting) {
      return;
    }

    final colorPoints =
        _pointsForColor(order);

    if (colorPoints.length < 2) {
      _message =
          '${_colorNameForOrder(order)} has no drawable path';

      _notify();

      _handleColorRunCompletion();

      return;
    }

    _colorRunExecuting = true;
    _colorCompletionPending = false;

    _programPoints = colorPoints;

    final group = _groupForOrder(order);

    final colorName = group == null
        ? _colorNameForOrder(order)
        : _colorName(group.colorValue);

    _message =
        'Running $colorName '
        '(${_colorRunOrders.indexOf(order) + 1}/'
        '${_colorRunOrders.length})';

    _notify();

    final programName =
        '${_designName ?? 'ROVEX_DESIGN'}_color_$order';

    final rows = <String>[
      'x_mm,y_mm',
    ];

    for (final point in colorPoints) {
      rows.add(
        '${point.x.toStringAsFixed(3)},'
        '${point.y.toStringAsFixed(3)}',
      );
    }

    try {
      final filePath =
          await _link.writeProgramCsv(
        programName,
        rows,
      );

      await setMode(MachineMode.auto);

      await loadPathFile(filePath);

      if (_colorRunCancelled) {
        return;
      }

      await sendCmd({
        'cmd': 'cycle_start',
      });
    } catch (error) {
      _colorRunExecuting = false;

      _message =
          'Failed to start $colorName: $error';

      _notify();
    }
  }

  void _handleColorRunCompletion() {
    if (!_colorRunMode ||
        !_colorRunExecuting ||
        _activeColorRunOrder == null) {
      return;
    }

    _colorRunExecuting = false;
    _haveSeg = false;

    final completedOrder =
        _activeColorRunOrder!;

    final completedName =
        _colorNameForOrder(completedOrder);

    _completedColorOrder =
        completedOrder;

    _colorCompletionPending = true;

    final nextOrder = nextColorOrder;

    if (nextOrder == null) {
      _message =
          'Completed $completedName — all colors finished';
    } else {
      _message =
          'Completed $completedName — '
          'ready for ${_colorNameForOrder(nextOrder)}';
    }

    _status = _copy(
      _status,
      state: MachineState.idle,
      needle: false,
      progPct: 100,
    );

    _notify();
  }

  String _colorNameForOrder(
    int order,
  ) {
    final group = _groupForOrder(order);

    if (group == null) {
      return 'Color ${_colorRunOrders.indexOf(order) + 1}';
    }

    return _colorName(
      group.colorValue,
    );
  }

  void _finishColorRun() {
    _colorRunMode = false;
    _colorRunExecuting = false;
    _colorCompletionPending = false;
    _colorRunCancelled = false;

    _completedColorOrder = null;
    _activeColorRunOrder = null;

    _programPoints =
        List<TuftPoint>.from(
      _allDesignPoints,
    );

    _message = 'All colors completed';

    _notify();
  }

  void _resetColorRunState() {
    _colorRunMode = false;
    _colorCompletionPending = false;
    _colorRunExecuting = false;
    _colorRunCancelled = false;
    _colorRunStarting = false;

    _activeColorRunOrder = null;
    _completedColorOrder = null;
  }

  List<TuftPoint> _optimizeNearest(
    List<TuftPoint> input,
  ) {
    if (input.isEmpty) {
      return input;
    }

    final remaining =
        List<TuftPoint>.from(input);

    final result = <TuftPoint>[
      remaining.removeAt(0),
    ];

    while (remaining.isNotEmpty) {
      var bestIndex = 0;
      var bestDistance = double.infinity;

      final last = result.last;

      for (var i = 0;
          i < remaining.length;
          i++) {
        final dx =
            remaining[i].x - last.x;

        final dy =
            remaining[i].y - last.y;

        final distance =
            dx * dx + dy * dy;

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

  void _startLocalSimIfNeeded() {
    if (!_useLocalSim) {
      return;
    }

    _localTick ??= Timer.periodic(
      const Duration(milliseconds: 50),
      (_) {
        if (!_useLocalSim) {
          return;
        }

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

  void _localHandle(
    Map<String, dynamic> command,
  ) {
    final cmd =
        command['cmd'] as String? ?? '';

    final status = _status;

    void updateStatus(
      MachineStatus newStatus,
    ) {
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
                command['backend'] as String? ??
                    'sim',
            port:
                command['port'] as String? ??
                    'local',
            baud:
                (command['baud'] as num?)
                        ?.toInt() ??
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
            command['axis'] as String? ??
                'X';

        final direction =
            (command['dir'] as num?)
                    ?.toInt() ??
                1;

        var x = status.x;
        var y = status.y;
        var z = status.z;

        final step =
            status.jogStep *
                (direction >= 0 ? 1 : -1);

        final normalizedAxis =
            axis.toUpperCase();

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
        final path =
            command['path'] as String?;

        if (path == null) {
          return;
        }

        () async {
          final lines =
              await _link.readCsvLines(path);

          if (lines == null) {
            if (_programPoints.length >= 2) {
              _localPath =
                  List<TuftPoint>.from(
                _programPoints,
              );

              updateStatus(
                _copy(
                  status,
                  pathLoaded: true,
                  pathCount:
                      _localPath.length,
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

          for (final line
              in lines.skip(1)) {
            final parts =
                line.split(',');

            if (parts.length < 2) {
              continue;
            }

            final x =
                double.tryParse(parts[0]);

            final y =
                double.tryParse(parts[1]);

            if (x == null || y == null) {
              continue;
            }

            _localPath.add(
              TuftPoint(
                x: x,
                y: y,
              ),
            );
          }

          updateStatus(
            _copy(
              status,
              pathLoaded:
                  _localPath.length >= 2,
              pathCount:
                  _localPath.length,
              pathIndex: 0,
              progPct: 0,
              alarm:
                  _localPath.length >= 2
                      ? ''
                      : 'Path empty',
            ),
          );

          _loadedProgramName =
              _link.basename(path);

          if (!_colorRunMode) {
            _programPoints =
                List<TuftPoint>.from(
              _localPath,
            );
          }
        }();

        break;

      case 'cycle_start':
        if (status.mode ==
            MachineMode.mdi) {
          _localMdi(
            status,
            _mdiLine,
          );

          return;
        }

        final hasProgram =
            _programPoints.length >= 2;

        final hasLocalPath =
            _localPath.length >= 2;

        if (status.mode !=
                MachineMode.auto ||
            (!status.pathLoaded &&
                !hasProgram) ||
            (!hasLocalPath &&
                !hasProgram)) {
          if (hasProgram) {
            _localPath =
                List<TuftPoint>.from(
              _programPoints,
            );
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

        if (_localPath.length < 2 &&
            hasProgram) {
          _localPath =
              List<TuftPoint>.from(
            _programPoints,
          );
        }

        if (status.state ==
            MachineState.hold) {
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

        _colorRunExecuting =
            _colorRunMode ||
                _colorRunExecuting;

        updateStatus(
          _copy(
            status,
            state: MachineState.running,
            x: _localPath[0].x,
            y: _localPath[0].y,
            pathLoaded: true,
            pathCount:
                _localPath.length,
            pathIndex: 0,
            progPct: 0,
            alarm: '',
            needle: true,
          ),
        );

        break;

      case 'feed_hold':
        if (status.state ==
            MachineState.running) {
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
        _colorRunExecuting = false;

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
        _colorRunExecuting = false;

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
        _colorRunExecuting = false;

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
            jogStep:
                double.tryParse(
                      '${command['step']}',
                    ) ??
                    1.0,
          ),
        );

        break;

      case 'mdi':
        _localMdi(
          status,
          command['line'] as String? ??
              '',
        );

        break;
    }
  }

  void _localMdi(
    MachineStatus status,
    String line,
  ) {
    if (status.mode !=
        MachineMode.mdi) {
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

    final xMatch = RegExp(
      r'[Xx]\s*([-0-9.]+)',
    ).firstMatch(line);

    final yMatch = RegExp(
      r'[Yy]\s*([-0-9.]+)',
    ).firstMatch(line);

    if (xMatch != null) {
      x = double.parse(
        xMatch.group(1)!,
      );
    }

    if (yMatch != null) {
      y = double.parse(
        yMatch.group(1)!,
      );
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
    if (_localIndex >=
        _localPath.length - 1) {
      _haveSeg = false;

      _status = _copy(
        _status,
        state: MachineState.idle,
        progPct: 100,
        needle: false,
      );

      if (_colorRunMode &&
          _colorRunExecuting) {
        _handleColorRunCompletion();
      }

      _notify();

      return;
    }

    _fromX =
        _localPath[_localIndex].x;

    _fromY =
        _localPath[_localIndex].y;

    _toX =
        _localPath[_localIndex + 1].x;

    _toY =
        _localPath[_localIndex + 1].y;

    final dx = _toX - _fromX;
    final dy = _toY - _fromY;

    final distance = math.sqrt(
      dx * dx + dy * dy,
    );

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

  void _localTickOnce(
    double dt,
  ) {
    if (_status.state !=
            MachineState.running ||
        !_haveSeg) {
      return;
    }

    _segT += dt;

    var progress =
        _segDur <= 0
            ? 1.0
            : _segT / _segDur;

    if (progress > 1) {
      progress = 1;
    }

    final x =
        _fromX +
            (_toX - _fromX) *
                progress;

    final y =
        _fromY +
            (_toY - _fromY) *
                progress;

    final percentage =
        _localPath.length > 1
            ? 100.0 *
                (_localIndex +
                    progress) /
                (_localPath.length - 1)
            : 0.0;

    final isLastSegment =
        _localIndex >=
                _localPath.length - 2 &&
            progress >= 0.999;

    _status = _copy(
      _status,
      x: x,
      y: y,
      progPct:
          percentage.clamp(0, 100),
      pathIndex: _localIndex,
      needle: !isLastSegment,
    );

    _notify();

    if (progress >= 1) {
      _localIndex++;

      if (_localIndex >=
          _localPath.length - 1) {
        _haveSeg = false;

        _status = _copy(
          _status,
          x: _localPath.last.x,
          y: _localPath.last.y,
          progPct: 100,
          pathIndex:
              _localPath.length - 1,
          state: MachineState.idle,
          needle: false,
        );

        if (_colorRunMode &&
            _colorRunExecuting) {
          _handleColorRunCompletion();
        }

        _notify();

        return;
      }

      _beginLocalSeg();
    }
  }

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

  void addPlcMacro(
    PlcMacro macro,
  ) {
    _plcMacros.add(macro);
    _notify();
  }

  Future<void> runPlcMacro(
    PlcMacro macro,
  ) async {
    await setMode(
      MachineMode.mdi,
    );

    setMdiLine(macro.code);

    await runMdi();

    _message =
        'PLC macro: ${macro.name} → ${macro.code}';

    _notify();
  }

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

    sb.writeln(
      '; ============================================',
    );

    sb.writeln(
      '; ROVEX Advanced G-Code Generator',
    );

    sb.writeln(
      '; Program Name : $programName',
    );

    sb.writeln(
      '; Total Points : ${points.length}',
    );

    sb.writeln(
      '; Color Groups : ${colorGroups.length}',
    );

    sb.writeln(
      '; ============================================',
    );

    sb.writeln(
      'G21 ; Set units to millimeters',
    );

    sb.writeln(
      'G90 ; Set positioning to absolute mode',
    );

    sb.writeln(
      'G17 ; Select XY plane',
    );

    sb.writeln(
      'G0 Z${safeZ.toStringAsFixed(2)} '
      '; Retract head to safe height',
    );

    double? activeFeed;

    String activeMotionMode = '';

    TuftPoint? currentPoint;

    int currentColorOrder = -1;

    void updateMotionMode(
      String mode,
    ) {
      activeMotionMode = mode;
    }

    void applyFeed(
      double targetFeed,
    ) {
      if (activeFeed == targetFeed) {
        return;
      }

      sb.write(
        ' F${targetFeed.toInt()}',
      );

      activeFeed = targetFeed;
    }

    void moveToPoint(
      TuftPoint target, {
      required bool isCutting,
    }) {
      final motionMode =
          isCutting ? 'G1' : 'G0';

      final feed =
          isCutting
              ? cutFeed
              : travelFeed;

      if (activeMotionMode !=
          motionMode) {
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

      if (point.colorOrder !=
          currentColorOrder) {
        currentColorOrder =
            point.colorOrder ?? 0;

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

      if (currentPoint != null) {
        final dx =
            point.x - currentPoint!.x;

        final dy =
            point.y - currentPoint!.y;

        final distance = math.sqrt(
          dx * dx + dy * dy,
        );

        if (distance >
            jumpThreshold) {
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

      if (index + 2 <
          points.length) {
        final p1 = point;
        final p2 = points[index + 1];
        final p3 = points[index + 2];

        if (p2.colorOrder ==
                currentColorOrder &&
            p3.colorOrder ==
                currentColorOrder) {
          final arc = _fitArc(
            p1,
            p2,
            p3,
          );

          if (arc != null &&
              arc.radius > 1.0 &&
              arc.radius < 500.0) {
            final command =
                arc.isClockwise
                    ? 'G2'
                    : 'G3';

            if (activeMotionMode !=
                command) {
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

      moveToPoint(
        point,
        isCutting: true,
      );

      index++;
    }

    sb.writeln();

    sb.writeln(
      '; --- Program End Cleanup ---',
    );

    sb.writeln(
      'M9 ; Disengage tool',
    );

    sb.writeln(
      'G0 Z${safeZ.toStringAsFixed(2)} '
      '; Retract to safe Z',
    );

    sb.writeln(
      'G0 X0.00 Y0.00 ; Return to origin',
    );

    sb.writeln(
      'M30 ; End of program',
    );

    return sb.toString();
  }

  static ArcFittingResult? _fitArc(
    TuftPoint p1,
    TuftPoint p2,
    TuftPoint p3,
  ) {
    final denominator =
        2 *
            (p1.x *
                    (p2.y - p3.y) +
                p2.x *
                    (p3.y - p1.y) +
                p3.x *
                    (p1.y - p2.y));

    if (denominator.abs() <
        1e-4) {
      return null;
    }

    final centerX =
        ((p1.x * p1.x +
                    p1.y * p1.y) *
                (p2.y - p3.y) +
            (p2.x * p2.x +
                    p2.y * p2.y) *
                (p3.y - p1.y) +
            (p3.x * p3.x +
                    p3.y * p3.y) *
                (p1.y - p2.y)) /
            denominator;

    final centerY =
        ((p1.x * p1.x +
                    p1.y * p1.y) *
                (p3.x - p2.x) +
            (p2.x * p2.x +
                    p2.y * p2.y) *
                (p1.x - p3.x) +
            (p3.x * p3.x +
                    p3.y * p3.y) *
                (p2.x - p1.x)) /
            denominator;

    final radius = math.sqrt(
      math.pow(
            p1.x - centerX,
            2,
          ) +
          math.pow(
            p1.y - centerY,
            2,
          ),
    );

    final i = centerX - p1.x;
    final j = centerY - p1.y;

    final crossProduct =
        (p2.x - p1.x) *
                (p3.y - p1.y) -
            (p2.y - p1.y) *
                (p3.x - p1.x);

    final isClockwise =
        crossProduct < 0;

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

ExtractResult _dxfExtractIsolate(
  Map<String, dynamic> args,
) {
  final bytes =
      args['bytes'] as Uint8List;

  return parseDxfEntities(bytes);
}

ExtractResult _extractIsolate(
  Map<String, dynamic> args,
) {
  try {
    final bytes =
        args['bytes'] as Uint8List;

    final pitch =
        (args['pitch'] as num?)
                ?.toDouble() ??
            10.0;

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