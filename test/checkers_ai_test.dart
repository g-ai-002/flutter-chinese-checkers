import 'dart:math';

import 'package:chinese_checkers/game/board_geometry.dart';
import 'package:chinese_checkers/game/checkers_ai.dart';
import 'package:chinese_checkers/game/checkers_board.dart';
import 'package:chinese_checkers/game/checkers_rules.dart';
import 'package:chinese_checkers/models/game_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late BoardGeometry geometry;
  late CheckersRules rules;

  setUp(() {
    geometry = BoardGeometry.star();
    rules = CheckersRules(geometry);
  });

  GameSetup setupOf(Difficulty difficulty, {int players = 2}) => GameSetup(
    mode: PlayMode.vsAi,
    playerCount: PlayerCount.byCount(players),
    difficulty: difficulty,
  );

  test('普通难度会朝目标营地推进', () {
    final setup = setupOf(Difficulty.normal);
    final ai = CheckersAi(
      geometry: geometry,
      rules: rules,
      setup: setup,
      random: Random(7),
    );
    final board = CheckersBoard(List<int>.filled(geometry.length, -1));
    final start = geometry.holeAt(0, 0)!;
    board.cells[start] = 0;
    final distances = geometry.distancesToArm(setup.targetArmOf(0));

    final move = ai.chooseMove(board, 0);
    expect(move, isNotNull);
    expect(move!.from, start);
    expect(distances[move.to], lessThan(distances[start]));
  });

  test('电脑不会修改传入的局面', () {
    final setup = setupOf(Difficulty.hard);
    final ai = CheckersAi(geometry: geometry, rules: rules, setup: setup);
    final board = CheckersBoard.initial(geometry, setup.seatArms);
    final snapshot = List<int>.of(board.cells);
    ai.chooseMove(board, 0);
    expect(board.cells, snapshot);
  });

  test('三档难度都只返回合法着法', () {
    for (final difficulty in Difficulty.values) {
      final setup = setupOf(difficulty, players: 6);
      final ai = CheckersAi(
        geometry: geometry,
        rules: rules,
        setup: setup,
        random: Random(3),
      );
      final board = CheckersBoard.initial(geometry, setup.seatArms);
      final legal = rules.legalMoves(board, 2);
      final move = ai.chooseMove(board, 2);
      expect(move, isNotNull);
      expect(legal.map((item) => item.to), contains(move!.to));
      expect(legal.map((item) => item.from), contains(move.from));
    }
  });

  test('没有棋子可走时返回 null', () {
    final setup = setupOf(Difficulty.normal);
    final ai = CheckersAi(geometry: geometry, rules: rules, setup: setup);
    final board = CheckersBoard(List<int>.filled(geometry.length, -1));
    expect(ai.chooseMove(board, 0), isNull);
  });

  test('高手难度能识别一步入营的机会', () {
    final setup = setupOf(Difficulty.hard);
    final ai = CheckersAi(geometry: geometry, rules: rules, setup: setup);
    final board = CheckersBoard(List<int>.filled(geometry.length, -1));
    // 除最后一格之外，目标营地已由自己占满，只差临门一脚。
    final target = geometry.armHoles[setup.targetArmOf(0)];
    for (var i = 1; i < target.length; i++) {
      board.cells[target[i]] = 0;
    }
    final empty = target.first;
    final source = geometry.neighbors[empty].first;
    board.cells[source] = 0;
    final move = ai.chooseMove(board, 0);
    expect(move, isNotNull);
    expect(move!.to, empty);
  });
}
