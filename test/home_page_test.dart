import 'package:chinese_checkers/pages/home_page.dart';
import 'package:chinese_checkers/providers/settings_provider.dart';
import 'package:chinese_checkers/services/storage_service.dart';
import 'package:chinese_checkers/theme/app_theme.dart';
import 'package:chinese_checkers/utils/constants.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/replay_fixtures.dart';

Widget wrap(SettingsProvider settings) => ChangeNotifierProvider.value(
  value: settings,
  child: MaterialApp(theme: buildLightTheme(), home: const HomePage()),
);

Future<SettingsProvider> boot() async {
  SharedPreferences.setMockInitialValues({});
  StorageService.resetForTests();
  final storage = await StorageService.instance;
  return SettingsProvider(storage);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('首页展示品牌、两种模式与版本号', (tester) async {
    final settings = await boot();
    await tester.pumpWidget(wrap(settings));

    expect(find.text(AppConstants.appName), findsWidgets);
    expect(find.text('人机对战'), findsOneWidget);
    expect(find.text('同屏对战'), findsOneWidget);
    expect(find.text('玩法说明'), findsOneWidget);
    expect(find.textContaining('v${AppConstants.version}'), findsOneWidget);
  });

  testWidgets('人机对战弹窗可选人数、座位与难度', (tester) async {
    final settings = await boot();
    await tester.pumpWidget(wrap(settings));

    await tester.tap(find.text('人机对战'));
    await tester.pumpAndSettle();

    expect(find.text('玩家人数'), findsOneWidget);
    expect(find.text('我的座位'), findsOneWidget);
    expect(find.text('电脑难度'), findsOneWidget);
    expect(find.text('开始对局'), findsOneWidget);
    expect(find.text('座位 1'), findsOneWidget);
    expect(find.text('座位 2'), findsOneWidget);
    expect(find.text('座位 3'), findsNothing);
  });

  testWidgets('切换到 4 人后座位数量同步增加', (tester) async {
    final settings = await boot();
    await tester.pumpWidget(wrap(settings));

    await tester.tap(find.text('人机对战'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('4 人'));
    await tester.pumpAndSettle();

    expect(find.text('座位 4'), findsOneWidget);
    await tester.ensureVisible(find.text('座位 4'));
    await tester.tap(find.text('座位 4'));
    await tester.pumpAndSettle();
    expect(find.text('高手'), findsOneWidget);
  });

  testWidgets('同屏对战弹窗隐藏座位与难度设置', (tester) async {
    final settings = await boot();
    await tester.pumpWidget(wrap(settings));

    await tester.tap(find.text('同屏对战'));
    await tester.pumpAndSettle();

    expect(find.text('玩家人数'), findsOneWidget);
    expect(find.text('我的座位'), findsNothing);
    expect(find.text('电脑难度'), findsNothing);
    expect(find.text('开始对局'), findsOneWidget);
  });

  testWidgets('玩法说明弹窗列出核心规则', (tester) async {
    final settings = await boot();
    await tester.pumpWidget(wrap(settings));

    await tester.ensureVisible(find.text('玩法说明'));
    await tester.tap(find.text('玩法说明'));
    await tester.pumpAndSettle();

    expect(find.text('玩法说明'), findsWidgets);
    expect(find.textContaining('走到相邻的空孔'), findsOneWidget);
    expect(find.textContaining('跨过任意一枚相邻棋子'), findsOneWidget);
    expect(find.text('知道了'), findsOneWidget);
  });

  testWidgets('首页统计入口在无记录时提示先完成一局', (tester) async {
    final settings = await boot();
    await tester.pumpWidget(wrap(settings));

    expect(find.text('对局统计'), findsOneWidget);
    expect(find.text('完成第一局后查看胜率与亮点'), findsOneWidget);

    await tester.ensureVisible(find.text('对局统计'));
    await tester.tap(find.text('对局统计'));
    await tester.pumpAndSettle();

    expect(find.text('还没有对局记录'), findsOneWidget);
  });

  testWidgets('首页棋谱库入口展示已存档数量并可直接打开', (tester) async {
    SharedPreferences.setMockInitialValues({});
    StorageService.resetForTests();
    final storage = await StorageService.instance;
    await storage.addReplay(sampleArchive());
    final settings = SettingsProvider(storage);
    await tester.pumpWidget(wrap(settings));

    expect(find.text('棋谱库'), findsOneWidget);
    expect(find.text('已存 1 局 · 分享码导入导出'), findsOneWidget);

    await tester.ensureVisible(find.text('棋谱库'));
    await tester.tap(find.text('棋谱库'));
    await tester.pumpAndSettle();

    expect(find.text('2 人 · 同屏对战'), findsOneWidget);
  });

  testWidgets('首页残局挑战入口展示关卡数并可直接打开', (tester) async {
    final settings = await boot();
    await tester.pumpWidget(wrap(settings));

    expect(find.text('残局挑战'), findsOneWidget);
    expect(find.text('9 道残局 · 限步通关 · 逐关解锁'), findsOneWidget);

    await tester.ensureVisible(find.text('残局挑战'));
    await tester.tap(find.text('残局挑战'));
    await tester.pumpAndSettle();

    expect(find.text('已通关 0/9'), findsOneWidget);
  });

  Future<void> pumpHome(WidgetTester tester, Size size) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final settings = await boot();
    await tester.pumpWidget(wrap(settings));
    await tester.pump();
  }

  testWidgets('桌面窗口首页无需滚动，内容整体垂直居中', (tester) async {
    await pumpHome(tester, const Size(1180, 860));

    final scrollable = tester.state<ScrollableState>(find.byType(Scrollable).first);
    expect(scrollable.position.maxScrollExtent, 0);

    final topGap = tester.getRect(find.text(AppConstants.appName).first).top;
    final bottomGap = 860 - tester.getRect(find.textContaining('v${AppConstants.version}')).bottom;
    expect(topGap, greaterThan(40));
    expect((topGap - bottomGap).abs(), lessThan(16));

    // 宽屏改为左右两栏：玩法入口在文案右侧，而不是压在预览图下方。
    final hero = tester.getRect(find.text('六角星上的\n连跳博弈'));
    expect(tester.getRect(find.text('人机对战')).left, greaterThan(hero.right));
  });

  testWidgets('窄屏首页保持单列并允许滚动', (tester) async {
    await pumpHome(tester, const Size(360, 780));

    final scrollable = tester.state<ScrollableState>(find.byType(Scrollable).first);
    expect(scrollable.position.maxScrollExtent, greaterThan(0));
    expect(tester.getRect(find.text(AppConstants.appName).first).top, lessThan(80));
    expect(tester.getRect(find.text('人机对战')).top, greaterThan(400));
  });

  testWidgets('首页全屏边到边：无 AppBar，渐变铺满整屏', (tester) async {
    await pumpHome(tester, const Size(400, 860));

    expect(find.byType(AppBar), findsNothing);
    expect(tester.getRect(find.byType(Scaffold)), const Rect.fromLTWH(0, 0, 400, 860));
    final gradient = tester.widget<Container>(
      find.descendant(of: find.byType(Scaffold), matching: find.byType(Container)).first,
    );
    final decoration = gradient.decoration as BoxDecoration;
    expect(decoration.gradient, isA<LinearGradient>());
    // 内容从状态栏下方开始，渐变仍铺到屏幕最顶端。
    expect(tester.getRect(find.text(AppConstants.appName).first).top, greaterThan(0));
  });

  testWidgets('桌面窗口尺寸矩阵下首页无需滚动且整体垂直居中', (tester) async {
    for (final size in const [Size(1024, 768), Size(1440, 900), Size(1920, 1080)]) {
      await pumpHome(tester, size);
      final scrollable = tester.state<ScrollableState>(find.byType(Scrollable).first);
      expect(scrollable.position.maxScrollExtent, 0, reason: '${size.width}×${size.height}');

      final topGap = tester.getRect(find.text(AppConstants.appName).first).top;
      final bottomGap =
          size.height - tester.getRect(find.textContaining('v${AppConstants.version}')).bottom;
      expect((topGap - bottomGap).abs(), lessThan(16), reason: '${size.width}×${size.height}');
    }
  });
}
