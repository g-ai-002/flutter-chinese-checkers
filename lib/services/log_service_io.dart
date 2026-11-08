import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../utils/formatters.dart';

/// 日志服务：内存环形缓冲 + 按天文件落盘。
///
/// 初始化前的日志先进入早期缓冲，初始化后补写；日志目录不可用时降级为内存模式。
class LogService {
  static LogService? _instance;
  static final List<String> _earlyBuffer = [];
  final List<String> _buffer = [];
  Directory? _logDir;
  File? _logFile;
  DateTime? _logDate;
  bool _initialized = false;
  DateTime Function() _now = DateTime.now;

  /// 待落盘的日志：攒一小批再异步写入，避免每条日志都同步卡住 UI 线程。
  final StringBuffer _pending = StringBuffer();
  Timer? _flushTimer;
  Future<void> _writes = Future<void>.value();

  /// 每写若干行才检查一次文件大小，避免每条日志都做同步 stat。
  int _rotateCheckCountdown = 128;

  static const Duration _flushDelay = Duration(milliseconds: 250);
  static const int _maxPendingChars = 32 * 1024;
  static const int _maxBufferLines = 2000;
  static const int _maxEarlyLines = 500;
  static const int _maxFileSize = 5 * 1024 * 1024;
  static const int _maxRetentionDays = 7;

  LogService._();

  static Future<void> init({
    Future<Directory> Function()? logRoot,
    DateTime Function()? clock,
  }) async {
    _instance ??= LogService._();
    await _instance!._init(logRoot, clock);
  }

  /// 仅用于测试。
  static void reset() {
    _instance?._flushSync();
    _instance = null;
    _earlyBuffer.clear();
  }

  /// 把尚未落盘的日志立即写入文件，应用暂停或退出前调用。
  static Future<void> flush() async {
    final inst = _instance;
    if (inst == null) return;
    inst._flushAsync();
    await inst._writes;
  }

  Future<void> _init(Future<Directory> Function()? logRoot, DateTime Function()? clock) async {
    if (_initialized) return;
    if (clock != null) _now = clock;
    if (logRoot != null) {
      try {
        _logDir = await logRoot();
      } catch (e) {
        debugPrint('[LogService] 日志目录不可用，降级为内存日志: $e');
      }
    }
    _logFile = _openTodayFile();
    _initialized = true;
    if (_logFile != null) {
      _logDate = _now();
      _cleanOldLogs();
    }
    if (_earlyBuffer.isNotEmpty) {
      for (final line in _earlyBuffer) {
        _buffer.add(line);
        _appendLine(line);
      }
      _earlyBuffer.clear();
    }
    _write('INFO', '==== LogService 已初始化, 日志文件: ${_logFile?.path ?? '内存模式'} ====');
    // 启动日志立即落盘，后续日志再走批量异步写入。
    _flushSync();
  }

  static String get logFilePath => _instance?._logFile?.path ?? '';

  static void info(String message) => _log('INFO', message);

  static void warning(String message) => _log('WARN', message);

  static void error(String message, [Object? error, StackTrace? stack]) {
    _log('ERROR', error != null ? '$message | $error' : message);
    if (stack != null) _log('ERROR', stack.toString());
  }

  static void _log(String level, String message) {
    final inst = _instance;
    if (inst == null || !inst._initialized) {
      final line = formatLogLine(inst?._now() ?? DateTime.now(), level, message);
      _earlyBuffer.add(line);
      if (_earlyBuffer.length > _maxEarlyLines) _earlyBuffer.removeAt(0);
      return;
    }
    inst._write(level, message);
  }

  void _write(String level, String message) {
    final line = formatLogLine(_now(), level, message);
    _buffer.add(line);
    if (_buffer.length > _maxBufferLines) _buffer.removeAt(0);
    _appendLine(line, immediate: level == 'ERROR');
  }

  /// 日志先进入待写缓冲：普通日志每 250 毫秒批量异步落盘，
  /// 错误日志立即同步写入，保证崩溃前最后一条错误一定在文件里。
  void _appendLine(String line, {bool immediate = false}) {
    _pending.write('$line\n');
    _refreshLogFile();
    if (immediate) {
      _flushSync();
      return;
    }
    if (_pending.length >= _maxPendingChars) {
      _flushAsync();
      return;
    }
    _flushTimer ??= Timer(_flushDelay, _flushAsync);
  }

  void _flushAsync() {
    _flushTimer?.cancel();
    _flushTimer = null;
    if (_pending.isEmpty) return;
    final text = _pending.toString();
    _pending.clear();
    final file = _logFile;
    if (file == null) return;
    _writes = _writes.then((_) async {
      try {
        await file.writeAsString(text, mode: FileMode.append);
      } catch (_) {}
    });
  }

  void _flushSync() {
    _flushTimer?.cancel();
    _flushTimer = null;
    if (_pending.isEmpty) return;
    final text = _pending.toString();
    _pending.clear();
    try {
      _logFile?.writeAsStringSync(text, mode: FileMode.append);
    } catch (_) {}
  }

  void _refreshLogFile() {
    final dir = _logDir;
    if (dir == null) return;
    final now = _now();
    final current = _logDate;
    final needSwitch =
        current == null ||
        current.year != now.year ||
        current.month != now.month ||
        current.day != now.day;
    if (needSwitch) {
      // 切到新的一天之前，把待写内容留给旧文件。
      _flushSync();
      final file = _openTodayFile();
      if (file != null) {
        _logFile = file;
        _logDate = now;
        _cleanOldLogs();
      }
      return;
    }
    _rotateIfNeeded();
  }

  File? _openTodayFile() {
    final dir = _logDir;
    if (dir == null) return null;
    try {
      final now = _now();
      final file = File('${dir.path}${Platform.pathSeparator}app_${formatDateKey(now)}.log');
      if (!file.existsSync()) file.createSync(recursive: true);
      return file;
    } catch (_) {
      return null;
    }
  }

  /// 每写若干行才检查一次文件大小，避免每条日志都做同步 stat。
  void _rotateIfNeeded() {
    final file = _logFile;
    if (file == null) return;
    if (--_rotateCheckCountdown > 0) return;
    _rotateCheckCountdown = 128;
    try {
      if (!file.existsSync() || file.lengthSync() < _maxFileSize) return;
      // 备份旧文件之前先把待写内容落盘，保证日志顺序。
      _flushSync();
      final originalPath = file.path;
      final parent = file.parent;
      final baseName = file.uri.pathSegments.last.replaceAll('.log', '');
      var index = 1;
      File backup;
      do {
        backup = File('${parent.path}${Platform.pathSeparator}${baseName}_$index.log');
        index++;
      } while (backup.existsSync());
      file.renameSync(backup.path);
      final fresh = File(originalPath);
      if (!fresh.existsSync()) fresh.createSync();
      _logFile = fresh;
    } catch (_) {}
  }

  void _cleanOldLogs() {
    final dir = _logDir;
    if (dir == null) return;
    try {
      final cutoff = _now().subtract(const Duration(days: _maxRetentionDays));
      for (final entity in dir.listSync()) {
        if (entity is! File) continue;
        final name = entity.uri.pathSegments.last;
        if (!name.startsWith('app_') || !name.endsWith('.log')) continue;
        try {
          if (entity.statSync().modified.isBefore(cutoff)) entity.deleteSync();
        } catch (_) {}
      }
    } catch (_) {}
  }

  /// 最近日志（内存缓冲，含尚未落盘的早期日志）。
  static List<String> getRecentLogs([int lines = 200]) {
    final inst = _instance;
    final all = <String>[..._earlyBuffer, if (inst != null) ...inst._buffer];
    if (all.length <= lines) return all;
    return all.sublist(all.length - lines);
  }
}
