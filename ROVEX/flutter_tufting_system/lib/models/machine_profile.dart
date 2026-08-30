class MachineProfile {
  final String id;
  final String name;
  final String host;
  final int port;

  const MachineProfile({
    required this.id,
    required this.name,
    required this.host,
    this.port = 9100,
  });

  factory MachineProfile.fromJson(Map<String, dynamic> json) {
    return MachineProfile(
      id: json['id'] as String,
      name: json['name'] as String,
      host: json['host'] as String,
      port: (json['port'] as num?)?.toInt() ?? 9100,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'host': host,
      'port': port,
    };
  }

  MachineProfile copyWith({
    String? name,
    String? host,
    int? port,
  }) {
    return MachineProfile(
      id: id,
      name: name ?? this.name,
      host: host ?? this.host,
      port: port ?? this.port,
    );
  }
}