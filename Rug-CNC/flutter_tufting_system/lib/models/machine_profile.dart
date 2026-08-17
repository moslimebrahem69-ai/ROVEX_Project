/// A saved machine connection profile: one Arduino/ESP-based tufting
/// machine reachable on the local WiFi network.
///
/// The app can keep several of these and switch between them, so one
/// phone + one app can drive several machines (one connection at a
/// time) without reinstalling or reconfiguring anything.
class MachineProfile {
  final String id;
  final String name;
  final String host; // LAN IP of the machine's WiFi controller, e.g. 192.168.1.42
  final int port; // TCP port the machine's controller listens on

  const MachineProfile({
    required this.id,
    required this.name,
    required this.host,
    this.port = 9100,
  });

  factory MachineProfile.fromJson(Map<String, dynamic> json) => MachineProfile(
        id: json['id'] as String,
        name: json['name'] as String,
        host: json['host'] as String,
        port: (json['port'] as num?)?.toInt() ?? 9100,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'host': host,
        'port': port,
      };

  MachineProfile copyWith({String? name, String? host, int? port}) =>
      MachineProfile(
        id: id,
        name: name ?? this.name,
        host: host ?? this.host,
        port: port ?? this.port,
      );
}
