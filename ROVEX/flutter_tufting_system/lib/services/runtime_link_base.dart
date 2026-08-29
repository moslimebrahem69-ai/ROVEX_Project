import 'dart:async';

typedef LineHandler = void Function(String line);

abstract class RuntimeLink {
  bool get isConnected;
  Future<bool> connect(
      String host, int port, LineHandler onLine, void Function() onGone);
  Future<void> send(String line);
  void close();
  Future<String> writeProgramCsv(String name, List<String> rows);
  Future<List<String>?> readCsvLines(String path);
  String basename(String path);

  /// Small persisted key/value text blobs (used for the saved machine
  /// list). Not meant for large data — see writeProgramCsv for that.
  Future<void> saveText(String key, String content);
  Future<String?> loadText(String key);
}
