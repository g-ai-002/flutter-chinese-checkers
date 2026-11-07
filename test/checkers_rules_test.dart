import 'package:chinese_checkers/game/board_geometry.dart';
import 'package:chinese_checkers/game/checkers_board.dart';
import 'package:chinese_checkers/game/checkers_rules.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late BoardGeometry geometry;
  late CheckersRules rules;

  setUp(() {
    geometry = BoardGeometry.star();
    rules = CheckersRules(geometry);
  });

  int hole(int q, int r) {
    final index = geometry.holeAt(q, r);
    expect(index, isNotNull, reason: '($q,$r) 应当存在于棋盘上');
    return index!;
  }

  CheckersBoard empty() => CheckersBoard(List<int>.filled(geometry.length, -1));

  CheckersBoard boardWith(Map<List<int>, int> pieces) {
    final board = empty();
    pieces.forEach((key, seat) => board.cells[hole(key[0], key[1])] = seat);
    return board;
  }

  test('两人开局各占 10 个孔位，中央全部为空', () {
    final board = CheckersBoard.initial(geometry, const [0, 3]);
    expect(board.holesOf(0), hasLength(10));
    expect(board.holesOf(1), hasLength(10));
    for (final holeIndex in geometry.armHoles[0]) {
      expect(board.at(holeIndex), 0);
    }
    for (final holeIndex in geometry.armHoles[3]) {
      expect(board.at(holeIndex), 1);
    }
    expect(board.cells.where((seat) => seat < 0).length, 101);
  });

  test('中央孔位的棋子有六个单步落点', () {
    final board = boardWith({
      [0, 0]: 0,
    });
    final moves = rules.movesFrom(board, hole(0, 0));
    final steps = moves.where((move) => !move.jump).toList();
    expect(steps, hasLength(6));
    expect(steps.map((move) => move.to).toSet(), hasLength(6));
    expect(moves.any((move) => move.jump), isFalse);
  });

  test('单步不能落到已占据的孔位，跳跃可以跨过任何一方的棋子', () {
    final board = boardWith({
      [0, 0]: 0,
      [1, 0]: 1,
      [2, 0]: -1,
    });
    final moves = rules.movesFrom(board, hole(0, 0));
    expect(moves.where((move) => !move.jump), hasLength(5));
    final jumps = moves.where((move) => move.jump).toList();
    expect(jumps, hasLength(1));
    expect(jumps.single.to, hole(2, 0));
    expect(jumps.single.jumpCount, 1);
  });

  test('可以跨过己方棋子', () {
    final board = boardWith({
      [0, 0]: 0,
      [1, 0]: 0,
    });
    final moves = rules.movesFrom(board, hole(0, 0));
    expect(moves.any((move) => move.jump && move.to == hole(2, 0)), isTrue);
  });

  test('连跳记录每一跳的落脚点，并可中途停下', () {
    final board = boardWith({
      [0, 0]: 0,
      [1, 0]: 1,
      [3, 0]: 1,
    });
    final moves = rules.movesFrom(board, hole(0, 0));
    final toTwo = moves.where((move) => move.to == hole(2, 0));
    expect(toTwo, isNotEmpty);
    final chain = moves.where((move) => move.to == hole(4, 0)).toList();
    expect(chain, hasLength(1));
    expect(chain.single.landings, [hole(2, 0), hole(4, 0)]);
    expect(chain.single.jumpCount, 2);
    expect(chain.single.isLongJump, isTrue);
  });

  test('落点被占据时不能跳过去', () {
    final board = boardWith({
      [0, 0]: 0,
      [1, 0]: 1,
      [2, 0]: 1,
    });
    final moves = rules.movesFrom(board, hole(0, 0));
    expect(moves.any((move) => move.to == hole(2, 0)), isFalse);
  });

  test('中间没有棋子不能跳', () {
    final board = boardWith({
      [0, 0]: 0,
    });
    final moves = rules.movesFrom(board, hole(0, 0));
    expect(moves.any((move) => move.jump), isFalse);
  });

  test('同一落点只保留最短的一条连跳', () {
    final board = boardWith({
      [0, 0]: 0,
      [1, 0]: 1,
      [1, -1]: 0,
      [-1, 1]: 0,
    });
    final moves = rules.movesFrom(board, hole(0, 0));
    final destinations = moves.map((move) => move.to).toList();
    expect(destinations.toSet().length, destinations.length);
  });

  test('只有当前玩家的棋子会产生着法', () {
    final board = boardWith({
      [0, 0]: 0,
      [0, 1]: 1,
    });
    final white = rules.legalMoves(board, 1);
    expect(white, hasLength(6));
    for (final move in white) {
      expect(move.from, hole(0, 1));
    }
  });

  test('十枚棋子全部进入对面营地才算获胜', () {
    final board = empty();
    for (final holeIndex in geometry.armHoles[3]) {
      board.cells[holeIndex] = 0;
    }
    expect(rules.hasWon(board, 0, 3), isTrue);
    board.cells[geometry.armHoles[3].first] = -1;
    expect(rules.hasWon(board, 0, 3), isFalse);
    board.cells[geometry.armHoles[3].first] = 1;
    expect(rules.hasWon(board, 0, 3), isFalse);
    expect(rules.progress(board, 0, 3), 9);
  });

  test('三个和四个玩家时营地分布对称', () {
    for (final arms in [
      const [0, 2, 4],
      const [0, 1, 3, 4],
      const [0, 1, 2, 3, 4, 5],
    ]) {
      final board = CheckersBoard.initial(geometry, arms);
      for (var seat = 0; seat < arms.length; seat++) {
        expect(board.holesOf(seat), hasLength(10));
      }
    }
  });

  test('座位轮转跳过无棋可走的玩家，全部无棋时返回 -1', () {
    final board = boardWith({
      [0, 0]: 0,
    });
    expect(rules.nextSeat(board, 0, 2), 0);
    expect(rules.nextSeat(board, 1, 3), 0);
    expect(rules.nextSeat(empty(), 0, 4), -1);
  });

  test('hasAnyMove 与整盘着法生成结果一致', () {
    final boards = <CheckersBoard>[
      CheckersBoard.initial(geometry, const [0, 3]),
      CheckersBoard.initial(geometry, const [0, 1, 2, 3, 4, 5]),
      boardWith({
        [0, 0]: 0,
        [0, 1]: 1,
        [1, 0]: 0,
        [-1, 1]: 1,
      }),
      empty(),
    ];
    // 再补一个真实中局，覆盖棋子互相封堵的情形。
    final midgame = CheckersBoard.initial(geometry, const [0, 3]);
    var seat = 0;
    for (var i = 0; i < 30; i++) {
      final moves = rules.legalMoves(midgame, seat);
      if (moves.isEmpty) break;
      midgame.move(moves.first.from, moves.first.to);
      seat = (seat + 1) % 2;
    }
    boards.add(midgame);

    for (final board in boards) {
      for (var seat = 0; seat < 6; seat++) {
        expect(
          rules.hasAnyMove(board, seat),
          rules.legalMoves(board, seat).isNotEmpty,
          reason: '座位 $seat 的快速判定应与完整着法一致',
        );
      }
    }
  });
}
