import 'package:flutter/material.dart';

import '../../models/game_models.dart';
import '../../theme/player_palette.dart';
import '../../utils/formatters.dart';

/// 终局弹窗：显示胜者、步数与用时。
Future<void> showGameResultDialog(
  BuildContext context, {
  required GameResult result,
  required String winnerLabel,
  required VoidCallback onRestart,
  required VoidCallback onHome,
}) {
  final winner = result.winner;
  final isDraw = winner == null;
  final style = playerStyleOf(winner ?? 0);
  final minutes = result.duration.inMinutes;
  final seconds = result.duration.inSeconds % 60;
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) => AlertDialog(
      title: Row(
        children: [
          Icon(
            isDraw ? Icons.handshake_outlined : Icons.emoji_events_outlined,
            color: isDraw
                ? Theme.of(dialogContext).colorScheme.onSurfaceVariant
                : style.main,
          ),
          const SizedBox(width: 10),
          Expanded(child: Text(isDraw ? '本局僵局' : '$winnerLabel获胜')),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            isDraw ? '所有玩家都没有可走的棋，本局就此结束。' : '十枚棋子全部进入对面营地。',
            style: Theme.of(dialogContext).textTheme.bodyMedium,
          ),
          const SizedBox(height: 16),
          _StatRow(label: '总步数', value: '${result.moves} 步'),
          const SizedBox(height: 8),
          _StatRow(label: '用时', value: '${pad2(minutes)}:${pad2(seconds)}'),
        ],
      ),
      actions: [
        TextButton(onPressed: onHome, child: const Text('返回首页')),
        FilledButton(onPressed: onRestart, child: const Text('再来一局')),
      ],
    ),
  );
}

class _StatRow extends StatelessWidget {
  const _StatRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const Spacer(),
        Text(
          value,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

/// 离开对局前的确认。
Future<bool> confirmLeaveGame(BuildContext context) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('退出对局？'),
      content: const Text('当前进度不会保存，返回首页后需要重新开始。'),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: const Text('继续对局'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: const Text('退出'),
        ),
      ],
    ),
  );
  return result ?? false;
}

/// 玩法说明，首页与对局页共用一个弹窗。
Future<void> showRulesDialog(BuildContext context) {
  return showDialog<void>(
    context: context,
    builder: (dialogContext) {
      final theme = Theme.of(dialogContext).textTheme;
      return AlertDialog(
        title: const Text('玩法说明'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('目标', style: theme.titleSmall),
              const SizedBox(height: 4),
              Text('把自己的 10 枚棋子全部走进正对面的营地，先完成的一方获胜。', style: theme.bodyMedium),
              const SizedBox(height: 14),
              Text('走法', style: theme.titleSmall),
              const SizedBox(height: 4),
              Text(
                '单步：走到相邻的空孔。\n'
                '连跳：跨过任意一枚相邻棋子落到对称的空孔，'
                '可以连续跳多步，中途可随时停下。',
                style: theme.bodyMedium,
              ),
              const SizedBox(height: 14),
              Text('人数', style: theme.titleSmall),
              const SizedBox(height: 4),
              Text(
                '支持 2、3、4、6 人对局。人机对战时其余座位由电脑接管，'
                '电脑会自动完成自己的回合。',
                style: theme.bodyMedium,
              ),
              const SizedBox(height: 14),
              Text('提示与悔棋', style: theme.titleSmall),
              const SizedBox(height: 4),
              Text(
                '「提示」会给出一手推荐的走法；「悔棋」在人机模式回到自己上一次走棋之前。',
                style: theme.bodyMedium,
              ),
            ],
          ),
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('知道了'),
          ),
        ],
      );
    },
  );
}
