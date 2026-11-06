import 'dart:math';

import 'package:chinese_checkers/game/ai_heuristics.dart';
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

  test('营地入口留空比只剩尖端更好', () {
    // 入口先被占满会让最后的棋子再也进不来，对局就卡在 9/10。
    final setup = setupOf(Difficulty.hard);
    final heuristics = AiHeuristics(geometry: geometry, setup: setup);
    final target = setup.targetArmOf(0);
    final tip = geometry.tipHole(target);
    final entrance = geometry.armHoles[target].reduce(
      (a, b) =>
          geometry.distance(a, geometry.holeAt(0, 0)!) <
              geometry.distance(b, geometry.holeAt(0, 0)!)
          ? a
          : b,
    );
    final outside = geometry.holeAt(0, 0)!;

    CheckersBoard campWithEmpty(int empty) =>
        CheckersBoard.fromPieces(geometry, {
          for (final hole in geometry.armHoles[target])
            if (hole != empty) hole: 0,
          outside: 0,
        });

    expect(
      heuristics.evaluate(campWithEmpty(entrance), 0),
      greaterThan(heuristics.evaluate(campWithEmpty(tip), 0)),
    );
  });

  test('高手会先完成收官计划，不移动已进营的棋子', () {
    final setup = setupOf(Difficulty.hard);
    final ai = CheckersAi(
      geometry: geometry,
      rules: rules,
      setup: setup,
      random: Random(1),
    );
    final target = geometry.armHoles[setup.targetArmOf(0)];
    final board = CheckersBoard.fromPieces(geometry, {
      for (var i = 1; i < target.length; i++) target[i]: 0,
      101: 0,
    });
    final distances = geometry.distancesToArm(setup.targetArmOf(0));

    final move = ai.chooseMove(board, 0)!;
    expect(target, isNot(contains(move.from)));
    expect(move.from, 101);
    expect(distances[move.to], lessThan(distances[101]));
  });

  test('高手会堵住对手一步收官的入口', () {
    final setup = setupOf(Difficulty.hard);
    final ai = CheckersAi(
      geometry: geometry,
      rules: rules,
      setup: setup,
      random: Random(1),
    );
    // 1 号座位占满 0 号营地的九格，18 号孔一步就能补上 9 号空位。
    const slot = 9;
    final board = CheckersBoard.fromPieces(geometry, {
      for (final hole in geometry.armHoles[0])
        if (hole != slot) hole: 1,
      18: 1,
      for (var i = 0; i < 8; i++) geometry.armHoles[3][i]: 0,
      17: 0,
      60: 0,
    });

    final threat = CheckersBoard(board.cells)..move(18, slot);
    expect(rules.hasWon(threat, 1, 0), isTrue);

    final move = ai.chooseMove(board, 0)!;
    expect(move.from, 17);
    expect(move.to, slot);
  });

  test('高手搜索受节点预算约束，普通难度不做搜索', () {
    final setup = setupOf(Difficulty.hard, players: 4);
    final board = CheckersBoard.initial(geometry, setup.seatArms);
    final hard = CheckersAi(
      geometry: geometry,
      rules: rules,
      setup: setup,
      random: Random(5),
    );
    expect(hard.chooseMove(board, 0), isNotNull);
    expect(hard.lastSearch, isNotNull);
    expect(hard.lastSearch!.nodes, greaterThan(0));
    expect(hard.lastSearch!.nodes, lessThanOrEqualTo(CheckersAi.nodeBudget));
    expect(hard.lastSearch!.depth, 3);

    final normalSetup = setupOf(Difficulty.normal, players: 4);
    final normal = CheckersAi(
      geometry: geometry,
      rules: rules,
      setup: normalSetup,
      random: Random(5),
    );
    expect(normal.chooseMove(board, 0), isNotNull);
    expect(normal.lastSearch, isNull);
  });

  test('六人局搜索限制为两步，节点数同样不超预算', () {
    final setup = setupOf(Difficulty.hard, players: 6);
    final board = CheckersBoard.initial(geometry, setup.seatArms);
    final ai = CheckersAi(
      geometry: geometry,
      rules: rules,
      setup: setup,
      random: Random(11),
    );

    expect(ai.chooseMove(board, 3), isNotNull);
    expect(ai.lastSearch, isNotNull);
    expect(ai.lastSearch!.depth, 2);
    expect(ai.lastSearch!.nodes, lessThanOrEqualTo(CheckersAi.nodeBudget));
  });

  test('预算耗尽时回退静态最优着法，仍返回合法着法', () {
    final setup = setupOf(Difficulty.hard, players: 4);
    final board = CheckersBoard.initial(geometry, setup.seatArms);
    final ai = CheckersAi(
      geometry: geometry,
      rules: rules,
      setup: setup,
      random: Random(9),
      maxNodes: 1,
    );
    final legal = rules.legalMoves(board, 0);

    final move = ai.chooseMove(board, 0);

    expect(move, isNotNull);
    final chosen = move!;
    expect(ai.lastSearch!.nodes, 1);
    expect(
      legal.any((item) => item.from == chosen.from && item.to == chosen.to),
      isTrue,
    );
  });

  test('对手进营越多，局面评分越低', () {
    final setup = setupOf(Difficulty.hard);
    final heuristics = AiHeuristics(geometry: geometry, setup: setup);
    final target = geometry.armHoles[setup.targetArmOf(1)];
    final outside = geometry.armHoles[3].take(4).toList();

    CheckersBoard boardWith(int inTarget) =>
        CheckersBoard.fromPieces(geometry, {
          for (var i = 0; i < inTarget; i++) target[i]: 1,
          for (var i = 0; i < 5 - inTarget; i++) outside[i]: 1,
        });

    final nearlyDone = heuristics.evaluate(boardWith(4), 0);
    final justStarted = heuristics.evaluate(boardWith(1), 0);

    expect(nearlyDone, lessThan(justStarted));
  });

  test('高手对普通能正常收官，不会卡在 9/10', () {
    const setup = GameSetup(
      mode: PlayMode.local,
      playerCount: PlayerCount.two,
      difficulty: Difficulty.hard,
    );
    final ais = [
      CheckersAi(
        geometry: geometry,
        rules: rules,
        setup: setup,
        difficulty: Difficulty.hard,
        random: Random(2),
      ),
      CheckersAi(
        geometry: geometry,
        rules: rules,
        setup: setup,
        difficulty: Difficulty.normal,
        random: Random(3),
      ),
    ];
    final board = CheckersBoard.initial(geometry, setup.seatArms);
    var seat = 0;
    var plies = 0;
    while (plies < 400) {
      final move = ais[seat].chooseMove(board, seat);
      if (move == null) break;
      board.move(move.from, move.to);
      plies++;
      if (rules.hasWon(board, seat, setup.targetArmOf(seat))) break;
      seat = 1 - seat;
    }
    expect(rules.hasWon(board, 0, 3), isTrue);
    expect(plies, lessThan(300));
  });
}
