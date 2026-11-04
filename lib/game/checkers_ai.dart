import 'dart:math';

import '../models/game_models.dart';
import 'board_geometry.dart';
import 'checkers_board.dart';
import 'checkers_rules.dart';

/// 电脑走子：按难度选择着法。
///
/// - 入门：随机走一步；
/// - 普通：贪心最大化「向对面营地推进」的评估；
/// - 高手：在候选着法里预判其他玩家一步，避免把对手送进营地。
class CheckersAi {
  CheckersAi({
    required this.geometry,
    required this.rules,
    required this.setup,
    Difficulty? difficulty,
    Random? random,
  }) : difficulty = difficulty ?? setup.difficulty,
       _random = random ?? Random();

  final BoardGeometry geometry;
  final CheckersRules rules;
  final GameSetup setup;
  final Difficulty difficulty;
  final Random _random;
  final Map<int, List<int>> _distances = {};

  CheckersMove? chooseMove(CheckersBoard board, int seat) {
    final moves = rules.legalMoves(board, seat);
    if (moves.isEmpty) return null;
    // 能一步收官就先收官，任何难度都不会错过。
    final targetArm = setup.targetArmOf(seat);
    for (final move in moves) {
      final after = board.copy()..move(move.from, move.to);
      if (rules.hasWon(after, seat, targetArm)) return move;
    }
    moves.shuffle(_random);
    if (difficulty == Difficulty.easy) return moves.first;

    final ranked = <_Ranked>[
      for (final move in moves) _Ranked(move, _valueAfter(board, move, seat)),
    ]..sort((a, b) => b.value.compareTo(a.value));

    if (difficulty == Difficulty.normal) return ranked.first.move;
    return _deepChoice(board, seat, ranked.take(8).toList());
  }

  /// 高手难度：我的候选着法 × 其他玩家最强回应，取最坏情况下的最优。
  CheckersMove _deepChoice(
    CheckersBoard board,
    int seat,
    List<_Ranked> candidates,
  ) {
    var best = candidates.first;
    var bestValue = double.negativeInfinity;
    for (final candidate in candidates) {
      final after = board.copy()..move(candidate.move.from, candidate.move.to);
      var worst = candidate.value;
      for (var other = 0; other < setup.players; other++) {
        if (other == seat) continue;
        final replies = rules.legalMoves(after, other);
        if (replies.isEmpty) continue;
        final before = _evaluate(after, other);
        var bestGain = 0.0;
        for (final reply in replies) {
          final replyBoard = after.copy()..move(reply.from, reply.to);
          final gain = _evaluate(replyBoard, other) - before;
          if (gain > bestGain) bestGain = gain;
        }
        worst -= bestGain * 0.55;
      }
      if (worst > bestValue) {
        bestValue = worst;
        best = candidate;
      }
    }
    return best.move;
  }

  double _valueAfter(CheckersBoard board, CheckersMove move, int seat) {
    final copy = board.copy()..move(move.from, move.to);
    // 落点本身已经体现了连跳的收益，额外加分会诱发在中央反复跳跃。
    return _evaluate(copy, seat);
  }

  /// 从 [seat] 的视角评估局面：越接近对面营地越好，滞留自家营地会被扣分。
  double _evaluate(CheckersBoard board, int seat) {
    final targetArm = setup.targetArmOf(seat);
    final homeArm = setup.seatArms[seat];
    final distances = _distances.putIfAbsent(
      targetArm,
      () => geometry.distancesToArm(targetArm),
    );
    var score = 0.0;
    for (var hole = 0; hole < board.length; hole++) {
      final owner = board.at(hole);
      if (owner < 0) continue;
      final arm = geometry.armOf(hole);
      if (owner == seat) {
        if (arm == targetArm) {
          score += 40;
        } else {
          score += (14 - distances[hole]) * 2.0;
          if (arm == homeArm) score -= 20;
        }
      } else if (arm == setup.targetArmOf(owner)) {
        // 对手已经进营，延缓他的进度。
        score -= 4.5;
      }
    }
    return score;
  }
}

class _Ranked {
  const _Ranked(this.move, this.value);

  final CheckersMove move;
  final double value;
}
