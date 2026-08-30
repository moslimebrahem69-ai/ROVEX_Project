import 'runtime_link_base.dart';

class StubRuntimeLink implements RuntimeLink {
  // In-memory only: this browser build has no writable filesystem here.
  // Fine for a same-session preview; native (mobile/desktop) builds use
  // IoRuntimeLink, which persists to real files.

  static final Map<String, String> _memory = {};

  @override
  bool get isConnected => false;

  @override
  Future<bool> connect(
    String host,
    int port,
    LineHandler onLine,
    void Function() onGone,
  ) async {
    return false;
  }

  @override
  Future<void> send(String line) async {}

  @override
  void close() {}

  @override
  Future<String> writeProgramCsv(
    String name,
    List<String> rows,
  ) async {
    return 'programs/$name.csv';
  }

  @override
  Future<List<String>?> readCsvLines(
    String path,
  ) async {
    return null;
  }

  @override
  String basename(String path) {
    final parts = path.split(RegExp(r'[\\/]'));
    return parts.isEmpty ? path : parts.last;
  }

  @override
  Future<void> saveText(
    String key,
    String content,
  ) async {
    _memory[key] = content;
  }

  @override
  Future<String?> loadText(
    String key,
  ) async {
    return _memory[key];
  }
}

RuntimeLink createRuntimeLinkImpl() => StubRuntimeLink();