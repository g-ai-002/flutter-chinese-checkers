import 'package:chinese_checkers/game/checkers_controller.dart';
import 'package:chinese_checkers/game/checkers_rules.dart';
import 'package:chinese_checkers/models/game_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  CheckersController build({
    PlayMode mode = PlayMode.local,
    PlayerCount count = PlayerCount.two,
    int humanSeat = 0,
    Difficulty difficulty = Difficulty.normal,
    Duration aiDelay = Duration.zero,
  }) {
    return CheckersController(
      setup: GameSetup(
        mode: mode,
        playerCount: count,
        humanSeat: humanSeat,
        difficulty: difficulty,
      ),
      aiDelay: aiDelay,
    );
  }

  test('同屏模式落子后轮到下一位，悔棋回到上一步', () {
    final controller = build();
    controller.start();
    expect(controller.currentSeat, 0);

    final moves = CheckersRules(controller.geometry)
        .legalMoves(controller.board, 0);
    controller.applyMove(moves.first);

    expect(controller.currentSeat, 1);
    expect(controller.history, hasLength(1));
    expect(controller.canUndo, isTrue);
    expect(controller.records.single.seat, 0);

    controller.undo();
    expect(controller.history, isEmpty);
    expect(controller.currentSeat, 0);
    expect(controller.board.holesOf(0), hasLength(10));
    expect(controller.board.holesOf(1), hasLength(10));
  });

  test('点击选子后只显示该棋子的落点，再点落点即走子', () {
    final controller = build();
    controller.start();

    final rules = CheckersRules(controller.geometry);
    final piece = controller.board
        .holesOf(0)
        .firstWhere(
          (hole) => rules.movesFrom(controller.board, hole).isNotEmpty,
        );
    controller.tapHole(piece);

    expect(controller.selectedHole, piece);
    expect(controller.targets, isNotEmpty);
    for (final entry in controller.targets.entries) {
      expect(entry.value.from, piece);
      expect(entry.value.to, entry.key);
    }

    controller.tapHole(controller.targets.keys.first);
    expect(controller.history, hasLength(1));
    expect(controller.selectedHole, isNull);
    expect(controller.targets, isEmpty);
  });

  test('点击空白处取消选择', () {
    final controller = build();
    controller.start();
    final piece = controller.board.holesOf(0).first;
    controller.tapHole(piece);
    expect(controller.selectedHole, piece);
    final empty = controller.board.cells.indexOf(-1);
    controller.tapHole(empty);
    expect(controller.selectedHole, isNull);
    expect(controller.history, isEmpty);
  });

  test('人机模式电脑自动回棋，随后轮到人类', () async {
    final controller = build(mode: PlayMode.vsAi, difficulty: Difficulty.easy);
    controller.start();
    final moves = CheckersRules(controller.geometry)
        .legalMoves(controller.board, 0);
    controller.applyMove(moves.first);
    expect(controller.currentSeat, 1);

    await Future<void>.delayed(const Duration(milliseconds: 60));

    expect(controller.history, hasLength(2));
    expect(controller.currentSeat, 0);
    expect(controller.isAiThinking, isFalse);
    controller.dispose();
  });

  test('人类执后手时电脑先行', () async {
    final controller = build(
      mode: PlayMode.vsAi,
      humanSeat: 1,
      difficulty: Difficulty.easy,
    );
    controller.start();
    expect(controller.canUndo, isFalse);

    await Future<void>.delayed(const Duration(milliseconds: 60));

    expect(controller.history, hasLength(1));
    expect(controller.currentSeat, 1);
    controller.dispose();
  });

  test('悔棋会取消尚未落子的电脑回合', () async {
    final controller = build(
      mode: PlayMode.vsAi,
      difficulty: Difficulty.easy,
      aiDelay: const Duration(milliseconds: 40),
    );
    controller.start();
    final moves = CheckersRules(controller.geometry)
        .legalMoves(controller.board, 0);
    controller.applyMove(moves.first);
    controller.undo();

    await Future<void>.delayed(const Duration(milliseconds: 100));

    expect(controller.history, isEmpty);
    expect(controller.currentSeat, 0);
    expect(controller.isAiThinking, isFalse);
    controller.dispose();
  });

  test('多人局中连续的电脑座位会依次走完', () async {
    final controller = build(
      mode: PlayMode.vsAi,
      count: PlayerCount.four,
      humanSeat: 2,
      difficulty: Difficulty.easy,
    );
    controller.start();

    await Future<void>.delayed(const Duration(milliseconds: 120));

    expect(controller.history, hasLength(2));
    expect(controller.currentSeat, 2);
    expect(controller.isAiThinking, isFalse);
    controller.dispose();
  });

  test('提示给出当前玩家的合法着法，落子后自动清除', () {
    final controller = build(difficulty: Difficulty.hard);
    controller.start();
    controller.requestHint();

    final hint = controller.hintMove;
    expect(hint, isNotNull);
    final legal = CheckersRules(controller.geometry)
        .legalMoves(controller.board, 0);
    expect(legal.map((move) => move.to), contains(hint!.to));

    controller.applyMove(hint);
    expect(controller.hintMove, isNull);
  });

  test('重开后回到开局，再次落子重新计数', () {
    final controller = build();
    controller.start();
    final moves = CheckersRules(controller.geometry)
        .legalMoves(controller.board, 0);
    controller.applyMove(moves.first);
    controller.restart();

    expect(controller.history, isEmpty);
    expect(controller.currentSeat, 0);
    expect(controller.winner, isNull);
    expect(controller.board.holesOf(0), hasLength(10));
  });

  test('每种人数与座位组合都有合法开局着法', () {
    for (final count in PlayerCount.values) {
      for (final seat in [0, count.count - 1]) {
        final controller = build(
          mode: PlayMode.vsAi,
          count: count,
          humanSeat: seat,
        );
        expect(controller.setup.targetArmOf(seat), isNot(seat));
        expect(controller.progressOf(seat), 0);
        for (var player = 0; player < count.count; player++) {
          expect(
            CheckersRules(controller.geometry)
                .legalMoves(controller.board, player),
            isNotEmpty,
          );
        }
        controller.dispose();
      }
    }
  });
}
