/// 全局时间格式化工具。
library;

String pad2(int value) => value.toString().padLeft(2, '0');

/// `yyyyMMdd`，用于日志文件名。
String formatDateKey(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}${pad2(date.month)}${pad2(date.day)}';

/// `HH:mm:ss.SSS`，日志行首时间戳。
String formatLogTimestamp(DateTime time) =>
    '${pad2(time.hour)}:${pad2(time.minute)}:${pad2(time.second)}.'
    '${time.millisecond.toString().padLeft(3, '0')}';

String formatLogLine(DateTime time, String level, String message) =>
    '[${formatLogTimestamp(time)}][$level] $message';

/// `mm:ss`，对局用时与统计平均值共用。
String formatDuration(Duration duration) {
  final minutes = duration.inMinutes;
  final seconds = duration.inSeconds % 60;
  return '${pad2(minutes)}:${pad2(seconds)}';
}

/// `MM-dd HH:mm`，统计页的紧凑时间。
String formatShortDateTime(DateTime time) =>
    '${pad2(time.month)}-${pad2(time.day)} ${pad2(time.hour)}:${pad2(time.minute)}';

/// 棋谱导出文件名：`tiaoqi_20261107_011200.txt`。
String replayFileName(DateTime savedAt) =>
    'tiaoqi_${formatDateKey(savedAt)}_'
    '${pad2(savedAt.hour)}${pad2(savedAt.minute)}${pad2(savedAt.second)}.txt';
