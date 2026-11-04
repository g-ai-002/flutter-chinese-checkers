import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';

import '../models/game_models.dart';
import '../services/log_service.dart';
import 'board_geometry.dart';
import 'checkers_ai.dart';
import 'checkers_board.dart';
import 'checkers_rules.dart';

/// 一条已完成的着法记录。
class MoveRecord {
  const MoveRecord({required this.seat, required this.move});

  final int seat;
  final CheckersMove move;
}

/// 对局控制器：维护局面、轮次、选子与悔棋，并在电脑回合自动走子。
///
/// 所有状态变化都通过 [notifyListeners] 通知界面；电脑走子使用延时任务，
/// 用 [_epoch] 令牌保证悔棋、重开后旧任务不会落子。
class CheckersController extends ChangeNotifier {
  CheckersController({
    required this.setup,
    BoardGeometry? geometry,
    Random? random,
    this.aiDelay = const Duration(milliseconds: 520),
  }) : geometry = geometry ?? BoardGeometry.star(),
       _random = random ?? Random() {
    rules = CheckersRules(this.geometry);
    _ai = CheckersAi(
      geometry: this.geometry,
      rules: rules,
      setup: setup,
      random: _random,
    );
    _hintAi = CheckersAi(
      geometry: this.geometry,
      rules: rules,
      setup: setup,
      difficulty: Difficulty.hard,
      random: _random,
    );
    _resetState();
  }

  /// 连续这么多步没有新棋子进营即判和。
  static const int maxQuietPlies = 120;

  final GameSetup setup;
  final BoardGeometry geometry;
  final Duration aiDelay;
  final Random _random;

  late final CheckersRules rules;
  late final CheckersAi _ai;
  late final CheckersAi _hintAi;

  late CheckersBoard board;
  int currentSeat = 0;
  int? winner;
  bool isDraw = false;
  bool isAiThinking = false;
  CheckersMove? hintMove;
  int? selectedHole;
  final Map<int, CheckersMove> _targets = {};
  final List<MoveRecord> history = [];
  final List<_Snapshot> _undoStack = [];
  DateTime? _startedAt;
  Duration _duration = Duration.zero;
  int _quietPlies = 0;
  int _epoch = 0;
  int _hintEpoch = 0;
  bool _disposed = false;

  List<MoveRecord> get records => List.unmodifiable(history);

  int get players => setup.players;

  bool get isFinished => winner != null || isDraw;

  bool get isHumanTurn => setup.isHuman(currentSeat);

  CheckersMove? get lastMove => history.isEmpty ? null : history.last.move;

  Set<int> get targetHoles => _targets.keys.toSet();

  Duration get duration => winner == null
      ? (_startedAt == null
            ? Duration.zero
            : DateTime.now().difference(_startedAt!))
      : _duration;

  bool get canUndo {
    if (history.isEmpty) return false;
    if (setup.mode == PlayMode.local) return true;
    return history.any((record) => record.seat == setup.humanSeat);
  }

  int progressOf(int seat) =>
      rules.progress(board, seat, setup.targetArmOf(seat));

  int distanceToGoal(int hole, int seat) =>
      geometry.distancesToArm(setup.targetArmOf(seat))[hole];

  /// 选中棋子后可以直接落子的孔位。
  Map<int, CheckersMove> get targets => Map.unmodifiable(_targets);

  void start() {
    if (_startedAt != null) return;
    _startedAt = DateTime.now();
    LogService.info(
      '开始对局: ${setup.mode.label}, ${setup.playerCount.label}, '
      '难度 ${setup.difficulty.label}, 人类座位 ${setup.humanSeat + 1}',
    );
    _scheduleAiIfNeeded();
  }

  /// 点击孔位：先尝试落子，再尝试选子，否则取消选择。
  void tapHole(int hole) {
    if (_disposed || isFinished || isAiThinking) return;
    if (!isHumanTurn) return;
    final move = _targets[hole];
    if (move != null) {
      applyMove(move);
      return;
    }
    if (board.at(hole) == currentSeat) {
      _select(hole);
      return;
    }
    if (selectedHole != null) {
      selectedHole = null;
      _targets.clear();
      notifyListeners();
    }
  }

  void _select(int hole) {
    selectedHole = hole;
    _targets.clear();
    for (final move in rules.movesFrom(board, hole)) {
      final existing = _targets[move.to];
      if (existing == null || move.jumpCount < existing.jumpCount) {
        _targets[move.to] = move;
      }
    }
    notifyListeners();
  }

  void applyMove(CheckersMove move) {
    if (_disposed) return;
    _undoStack.add(
      _Snapshot(
        cells: List<int>.of(board.cells),
        seat: currentSeat,
        historyLength: history.length,
      ),
    );
    final progressBefore = progressOf(currentSeat);
    board.move(move.from, move.to);
    history.add(MoveRecord(seat: currentSeat, move: move));
    // 长时间没有新棋子进营说明局面停滞，判和避免无休止消耗。
    _quietPlies = progressOf(currentSeat) > progressBefore
        ? 0
        : _quietPlies + 1;
    selectedHole = null;
    _targets.clear();
    hintMove = null;
    final mover = currentSeat;

    if (rules.hasWon(board, mover, setup.targetArmOf(mover))) {
      winner = mover;
      _duration = _startedAt == null
          ? Duration.zero
          : DateTime.now().difference(_startedAt!);
      LogService.info(
        '对局结束: ${setup.seatLabel(mover)} 获胜, ${history.length} 步, '
        '${_duration.inSeconds}s',
      );
      notifyListeners();
      return;
    }

    if (_quietPlies >= maxQuietPlies) {
      isDraw = true;
      _duration = _startedAt == null
          ? Duration.zero
          : DateTime.now().difference(_startedAt!);
      LogService.warning('对局判和: 连续 $maxQuietPlies 步没有棋子进营');
      notifyListeners();
      return;
    }

    if (!_advanceTurn()) {
      isDraw = true;
      _duration = _startedAt == null
          ? Duration.zero
          : DateTime.now().difference(_startedAt!);
      LogService.warning('对局陷入僵局: 所有玩家均无合法着法');
      notifyListeners();
      return;
    }
    notifyListeners();
    _scheduleAiIfNeeded();
  }

  /// 轮到下一位仍有棋可走的玩家；全部无棋可走时返回 false。
  bool _advanceTurn() {
    for (var step = 1; step <= players; step++) {
      final next = (currentSeat + step) % players;
      if (rules.legalMoves(board, next).isNotEmpty) {
        currentSeat = next;
        return true;
      }
    }
    return false;
  }

  void _scheduleAiIfNeeded() {
    if (_disposed || isFinished) return;
    if (!setup.isAi(currentSeat)) return;
    final epoch = ++_epoch;
    isAiThinking = true;
    notifyListeners();
    Future<void>.delayed(aiDelay, () {
      if (_disposed || epoch != _epoch || isFinished) return;
      final move = _ai.chooseMove(board, currentSeat);
      isAiThinking = false;
      if (move == null) {
        final advanced = _advanceTurn();
        if (!advanced) {
          isDraw = true;
          _duration = _startedAt == null
              ? Duration.zero
              : DateTime.now().difference(_startedAt!);
          LogService.warning('对局陷入僵局: 所有玩家均无合法着法');
        }
        notifyListeners();
        if (advanced) _scheduleAiIfNeeded();
        return;
      }
      applyMove(move);
    });
  }

  /// 悔棋：同屏模式退一手；人机模式回退到上一次自己走棋之前。
  void undo() {
    if (!canUndo) return;
    _epoch++;
    _hintEpoch++;
    isAiThinking = false;
    while (_undoStack.isNotEmpty) {
      final snapshot = _undoStack.removeLast();
      _restore(snapshot);
      if (setup.mode == PlayMode.local) break;
      if (currentSeat == setup.humanSeat) break;
    }
    winner = null;
    isDraw = false;
    _quietPlies = 0;
    selectedHole = null;
    _targets.clear();
    hintMove = null;
    notifyListeners();
    _scheduleAiIfNeeded();
  }

  void _restore(_Snapshot snapshot) {
    board = CheckersBoard(snapshot.cells);
    currentSeat = snapshot.seat;
    while (history.length > snapshot.historyLength) {
      history.removeLast();
    }
  }

  void restart() {
    _epoch++;
    _hintEpoch++;
    isAiThinking = false;
    _resetState();
    notifyListeners();
    _startedAt = DateTime.now();
    LogService.info('重新开始对局');
    _scheduleAiIfNeeded();
  }

  void _resetState() {
    board = CheckersBoard.initial(geometry, setup.seatArms);
    currentSeat = 0;
    winner = null;
    isDraw = false;
    selectedHole = null;
    hintMove = null;
    _targets.clear();
    history.clear();
    _undoStack.clear();
    _duration = Duration.zero;
    _quietPlies = 0;
    _startedAt = null;
  }

  /// 请求一步提示，6 秒后自动收起。
  void requestHint() {
    if (isFinished || !isHumanTurn) return;
    final move = _hintAi.chooseMove(board, currentSeat);
    if (move == null) return;
    hintMove = move;
    final epoch = ++_hintEpoch;
    notifyListeners();
    Future<void>.delayed(const Duration(seconds: 6), () {
      if (_disposed || epoch != _hintEpoch) return;
      hintMove = null;
      notifyListeners();
    });
  }

  @override
  void dispose() {
    _disposed = true;
    _epoch++;
    _hintEpoch++;
    super.dispose();
  }
}

class _Snapshot {
  const _Snapshot({
    required this.cells,
    required this.seat,
    required this.historyLength,
  });

  final List<int> cells;
  final int seat;
  final int historyLength;
}
