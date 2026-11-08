import 'package:chinese_checkers/utils/board_orientation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('棋盘尺寸按 14:16 网格在窗口内取最大', () {
    final portrait = BoardOrientation.boardSize(const Size(360, 780));
    expect(portrait.width, closeTo(360, 0.01));
    expect(portrait.height, closeTo(360 * 16 / 14, 0.01));

    final wide = BoardOrientation.boardSize(const Size(1200, 900));
    expect(wide.height, closeTo(900, 0.01));
    expect(wide.width, closeTo(900 * 14 / 16, 0.01));
  });

  test('竖高网格在手机上保持竖屏，换成宽网格才转横屏', () {
    const phone = Size(360, 780);
    expect(BoardOrientation.prefersLandscape(phone), isFalse);
    expect(
      BoardOrientation.prefersLandscape(phone, aspect: 16 / 10),
      isTrue,
      reason: '宽网格旋转后棋盘明显更大',
    );
  });

  test('已经是横屏或平板宽屏时不再旋转', () {
    expect(BoardOrientation.prefersLandscape(const Size(780, 360)), isFalse);
    expect(BoardOrientation.prefersLandscape(const Size(800, 1280)), isFalse);
    expect(BoardOrientation.prefersLandscape(const Size(800, 1280), aspect: 16 / 10), isFalse);
  });

  testWidgets('窄屏锁定竖屏且重复调用不重复请求平台', (tester) async {
    final calls = <MethodCall>[];
    final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      calls.add(call);
      return null;
    });
    addTearDown(() {
      messenger.setMockMethodCallHandler(SystemChannels.platform, null);
      BoardOrientation.reset();
    });

    BoardOrientation.reset();
    BoardOrientation.apply(const Size(360, 780));
    await tester.pump();

    final orientations = calls
        .where((call) => call.method == 'SystemChrome.setPreferredOrientations')
        .toList();
    expect(orientations, hasLength(1));
    expect(
      orientations.single.arguments,
      containsAll(<String>['DeviceOrientation.portraitUp', 'DeviceOrientation.portraitDown']),
    );

    final settled = calls.length;
    BoardOrientation.apply(const Size(360, 780));
    await tester.pump();
    expect(calls, hasLength(settled), reason: '同一尺寸不重复下发方向');

    // 平板等宽屏恢复四向自由旋转。
    BoardOrientation.apply(const Size(1024, 768));
    await tester.pump();
    final last = calls.lastWhere((call) => call.method == 'SystemChrome.setPreferredOrientations');
    expect((last.arguments as List<Object?>), hasLength(4));
  });
}
