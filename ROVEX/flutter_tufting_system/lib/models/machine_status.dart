enum MachineMode { jog, auto, mdi, ref }

enum MachineState { idle, running, hold, alarm, homing }

enum HmiArea {
  machine,
  program,
  design,
  needle3d,
  errors,
  plc,
  diagnosis,
  setup,
}

class MachineStatus {
  final MachineMode mode;
  final MachineState state;
  final double x;
  final double y;
  final double z;
  final double wcsX;
  final double wcsY;
  final double wcsZ;
  final int feedOverride;
  final bool connected;
  final bool referenced;
  final bool needle;
  final String alarm;
  final double progPct;
  final bool pathLoaded;
  final int pathCount;
  final int pathIndex;
  final String backend;
  final String port;
  final int baud;
  final double jogStep;

  const MachineStatus({
    this.mode = MachineMode.jog,
    this.state = MachineState.idle,
    this.x = 0,
    this.y = 0,
    this.z = 5,
    this.wcsX = 0,
    this.wcsY = 0,
    this.wcsZ = 0,
    this.feedOverride = 100,
    this.connected = false,
    this.referenced = false,
    this.needle = false,
    this.alarm = '',
    this.progPct = 0,
    this.pathLoaded = false,
    this.pathCount = 0,
    this.pathIndex = 0,
    this.backend = 'sim',
    this.port = '',
    this.baud = 115200,
    this.jogStep = 1.0,
  });

  static MachineMode modeFrom(String? value) {
    switch (value) {
      case 'AUTO':
        return MachineMode.auto;
      case 'MDI':
        return MachineMode.mdi;
      case 'REF':
        return MachineMode.ref;
      default:
        return MachineMode.jog;
    }
  }

  static MachineState stateFrom(String? value) {
    switch (value) {
      case 'RUNNING':
        return MachineState.running;
      case 'HOLD':
        return MachineState.hold;
      case 'ALARM':
        return MachineState.alarm;
      case 'HOMING':
        return MachineState.homing;
      default:
        return MachineState.idle;
    }
  }

  factory MachineStatus.fromJson(Map<String, dynamic> json) {
    return MachineStatus(
      mode: modeFrom(json['mode'] as String?),
      state: stateFrom(json['state'] as String?),
      x: (json['x'] as num?)?.toDouble() ?? 0,
      y: (json['y'] as num?)?.toDouble() ?? 0,
      z: (json['z'] as num?)?.toDouble() ?? 5,
      wcsX: (json['wcs_x'] as num?)?.toDouble() ?? 0,
      wcsY: (json['wcs_y'] as num?)?.toDouble() ?? 0,
      wcsZ: (json['wcs_z'] as num?)?.toDouble() ?? 0,
      feedOverride: (json['feed_override'] as num?)?.toInt() ?? 100,
      connected: json['connected'] == true,
      referenced: json['referenced'] == true,
      needle: json['needle'] == true,
      alarm: json['alarm'] as String? ?? '',
      progPct: (json['prog_pct'] as num?)?.toDouble() ?? 0,
      pathLoaded: json['path_loaded'] == true,
      pathCount: (json['path_count'] as num?)?.toInt() ?? 0,
      pathIndex: (json['path_index'] as num?)?.toInt() ?? 0,
      backend: json['backend'] as String? ?? 'sim',
      port: json['port'] as String? ?? '',
      baud: (json['baud'] as num?)?.toInt() ?? 115200,
      jogStep: (json['jog_step'] as num?)?.toDouble() ?? 1.0,
    );
  }

  String get modeLabel {
    switch (mode) {
      case MachineMode.jog:
        return 'JOG';
      case MachineMode.auto:
        return 'AUTO';
      case MachineMode.mdi:
        return 'MDI';
      case MachineMode.ref:
        return 'REF';
    }
  }

  String get stateLabel {
    switch (state) {
      case MachineState.idle:
        return 'IDLE';
      case MachineState.running:
        return 'RUNNING';
      case MachineState.hold:
        return 'HOLD';
      case MachineState.alarm:
        return 'ALARM';
      case MachineState.homing:
        return 'HOMING';
    }
  }
}