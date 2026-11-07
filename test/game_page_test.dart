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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<void> pumpGame(
    WidgetTester tester,
    GameSetup setup, {
    Size size = const Size(1200, 900),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    SharedPreferences.setMockInitialValues({});
    StorageService.resetForTests();
    final storage = await StorageService.instance;
    final settings = SettingsProvider(storage);
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

  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('宽屏对局页显示进度侧栏与操作按钮', (tester) async {
    await pumpGame(
      tester,
      const GameSetup(mode: PlayMode.local, playerCount: PlayerCount.two),
    );

    expect(find.text('轮到 玩家 1'), findsOneWidget);
    expect(find.text('对局进度'), findsOneWidget);
    expect(find.text('提示'), findsOneWidget);
    expect(find.text('悔棋'), findsOneWidget);
    expect(find.text('重开'), findsOneWidget);
    expect(find.textContaining('0/10'), findsNWidgets(2));

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('窄屏对局页堆叠显示状态与操作栏', (tester) async {
    await pumpGame(
      tester,
      const GameSetup(mode: PlayMode.local, playerCount: PlayerCount.three),
      size: const Size(400, 820),
    );

    expect(find.text('轮到 玩家 1'), findsOneWidget);
    expect(find.text('对局进度'), findsNothing);
    expect(find.text('提示'), findsOneWidget);
    expect(find.textContaining('0/10'), findsNWidgets(3));

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('重开按钮先弹出确认框', (tester) async {
    await pumpGame(
      tester,
      const GameSetup(mode: PlayMode.local, playerCount: PlayerCount.two),
    );

    await tester.tap(find.text('重开'));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('重新开始？'), findsOneWidget);
    expect(find.text('当前对局的走子记录会被清空。'), findsOneWidget);

    await tester.tap(find.text('取消'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('重新开始？'), findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('人机对战自动完成电脑回合并渲染旋转后的棋盘', (tester) async {
    await pumpGame(
      tester,
      const GameSetup(
        mode: PlayMode.vsAi,
        playerCount: PlayerCount.two,
        difficulty: Difficulty.easy,
      ),
      size: const Size(400, 820),
    );

    await tester.pump(const Duration(milliseconds: 800));
    expect(tester.takeException(), isNull);
    expect(find.text('轮到 你'), findsOneWidget);

    await tester.tap(find.text('提示'));
    await tester.pump(const Duration(milliseconds: 200));
    expect(tester.takeException(), isNull);
    await tester.pump(const Duration(seconds: 7));

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('对局页标题展示人数与模式', (tester) async {
    await pumpGame(
      tester,
      const GameSetup(mode: PlayMode.local, playerCount: PlayerCount.six),
    );
    expect(find.text('6 人 · 同屏对战'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('对局未结束时复盘入口不可用', (tester) async {
    await pumpGame(
      tester,
      const GameSetup(mode: PlayMode.local, playerCount: PlayerCount.two),
    );

    final button = tester.widget<IconButton>(
      find.widgetWithIcon(IconButton, Icons.history),
    );
    expect(button.onPressed, isNull);
    expect(find.byTooltip('复盘（终局后可查看）'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('宽屏棋盘铺满高度并突破旧的宽度上限', (tester) async {
    await pumpGame(
      tester,
      const GameSetup(mode: PlayMode.local, playerCount: PlayerCount.two),
    );

    final board = tester.getRect(find.byKey(const ValueKey('board')));
    // 旧版棋盘被限制在 680 宽，现在由可用高度决定。
    expect(board.width, greaterThan(700));
    expect(board.height, closeTo(900, 0.5));
    expect(board.center.dx, closeTo(600, 0.5));

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('窄屏棋盘贴边显示，信息浮层不占用棋盘高度', (tester) async {
    await pumpGame(
      tester,
      const GameSetup(mode: PlayMode.local, playerCount: PlayerCount.three),
      size: const Size(400, 820),
    );

    final board = tester.getRect(find.byKey(const ValueKey('board')));
    expect(board.width, closeTo(400, 0.5));
    expect(board.height, closeTo(400 * 16 / 14, 0.5));
    expect(board.center.dx, closeTo(200, 0.5));
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('提示与轮次变化不改变棋盘位置', (tester) async {
    await pumpGame(
      tester,
      const GameSetup(
        mode: PlayMode.vsAi,
        playerCount: PlayerCount.two,
        difficulty: Difficulty.easy,
      ),
    );

    final board = find.byKey(const ValueKey('board'));
    final before = tester.getRect(board);

    await tester.tap(find.text('提示'));
    await tester.pump(const Duration(milliseconds: 200));
    expect(tester.getRect(board), before);

    // 电脑接管回合并切换提示文字，棋盘仍保持原位。
    await tester.pump(const Duration(milliseconds: 900));
    expect(tester.getRect(board), before);
    expect(tester.takeException(), isNull);

    // 走完提示的 6 秒自动收起计时，避免留下 pending timer。
    await tester.pump(const Duration(seconds: 7));
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('玩法说明包含落点图例', (tester) async {
    await pumpGame(
      tester,
      const GameSetup(mode: PlayMode.local, playerCount: PlayerCount.two),
    );

    await tester.tap(find.byTooltip('玩法说明'));
    await tester.pumpAndSettle();
    expect(find.text('落点提示'), findsOneWidget);
    expect(find.textContaining('白色圆点是单步可落位置'), findsOneWidget);
    expect(find.textContaining('白色双环是连跳可落位置'), findsOneWidget);

    await tester.tap(find.text('知道了'));
    await tester.pumpAndSettle();
    expect(find.text('落点提示'), findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('残局关卡目标浮层展示提示与星级门槛', (tester) async {
    final level = kChallengeLevels.first;
    await pumpGame(tester, GameSetup.forChallenge(level));

    expect(find.text('剩 ${level.moveLimit} 步'), findsOneWidget);
    await tester.tap(find.text('关卡目标'));
    await tester.pumpAndSettle();

    expect(find.text(level.hint), findsOneWidget);
    expect(
      find.text('三星 ≤ ${level.parMoves} 步 · 两星 ≤ ${level.parMoves + 2} 步'),
      findsOneWidget,
    );

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('矮窗口将对局进度收进悬浮浮层', (tester) async {
    await pumpGame(
      tester,
      const GameSetup(mode: PlayMode.local, playerCount: PlayerCount.six),
      size: const Size(320, 568),
    );

    expect(find.byTooltip('对局进度'), findsOneWidget);
    expect(find.text('对局进度'), findsNothing);

    await tester.tap(find.byTooltip('对局进度'));
    await tester.pumpAndSettle();

    expect(find.text('对局进度'), findsOneWidget);
    expect(find.textContaining('0/10'), findsNWidgets(6));
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox.shrink());
  });
}
