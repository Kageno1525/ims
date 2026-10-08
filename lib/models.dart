enum LogLevel { info, ok, error, wait }

class LogEntry {
  final String msg;
  final DateTime time;
  final LogLevel level;
  LogEntry(this.msg, this.time, this.level);
}