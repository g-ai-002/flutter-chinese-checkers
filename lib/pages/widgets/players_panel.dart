import 'package:flutter/material.dart';

import '../../game/checkers_controller.dart';
import '../../models/game_models.dart';
import '../../theme/player_palette.dart';

/// 顶部轮次提示：谁在走、该做什么。
class TurnBanner extends StatelessWidget {
  const TurnBanner({super.key, required this.controller});

  final CheckersController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final setup = controller.setup;
    if (controller.isFinished) {
      final winner = controller.winner;
      return _Banner(
        color: winner == null
            ? theme.colorScheme.onSurfaceVariant
            : playerStyleOf(winner).main,
        title: winner == null ? '本局僵局' : '${setup.seatLabel(winner)}获胜',
        subtitle: '共 ${controller.history.length} 步',
      );
    }
    final style = playerStyleOf(controller.currentSeat);
    final thinking = controller.isAiThinking;
    return _Banner(
      color: style.main,
      title: thinking
          ? '${setup.seatLabel(controller.currentSeat)}思考中…'
          : '轮到 ${setup.seatLabel(controller.currentSeat)}',
      subtitle: thinking
          ? '正在寻找最佳落点'
          : setup.mode == PlayMode.vsAi && setup.isHuman(controller.currentSeat)
          ? '点自己的棋子，再点亮点落子'
          : '同屏轮流走子，连跳可一次走完',
      trailing: thinking
          ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : null,
    );
  }
}

class _Banner extends StatelessWidget {
  const _Banner({
    required this.color,
    required this.title,
    required this.subtitle,
    this.trailing,
  });

  final Color color;
  final String title;
  final String subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 30,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleSmall,
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

/// 玩家进度：横向小胶囊或侧栏纵向列表。
class PlayerStandings extends StatelessWidget {
  const PlayerStandings({
    super.key,
    required this.controller,
    this.vertical = false,
  });

  final CheckersController controller;
  final bool vertical;

  @override
  Widget build(BuildContext context) {
    final setup = controller.setup;
    final items = [
      for (var seat = 0; seat < setup.players; seat++)
        _PlayerItem(controller: controller, seat: seat),
    ];
    if (!vertical) {
      return SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            for (var i = 0; i < items.length; i++) ...[
              if (i > 0) const SizedBox(width: 8),
              items[i].compact(context),
            ],
          ],
        ),
      );
    }
    return Column(
      children: [
        for (var i = 0; i < items.length; i++) ...[
          if (i > 0) const SizedBox(height: 8),
          items[i].wide(context),
        ],
      ],
    );
  }
}

class _PlayerItem {
  _PlayerItem({required this.controller, required this.seat});

  final CheckersController controller;
  final int seat;

  PlayerStyle get style => playerStyleOf(seat);
  bool get active => controller.currentSeat == seat && !controller.isFinished;
  int get progress => controller.progressOf(seat);
  String get name => controller.setup.seatLabel(seat);

  Widget compact(BuildContext context) {
    final theme = Theme.of(context);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: active
            ? style.main.withValues(alpha: 0.12)
            : theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: active
              ? style.main.withValues(alpha: 0.8)
              : theme.colorScheme.outline,
          width: active ? 1.4 : 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _Dot(color: style.main, active: active),
          const SizedBox(width: 7),
          Text(name, style: theme.textTheme.bodySmall),
          const SizedBox(width: 6),
          Text(
            '$progress/10',
            style: theme.textTheme.bodySmall?.copyWith(
              color: style.main,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget wide(BuildContext context) {
    final theme = Theme.of(context);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: active
            ? style.main.withValues(alpha: 0.09)
            : theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: active
              ? style.main.withValues(alpha: 0.75)
              : theme.colorScheme.outline,
        ),
      ),
      child: Row(
        children: [
          _Dot(color: style.main, active: active),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: active
                              ? FontWeight.w700
                              : FontWeight.w500,
                        ),
                      ),
                    ),
                    Text(
                      '$progress/10',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: style.main,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: LinearProgressIndicator(
                    value: progress / 10,
                    minHeight: 5,
                    backgroundColor: style.main.withValues(alpha: 0.14),
                    valueColor: AlwaysStoppedAnimation<Color>(style.main),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot({required this.color, required this.active});

  final Color color;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: active ? 11 : 9,
      height: active ? 11 : 9,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        boxShadow: active
            ? [
                BoxShadow(
                  color: color.withValues(alpha: 0.5),
                  blurRadius: 6,
                  spreadRadius: 1,
                ),
              ]
            : null,
      ),
    );
  }
}

/// 对局操作：提示、悔棋、重开。
class GameActionBar extends StatelessWidget {
  const GameActionBar({
    super.key,
    required this.controller,
    required this.onHint,
    required this.onUndo,
    required this.onRestart,
    this.showUndo = true,
  });

  final CheckersController controller;
  final VoidCallback onHint;
  final VoidCallback onUndo;
  final VoidCallback onRestart;

  /// 残局禁用悔棋，直接隐藏按钮而不是留一个不可点的占位。
  final bool showUndo;

  @override
  Widget build(BuildContext context) {
    final canHint =
        !controller.isFinished &&
        controller.isHumanTurn &&
        !controller.isAiThinking;
    final canUndo = controller.canUndo && !controller.isAiThinking;
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: canHint ? onHint : null,
            icon: const Icon(Icons.lightbulb_outline, size: 19),
            label: const Text('提示'),
          ),
        ),
        if (showUndo) ...[
          const SizedBox(width: 10),
          Expanded(
            child: OutlinedButton.icon(
              onPressed: canUndo ? onUndo : null,
              icon: const Icon(Icons.undo, size: 19),
              label: const Text('悔棋'),
            ),
          ),
        ],
        const SizedBox(width: 10),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: onRestart,
            icon: const Icon(Icons.refresh, size: 19),
            label: Text(showUndo ? '重开' : '重试'),
          ),
        ),
      ],
    );
  }
}
