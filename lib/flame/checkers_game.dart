import 'package:flame/game.dart';
import 'package:flutter/material.dart';

import '../game/board_source.dart';
import '../theme/app_theme.dart';
import 'board_component.dart';

/// Flame 游戏入口：棋盘组件 + 主题监听。
class CheckersGame extends FlameGame {
  CheckersGame({
    required this.source,
    required BoardTheme theme,
    this.showHints = true,
  }) : _theme = ValueNotifier(theme);

  final BoardSource source;
  final bool showHints;
  final ValueNotifier<BoardTheme> _theme;
  BoardComponent? _board;

  BoardTheme get theme => _theme.value;
  set theme(BoardTheme value) => _theme.value = value;

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
    _fit(board);
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

  @override
  void onRemove() {
    _theme.dispose();
    super.onRemove();
  }
}
