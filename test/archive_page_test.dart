import 'package:chinese_checkers/models/replay_archive.dart';
import 'package:chinese_checkers/pages/archive_page.dart';
import 'package:chinese_checkers/providers/settings_provider.dart';
import 'package:chinese_checkers/services/storage_service.dart';
import 'package:chinese_checkers/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/replay_fixtures.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<SettingsProvider> boot({
    List<ReplayArchive> archives = const [],
  }) async {
    SharedPreferences.setMockInitialValues({});
    StorageService.resetForTests();
    final storage = await StorageService.instance;
    for (final archive in archives) {
      await storage.addReplay(archive);
    }
    return SettingsProvider(storage);
  }

  Future<void> pumpArchive(
    WidgetTester tester,
    SettingsProvider settings, {
    Size size = const Size(1000, 900),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: settings,
        child: MaterialApp(theme: buildLightTheme(), home: const ArchivePage()),
      ),
    );
    await tester.pump(const Duration(milliseconds: 32));
  }

  testWidgets('棋谱库为空时展示引导与导入入口', (tester) async {
    final settings = await boot();
    await pumpArchive(tester, settings);

    expect(find.text('棋谱库'), findsOneWidget);
    expect(find.text('还没有存档棋谱'), findsOneWidget);
    expect(find.textContaining('对局结束后会自动存一份完整棋谱'), findsOneWidget);
    expect(find.text('导入棋谱'), findsOneWidget);

    await tester.tap(find.text('导入棋谱'));
    await tester.pumpAndSettle();
    expect(find.text('在此粘贴分享码'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('棋谱条目展示时间、步数、用时与结果', (tester) async {
    final settings = await boot(archives: [sampleArchive()]);
    await pumpArchive(tester, settings);

    expect(find.text('2 人 · 同屏对战'), findsOneWidget);
    expect(find.textContaining('6 步 · 03:20'), findsOneWidget);
    expect(find.text('平局'), findsOneWidget);
    expect(find.byTooltip('棋谱操作'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('点击棋谱进入复盘页', (tester) async {
    final settings = await boot(archives: [sampleArchive()]);
    await pumpArchive(tester, settings);

    await tester.tap(find.text('2 人 · 同屏对战'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('对局复盘'), findsOneWidget);
    expect(find.text('共 6 手'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('导出棋谱浮层展示分享码', (tester) async {
    final settings = await boot(archives: [sampleArchive()]);
    await pumpArchive(tester, settings);

    await tester.tap(find.byTooltip('棋谱操作'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('导出棋谱'));
    await tester.pumpAndSettle();

    expect(find.text('导出棋谱'), findsOneWidget);
    expect(find.textContaining('TIAOQI1:'), findsOneWidget);
    expect(find.text('复制'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('删除单份棋谱后回到空状态', (tester) async {
    final settings = await boot(archives: [sampleArchive()]);
    await pumpArchive(tester, settings);

    await tester.tap(find.byTooltip('棋谱操作'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('删除'));
    await tester.pumpAndSettle();

    expect(find.text('删除这份棋谱？'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, '删除'));
    await tester.pumpAndSettle();

    expect(find.text('还没有存档棋谱'), findsOneWidget);
    expect(settings.replays, isEmpty);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('粘贴分享码可导入棋谱', (tester) async {
    final settings = await boot();
    await pumpArchive(tester, settings);

    await tester.tap(find.byTooltip('导入棋谱'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), sampleArchive().encode());
    await tester.tap(find.widgetWithText(FilledButton, '导入'));
    await tester.pumpAndSettle();

    expect(find.text('2 人 · 同屏对战'), findsOneWidget);
    expect(find.textContaining('6 步'), findsOneWidget);
    expect(find.text('已导入 6 手棋谱'), findsOneWidget);
    expect(settings.replays, hasLength(1));

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('无效分享码给出错误提示且不写入棋谱库', (tester) async {
    final settings = await boot();
    await pumpArchive(tester, settings);

    await tester.tap(find.byTooltip('导入棋谱'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'TIAOQI1:broken');
    await tester.tap(find.widgetWithText(FilledButton, '导入'));
    await tester.pumpAndSettle();

    expect(find.text('分享码无法识别，请确认完整复制后再试'), findsOneWidget);
    expect(settings.replays, isEmpty);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('清空棋谱库需要确认，确认后列表清空', (tester) async {
    final settings = await boot(
      archives: [
        sampleArchive(savedAt: DateTime(2026, 1, 1, 9)),
        sampleArchive(savedAt: DateTime(2026, 1, 2, 9)),
      ],
    );
    await pumpArchive(tester, settings);

    expect(find.byTooltip('棋谱操作'), findsNWidgets(2));
    await tester.tap(find.byTooltip('清空棋谱'));
    await tester.pumpAndSettle();
    expect(find.text('清空棋谱库？'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, '清空'));
    await tester.pumpAndSettle();

    expect(find.text('还没有存档棋谱'), findsOneWidget);
    expect(settings.replays, isEmpty);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('窄屏棋谱条目仍完整展示概要与操作', (tester) async {
    final settings = await boot(archives: [sampleArchive()]);
    await pumpArchive(tester, settings, size: const Size(400, 820));

    expect(find.text('2 人 · 同屏对战'), findsOneWidget);
    expect(find.byTooltip('棋谱操作'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox.shrink());
  });
}
