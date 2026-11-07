import 'dart:async';

import 'package:flame/game.dart';
import 'package:flutter/material.dart';

import '../game/board_source.dart';
import '../game/replay_controller.dart';
import '../models/game_models.dart';
import '../theme/app_theme.dart';
import 'board_component.dart';

class CheckersGame extends FlameGame {
  CheckersGame({
    required this.source,
    required BoardTheme theme,
    this.showHints = true,
    this.logicRate = LogicRate.defaultRate,
  }) : _theme = ValueNotifier(theme) {
    _theme.addListener(_onActivity);
  }

  /// 静止这么久后停掉渲染循环，避免空闲时仍以 60 FPS 重绘棋盘。
  static const Duration idleDelay = Duration(milliseconds: 1200);

  /// 单帧最多补 8 步，长时间卡顿后丢弃余量，避免逻辑越追越慢。
  static const int maxStepsPerFrame = 8;

  final BoardSource source;
  final bool showHints;

  /// 逻辑更新速率：渲染跟随屏幕刷新，逻辑按固定步长推进。
  final LogicRate logicRate;

  final ValueNotifier<BoardTheme> _theme;
  BoardComponent? _board;
  Timer? _idleTimer;
  double _pendingLogic = 0;
  int _logicSteps = 0;
  bool _loaded = false;
  bool _idlePaused = false;
  bool _removed = false;

  @override
  void update(double dt) {
    // 即使这一帧不足一个逻辑步，也要处理组件挂载/移除，棋盘才能首帧渲染。
    processLifecycleEvents();
    _pendingLogic += dt.clamp(0.0, 0.25);
    final step = logicRate.stepSeconds;
    var steps = 0;
    while (_pendingLogic >= step && steps < maxStepsPerFrame) {
      super.update(step);
      _pendingLogic -= step;
      steps++;
    }
    if (steps == maxStepsPerFrame) _pendingLogic = 0;
    _logicSteps += steps;
  }

  /// 已经执行的逻辑步数，用于验证固定步长。
  @visibleForTesting
  int get logicSteps => _logicSteps;

  BoardTheme get theme => _theme.value;
  set theme(BoardTheme value) => _theme.value = value;

  /// 实时对局与复盘控制器都是 [ChangeNotifier]，监听后即可在交互时唤醒循环。
  Listenable? get _listenableSource =>
      source is Listenable ? source as Listenable : null;

  bool get isIdlePaused => _idlePaused;

  @override
  Color backgroundColor() => Colors.transparent;

  @override
  Future<void> onLoad() async {
    final board = BoardComponent(
      source: source,
      theme: _theme,
      showHints: showHints,
    );
    _board = board;
    await add(board);
    if (_removed) return;
    _fit(board);
    _loaded = true;
    _listenableSource?.addListener(_onActivity);
    _scheduleIdlePause();
  }

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    final board = _board;
    if (board != null) _fit(board);
  }

  void _fit(BoardComponent board) {
    board
      ..size = size.clone()
      ..position = Vector2.zero();
  }

  /// 任何交互或局面变化都唤醒渲染循环，并重新计时。
  void _onActivity() {
    _idleTimer?.cancel();
    if (_idlePaused) {
      _idlePaused = false;
      resumeEngine();
    }
    _scheduleIdlePause();
  }

  void _scheduleIdlePause() {
    if (!_loaded || _removed) return;
    _idleTimer?.cancel();
    _idleTimer = Timer(idleDelay, _pauseIfIdle);
  }

  void _pauseIfIdle() {
    _idleTimer = null;
    if (!_loaded || _removed || _idlePaused) return;
    // 应用切到后台时 Flame 会自行暂停，这里不再重复安排检查。
    if (paused) return;
    if (_board?.wantsFrames ?? true) {
      _scheduleIdlePause();
      return;
    }
    if (source is ReplayController && (source as ReplayController).isPlaying) {
      _scheduleIdlePause();
      return;
    }
    _idlePaused = true;
    pauseEngine();
  }

  @override
  void onRemove() {
    _removed = true;
    _idleTimer?.cancel();
    _idleTimer = null;
    _listenableSource?.removeListener(_onActivity);
    _theme.removeListener(_onActivity);
    _theme.dispose();
    super.onRemove();
  }
}
