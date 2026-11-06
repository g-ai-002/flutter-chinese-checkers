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
    this.maxNodes = nodeBudget,
  }) : difficulty = difficulty ?? setup.difficulty,
       _random = random ?? Random() {
    _heuristics = AiHeuristics(geometry: geometry, setup: setup);
  }

  /// 根节点最多展开的候选着法数。
  static const int rootBranch = 9;

  /// 对手回应与后续自己着法的展开上限。
  static const int replyBranch = 7;
  static const int followBranch = 4;

  /// 高手难度默认的每步搜索节点上限，保证界面上不会长时间卡顿。
  static const int nodeBudget = 900;

  /// 对手营地只差这么多格（含）就填满时，视为一步收官的威胁。
  static const int _criticalGap = 2;

  final BoardGeometry geometry;
  final CheckersRules rules;
  final GameSetup setup;
  final Difficulty difficulty;
  final Random _random;

  /// 单步搜索允许展开的节点数，测试可以调小以覆盖预算耗尽的分支。
  final int maxNodes;

  late final AiHeuristics _heuristics;

  /// 最近一次搜索的统计信息，界面与日志用它在出错时定位棋力开销。
  AiSearchStats? lastSearch;

  CheckersMove? chooseMove(CheckersBoard board, int seat) {
    lastSearch = null;
    final moves = rules.legalMoves(board, seat);
    if (moves.isEmpty) return null;
    // 能一步收官就先收官，任何难度都不会错过。
    final winning = _winningMove(board, seat, moves);
    if (winning != null) return winning;

    moves.shuffle(_random);
    if (difficulty == Difficulty.easy) return moves.first;

    final rated = _rate(board, moves, seat);
    if (difficulty == Difficulty.normal) return rated.first.move;
    return _search(board, seat, rated);
  }

  /// 一步进营即可获胜的着法；没有则返回 null。
  CheckersMove? _winningMove(
    CheckersBoard board,
    int seat,
    List<CheckersMove> moves,
  ) {
    final target = _heuristics.targetOf(seat);
    for (final move in moves) {
      if (_heuristics.armOf(move.to) != target) continue;
      final after = board.copy()..move(move.from, move.to);
      if (rules.hasWon(after, seat, target)) return move;
    }
    return null;
  }

  /// 高手难度：候选着法 × 对手最佳回应 × 自己的后续，取最坏情况下的最优。
  CheckersMove _search(CheckersBoard board, int seat, List<_RatedMove> rated) {
    final budget = _SearchBudget(maxNodes);
    final roots = _rootCandidates(board, seat, rated);
    var best = roots.first;
    var bestValue = double.negativeInfinity;

    for (final candidate in roots) {
      if (!budget.trySpend()) break;
      final after = board.copy()..move(candidate.move.from, candidate.move.to);
      final next = rules.nextSeat(after, seat, setup.players);
      final value = _searchValue(
        after,
        seat,
        next,
        1,
        budget,
        _SearchWindow(bestValue, double.infinity),
      );
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
  List<_RatedMove> _rootCandidates(
    CheckersBoard board,
    int seat,
    List<_RatedMove> rated,
  ) {
    final roots = rated.take(rootBranch).toList();
    final critical = _criticalSlots(board, seat);
    if (critical.isEmpty) return roots;
    for (final candidate in rated.skip(rootBranch)) {
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
      if (held < holes.length - _criticalGap) continue;
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
    _SearchWindow window,
  ) {
    if (current < 0 || ply >= _depth || budget.exhausted) {
      return _heuristics.evaluate(board, seat);
    }
    final moves = rules.legalMoves(board, current);
    if (moves.isEmpty) {
      return _searchValue(
        board,
        seat,
        rules.nextSeat(board, current, setup.players),
        ply,
        budget,
        window,
      );
    }

    final maximizing = current == seat;
    final limit = maximizing ? followBranch : replyBranch;
    final candidates = _rate(board, moves, current).take(limit);

    if (maximizing) {
      var best = double.negativeInfinity;
      var alpha = window.alpha;
      for (final candidate in candidates) {
        if (!budget.trySpend()) break;
        final after = board.copy()
          ..move(candidate.move.from, candidate.move.to);
        if (rules.hasWon(after, current, _heuristics.targetOf(current))) {
          return AiHeuristics.winScore;
        }
        final value = _searchValue(
          after,
          seat,
          rules.nextSeat(after, current, setup.players),
          ply + 1,
          budget,
          _SearchWindow(alpha, window.beta),
        );
        if (value > best) best = value;
        if (best > alpha) alpha = best;
        if (alpha >= window.beta) break;
      }
      return best.isFinite ? best : _heuristics.evaluate(board, seat);
    }

    var best = double.infinity;
    var beta = window.beta;
    for (final candidate in candidates) {
      if (!budget.trySpend()) break;
      final after = board.copy()..move(candidate.move.from, candidate.move.to);
      if (rules.hasWon(after, current, _heuristics.targetOf(current))) {
        return -AiHeuristics.winScore;
      }
      final value = _searchValue(
        after,
        seat,
        rules.nextSeat(after, current, setup.players),
        ply + 1,
        budget,
        _SearchWindow(window.alpha, beta),
      );
      if (value < best) best = value;
      if (best < beta) beta = best;
      if (window.alpha >= beta) break;
    }
    return best.isFinite ? best : _heuristics.evaluate(board, seat);
  }

  /// 2 / 3 / 4 人局搜索三个半回合，6 人局按整轮展开太贵，只走两步。
  int get _depth => setup.players <= 4 ? 3 : 2;

  /// 按指定座位评估落子后的局面，并按评分降序排列。
  List<_RatedMove> _rate(
    CheckersBoard board,
    List<CheckersMove> moves,
    int seat,
  ) {
    return [
      for (final move in moves)
        _RatedMove(move, _valueAfter(board, move, seat)),
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

class _RatedMove {
  const _RatedMove(this.move, this.value);

  final CheckersMove move;
  final double value;
}

/// alpha-beta 的搜索窗口，[alpha] 是已确保的下界，[beta] 是上界。
class _SearchWindow {
  const _SearchWindow(this.alpha, this.beta);

  final double alpha;
  final double beta;
}

class _SearchBudget {
  _SearchBudget(this.maxNodes);

  final int maxNodes;
  int nodes = 0;

  bool get exhausted => nodes >= maxNodes;

  /// 申请展开一个节点；预算用尽时返回 false，调用方必须停止循环。
  bool trySpend() {
    if (exhausted) return false;
    nodes++;
    return true;
  }
}
