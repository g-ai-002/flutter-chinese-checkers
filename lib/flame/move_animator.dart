import 'dart:math' as math;

import '../game/checkers_rules.dart';

/// 一手棋的播放状态。
///
/// [cells] 是这手棋走完后的局面快照。连续落子时后续着法可能已经改写棋盘，
/// 播放早期着法必须依赖自己的快照，否则会出现棋子瞬移或残影。
///
/// [leadIn] 是走子前的预高亮时长：这段时间棋子停在起点并闪烁，进度仍为 0。
class MoveAnimation {
  MoveAnimation({required this.move, required List<int> cells, this.leadIn = 0})
    : cells = List<int>.of(cells),
      duration = 0.16 + 0.05 * math.min(move.landings.length - 1, 6);

  final CheckersMove move;
  final List<int> cells;

  /// 单步 0.16 秒，每多一跳增加 0.05 秒，最长 0.46 秒。
  final double duration;

  /// 走子前的预高亮秒数（由棋盘源的 `animationLeadIn` 换算）。
  final double leadIn;

  double elapsed = 0;

  bool get previewing => elapsed < leadIn;

  double get total => leadIn + duration;

  /// 走子进度：预高亮阶段恒为 0。
  double get progress => ((elapsed - leadIn) / duration).clamp(0.0, 1.0);

  bool get isDone => elapsed >= total;
}

/// 走子动画队列：按发生顺序播放，真实棋盘领先时不会丢弃或截断动画。
class MoveAnimator {
  final List<MoveAnimation> _queue = [];

  MoveAnimation? get current => _queue.isEmpty ? null : _queue.first;

  bool get isAnimating => _queue.isNotEmpty;

  int get pending => _queue.length;

  void enqueue(CheckersMove move, List<int> cells, {double leadIn = 0}) {
    _queue.add(MoveAnimation(move: move, cells: cells, leadIn: leadIn));
  }

  /// 推进时间，播完的动画立即出队，剩余时间顺延给下一手。
  void advance(double dt) {
    var remaining = dt <= 0 ? 0.0 : dt;
    while (_queue.isNotEmpty) {
      final anim = _queue.first;
      final left = anim.total - anim.elapsed;
      if (remaining < left) {
        anim.elapsed += remaining;
        return;
      }
      remaining -= left;
      _queue.removeAt(0);
    }
  }

  void clear() => _queue.clear();
}
