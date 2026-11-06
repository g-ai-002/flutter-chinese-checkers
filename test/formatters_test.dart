import 'package:chinese_checkers/utils/formatters.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('棋谱导出文件名带上保存时间', () {
    expect(
      replayFileName(DateTime(2026, 11, 7, 1, 2, 3)),
      'tiaoqi_20261107_010203.txt',
    );
    expect(
      replayFileName(DateTime(2026, 1, 2, 3, 4, 5)),
      'tiaoqi_20260102_030405.txt',
    );
  });

  test('对局用时按分秒补齐两位', () {
    expect(formatDuration(const Duration(minutes: 3, seconds: 20)), '03:20');
    expect(formatDuration(const Duration(seconds: 5)), '00:05');
    expect(formatDuration(const Duration(minutes: 120)), '120:00');
  });
}
