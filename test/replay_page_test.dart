import 'package:chinese_checkers/game/board_geometry.dart';
import 'package:chinese_checkers/game/checkers_board.dart';
import 'package:chinese_checkers/game/checkers_rules.dart';
import 'package:chinese_checkers/game/move_record.dart';
import 'package:chinese_checkers/game/replay_controller.dart';
import 'package:chinese_checkers/models/game_models.dart';
import 'package:chinese_checkers/pages/replay_page.dart';
import 'package:chinese_checkers/providers/settings_provider.dart';
import 'package:chinese_checkers/services/storage_service.dart';
import 'package:chinese_checkers/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const setup = GameSetup(mode: PlayMode.local, playerCount: PlayerCount.two);

  List<MoveRecord> sampleRecords(int count) {
    final geometry = BoardGeometry.star();
    final board = CheckersBoard.initial(geometry, setup.seatArms);
    final rules = CheckersRules(geometry);
    final records = <MoveRecord>[];
    var seat = 0;
    for (var i = 0; i < count; i++) {
      final move = rules.legalMoves(board, seat).first;
      board.move(move.from, move.to);
      records.add(MoveRecord(seat: seat, move: move));
      seat = (seat + 1) % setup.players;
    }
    return records;
  }

  /// 走子和复盘控制器共用的一组带跳跃的记录。
  List<MoveRecord> recordsUntilJump({int limit = 200}) {
    final geometry = BoardGeometry.star();
    final board = CheckersBoard.initial(geometry, setup.seatArms);
    final rules = CheckersRules(geometry);
    final records = <MoveRecord>[];
    var seat = 0;
    for (var i = 0; i < limit; i++) {
      final moves = rules.legalMoves(board, seat);
      CheckersMove? jump;
      for (final move in moves) {
        if (move.jump) {
          jump = move;
          break;
        }
      }
      final move = jump ?? moves.first;
      board.move(move.from, move.to);
      records.add(MoveRecord(seat: seat, move: move));
      seat = (seat + 1) % setup.players;
      if (jump != null) return records;
    }
    fail('前 $limit 手内没有出现跳跃');
  }

  Future<void> pumpReplay(
    WidgetTester tester, {
    int moves = 6,
    List<MoveRecord>? records,
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
          home: ReplayPage(
            setup: setup,
            records: records ?? sampleRecords(moves),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 32));
  }

  testWidgets('宽屏复盘页展示棋盘、棋谱与播放控件', (tester) async {
    await pumpReplay(tester);

    expect(find.text('对局复盘'), findsOneWidget);
    expect(find.text('棋谱'), findsOneWidget);
    expect(find.text('共 6 手'), findsOneWidget);
    expect(find.text('初始营地布局'), findsOneWidget);
    expect(find.byTooltip('播放'), findsOneWidget);
    expect(find.byTooltip('下一手'), findsOneWidget);
    expect(find.byTooltip('跳到终局'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('逐手前进与跳转会更新进度和棋谱选中项', (tester) async {
    await pumpReplay(tester);

    expect(find.text('开局'), findsNWidgets(2));

    await tester.tap(find.byTooltip('下一手'));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('第 1 / 6 手'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.byTooltip('跳到终局'));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('第 6 / 6 手'), findsOneWidget);
    expect(find.byTooltip('下一手'), findsOneWidget);

    await tester.tap(find.byTooltip('回到开局'));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('开局'), findsNWidgets(2));

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('窄屏通过棋谱按钮打开走子列表', (tester) async {
    await pumpReplay(tester, size: const Size(400, 820));

    expect(find.byTooltip('棋谱'), findsOneWidget);
    expect(find.text('共 6 手'), findsNothing);

    await tester.tap(find.byTooltip('棋谱'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('棋谱'), findsOneWidget);
    expect(find.text('共 6 手'), findsOneWidget);
    expect(find.text('初始营地布局'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('窄屏棋谱浮层可直接跳转到某一手', (tester) async {
    await pumpReplay(tester, size: const Size(400, 820));

    await tester.tap(find.byTooltip('棋谱'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    await tester.tap(find.text('2'));
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('第 2 / 6 手'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('棋谱展示最佳着法，点击直接跳到该手', (tester) async {
    final records = recordsUntilJump();
    final probe = ReplayController(setup: setup, records: records);
    final best = probe.bestMoveNumber!;
    probe.dispose();

    await pumpReplay(tester, records: records);

    final label = find.textContaining('最佳着法 第 $best 手');
    expect(label, findsOneWidget);
    expect(find.byIcon(Icons.auto_awesome), findsWidgets);

    await tester.tap(label);
    await tester.pump(const Duration(milliseconds: 120));

    expect(find.text('第 $best / ${records.length} 手'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('窄屏棋谱浮层同样展示最佳着法', (tester) async {
    await pumpReplay(
      tester,
      records: recordsUntilJump(),
      size: const Size(400, 820),
    );

    await tester.tap(find.byTooltip('棋谱'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.textContaining('最佳着法 第'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox.shrink());
  });
}
