import 'package:chinese_checkers/game/challenge_levels.dart';
import 'package:chinese_checkers/models/challenge_result.dart';
import 'package:chinese_checkers/pages/challenge_page.dart';
import 'package:chinese_checkers/pages/widgets/challenge_widgets.dart';
import 'package:chinese_checkers/providers/settings_provider.dart';
import 'package:chinese_checkers/services/storage_service.dart';
import 'package:chinese_checkers/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

Widget wrap(SettingsProvider settings) => ChangeNotifierProvider.value(
  value: settings,
  child: MaterialApp(theme: buildLightTheme(), home: const ChallengePage()),
);

Future<SettingsProvider> boot() async {
  SharedPreferences.setMockInitialValues({});
  StorageService.resetForTests();
  final storage = await StorageService.instance;
  return SettingsProvider(storage);
}

void sizeView(WidgetTester tester, {double height = 1600}) {
  tester.view.physicalSize = Size(900, height);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('未通关时只解锁第一关，其余显示锁定', (tester) async {
    sizeView(tester);
    final settings = await boot();
    await tester.pumpWidget(wrap(settings));

    expect(find.text('已通关 0/9'), findsOneWidget);
    expect(find.text('0 / 27 星'), findsOneWidget);
    expect(find.text('通关上一关后解锁'), findsNWidgets(8));
    expect(find.text(kChallengeLevels.first.hint), findsOneWidget);

    final first = tester.widget<InkWell>(
      find.byKey(ValueKey('challenge-${kChallengeLevels.first.id}')),
    );
    final second = tester.widget<InkWell>(
      find.byKey(ValueKey('challenge-${kChallengeLevels[1].id}')),
    );
    expect(first.onTap, isNotNull);
    expect(second.onTap, isNull);
  });

  testWidgets('通关后展示最佳步数并解锁下一关', (tester) async {
    sizeView(tester);
    SharedPreferences.setMockInitialValues({});
    StorageService.resetForTests();
    final storage = await StorageService.instance;
    await storage.saveChallengeResult(
      const ChallengeResult(levelId: 'starter-1', stars: 3, moves: 4),
    );
    final settings = SettingsProvider(storage);
    await tester.pumpWidget(wrap(settings));

    expect(find.text('已通关 1/9'), findsOneWidget);
    expect(find.text('3 / 27 星'), findsOneWidget);
    expect(find.text('最佳 4 步 · 参考 4 步'), findsOneWidget);
    expect(find.text(kChallengeLevels[1].hint), findsOneWidget);
    expect(
      tester
          .widget<InkWell>(
            find.byKey(ValueKey('challenge-${kChallengeLevels[1].id}')),
          )
          .onTap,
      isNotNull,
    );
  });

  testWidgets('重置进度需要确认，确认后重新锁定关卡', (tester) async {
    sizeView(tester);
    SharedPreferences.setMockInitialValues({});
    StorageService.resetForTests();
    final storage = await StorageService.instance;
    await storage.saveChallengeResult(
      const ChallengeResult(levelId: 'starter-1', stars: 3, moves: 4),
    );
    final settings = SettingsProvider(storage);
    await tester.pumpWidget(wrap(settings));

    await tester.tap(find.byTooltip('重置进度'));
    await tester.pumpAndSettle();
    expect(find.text('重置挑战进度？'), findsOneWidget);

    await tester.tap(find.text('重置'));
    await tester.pumpAndSettle();
    expect(find.text('已通关 0/9'), findsOneWidget);
    expect(find.text('通关上一关后解锁'), findsNWidgets(8));
  });

  testWidgets('点击已解锁关卡进入残局对局页', (tester) async {
    sizeView(tester);
    final settings = await boot();
    await tester.pumpWidget(wrap(settings));
    await tester.tap(
      find.byKey(ValueKey('challenge-${kChallengeLevels.first.id}')),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('第 1 关 · 一眼归位'), findsOneWidget);
    expect(find.text('剩 8 步'), findsOneWidget);
    expect(find.text('进营 6/10'), findsOneWidget);
    expect(find.text('重试'), findsOneWidget);
    expect(find.text('悔棋'), findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('结算浮层在成功时展示星级与下一关', (tester) async {
    final level = kChallengeLevels.first;
    await tester.pumpWidget(
      MaterialApp(
        theme: buildLightTheme(),
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => showChallengeResultDialog(
                context,
                level: level,
                success: true,
                moves: level.parMoves,
                onRetry: () {},
                onBack: () {},
                onNext: () {},
              ),
              child: const Text('打开'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('打开'));
    await tester.pumpAndSettle();

    expect(find.text('挑战成功'), findsOneWidget);
    expect(find.text('4 步完成 · 参考 4 步'), findsOneWidget);
    expect(find.byType(ChallengeStars), findsOneWidget);
    expect(find.text('下一关'), findsOneWidget);
    expect(find.text('再试一次'), findsOneWidget);
  });

  test('星级评定按参考步数分三档', () {
    final level = kChallengeLevels.first;
    expect(level.starsFor(4), 3);
    expect(level.starsFor(6), 2);
    expect(level.starsFor(7), 1);
  });
}
