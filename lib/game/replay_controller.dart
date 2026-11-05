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
  });

  final MoveRecord record;

  /// 这一手走完后，本方在目标营地里的棋子数。
  final int progress;

  /// 这一手是否把棋子直接送进了目标营地。
  final bool landedInCamp;
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
  bool _disposed = false;

  @override
  int get players => setup.players;

  @override
  bool get supportsMoveAnimation => false;

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

  void _buildSteps() {
    final probe = CheckersBoard.initial(geometry, setup.seatArms);
    for (final record in _records) {
      probe.move(record.move.from, record.move.to);
      final targetArm = setup.targetArmOf(record.seat);
      _steps.add(
        ReplayStep(
          record: record,
          progress: probe.countInArm(geometry, record.seat, targetArm),
          landedInCamp: geometry.armOf(record.move.to) == targetArm,
        ),
      );
    }
  }

  /// 跳到第 [target] 手之后（0 表示开局）。手动跳转会暂停自动播放。
  void seekTo(int target) {
    final wasPlaying = _playing;
    _stopPlayback();
    final moved = _seek(target.clamp(0, total));
    if (moved || wasPlaying) notifyListeners();
  }

  void next() => seekTo(_index + 1);

  void previous() => seekTo(_index - 1);

  void toStart() => seekTo(0);

  void toEnd() => seekTo(total);

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
      _seek(_index + 1);
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
  bool _seek(int target) {
    if (_disposed) return false;
    if (target == _index) return false;

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
