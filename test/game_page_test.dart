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
    expect(find.text('怎么看'), findsOneWidget);
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
}
