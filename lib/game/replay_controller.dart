import 'dart:async';
import 'dart:collection';

import 'package:flutter/foundation.dart';

import '../models/game_models.dart';
import 'board_geometry.dart';
import 'board_source.dart';
import 'checkers_board.dart';
import 'checkers_rules.dart';
import 'move_record.dart';

/// 复盘中的一手：着法本身，加上走完后的进营情况。
class ReplayStep {
  const ReplayStep({
    required this.record,
    required this.progress,
    required this.landedInCamp,
    required this.progressGain,
    required this.score,
  });

  final MoveRecord record;

  /// 这一手走完后，本方在目标营地里的棋子数。
  final int progress;

  /// 这一手是否把棋子直接送进了目标营地。
  final bool landedInCamp;

  /// 这一手让本方营地里的棋子增加了多少（通常为 0 或 1）。
  final int progressGain;

  /// 复盘亮点评分：进营权重最高，其次是比较连跳长度。
  final int score;
}

/// 复盘控制器：按记录逐手重建局面，支持前后跳转与自动播放。
///
/// 与 [CheckersController] 一样实现 [BoardSource]，因此可以复用同一套棋盘渲染。
class ReplayController extends ChangeNotifier implements BoardSource {
  ReplayController({
    required this.setup,
    required List<MoveRecord> records,
    BoardGeometry? geometry,
    this.playInterval = const Duration(milliseconds: 820),
  }) : geometry = geometry ?? BoardGeometry.star(),
       _records = List<MoveRecord>.unmodifiable(records) {
    board = CheckersBoard.initial(this.geometry, setup.seatArms);
    _buildSteps();
  }

  @override
  final GameSetup setup;

  @override
  final BoardGeometry geometry;

  /// 自动播放时每一手的间隔。
  final Duration playInterval;

  final List<MoveRecord> _records;
  final List<ReplayStep> _steps = [];
  final List<MoveRecord> _visible = [];
  int? _bestIndex;
  late final UnmodifiableListView<MoveRecord> _historyView =
      UnmodifiableListView(_visible);
  late final UnmodifiableListView<ReplayStep> _stepsView = UnmodifiableListView(
    _steps,
  );

  @override
  late CheckersBoard board;

  int _index = 0;
  bool _playing = false;
  int _epoch = 0;
  int _animationStart = 0;
  bool _disposed = false;

  @override
  int get players => setup.players;

  @override
  int get animationStartIndex => _animationStart;

  @override
  int? get selectedHole => null;

  @override
  Map<int, CheckersMove> get targets => const {};

  @override
  CheckersMove? get hintMove => null;

  List<ReplayStep> get steps => _stepsView;

  @override
  List<MoveRecord> get history => _historyView;

  /// 已经回放的手数。
  int get index => _index;

  int get total => _records.length;

  bool get isPlaying => _playing;

  bool get atStart => _index == 0;

  bool get atEnd => _index >= total;

  /// 当前进度对应的最后一手，开局为 null。
  ReplayStep? get currentStep => _index == 0 ? null : _steps[_index - 1];

  /// 本局最佳着法的序号（1 起），没有可圈可点的着法时为 null。
  int? get bestMoveNumber {
    final index = _bestIndex;
    return index == null ? null : index + 1;
  }

  ReplayStep? get bestStep {
    final index = _bestIndex;
    return index == null ? null : _steps[index];
  }

  /// 只有进营或跳跃才算亮点，纯单步的开局不强行制造「最佳」。
  bool get hasBestMove => (bestStep?.score ?? 0) > 0;

  void _buildSteps() {
    final probe = CheckersBoard.initial(geometry, setup.seatArms);
    final progressBySeat = List<int>.filled(setup.players, 0);
    for (final record in _records) {
      final targetArm = setup.targetArmOf(record.seat);
      final before = progressBySeat[record.seat];
      probe.move(record.move.from, record.move.to);
      final progress = probe.countInArm(geometry, record.seat, targetArm);
      progressBySeat[record.seat] = progress;
      final gain = progress - before;
      final landedInCamp = geometry.armOf(record.move.to) == targetArm;
      final score =
          gain * 100 + record.move.jumpCount * 10 + (landedInCamp ? 5 : 0);
      _steps.add(
        ReplayStep(
          record: record,
          progress: progress,
          landedInCamp: landedInCamp,
          progressGain: gain,
          score: score,
        ),
      );
    }
    for (var i = 0; i < _steps.length; i++) {
      final best = _bestIndex;
      if (best == null || _steps[i].score > _steps[best].score) _bestIndex = i;
    }
  }

  /// 跳到第 [target] 手之后（0 表示开局）。手动跳转会暂停自动播放，
  /// 拖动进度条或直接跳转直接切换局面，不播放动画。
  void seekTo(int target) => _jumpTo(target);

  /// 向前一手：保留这一手的走子动画。
  void next() => _jumpTo(_index + 1, animate: true);

  void previous() => _jumpTo(_index - 1);

  void toStart() => _jumpTo(0);

  void toEnd() => _jumpTo(total);

  void _jumpTo(int target, {bool animate = false}) {
    final wasPlaying = _playing;
    _stopPlayback();
    final moved = _seek(target.clamp(0, total), animate: animate);
    if (moved || wasPlaying) notifyListeners();
  }

  /// 从当前进度自动播放；已经在终点时从头开始。
  void play() {
    if (_disposed || total == 0 || _playing) return;
    if (atEnd) _seek(0);
    _playing = true;
    notifyListeners();
    _scheduleTick();
  }

  void pause() {
    if (!_playing) return;
    _stopPlayback();
    notifyListeners();
  }

  void togglePlay() => _playing ? pause() : play();

  void _scheduleTick() {
    final epoch = ++_epoch;
    Future<void>.delayed(playInterval, () {
      if (_disposed || !_playing || epoch != _epoch) return;
      if (atEnd) {
        _playing = false;
        notifyListeners();
        return;
      }
      _seek(_index + 1, animate: true);
      notifyListeners();
      _scheduleTick();
    });
  }

  void _stopPlayback() {
    if (!_playing) return;
    _playing = false;
    _epoch++;
  }

  /// 重建到第 [target] 手。向前只补走增量，向后才从开局重放。
  ///
  /// 自动播放逐手前进时因此是 O(1)，拖动进度条回退时才整局重放。
  bool _seek(int target, {bool animate = false}) {
    if (_disposed) return false;
    if (target == _index) return false;

    // 只有逐手前进才播放刚走出的一手；批量跳转与后退直接切到目标局面。
    _animationStart = animate && target == _index + 1 ? target - 1 : target;

    if (target > _index) {
      for (var i = _index; i < target; i++) {
        final move = _records[i].move;
        board.move(move.from, move.to);
      }
    } else {
      board = CheckersBoard.initial(geometry, setup.seatArms);
      for (var i = 0; i < target; i++) {
        final move = _records[i].move;
        board.move(move.from, move.to);
      }
    }

    _index = target;
    _visible
      ..clear()
      ..addAll(_records.take(target));
    return true;
  }

  @override
  void tapHole(int hole) {
    // 复盘只读，点击棋盘不改变局面。
  }

  @override
  void dispose() {
    _disposed = true;
    _epoch++;
    super.dispose();
  }
}
