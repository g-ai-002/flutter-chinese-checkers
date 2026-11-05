import 'dart:convert';

import 'package:chinese_checkers/models/game_models.dart';
import 'package:chinese_checkers/models/match_record.dart';
import 'package:chinese_checkers/pages/stats_page.dart';
import 'package:chinese_checkers/providers/settings_provider.dart';
import 'package:chinese_checkers/services/storage_service.dart';
import 'package:chinese_checkers/theme/app_theme.dart';
import 'package:chinese_checkers/utils/constants.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  MatchRecord record({
    required int minute,
    required int? winner,
    required int moves,
    required Duration duration,
    int longestJump = 0,
    String opening = '单步',
    int winnerMoves = 0,
  }) {
    return MatchRecord(
      playedAt: DateTime(2026, 11, 5, 10, minute),
      mode: PlayMode.vsAi,
      playerCount: PlayerCount.two,
      difficulty: Difficulty.normal,
      humanSeat: 0,
      winner: winner,
      moves: moves,
      duration: duration,
      longestJump: longestJump,
      opening: opening,
      winnerMoves: winnerMoves,
    );
  }

  List<String> sampleLines() => [
    jsonEncode(
      record(
        minute: 4,
        winner: 0,
        moves: 50,
        duration: const Duration(minutes: 3),
        longestJump: 3,
        opening: '连跳 ×3',
        winnerMoves: 30,
      ).toJson(),
    ),
    jsonEncode(
      record(
        minute: 2,
        winner: null,
        moves: 120,
        duration: const Duration(minutes: 5),
      ).toJson(),
    ),
    jsonEncode(
      record(
        minute: 1,
        winner: 1,
        moves: 60,
        duration: const Duration(minutes: 4),
        winnerMoves: 35,
      ).toJson(),
    ),
  ];

  Future<SettingsProvider> pumpStats(
    WidgetTester tester, {
    List<String> lines = const [],
    Size size = const Size(400, 820),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    SharedPreferences.setMockInitialValues({
      if (lines.isNotEmpty) AppConstants.prefKeyMatches: lines,
    });
    StorageService.resetForTests();
    final storage = await StorageService.instance;
    final settings = SettingsProvider(storage);
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: settings,
        child: MaterialApp(theme: buildLightTheme(), home: const StatsPage()),
      ),
    );
    await tester.pump(const Duration(milliseconds: 32));
    return settings;
  }

  testWidgets('没有对局时展示空状态且不显示清空入口', (tester) async {
    await pumpStats(tester);

    expect(find.text('对局统计'), findsOneWidget);
    expect(find.text('还没有对局记录'), findsOneWidget);
    expect(find.textContaining('完成一局后会自动记录'), findsOneWidget);
    expect(find.byTooltip('清空统计'), findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('窄屏统计页展示概览、战绩、亮点与最近对局', (tester) async {
    await pumpStats(tester, lines: sampleLines());

    expect(find.text('人机 3 · 同屏 0'), findsOneWidget);
    expect(find.text('33%'), findsOneWidget);
    expect(find.text('1 胜 1 平 1 负'), findsOneWidget);
    expect(find.text('77'), findsOneWidget);
    expect(find.text('04:00'), findsOneWidget);

    expect(find.text('人机战绩'), findsOneWidget);
    expect(find.text('胜率 33%'), findsOneWidget);
    expect(find.text('50 步'), findsOneWidget);
    expect(find.text('×3'), findsOneWidget);
    expect(find.text('单步 · 2 次'), findsOneWidget);
    expect(find.text('3.3 步/子'), findsOneWidget);

    expect(find.text('最近对局'), findsOneWidget);
    expect(find.text('最近 3 场'), findsOneWidget);
    expect(find.textContaining('11-05 10:04'), findsOneWidget);
    expect(find.text('胜'), findsOneWidget);
    expect(find.text('平局'), findsOneWidget);
    expect(find.text('负'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('宽屏统计页使用四列概览卡片', (tester) async {
    await pumpStats(tester, lines: sampleLines(), size: const Size(1200, 900));

    expect(find.text('总对局'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('超过八局时最近对局只展示八场并如实标注', (tester) async {
    final lines = [
      for (var i = 0; i < 10; i++)
        jsonEncode(
          record(
            minute: i,
            winner: i.isEven ? 0 : 1,
            moves: 40 + i,
            duration: const Duration(minutes: 3),
          ).toJson(),
        ),
    ];
    await pumpStats(tester, lines: lines);

    expect(find.text('人机 10 · 同屏 0'), findsOneWidget);
    expect(find.text('最近 8 场'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('清空统计需要确认，确认后回到空状态', (tester) async {
    final settings = await pumpStats(tester, lines: sampleLines());

    await tester.tap(find.byTooltip('清空统计'));
    await tester.pumpAndSettle();
    expect(find.text('清空对局统计？'), findsOneWidget);

    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();
    expect(settings.matches, hasLength(3));

    await tester.tap(find.byTooltip('清空统计'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('清空'));
    await tester.pumpAndSettle();

    expect(settings.matches, isEmpty);
    expect(find.text('还没有对局记录'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
  });
}
