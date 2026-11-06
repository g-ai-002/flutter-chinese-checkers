import 'package:chinese_checkers/models/game_models.dart';
import 'package:chinese_checkers/models/match_record.dart';
import 'package:chinese_checkers/pages/widgets/game_dialogs.dart';
import 'package:chinese_checkers/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  MatchRecord record({required int? winner, int winnerMoves = 30}) {
    return MatchRecord(
      playedAt: DateTime(2026, 11, 5, 10),
      mode: PlayMode.vsAi,
      playerCount: PlayerCount.two,
      difficulty: Difficulty.normal,
      humanSeat: 0,
      winner: winner,
      moves: 50,
      duration: const Duration(minutes: 3),
      longestJump: 3,
      opening: '连跳 ×3',
      winnerMoves: winnerMoves,
    );
  }

  Future<void> pumpDialog(WidgetTester tester, MatchRecord value) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildLightTheme(),
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () => showGameResultDialog(
                  context,
                  record: value,
                  onReplay: () {},
                  onRestart: () {},
                  onHome: () {},
                ),
                child: const Text('打开'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('打开'));
    await tester.pumpAndSettle();
  }

  testWidgets('人机获胜弹窗展示步数、用时、连跳与入营效率', (tester) async {
    await pumpDialog(tester, record(winner: 0));

    expect(find.text('你获胜'), findsOneWidget);
    expect(find.text('十枚棋子全部进入对面营地。'), findsOneWidget);
    expect(find.text('50 步'), findsOneWidget);
    expect(find.text('03:00'), findsOneWidget);
    expect(find.text('最长连跳'), findsOneWidget);
    expect(find.text('×3'), findsOneWidget);
    expect(find.text('入营效率'), findsOneWidget);
    expect(find.text('3.0 步/子'), findsOneWidget);
    expect(find.text('本局已存入棋谱库，可复盘、导出分享或随时回看。'), findsOneWidget);
    expect(find.text('复盘本局'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('平局弹窗不展示获胜方效率', (tester) async {
    await pumpDialog(tester, record(winner: null, winnerMoves: 0));

    expect(find.text('本局僵局'), findsOneWidget);
    expect(find.text('局面陷入停滞，本局就此结束。'), findsOneWidget);
    expect(find.text('入营效率'), findsNothing);
    expect(find.text('最长连跳'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
  });
}
