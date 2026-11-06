import '../models/game_models.dart';
import 'board_geometry.dart';
import 'checkers_board.dart';

/// 局面的静态评估，评分始终从指定座位的视角计算。
///
/// 评估由三部分组成：自己的推进与进营、收官阶段填满目标营地还差多少距离、
/// 对手的进营进度与一步收官威胁。所有项都是「越大越好」。
class AiHeuristics {
  AiHeuristics({required this.geometry, required this.setup})
    : _targets = List<int>.generate(setup.players, setup.targetArmOf),
      _homes = List<int>.of(setup.seatArms),
      _arms = List<int>.generate(geometry.length, geometry.armOf),
      _slotWeights = _weightsOf(geometry);

  /// 已经全部进营的胜势分，任何正常局面的估值都不会接近它。
  static const double winScore = 100000;

  /// 单个棋子进营后的固定分，远高于普通推进。
  static const double _inTarget = 46;

  final BoardGeometry geometry;
  final GameSetup setup;
  final List<int> _targets;
  final List<int> _homes;
  final List<int> _arms;
  final List<int> _slotWeights;
  final Map<int, List<int>> _distanceCache = {};

  int targetOf(int seat) => _targets[seat];

  int armOf(int hole) => _arms[hole];

  double evaluate(CheckersBoard board, int seat) {
    final target = _targets[seat];
    final distances = _distances(target);
    var score = 0.0;
    final outside = <int>[];

    for (var hole = 0; hole < board.length; hole++) {
      if (board.at(hole) != seat) continue;
      if (_arms[hole] == target) {
        score += _inTarget;
        continue;
      }
      outside.add(hole);
      final near = 14 - distances[hole];
      score += near * 2.4;
      if (_arms[hole] == _homes[seat]) score -= 14;
      // 已经贴着营地，再在营外兜圈就浪费了临门机会。
      if (near >= 11) score += 6;
    }

    final slots = _slotsFor(board, target, seat);
    if (slots.isNotEmpty && outside.isNotEmpty) {
      score -= _fillCost(outside, slots, ordered: true);
    }

    for (var other = 0; other < setup.players; other++) {
      if (other == seat) continue;
      final otherTarget = _targets[other];
      final otherDistances = _distances(otherTarget);
      var held = 0;
      final otherOutside = <int>[];
      for (var hole = 0; hole < board.length; hole++) {
        if (board.at(hole) != other) continue;
        if (_arms[hole] == otherTarget) {
          held++;
        } else {
          otherOutside.add(hole);
          score -= (14 - otherDistances[hole]) * 1.35;
        }
      }
      score -= held * 5.4;
      final openSlots = _slotsFor(board, otherTarget, other);
      if (openSlots.isNotEmpty && otherOutside.isNotEmpty) {
        // 填满目标营地所需距离越短，对手越接近收官。
        score -= 60 / (1 + _fillCost(otherOutside, openSlots));
      }
    }
    return score;
  }

  /// 目标营地中尚未被 [seat] 占据的孔位。
  List<int> _slotsFor(CheckersBoard board, int arm, int seat) => [
    for (final hole in geometry.armHoles[arm])
      if (board.at(hole) != seat) hole,
  ];

  /// 估算把 [pieces] 填进 [slots] 的代价：每个空位取最近的一枚棋子。
  ///
  /// 同一枚棋子可能被多个空位重复计入，属于偏保守的近似；
  /// 它只用来比较候选着法的优劣，不参与胜负判定。
  ///
  /// [ordered] 为 true 时按营地的深浅加权：营地深处的孔位应优先填满，
  /// 否则先占住入口会让剩下的棋子再也进不来，对局就会卡在 9/10。
  double _fillCost(List<int> pieces, List<int> slots, {bool ordered = false}) {
    var total = 0.0;
    for (final slot in slots) {
      var nearest = 99;
      for (final piece in pieces) {
        final d = geometry.distance(piece, slot);
        if (d < nearest) nearest = d;
      }
      total += ordered
          ? _slotWeights[slot] * (5.0 + nearest * 1.2)
          : nearest.toDouble();
    }
    return total;
  }

  List<int> _distances(int arm) =>
      _distanceCache.putIfAbsent(arm, () => geometry.distancesToArm(arm));

  /// 每个营地孔位的深浅权重：越靠营地尖端权重越大（1 到 4）。
  static List<int> _weightsOf(BoardGeometry geometry) {
    final weights = List<int>.filled(geometry.length, 0);
    final origin = geometry.holeAt(0, 0)!;
    for (final holes in geometry.armHoles) {
      var min = 99;
      for (final hole in holes) {
        final d = geometry.distance(hole, origin);
        if (d < min) min = d;
      }
      for (final hole in holes) {
        weights[hole] = geometry.distance(hole, origin) - min + 1;
      }
    }
    return weights;
  }
}
