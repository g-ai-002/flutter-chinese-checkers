import 'dart:math';

import '../models/game_models.dart';
import 'ai_heuristics.dart';
import 'board_geometry.dart';
import 'checkers_board.dart';
import 'checkers_rules.dart';

/// 电脑走子：按难度选择着法。
///
/// - 入门：随机走一步；
/// - 普通：贪心最大化推进与进营评估；
/// - 高手：在候选着法上做带剪枝的多步搜索，并优先完成收官。
class CheckersAi {
  CheckersAi({
    required this.geometry,
    required this.rules,
    required this.setup,
    Difficulty? difficulty,
    Random? random,
  }) : difficulty = difficulty ?? setup.difficulty,
       _random = random ?? Random() {
    _heuristics = AiHeuristics(geometry: geometry, setup: setup);
  }

  /// 根节点最多展开的候选着法数。
  static const int rootBranch = 9;

  /// 对手回应与后续自己着法的展开上限。
  static const int replyBranch = 7;
  static const int followBranch = 4;

  /// 高手难度每步搜索的节点上限，保证界面上不会长时间卡顿。
  static const int nodeBudget = 900;

  final BoardGeometry geometry;
  final CheckersRules rules;
  final GameSetup setup;
  final Difficulty difficulty;
  final Random _random;
  late final AiHeuristics _heuristics;

  /// 最近一次搜索的统计信息，界面与日志用它在出错时定位棋力开销。
  AiSearchStats? lastSearch;

  CheckersMove? chooseMove(CheckersBoard board, int seat) {
    lastSearch = null;
    final moves = rules.legalMoves(board, seat);
    if (moves.isEmpty) return null;
    // 能一步收官就先收官，任何难度都不会错过。
    final targetArm = _heuristics.targetOf(seat);
    for (final move in moves) {
      if (_heuristics.armOf(move.to) != targetArm) continue;
      final after = board.copy()..move(move.from, move.to);
      if (rules.hasWon(after, seat, targetArm)) return move;
    }
    moves.shuffle(_random);
    if (difficulty == Difficulty.easy) return moves.first;

    final ranked = _rank(board, moves, seat);
    if (difficulty == Difficulty.normal) return ranked.first.move;
    return _search(board, seat, ranked);
  }

  /// 高手难度：候选着法 × 对手最佳回应 × 自己的后续，取最坏情况下的最优。
  CheckersMove _search(CheckersBoard board, int seat, List<_Ranked> ranked) {
    final budget = _SearchBudget(nodeBudget);
    final roots = _rootCandidates(board, seat, ranked);
    var best = roots.first;
    var bestValue = double.negativeInfinity;

    for (final candidate in roots) {
      final after = board.copy()..move(candidate.move.from, candidate.move.to);
      budget.nodes++;
      final next = _nextSeat(after, seat);
      final value = _searchValue(after, seat, next, 1, budget, bestValue);
      if (value > bestValue) {
        bestValue = value;
        best = candidate;
      }
    }

    lastSearch = AiSearchStats(
      nodes: budget.nodes,
      depth: _depth,
      candidates: roots.length,
    );
    return best.move;
  }

  /// 根节点候选：常规排名靠前的着法，外加能堵住对手收官空位的防守着法。
  ///
  /// 堵空位通常是后退，静态估值很差，只按排名会被提前裁掉；
  /// 但它可能是唯一避免对手一步获胜的选择。
  List<_Ranked> _rootCandidates(
    CheckersBoard board,
    int seat,
    List<_Ranked> ranked,
  ) {
    final roots = ranked.take(rootBranch).toList();
    final critical = _criticalSlots(board, seat);
    if (critical.isEmpty) return roots;
    for (final candidate in ranked.skip(rootBranch)) {
      if (critical.contains(candidate.move.to)) roots.add(candidate);
    }
    return roots;
  }

  /// 对手目标营地只差一两格就填满时的空位。
  List<int> _criticalSlots(CheckersBoard board, int seat) {
    final slots = <int>[];
    for (var other = 0; other < setup.players; other++) {
      if (other == seat) continue;
      final target = _heuristics.targetOf(other);
      final holes = geometry.armHoles[target];
      var held = 0;
      for (final hole in holes) {
        if (board.at(hole) == other) held++;
      }
      if (held < holes.length - 2) continue;
      for (final hole in holes) {
        if (board.at(hole) != other) slots.add(hole);
      }
    }
    return slots;
  }

  double _searchValue(
    CheckersBoard board,
    int seat,
    int current,
    int ply,
    _SearchBudget budget,
    double alpha,
  ) {
    if (current < 0 || ply >= _depth || budget.exhausted) {
      return _heuristics.evaluate(board, seat);
    }
    final moves = rules.legalMoves(board, current);
    if (moves.isEmpty) {
      return _searchValue(
        board,
        seat,
        _nextSeat(board, current),
        ply,
        budget,
        alpha,
      );
    }

    final maximizing = current == seat;
    final limit = maximizing ? followBranch : replyBranch;
    final top = _rank(board, moves, current).take(limit);
    var best = maximizing ? double.negativeInfinity : double.infinity;

    for (final candidate in top) {
      budget.nodes++;
      final after = board.copy()..move(candidate.move.from, candidate.move.to);
      if (rules.hasWon(after, current, _heuristics.targetOf(current))) {
        return maximizing ? AiHeuristics.winScore : -AiHeuristics.winScore;
      }
      final value = _searchValue(
        after,
        seat,
        _nextSeat(after, current),
        ply + 1,
        budget,
        maximizing ? best : alpha,
      );
      if (maximizing) {
        if (value > best) best = value;
        if (best >= alpha) break;
      } else {
        if (value < best) best = value;
        if (best <= alpha) break;
      }
    }
    return best;
  }

  /// 2 / 3 / 4 人局搜索三个半回合，6 人局按整轮展开太贵，只走两步。
  int get _depth => setup.players <= 4 ? 3 : 2;

  /// 走完 [from] 之后下一个仍有棋可走的座位，全部无棋可走时返回 -1。
  int _nextSeat(CheckersBoard board, int from) {
    for (var step = 1; step <= setup.players; step++) {
      final seat = (from + step) % setup.players;
      if (rules.legalMoves(board, seat).isNotEmpty) return seat;
    }
    return -1;
  }

  List<_Ranked> _rank(CheckersBoard board, List<CheckersMove> moves, int seat) {
    return [
      for (final move in moves) _Ranked(move, _valueAfter(board, move, seat)),
    ]..sort((a, b) => b.value.compareTo(a.value));
  }

  /// 落子后的静态估值；落点本身已体现连跳收益，不额外加分。
  double _valueAfter(CheckersBoard board, CheckersMove move, int seat) {
    final copy = board.copy()..move(move.from, move.to);
    return _heuristics.evaluate(copy, seat);
  }
}

/// 一次搜索的节点数与深度，用于日志与测试。
class AiSearchStats {
  const AiSearchStats({
    required this.nodes,
    required this.depth,
    required this.candidates,
  });

  final int nodes;
  final int depth;
  final int candidates;

  @override
  String toString() => '节点 $nodes, 深度 $depth, 候选 $candidates';
}

class _Ranked {
  const _Ranked(this.move, this.value);

  final CheckersMove move;
  final double value;
}

class _SearchBudget {
  _SearchBudget(this.maxNodes);

  final int maxNodes;
  int nodes = 0;

  bool get exhausted => nodes >= maxNodes;
}
