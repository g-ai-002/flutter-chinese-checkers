/// 全局时间格式化工具。
library;

String pad2(int value) => value.toString().padLeft(2, '0');

/// `yyyyMMdd`，用于日志文件名。
String formatDateKey(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}${pad2(date.month)}${pad2(date.day)}';

/// `yyyy-MM-dd HH:mm`，棋谱与棋谱列表共用。
String formatDateTime(DateTime time) =>
    '${time.year.toString().padLeft(4, '0')}-${pad2(time.month)}-${pad2(time.day)} '
    '${pad2(time.hour)}:${pad2(time.minute)}';

/// `HH:mm:ss.SSS`，日志行首时间戳。
String formatLogTimestamp(DateTime time) =>
    '${pad2(time.hour)}:${pad2(time.minute)}:${pad2(time.second)}.'
    '${time.millisecond.toString().padLeft(3, '0')}';

/// 棋钟剩余时间：`mm:ss`，满一小时显示 `h:mm:ss`。
String formatClock(int milliseconds) {
  final total = (milliseconds / 1000).ceil();
  final hours = total ~/ 3600;
  final minutes = (total % 3600) ~/ 60;
  final seconds = total % 60;
  return hours > 0
      ? '$hours:${pad2(minutes)}:${pad2(seconds)}'
      : '${pad2(minutes)}:${pad2(seconds)}';
}

String formatLogLine(DateTime time, String level, String message) =>
    '[${formatLogTimestamp(time)}][$level] $message';
