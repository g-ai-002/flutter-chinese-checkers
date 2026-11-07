import 'dart:math' as math;

import 'package:flame/game.dart';
import 'package:flutter/material.dart';

import '../../flame/checkers_game.dart';

/// 棋盘舞台：把 Flame 画布按固定比例放进可用空间，宽高都尽量铺满。
class BoardStage extends StatelessWidget {
  const BoardStage({
    super.key,
    required this.game,
    required this.gameKey,
    this.maxWidth = 680,
  });

  final CheckersGame game;
  final Key gameKey;
  final double maxWidth;

  static const double _aspect = 14 / 16;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        var width = math.min(constraints.maxWidth, maxWidth);
        var height = width / _aspect;
        if (height > constraints.maxHeight) {
          height = constraints.maxHeight;
          width = height * _aspect;
        }
        return Center(
          child: SizedBox(
            width: width,
            height: height,
            // 棋盘自成一棵重绘边界，周边面板刷新时不会连带重绘整块画布。
            child: RepaintBoundary(
              child: GameWidget<CheckersGame>(key: gameKey, game: game),
            ),
          ),
        );
      },
    );
  }
}
