import 'dart:math' as math;

import 'package:chinese_checkers/flame/checkers_game.dart';
import 'package:chinese_checkers/game/checkers_controller.dart';
import 'package:chinese_checkers/models/game_models.dart';
import 'package:chinese_checkers/theme/app_theme.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const setup = GameSetup(mode: PlayMode.local, playerCount: PlayerCount.two);

  testWidgets('棋盘静止后暂停渲染循环，局面变化时自动恢复', (tester) async {
    final controller = CheckersController(setup: setup);
    final game = CheckersGame(
      source: controller,
      theme: kBoardThemes.first,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: SizedBox(
          width: 420,
          height: 480,
          child: GameWidget<CheckersGame>(game: game),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(game.paused, isFalse);
    expect(game.isIdlePaused, isFalse);

    await tester.pump(CheckersGame.idleDelay + const Duration(milliseconds: 50));
    expect(game.isIdlePaused, isTrue);
    expect(game.paused, isTrue);

    // 暂停的是渲染循环，点击棋盘仍然要能选中棋子并唤醒循环。
    final widget = find.byType(GameWidget<CheckersGame>);
    final boardSize = tester.getSize(widget);
    final center = tester.getCenter(widget);
    final scale = math.min(boardSize.width / 14, boardSize.height / 16);
    final hole = controller.geometry.armHoles[0].first;
    final point = controller.geometry.holes[hole];
    await tester.tapAt(center + Offset(point.x * scale, point.y * scale));
    await tester.pump();
    expect(controller.selectedHole, hole);
    expect(game.isIdlePaused, isFalse);
    expect(game.paused, isFalse);
    // 让手势识别器的双击等待计时器走完，避免测试结束时仍有待处理计时器。
    await tester.pump(const Duration(milliseconds: 500));

    final move = controller.rules.legalMoves(controller.board, 0).first;
    controller.applyMove(move);
    await tester.pump();
    expect(game.isIdlePaused, isFalse);
    expect(game.paused, isFalse);

    await tester.pumpWidget(const SizedBox.shrink());
    controller.dispose();
  });

  test('逻辑更新速率默认 60Hz，未知值回退默认', () {
    expect(LogicRate.defaultRate, LogicRate.hz60);
    expect(LogicRate.byHz(30), LogicRate.hz30);
    expect(LogicRate.byHz(120), LogicRate.hz120);
    expect(LogicRate.byHz(45), LogicRate.hz60);
    expect(LogicRate.byHz(null), LogicRate.hz60);
    expect(LogicRate.hz120.stepSeconds, 1 / 120);
  });

  test('逻辑按所选速率固定步长推进，卡顿帧不无限补步', () {
    final controller = CheckersController(setup: setup);
    final theme = kBoardThemes.first;

    final slow = CheckersGame(
      source: controller,
      theme: theme,
      logicRate: LogicRate.hz30,
    );
    slow.update(1 / 60);
    expect(slow.logicSteps, 0);
    slow.update(1 / 60);
    expect(slow.logicSteps, 1);

    final fast = CheckersGame(
      source: controller,
      theme: theme,
      logicRate: LogicRate.hz120,
    );
    fast.update(1 / 60);
    expect(fast.logicSteps, 2);

    // 1 秒的卡顿帧只补 8 步，余量丢弃，避免逻辑越追越慢。
    fast.update(1);
    expect(fast.logicSteps, 10);
    fast.update(1 / 120);
    expect(fast.logicSteps, 11);

    expect(
      CheckersGame(source: controller, theme: theme).logicRate,
      LogicRate.hz60,
    );
    controller.dispose();
  });
}
