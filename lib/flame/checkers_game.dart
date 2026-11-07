import 'dart:async';

import 'package:flame/game.dart';
import 'package:flutter/material.dart';

import '../game/board_source.dart';
import '../game/replay_controller.dart';
import '../theme/app_theme.dart';
import 'board_component.dart';

/// Flame 游戏入口：棋盘组件 + 主题监听。
class CheckersGame extends FlameGame {
  CheckersGame({
    required this.source,
    required BoardTheme theme,
    this.showHints = true,
  }) : _theme = ValueNotifier(theme) {
    _theme.addListener(_onActivity);
  }

  /// 静止这么久后停掉渲染循环，避免空闲时仍以 60 FPS 重绘棋盘。
  static const Duration idleDelay = Duration(milliseconds: 1200);

  final BoardSource source;
  final bool showHints;
  final ValueNotifier<BoardTheme> _theme;
  BoardComponent? _board;
  Timer? _idleTimer;
  bool _loaded = false;
  bool _idlePaused = false;
  bool _removed = false;

  BoardTheme get theme => _theme.value;
  set theme(BoardTheme value) => _theme.value = value;

  /// 实时对局与复盘控制器都是 [ChangeNotifier]，监听后即可在交互时唤醒循环。
  Listenable? get _listenableSource =>
      source is Listenable ? source as Listenable : null;

  /// 是否因长时间静止而主动暂停了渲染循环。
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
