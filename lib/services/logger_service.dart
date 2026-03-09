import 'package:flutter/foundation.dart';

enum LogLevel { debug, info, warning, error }

class LogEntry {
  final DateTime timestamp;
  final LogLevel level;
  final String message;
  final String? source;

  LogEntry({
    required this.timestamp,
    required this.level,
    required this.message,
    this.source,
  });

  @override
  String toString() {
    final time = timestamp.toString().substring(0, 19);
    final levelStr = level.name.toUpperCase().padRight(7);
    final sourceStr = source != null ? '[$source] ' : '';
    return '[$time] $levelStr$sourceStr$message';
  }
}

class LoggerService extends ChangeNotifier {
  final List<LogEntry> _logs = [];
  final int _maxLogs = 500;

  List<LogEntry> get logs => List.unmodifiable(_logs);

  void _addLog(LogLevel level, String message, {String? source}) {
    final entry = LogEntry(
      timestamp: DateTime.now(),
      level: level,
      message: message,
      source: source,
    );
    _logs.add(entry);
    if (_logs.length > _maxLogs) {
      _logs.removeAt(0);
    }
    notifyListeners();
  }

  void debug(String message, {String? source}) {
    _addLog(LogLevel.debug, message, source: source);
    if (kDebugMode) {
      print('[DEBUG] $message');
    }
  }

  void info(String message, {String? source}) {
    _addLog(LogLevel.info, message, source: source);
    if (kDebugMode) {
      print('[INFO] $message');
    }
  }

  void warning(String message, {String? source}) {
    _addLog(LogLevel.warning, message, source: source);
    if (kDebugMode) {
      print('[WARNING] $message');
    }
  }

  void error(String message, {String? source}) {
    _addLog(LogLevel.error, message, source: source);
    if (kDebugMode) {
      print('[ERROR] $message');
    }
  }

  void clear() {
    _logs.clear();
    notifyListeners();
  }

  String getLogsAsString() {
    if (_logs.isEmpty) {
      return 'No logs available';
    }
    return _logs.map((e) => e.toString()).join('\n');
  }
}
