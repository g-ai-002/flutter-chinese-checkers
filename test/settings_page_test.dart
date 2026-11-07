import 'package:chinese_checkers/models/game_models.dart';
import 'package:chinese_checkers/pages/settings_page.dart';
import 'package:chinese_checkers/providers/settings_provider.dart';
import 'package:chinese_checkers/services/storage_service.dart';
import 'package:chinese_checkers/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SettingsProvider settings;

  Future<void> boot(WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    StorageService.resetForTests();
    final storage = await StorageService.instance;
    settings = SettingsProvider(storage);
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: settings,
        child: MaterialApp(
          theme: buildLightTheme(),
          home: const SettingsPage(),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('设置页展示外观、声音、对局与日志分区', (tester) async {
    await boot(tester);
    expect(find.text('设置'), findsOneWidget);
    expect(find.text('外观'), findsOneWidget);
    expect(find.text('声音与触感'), findsOneWidget);
    expect(find.text('深色模式'), findsOneWidget);
    expect(find.text('竹影'), findsOneWidget);
    expect(find.text('暖木'), findsOneWidget);
    expect(find.text('夜墨'), findsOneWidget);

    await tester.scrollUntilVisible(find.text('日志'), 240);
    await tester.pump();
    expect(find.text('对局'), findsOneWidget);
    expect(find.text('日志'), findsOneWidget);
  });

  testWidgets('切换深色模式会写入偏好并通知界面', (tester) async {
    await boot(tester);
    await tester.tap(find.text('深色模式'));
    await tester.pump();
    expect(settings.darkMode, isTrue);
    final storage = await StorageService.instance;
    expect(storage.darkMode, isTrue);
  });

  testWidgets('选择棋盘配色后立即生效', (tester) async {
    await boot(tester);
    expect(settings.boardTheme.id, 'jade');
    await tester.tap(find.text('暖木'));
    await tester.pump();
    expect(settings.boardTheme.id, 'wood');
  });

  testWidgets('关闭音效开关会更新偏好', (tester) async {
    await boot(tester);
    await tester.tap(find.text('走子音效'));
    await tester.pump();
    expect(settings.soundEnabled, isFalse);
  });

  testWidgets('逻辑更新速率可选 30 / 60 / 120Hz 并写入偏好', (tester) async {
    await boot(tester);
    await tester.scrollUntilVisible(find.text('逻辑更新速率'), 240);
    await tester.tap(find.text('逻辑更新速率'));
    await tester.pumpAndSettle();
    expect(find.text('30 Hz · 省电优先，低端设备更稳'), findsOneWidget);
    expect(find.text('60 Hz · 性能与流畅度平衡'), findsNWidgets(2));
    expect(find.text('120 Hz · 高刷屏动画最顺滑'), findsOneWidget);

    await tester.tap(find.text('120 Hz · 高刷屏动画最顺滑'));
    await tester.pumpAndSettle();
    expect(settings.logicRate, LogicRate.hz120);
    final storage = await StorageService.instance;
    expect(storage.logicRate, LogicRate.hz120);
  });

  testWidgets('窄屏下设置页不溢出', (tester) async {
    tester.view.physicalSize = const Size(360, 780);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await boot(tester);
    expect(tester.takeException(), isNull);
    expect(find.text('默认玩家人数'), findsOneWidget);
  });
}
