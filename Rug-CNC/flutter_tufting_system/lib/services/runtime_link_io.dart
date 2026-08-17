import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'runtime_link_base.dart';

class IoRuntimeLink implements RuntimeLink {
  Socket? _socket;
  StreamSubscription<String>? _sub;

  @override
  bool get isConnected => _socket != null;

  @override
  Future<bool> connect(
      String host, int port, LineHandler onLine, void Function() onGone) async {
    try {
      final s = await Socket.connect(host, port,
          timeout: const Duration(milliseconds: 600));
      _socket = s;
      _sub = s
          .cast<List<int>>()
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen(onLine, onDone: onGone, onError: (_) => onGone());
      return true;
    } catch (_) {
      _socket = null;
      return false;
    }
  }

  @override
  Future<void> send(String line) async {
    if (_socket == null) return;
    _socket!.write('$line\n');
    await _socket!.flush();
  }

  @override
  void close() {
    _sub?.cancel();
    _sub = null;
    _socket?.destroy();
    _socket = null;
  }

  @override
  Future<String> writeProgramCsv(String name, List<String> rows) async {
    final dir = Directory('programs');
    if (!dir.existsSync()) dir.createSync(recursive: true);
    final safe = name.replaceAll(RegExp(r'[^A-Za-z0-9_\-]'), '_');
    final filePath = 'programs${Platform.pathSeparator}$safe.csv';
    final sink = File(filePath).openWrite();
    for (final r in rows) {
      sink.writeln(r);
    }
    await sink.flush();
    await sink.close();
    return File(filePath).absolute.path;
  }

  @override
  Future<List<String>?> readCsvLines(String path) async {
    try {
      return File(path).readAsLinesSync();
    } catch (_) {
      return null;
    }
  }

  @override
  String basename(String path) {
    return path.split(RegExp(r'[\\/]')).last;
  }

  @override
  Future<void> saveText(String key, String content) async {
    final dir = Directory('config');
    if (!dir.existsSync()) dir.createSync(recursive: true);
    final safe = key.replaceAll(RegExp(r'[^A-Za-z0-9_\-]'), '_');
    final file = File('config${Platform.pathSeparator}$safe.json');
    await file.writeAsString(content, flush: true);
  }

  @override
  Future<String?> loadText(String key) async {
    try {
      final safe = key.replaceAll(RegExp(r'[^A-Za-z0-9_\-]'), '_');
      final file = File('config${Platform.pathSeparator}$safe.json');
      if (!file.existsSync()) return null;
      return await file.readAsString();
    } catch (_) {
      return null;
    }
  }
}

RuntimeLink createRuntimeLinkImpl() => IoRuntimeLink();
