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

  /// 棋盘上距离目标营地最远的格数，用来把距离换算成「还差多远」。
  static const int _farDistance = 14;

  /// 自己的棋子已经贴着目标营地（差 3 格以内）时的额外奖励。
  static const int _nearTargetDistance = 11;
  static const double _nearTargetBonus = 6;

  static const double _ownInTarget = 46;
  static const double _ownAdvance = 2.4;
  static const double _ownHomePenalty = 14;

  static const double _opponentInTarget = 5.4;
  static const double _opponentAdvance = 1.35;
  static const double _opponentFillPressure = 60;

  /// 预估把棋子填进空位的代价：每格距离的分值，以及营地深浅的基数。
  static const double _fillBase = 5;
  static const double _fillPerStep = 1.2;

  /// 计算最近棋子时使用的哨兵值，六角星棋盘上任意两点都远小于它。
  static const int _noPieceDistance = 99;

  final BoardGeometry geometry;
  final GameSetup setup;
  final List<int> _targets;
  final List<int> _homes;
  final List<int> _arms;
  final List<int> _slotWeights;
  final Map<int, List<int>> _distanceCache = {};

  /// 估值期间复用的临时容器：搜索每步会评估上千次，避免反复分配列表。
  late final List<List<int>> _groups = List.generate(
    setup.players,
    (_) => <int>[],
  );
  final List<int> _outside = [];
  final List<int> _slots = [];

  int targetOf(int seat) => _targets[seat];

  int armOf(int hole) => _arms[hole];

  double evaluate(CheckersBoard board, int seat) {
    final pieces = _piecesBySeat(board);
    final target = _targets[seat];
    var score = _ownScore(pieces[seat], board, seat, target);

    for (var other = 0; other < setup.players; other++) {
      if (other == seat) continue;
      score += _opponentScore(pieces[other], board, other, _targets[other]);
    }
    return score;
  }

  /// 一次遍历把棋子按座位分组，避免每位对手都重扫整块棋盘。
  ///
  /// 分组列表在实例内复用，下一轮估值直接清空重填。
  List<List<int>> _piecesBySeat(CheckersBoard board) {
    for (final group in _groups) {
      group.clear();
    }
    for (var hole = 0; hole < board.length; hole++) {
      final owner = board.at(hole);
      if (owner >= 0 && owner < setup.players) _groups[owner].add(hole);
    }
    return _groups;
  }

  double _ownScore(
    List<int> pieces,
    CheckersBoard board,
    int seat,
    int target,
  ) {
    final distances = _distances(target);
    var score = 0.0;
    _outside.clear();

    for (final hole in pieces) {
      if (_arms[hole] == target) {
        score += _ownInTarget;
        continue;
      }
      _outside.add(hole);
      final near = _farDistance - distances[hole];
      score += near * _ownAdvance;
      // 已经贴着营地，再在营外兜圈就浪费了临门机会。
      if (_arms[hole] == _homes[seat]) score -= _ownHomePenalty;
      if (near >= _nearTargetDistance) score += _nearTargetBonus;
    }

    _openSlots(board, target, seat);
    if (_slots.isNotEmpty && _outside.isNotEmpty) {
      score -= _fillCost(_outside, _slots, ordered: true);
    }
    return score;
  }

  double _opponentScore(
    List<int> pieces,
    CheckersBoard board,
    int other,
    int target,
  ) {
    final distances = _distances(target);
    var score = 0.0;
    var held = 0;
    _outside.clear();

    for (final hole in pieces) {
      if (_arms[hole] == target) {
        held++;
        continue;
      }
      _outside.add(hole);
      score -= (_farDistance - distances[hole]) * _opponentAdvance;
    }
    score -= held * _opponentInTarget;

    _openSlots(board, target, other);
    if (_slots.isNotEmpty && _outside.isNotEmpty) {
      // 填满目标营地所需距离越短，对手越接近收官。
      score -= _opponentFillPressure / (1 + _fillCost(_outside, _slots));
    }
    return score;
  }

  /// 把目标营地中尚未被 [seat] 占据的孔位写入复用的 [_slots]。
  void _openSlots(CheckersBoard board, int arm, int seat) {
    _slots.clear();
    for (final hole in geometry.armHoles[arm]) {
      if (board.at(hole) != seat) _slots.add(hole);
    }
  }

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
      var nearest = _noPieceDistance;
      for (final piece in pieces) {
        final d = geometry.distance(piece, slot);
        if (d < nearest) nearest = d;
      }
      total += ordered
          ? _slotWeights[slot] * (_fillBase + nearest * _fillPerStep)
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
      var min = _noPieceDistance;
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
