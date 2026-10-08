enum LogLevel { info, ok, error, wait }

class LogEntry {
  final String msg;
  final DateTime time;
  final LogLevel level;
  LogEntry(this.msg, this.time, this.level);
}

class CsvFile {
  final String name;
  final String path;
  final int count;
  CsvFile({required this.name, required this.path, required this.count});
}