import 'dart:math' as math;

import 'package:chinese_checkers/game/board_geometry.dart';
import 'package:chinese_checkers/game/challenge_levels.dart';
import 'package:chinese_checkers/models/game_models.dart';
import 'package:chinese_checkers/pages/game_page.dart';
import 'package:chinese_checkers/providers/settings_provider.dart';
import 'package:chinese_checkers/services/storage_service.dart';
import 'package:chinese_checkers/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 对局页布局矩阵：覆盖手机、折叠屏、平板、桌面与极端横竖屏。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final geometry = BoardGeometry.star();
  const hudKeys = <String>[
    'hud-title',
    'hud-status',
    'hud-tools',
    'hud-progress',
    'hud-actions',
  ];

  Future<void> pumpGame(
    WidgetTester tester,
    Size size, {
    double textScale = 1,
    int players = 2,
    bool challenge = false,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    tester.platformDispatcher.textScaleFactorTestValue = textScale;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    SharedPreferences.setMockInitialValues({});
    StorageService.resetForTests();
    final settings = SettingsProvider(await StorageService.instance);
    final setup = challenge
        ? GameSetup.forChallenge(kChallengeLevels.first)
        : GameSetup(
            mode: PlayMode.local,
            playerCount: players == 6 ? PlayerCount.six : PlayerCount.two,
          );
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: settings,
        child: MaterialApp(
          theme: buildLightTheme(),
          home: GamePage(setup: setup),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 32));
  }

  Map<String, Rect> hudRects(WidgetTester tester) {
    final result = <String, Rect>{};
    for (final key in hudKeys) {
      final finder = find.byKey(ValueKey(key));
      if (finder.evaluate().isNotEmpty) result[key] = tester.getRect(finder);
    }
    return result;
  }

  /// 浮层矩形不能压到任何孔位（含棋子半径与 2px 间隙）。
  void expectHudClearOfHoles(WidgetTester tester, Size size) {
    final board = tester.getRect(find.byKey(const ValueKey('board')));
    final scale = board.width / 14;
    final pad = scale * 0.44 + 2;
    for (final entry in hudRects(tester).entries) {
      for (final hole in geometry.holes) {
        final point = board.center + Offset(hole.x * scale, hole.y * scale);
        expect(
          entry.value.inflate(pad).contains(point),
          isFalse,
          reason: '${entry.key} 盖住了孔位 ${hole.index}（$size）',
        );
      }
      expect(entry.value.left, greaterThan(-0.5), reason: '${entry.key} 越界');
      expect(entry.value.top, greaterThan(-0.5), reason: '${entry.key} 越界');
      expect(
        entry.value.right,
        lessThan(size.width + 0.5),
        reason: '${entry.key} 越界',
      );
      expect(
        entry.value.bottom,
        lessThan(size.height + 0.5),
        reason: '${entry.key} 越界',
      );
    }
  }

  void expectHudApart(WidgetTester tester) {
    final rects = hudRects(tester).entries.toList();
    for (var i = 0; i < rects.length; i++) {
      for (var j = i + 1; j < rects.length; j++) {
        expect(
          rects[i].value.overlaps(rects[j].value),
          isFalse,
          reason: '${rects[i].key} 与 ${rects[j].key} 重叠',
        );
      }
    }
  }

  void expectBoardFit(WidgetTester tester, Size size) {
    final board = tester.getRect(find.byKey(const ValueKey('board')));
    expect(board.width / board.height, closeTo(14 / 16, 1e-3));
    final full = math.min(size.width, size.height * 14 / 16);
    expect(board.width, greaterThan(full * 0.94));
    expect(board.left, greaterThanOrEqualTo(-0.5));
    expect(board.right, lessThanOrEqualTo(size.width + 0.5));
  }

  void audit(WidgetTester tester, Size size) {
    expectHudClearOfHoles(tester, size);
    expectHudApart(tester);
    expectBoardFit(tester, size);
    expect(tester.takeException(), isNull);
  }

  const phones = <String, Size>{
    '320x568': Size(320, 568),
    '360x640': Size(360, 640),
    '360x780': Size(360, 780),
    '412x915': Size(412, 915),
    '390x844': Size(390, 844),
  };
  const wideScreens = <String, Size>{
    '640x360 横屏手机': Size(640, 360),
    '820x400 折叠屏横屏': Size(820, 400),
    '768x1024 平板竖屏': Size(768, 1024),
    '1024x768 平板横屏': Size(1024, 768),
    '1280x800 笔记本': Size(1280, 800),
    '1920x1080 桌面': Size(1920, 1080),
    '2560x1440 大屏': Size(2560, 1440),
  };

  for (final entry in {...phones, ...wideScreens}.entries) {
    testWidgets('${entry.key}：浮层不压棋子也不互相重叠', (tester) async {
      final six = entry.key == '390x844';
      await pumpGame(tester, entry.value, players: six ? 6 : 2);
      audit(tester, entry.value);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }

  for (final scale in [1.3, 1.6]) {
    for (final entry in {
      '320x568': const Size(320, 568),
      '360x640': const Size(360, 640),
      '640x360': const Size(640, 360),
      '1024x768': const Size(1024, 768),
    }.entries) {
      testWidgets('${entry.key} 字号 ${scale}x 时布局稳定', (tester) async {
        await pumpGame(tester, entry.value, textScale: scale);
        audit(tester, entry.value);
        await tester.pumpWidget(const SizedBox.shrink());
      });
    }
  }

  testWidgets('竖屏手机把信息放进上下信息带，进度面板保留', (tester) async {
    const size = Size(320, 568);
    await pumpGame(tester, size);

    final board = tester.getRect(find.byKey(const ValueKey('board')));
    final status = tester.getRect(find.byKey(const ValueKey('hud-status')));
    expect(status.bottom, lessThan(board.top));
    expect(find.byKey(const ValueKey('hud-progress')), findsOneWidget);
    expect(find.text('0/10'), findsNWidgets(2));

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('窄屏操作坞收成图标，与进度面板并排', (tester) async {
    const size = Size(360, 780);
    await pumpGame(tester, size);

    expect(find.text('提示'), findsNothing);
    expect(find.byTooltip('提示'), findsOneWidget);
    final progress = tester.getRect(find.byKey(const ValueKey('hud-progress')));
    final actions = tester.getRect(find.byKey(const ValueKey('hud-actions')));
    expect(progress.right, lessThan(actions.left));

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('横屏手机把信息贴到棋盘两侧', (tester) async {
    const size = Size(640, 360);
    await pumpGame(tester, size);

    final board = tester.getRect(find.byKey(const ValueKey('board')));
    final status = tester.getRect(find.byKey(const ValueKey('hud-status')));
    final progress = tester.getRect(find.byKey(const ValueKey('hud-progress')));
    final actions = tester.getRect(find.byKey(const ValueKey('hud-actions')));
    expect(status.right, lessThanOrEqualTo(board.left));
    expect(progress.right, lessThanOrEqualTo(board.left));
    // 操作坞在棋盘右下方的空白角落，孔位校验由 audit 负责。
    expect(actions.left, greaterThan(board.center.dx));

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('宽屏浮层贴着棋盘，不再留在窗口角落', (tester) async {
    const size = Size(1280, 800);
    await pumpGame(tester, size);

    final board = tester.getRect(find.byKey(const ValueKey('board')));
    final status = tester.getRect(find.byKey(const ValueKey('hud-status')));
    final progress = tester.getRect(find.byKey(const ValueKey('hud-progress')));
    final actions = tester.getRect(find.byKey(const ValueKey('hud-actions')));
    expect(status.left, greaterThan(40));
    expect(status.right, lessThanOrEqualTo(board.left));
    expect(progress.left, status.left);
    expect(actions.left, greaterThanOrEqualTo(board.right));

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('极矮窗口保留整块棋盘，信息浮层自动收窄', (tester) async {
    const size = Size(420, 640);
    await pumpGame(tester, size, players: 6);

    final board = tester.getRect(find.byKey(const ValueKey('board')));
    expect(board.width, closeTo(420, 1));
    expect(find.byKey(const ValueKey('hud-progress')), findsOneWidget);
    audit(tester, size);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('残局页在竖屏与横屏都不遮挡棋盘', (tester) async {
    for (final size in [const Size(390, 844), const Size(640, 360)]) {
      await pumpGame(tester, size, challenge: true);
      expect(find.text('关卡目标'), findsOneWidget);
      audit(tester, size);
      await tester.pumpWidget(const SizedBox.shrink());
    }
  });
}
