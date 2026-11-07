import 'package:chinese_checkers/game/challenge_levels.dart';
import 'package:chinese_checkers/game/checkers_controller.dart';
import 'package:chinese_checkers/game/checkers_rules.dart';
import 'package:chinese_checkers/models/game_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final level = kChallengeLevels.first;

  CheckersController build() => CheckersController(
    setup: GameSetup.forChallenge(level),
    aiDelay: Duration.zero,
  );

  test('残局使用固定局面，只有己方一方走子', () {
    final controller = build()..start();
    expect(controller.setup.isChallenge, isTrue);
    expect(controller.players, 1);
    expect(controller.board.holesOf(0), hasLength(10));
    expect(controller.board.holesOf(1), hasLength(level.blockers.length));
    expect(controller.progressOf(0), 6);
    expect(controller.movesLeft, level.moveLimit);
    expect(controller.isAiThinking, isFalse);
    expect(controller.currentSeat, 0);
    controller.dispose();
  });

  test('每走一步剩余步数递减，轮次仍停在己方', () {
    final controller = build()..start();
    final rules = CheckersRules(controller.geometry);
    final from = controller.geometry.holeAt(-4, 4)!;
    final move = rules.movesFrom(controller.board, from).first;
    controller.applyMove(move);

    expect(controller.history, hasLength(1));
    expect(controller.currentSeat, 0);
    expect(controller.movesLeft, level.moveLimit - 1);
    expect(controller.isFinished, isFalse);
    controller.dispose();
  });

  test('按参考解法走完即获胜并得到三星', () {
    final controller = build()..start();
    final steps = level.solutionHoles(controller.geometry);
    for (final (from, to) in steps) {
      controller.applyMove(CheckersMove.step(from, to));
    }

    expect(controller.isFinished, isTrue);
    expect(controller.winner, 0);
    expect(controller.history, hasLength(level.parMoves));
    expect(controller.progressOf(0), 10);
    expect(level.starsFor(controller.history.length), 3);
    controller.dispose();
  });

  test('步数用尽仍未进营则挑战失败', () {
    final controller = build()..start();
    final rules = CheckersRules(controller.geometry);
    final outside = controller.geometry.holeAt(-4, 4)!;
    final detour = controller.geometry.holeAt(-4, 3)!;

    for (var i = 0; i < level.moveLimit; i++) {
      final from = i.isEven ? outside : detour;
      final to = i.isEven ? detour : outside;
      final move = rules
          .movesFrom(controller.board, from)
          .firstWhere((candidate) => !candidate.jump && candidate.to == to);
      controller.applyMove(move);
    }

    expect(controller.isFinished, isTrue);
    expect(controller.winner, isNull);
    expect(controller.isDraw, isTrue);
    expect(controller.movesLeft, 0);
    expect(controller.progressOf(0), 6);
    controller.dispose();
  });

  test('残局禁用悔棋，重试回到初始局面', () {
    final controller = build()..start();
    final rules = CheckersRules(controller.geometry);
    controller.applyMove(
      rules.movesFrom(controller.board, controller.board.holesOf(0).first).first,
    );
    expect(controller.canUndo, isFalse);

    controller.undo();
    expect(controller.history, hasLength(1));

    controller.restart();
    expect(controller.history, isEmpty);
    expect(controller.movesLeft, level.moveLimit);
    expect(controller.board.holesOf(0), hasLength(10));
    controller.dispose();
  });
}
