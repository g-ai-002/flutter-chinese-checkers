import 'package:flutter/material.dart';

import '../../game/challenge_levels.dart';
import '../../game/checkers_controller.dart';

/// 三颗星评分，供关卡列表与结算浮层共用。
class ChallengeStars extends StatelessWidget {
  const ChallengeStars({super.key, required this.stars, this.size = 16});

  final int stars;
  final double size;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < 3; i++)
          Padding(
            padding: EdgeInsets.only(left: i == 0 ? 0 : 2),
            child: Icon(
              i < stars ? Icons.star_rounded : Icons.star_outline_rounded,
              size: size,
              color: i < stars
                  ? const Color(0xFFE0A526)
                  : theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.45),
            ),
          ),
      ],
    );
  }
}

/// 残局顶部状态：关卡名、剩余步数与进营进度。
class ChallengeStatusBar extends StatelessWidget {
  const ChallengeStatusBar({
    super.key,
    required this.controller,
    required this.level,
  });

  final CheckersController controller;
  final ChallengeLevel level;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = theme.colorScheme.primary;
    final progress = controller.progressOf(controller.currentSeat);
    final left = controller.movesLeft ?? level.moveLimit;
    final finished = controller.isFinished;
    final warning = !finished && left <= 2;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 9, 14, 10),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: (warning ? theme.colorScheme.error : color).withValues(
            alpha: 0.35,
          ),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(Icons.flag_outlined, size: 19, color: color),
              const SizedBox(width: 9),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      level.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall,
                    ),
                    Text(
                      '参考 ${level.parMoves} 步 · 上限 ${level.moveLimit} 步',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Text(
                finished ? '已结束' : '剩 $left 步',
                style: theme.textTheme.titleSmall?.copyWith(
                  color: warning ? theme.colorScheme.error : color,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: LinearProgressIndicator(
                    value: progress / 10,
                    minHeight: 5,
                    backgroundColor: color.withValues(alpha: 0.14),
                    valueColor: AlwaysStoppedAnimation<Color>(color),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                '进营 $progress/10',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// 残局结算：成功展示星级与下一关，失败只给重试。
Future<void> showChallengeResultDialog(
  BuildContext context, {
  required ChallengeLevel level,
  required bool success,
  required int moves,
  required VoidCallback onRetry,
  required VoidCallback onBack,
  VoidCallback? onNext,
}) {
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) {
      final theme = Theme.of(dialogContext);
      final stars = success ? level.starsFor(moves) : 0;
      return AlertDialog(
        icon: Icon(
          success ? Icons.emoji_events_outlined : Icons.hourglass_bottom,
          size: 34,
          color: success
              ? const Color(0xFFE0A526)
              : theme.colorScheme.onSurfaceVariant,
        ),
        title: Text(success ? '挑战成功' : '步数用尽'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (success) ...[
              ChallengeStars(stars: stars, size: 30),
              const SizedBox(height: 10),
              Text(
                '$moves 步完成 · 参考 ${level.parMoves} 步',
                style: theme.textTheme.bodyMedium,
              ),
            ] else ...[
              Text(
                '在 ${level.moveLimit} 步内没能填满目标营地，换个顺序再试试。',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  height: 1.6,
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              onBack();
            },
            child: const Text('返回列表'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              onRetry();
            },
            child: const Text('再试一次'),
          ),
          if (success && onNext != null)
            FilledButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
                onNext();
              },
              child: const Text('下一关'),
            ),
        ],
      );
    },
  );
}
