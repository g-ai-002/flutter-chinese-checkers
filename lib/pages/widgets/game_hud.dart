import 'package:flutter/material.dart';

import '../../game/challenge_levels.dart';
import '../../game/checkers_controller.dart';
import '../../models/game_models.dart';
import '../../theme/player_palette.dart';

/// 悬浮信息面板：统一半透明底板、圆角与阴影。
///
/// 面板只负责自身外观，位置由对局页的 [Stack] 锚定在棋盘四周，
/// 因此文字变化、思考指示器出现都不会改变棋盘尺寸或位置。
class HudPanel extends StatelessWidget {
  const HudPanel({
    super.key,
    required this.child,
    this.width,
    this.padding = const EdgeInsets.all(10),
    this.accent,
  });

  final Widget child;
  final double? width;
  final EdgeInsetsGeometry padding;

  /// 非空时用于边框强调色，例如当前走子方或残局步数告急。
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final border = accent ?? scheme.outline;
    return Container(
      width: width,
      padding: padding,
      decoration: BoxDecoration(
        color: scheme.surface.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: border.withValues(alpha: accent == null ? 0.7 : 0.5)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF000000).withValues(alpha: 0.14),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }
}

/// 悬浮按钮：只给图标时是圆形按钮，带 [label] 时是胶囊文字按钮。
class HudButton extends StatelessWidget {
  const HudButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.label,
    this.size = 42,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final String? label;
  final double size;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = label;
    if (text == null) {
      return IconButton(
        tooltip: tooltip,
        onPressed: onPressed,
        icon: Icon(icon, size: 20),
        style: IconButton.styleFrom(
          fixedSize: Size.square(size),
          minimumSize: Size.square(size),
          padding: EdgeInsets.zero,
          backgroundColor: scheme.surface.withValues(alpha: 0.94),
          foregroundColor: scheme.onSurface,
          disabledForegroundColor: scheme.onSurfaceVariant.withValues(alpha: 0.38),
          side: BorderSide(color: scheme.outline.withValues(alpha: 0.7)),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
    return Tooltip(
      message: tooltip,
      child: HudPanel(
        padding: EdgeInsets.zero,
        child: TextButton.icon(
          onPressed: onPressed,
          icon: Icon(icon, size: 16),
          label: Text(text),
          style: TextButton.styleFrom(
            minimumSize: const Size(0, 36),
            padding: const EdgeInsets.symmetric(horizontal: 11),
            foregroundColor: scheme.onSurface,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)),
            textStyle: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
          ),
        ),
      ),
    );
  }
}

/// 轮次提示：谁在走、该做什么；电脑思考时在原位显示进度圈。
class TurnHud extends StatelessWidget {
  const TurnHud({super.key, required this.controller, required this.width, this.dense = false});

  final CheckersController controller;
  final double width;

  /// 矮窗口下省略副标题，避免浮层侵入棋盘。
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final setup = controller.setup;
    final finished = controller.isFinished;
    final thinking = controller.isAiThinking;
    final color = finished
        ? (controller.winner == null
              ? theme.colorScheme.onSurfaceVariant
              : playerStyleOf(controller.winner!).main)
        : playerStyleOf(controller.currentSeat).main;
    final title = finished
        ? (controller.winner == null ? '本局僵局' : '${setup.seatLabel(controller.winner!)}获胜')
        : thinking
        ? '${setup.seatLabel(controller.currentSeat)}思考中…'
        : '轮到 ${setup.seatLabel(controller.currentSeat)}';
    final subtitle = finished
        ? '共 ${controller.history.length} 步'
        : thinking
        ? '正在寻找最佳落点'
        : setup.mode == PlayMode.vsAi && setup.isHuman(controller.currentSeat)
        ? '点自己的棋子，再点亮点落子'
        : '同屏轮流走子，连跳可一次走完';
    return HudPanel(
      width: width,
      accent: color,
      padding: const EdgeInsets.fromLTRB(11, 9, 10, 9),
      child: Row(
        children: [
          Container(
            width: 6,
            height: dense ? 22 : 30,
            decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3)),
          ),
          const SizedBox(width: 10),
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
                if (!dense) ...[
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
              ],
            ),
          ),
          const SizedBox(width: 8),
          // 固定占位：思考圈出现或消失都不会改变面板宽度。
          SizedBox(
            width: 16,
            height: 16,
            child: thinking ? CircularProgressIndicator(strokeWidth: 2, color: color) : null,
          ),
        ],
      ),
    );
  }
}

/// 残局状态：剩余步数与进营进度，步数告急时边框转红。
class ChallengeHud extends StatelessWidget {
  const ChallengeHud({
    super.key,
    required this.controller,
    required this.level,
    required this.width,
  });

  final CheckersController controller;
  final ChallengeLevel level;
  final double width;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final progress = controller.progressOf(controller.currentSeat);
    final left = controller.movesLeft ?? level.moveLimit;
    final finished = controller.isFinished;
    final warning = !finished && left <= 2;
    final color = warning ? scheme.error : scheme.primary;
    return HudPanel(
      width: width,
      accent: color,
      padding: const EdgeInsets.fromLTRB(12, 9, 12, 10),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(Icons.flag_outlined, size: 18, color: color),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  finished ? '已结束' : '剩 $left 步',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: color,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Text(
                '进营 $progress/10',
                style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
              ),
            ],
          ),
          const SizedBox(height: 7),
          ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(
              value: progress / 10,
              minHeight: 4,
              backgroundColor: color.withValues(alpha: 0.14),
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
        ],
      ),
    );
  }
}

class PlayersHud extends StatelessWidget {
  const PlayersHud({super.key, required this.controller, this.width = 128, this.showTitle = true});

  final CheckersController controller;
  final double width;
  final bool showTitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final rows = <Widget>[
      for (var seat = 0; seat < controller.players; seat++)
        _PlayerProgressRow(controller: controller, seat: seat),
    ];
    return HudPanel(
      width: width,
      padding: const EdgeInsets.fromLTRB(10, 9, 10, 9),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (showTitle) ...[
            Text(
              '对局进度',
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 6),
          ],
          for (var i = 0; i < rows.length; i++) ...[if (i > 0) const SizedBox(height: 4), rows[i]],
        ],
      ),
    );
  }
}

class _PlayerProgressRow extends StatelessWidget {
  const _PlayerProgressRow({required this.controller, required this.seat});

  final CheckersController controller;
  final int seat;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final style = playerStyleOf(seat);
    final active = controller.currentSeat == seat && !controller.isFinished;
    final progress = controller.progressOf(seat);
    return SizedBox(
      height: 22,
      child: Row(
        children: [
          // 固定槽位，选中态放大圆点不会挤动名字与步数。
          SizedBox(
            width: 12,
            child: Center(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                width: active ? 11 : 9,
                height: active ? 11 : 9,
                decoration: BoxDecoration(
                  color: style.main,
                  shape: BoxShape.circle,
                  boxShadow: active
                      ? [
                          BoxShadow(
                            color: style.main.withValues(alpha: 0.5),
                            blurRadius: 6,
                            spreadRadius: 1,
                          ),
                        ]
                      : null,
                ),
              ),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              controller.setup.seatLabel(seat),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: active ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(width: 4),
          SizedBox(
            width: 30,
            child: Text(
              '$progress/10',
              textAlign: TextAlign.right,
              style: theme.textTheme.bodySmall?.copyWith(
                color: style.main,
                fontWeight: FontWeight.w700,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 操作坞：提示、悔棋、重开（残局为提示、重试）。
///
/// 窄屏用 [compact] 收成纯图标按钮，宽度从约 240 降到 130，
/// 与左下的进度面板并排时不会互相覆盖。
class ActionDock extends StatelessWidget {
  const ActionDock({
    super.key,
    required this.controller,
    required this.onHint,
    required this.onUndo,
    required this.onRestart,
    this.showUndo = true,
    this.compact = false,
  });

  final CheckersController controller;
  final VoidCallback onHint;
  final VoidCallback onUndo;
  final VoidCallback onRestart;
  final bool showUndo;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final canHint = !controller.isFinished && controller.isHumanTurn && !controller.isAiThinking;
    final canUndo = controller.canUndo && !controller.isAiThinking;
    return HudPanel(
      padding: const EdgeInsets.all(4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _DockButton(
            icon: Icons.lightbulb_outline,
            label: '提示',
            onPressed: canHint ? onHint : null,
            compact: compact,
          ),
          if (showUndo) ...[
            SizedBox(width: compact ? 4 : 2),
            _DockButton(
              icon: Icons.undo,
              label: '悔棋',
              onPressed: canUndo ? onUndo : null,
              compact: compact,
            ),
          ],
          SizedBox(width: compact ? 4 : 2),
          _DockButton(
            icon: Icons.refresh,
            label: showUndo ? '重开' : '重试',
            onPressed: onRestart,
            compact: compact,
          ),
        ],
      ),
    );
  }
}

class _DockButton extends StatelessWidget {
  const _DockButton({
    required this.icon,
    required this.label,
    required this.onPressed,
    required this.compact,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onPressed;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    if (compact) {
      return IconButton(
        tooltip: label,
        onPressed: onPressed,
        icon: Icon(icon, size: 19),
        style: IconButton.styleFrom(
          fixedSize: const Size.square(40),
          minimumSize: const Size.square(40),
          padding: EdgeInsets.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          foregroundColor: scheme.primary,
          disabledForegroundColor: scheme.onSurfaceVariant.withValues(alpha: 0.4),
          backgroundColor: scheme.primary.withValues(alpha: 0.08),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    }
    return TextButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 17),
      label: Text(label, maxLines: 1),
      style: TextButton.styleFrom(
        fixedSize: const Size(74, 40),
        padding: EdgeInsets.zero,
        foregroundColor: scheme.primary,
        disabledForegroundColor: scheme.onSurfaceVariant.withValues(alpha: 0.4),
        backgroundColor: scheme.primary.withValues(alpha: 0.08),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        textStyle: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
      ),
    );
  }
}

/// 残局关卡目标：参考步数、星级门槛与障碍说明。
Future<void> showChallengeBriefDialog(BuildContext context, ChallengeLevel level) {
  return showDialog<void>(
    context: context,
    builder: (dialogContext) {
      final theme = Theme.of(dialogContext);
      final style = theme.textTheme.bodyMedium?.copyWith(
        color: theme.colorScheme.onSurfaceVariant,
        height: 1.6,
      );
      return AlertDialog(
        icon: const Icon(Icons.flag_outlined, size: 30),
        title: Text(level.name),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(level.hint, style: style),
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(Icons.star_rounded, size: 18, color: Color(0xFFE0A526)),
                const SizedBox(width: 5),
                Expanded(
                  child: Text(
                    '三星 ≤ ${level.parMoves} 步 · '
                    '两星 ≤ ${level.parMoves + 2} 步',
                    style: style,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text('上限 ${level.moveLimit} 步 · 障碍子可跨越，不会移动。', style: style),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(), child: const Text('知道了')),
        ],
      );
    },
  );
}

Future<void> showPlayerProgressDialog(BuildContext context, CheckersController controller) {
  return showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('对局进度'),
      content: ListenableBuilder(
        listenable: controller,
        builder: (context, _) => PlayersHud(controller: controller, width: 264, showTitle: false),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(dialogContext).pop(), child: const Text('关闭')),
      ],
    ),
  );
}
