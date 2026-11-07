import 'package:chinese_checkers/game/board_geometry.dart';
import 'package:chinese_checkers/game/challenge_levels.dart';
import 'package:chinese_checkers/game/checkers_board.dart';
import 'package:chinese_checkers/game/checkers_rules.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final geometry = BoardGeometry.star();
  final rules = CheckersRules(geometry);

  test('九道残局按难度分为三档，编号唯一', () {
    expect(kChallengeLevels, hasLength(9));
    expect(
      kChallengeLevels.map((level) => level.id).toSet(),
      hasLength(kChallengeLevels.length),
    );
    for (final tier in ChallengeTier.values) {
      expect(
        kChallengeLevels.where((level) => level.tier == tier),
        hasLength(3),
      );
    }
  });

  test('每道残局都有十枚己方棋子与合法参考解法', () {
    for (final level in kChallengeLevels) {
      final board = CheckersBoard(level.cellsFor(geometry));
      expect(board.holesOf(0), hasLength(10), reason: level.id);
      expect(level.human.length, 10, reason: level.id);
      expect(
        level.human.toSet(),
        hasLength(level.human.length),
        reason: '${level.id} 己方棋子重叠',
      );
      expect(level.solution, hasLength(level.parMoves), reason: level.id);
      expect(level.moveLimit, greaterThan(level.parMoves), reason: level.id);

      for (final (from, to) in level.solutionHoles(geometry)) {
        final legal = rules
            .movesFrom(board, from)
            .where((move) => !move.jump && move.to == to);
        expect(legal, isNotEmpty, reason: '${level.id} 参考解法非法: $from -> $to');
        board.move(from, to);
      }
      expect(
        rules.hasWon(board, 0, 3),
        isTrue,
        reason: '${level.id} 参考解法没有填满目标营地',
      );
    }
  });

  test('障碍子不占据目标营地，也不会与己方棋子重叠', () {
    final target = geometry.armHoles[3].toSet();
    for (final level in kChallengeLevels) {
      final cells = level.cellsFor(geometry);
      final occupied = <int>{};
      for (final hole in level.human.map(
        (piece) => geometry.holeAt(piece.$1, piece.$2)!,
      )) {
        expect(occupied.add(hole), isTrue, reason: '${level.id} 己方重叠');
      }
      for (final hole in level.blockers.map(
        (piece) => geometry.holeAt(piece.$1, piece.$2)!,
      )) {
        expect(occupied.add(hole), isTrue, reason: '${level.id} 障碍重叠');
        expect(target, isNot(contains(hole)), reason: '${level.id} 障碍在营地内');
      }
      expect(cells.where((seat) => seat == 1), hasLength(level.blockers.length));
    }
  });

  test('星级按参考步数递减，最后一关没有下一关', () {
    final level = kChallengeLevels.first;
    expect(level.starsFor(level.parMoves - 1), 3);
    expect(level.starsFor(level.parMoves), 3);
    expect(level.starsFor(level.parMoves + 1), 2);
    expect(level.starsFor(level.parMoves + 2), 2);
    expect(level.starsFor(level.parMoves + 3), 1);
    expect(challengeAfter(kChallengeLevels.last), isNull);
    expect(challengeAfter(level), kChallengeLevels[1]);
    expect(challengeById(level.id), same(level));
    expect(challengeById('missing'), isNull);
    expect(challengeIndexOf(level), 0);
  });
}
