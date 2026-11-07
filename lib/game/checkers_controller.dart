import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';

import '../models/game_models.dart';
import '../services/log_service.dart';
import 'board_geometry.dart';
import 'board_source.dart';
import 'checkers_ai.dart';
import 'checkers_board.dart';
import 'checkers_rules.dart';
import 'move_record.dart';

export 'move_record.dart';

/// 对局控制器：维护局面、轮次、选子与悔棋，并在电脑回合自动走子。
///
/// 所有状态变化都通过 [notifyListeners] 通知界面；电脑走子使用延时任务，
/// 用 [_epoch] 令牌保证悔棋、重开后旧任务不会落子。
class CheckersController extends ChangeNotifier implements BoardSource {
  CheckersController({
    required this.setup,
    BoardGeometry? geometry,
    Random? random,
    this.aiDelay = const Duration(milliseconds: 520),
    this.allowUndo = true,
  }) : geometry = geometry ?? BoardGeometry.star(),
       _random = random ?? Random() {
    rules = CheckersRules(this.geometry);
    _ai = _createAi();
    // 提示用独立随机源：查看提示不应改变电脑后续走子的随机结果。
    _hintAi = _createAi(difficulty: Difficulty.hard, random: Random());
    _resetState();
  }

  CheckersAi _createAi({Difficulty? difficulty, Random? random}) => CheckersAi(
    geometry: geometry,
    rules: rules,
    setup: setup,
    difficulty: difficulty,
    random: random ?? _random,
  );

  /// 连续这么多步没有新棋子进营即判和。
  static const int maxQuietPlies = 120;

  @override
  final GameSetup setup;
  @override
  final BoardGeometry geometry;
  final Duration aiDelay;

  /// 残局模式禁用悔棋，成绩才有可比性。
  final bool allowUndo;
  final Random _random;

  late final CheckersRules rules;
  late final CheckersAi _ai;
  late final CheckersAi _hintAi;

  @override
  late CheckersBoard board;
  int currentSeat = 0;
  int? winner;
  bool isDraw = false;
  bool isAiThinking = false;
  @override
  CheckersMove? hintMove;
  @override
  int? selectedHole;
  final Map<int, CheckersMove> _movesByTarget = {};
  @override
  final List<MoveRecord> history = [];
  final List<_Snapshot> _undoStack = [];
  DateTime? _startedAt;
  Duration _duration = Duration.zero;
  int _quietPlies = 0;
  int _epoch = 0;
  int _hintEpoch = 0;
  bool _disposed = false;

  List<MoveRecord> get records => List.unmodifiable(history);

  /// 残局只有己方一方走子，障碍子永远不轮到。
  @override
  int get players => setup.isChallenge ? 1 : setup.players;

  @override
  int get animationStartIndex => 0;

  /// 实时对局走子即是操作反馈，不需要额外的预高亮。
  @override
  Duration get animationLeadIn => Duration.zero;

  bool get isFinished => winner != null || isDraw;

  bool get isHumanTurn => setup.isHuman(currentSeat);

  int? get movesLeft {
    final limit = setup.challenge?.moveLimit;
    if (limit == null) return null;
    return (limit - history.length).clamp(0, limit);
  }

  CheckersMove? get lastMove => history.isEmpty ? null : history.last.move;

  Set<int> get targetHoles => _movesByTarget.keys.toSet();

  /// 连续多少手没有新棋子进营，供测试校验悔棋后的恢复。
  @visibleForTesting
  int get quietPlies => _quietPlies;

  Duration get _elapsed => _startedAt == null
      ? Duration.zero
      : DateTime.now().difference(_startedAt!);

  Duration get duration => isFinished ? _duration : _elapsed;

  bool get canUndo {
    if (!allowUndo || setup.isChallenge || history.isEmpty) return false;
    if (setup.mode == PlayMode.local) return true;
    return history.any((record) => record.seat == setup.humanSeat);
  }

  int progressOf(int seat) =>
      rules.progress(board, seat, setup.targetArmOf(seat));

  @override
  Map<int, CheckersMove> get targets => Map.unmodifiable(_movesByTarget);

  void start() {
    if (_startedAt != null) return;
    _startedAt = DateTime.now();
    final challenge = setup.challenge;
    if (challenge != null) {
      LogService.info(
        '开始残局: ${challenge.id} ${challenge.name}, '
        '预算 ${challenge.moveLimit} 步, 参考 ${challenge.parMoves} 步',
      );
    } else {
      LogService.info(
        '开始对局: ${setup.mode.label}, ${setup.playerCount.label}, '
        '难度 ${setup.difficulty.label}, 人类座位 ${setup.humanSeat + 1}',
      );
    }
    _scheduleAiIfNeeded();
  }

  /// 点击孔位：先尝试落子，再尝试选子，否则取消选择。
  @override
  void tapHole(int hole) {
    if (_disposed || isFinished || isAiThinking) return;
    if (!isHumanTurn) return;
    final move = _movesByTarget[hole];
    if (move != null) {
      applyMove(move);
      return;
    }
    if (board.at(hole) == currentSeat) {
      _select(hole);
      return;
    }
    if (selectedHole != null) {
      _clearSelection();
      notifyListeners();
    }
  }

  void _select(int hole) {
    selectedHole = hole;
    if (hintMove != null && hintMove!.from != hole) hintMove = null;
    _movesByTarget.clear();
    for (final move in rules.movesFrom(board, hole)) {
      final existing = _movesByTarget[move.to];
      if (existing == null || move.jumpCount < existing.jumpCount) {
        _movesByTarget[move.to] = move;
      }
    }
    notifyListeners();
  }

  void _clearSelection() {
    selectedHole = null;
    _movesByTarget.clear();
  }

  void applyMove(CheckersMove move) {
    if (_disposed) return;
    _undoStack.add(
      _Snapshot(
        cells: List<int>.of(board.cells),
        seat: currentSeat,
        historyLength: history.length,
        quietPlies: _quietPlies,
        winner: winner,
        isDraw: isDraw,
      ),
    );
    final progressBefore = progressOf(currentSeat);
    board.move(move.from, move.to);
    history.add(MoveRecord(seat: currentSeat, move: move));
    // 长时间没有新棋子进营说明局面停滞，判和避免无休止消耗。
    _quietPlies = progressOf(currentSeat) > progressBefore
        ? 0
        : _quietPlies + 1;
    _clearSelection();
    hintMove = null;
    final mover = currentSeat;

    if (rules.hasWon(board, mover, setup.targetArmOf(mover))) {
      _endGame(
        winner: mover,
        message:
            '对局结束: ${setup.seatLabel(mover)} 获胜, ${history.length} 步, '
            '${_elapsed.inSeconds}s',
      );
      return;
    }

    final limit = setup.challenge?.moveLimit;
    if (limit != null && history.length >= limit) {
      _endGame(message: '残局失败: ${setup.challenge!.name} 步数用尽');
      return;
    }

    if (_quietPlies >= maxQuietPlies) {
      _endGame(message: '对局判和: 连续 $maxQuietPlies 步没有棋子进营');
      return;
    }

    if (!_advanceTurn()) {
      _endGame(message: '对局判和: 所有玩家均无合法着法');
      return;
    }
    notifyListeners();
    _scheduleAiIfNeeded();
  }

  /// 统一收尾：记录结果、冻结用时并通知界面。
  void _endGame({int? winner, required String message}) {
    this.winner = winner;
    isDraw = winner == null;
    _duration = _elapsed;
    if (winner == null) {
      LogService.warning(message);
    } else {
      LogService.info(message);
    }
    notifyListeners();
  }

  /// 轮到下一位仍有棋可走的玩家；全部无棋可走时返回 false。
  bool _advanceTurn() {
    final next = rules.nextSeat(board, currentSeat, players);
    if (next < 0) return false;
    currentSeat = next;
    return true;
  }

  void _scheduleAiIfNeeded() {
    if (_disposed || isFinished) return;
    if (!setup.isAi(currentSeat)) return;
    final epoch = ++_epoch;
    isAiThinking = true;
    notifyListeners();
    Future<void>.delayed(aiDelay, () => _playAiTurn(epoch));
  }

  /// 电脑回合：选子、记录搜索开销，并在无棋可走时跳过该座位。
  void _playAiTurn(int epoch) {
    if (_disposed || epoch != _epoch || isFinished) return;
    final seat = currentSeat;
    final move = _ai.chooseMove(board, seat);
    final search = _ai.lastSearch;
    if (search != null) {
      LogService.info('电脑搜索: 座位 ${seat + 1}, $search');
    }
    isAiThinking = false;
    if (move != null) {
      applyMove(move);
      return;
    }
    if (!_advanceTurn()) {
      _endGame(message: '对局判和: 所有玩家均无合法着法');
      return;
    }
    notifyListeners();
    _scheduleAiIfNeeded();
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
    _clearSelection();
    hintMove = null;
    notifyListeners();
    _scheduleAiIfNeeded();
  }

  void _restore(_Snapshot snapshot) {
    board = CheckersBoard(snapshot.cells);
    currentSeat = snapshot.seat;
    winner = snapshot.winner;
    isDraw = snapshot.isDraw;
    _quietPlies = snapshot.quietPlies;
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
    final challenge = setup.challenge;
    board = challenge == null
        ? CheckersBoard.initial(geometry, setup.seatArms)
        : CheckersBoard(challenge.cellsFor(geometry));
    currentSeat = 0;
    winner = null;
    isDraw = false;
    _clearSelection();
    hintMove = null;
    history.clear();
    _undoStack.clear();
    _duration = Duration.zero;
    _quietPlies = 0;
    _startedAt = null;
  }

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
    required this.quietPlies,
    required this.winner,
    required this.isDraw,
  });

  final List<int> cells;
  final int seat;
  final int historyLength;
  final int quietPlies;
  final int? winner;
  final bool isDraw;
}
