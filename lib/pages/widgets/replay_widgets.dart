import 'package:flutter/material.dart';

import '../../game/replay_controller.dart';
import '../../theme/player_palette.dart';
import '../../utils/move_notation.dart';

/// 棋谱每行高度：页面滚动定位与列表 itemExtent 共用。
const double kReplayRowExtent = 62;

/// 当前进度条：手数、走子方、走法与进营数。
class ReplayBanner extends StatelessWidget {
  const ReplayBanner({super.key, required this.controller});

  final ReplayController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final step = controller.currentStep;
    final accent = step == null
        ? theme.colorScheme.primary
        : playerStyleOf(step.record.seat).main;
    final title = step == null
        ? '开局'
        : '第 ${controller.index} / ${controller.total} 手';
    final subtitle = step == null
        ? '初始营地布局 · 点播放或向后翻看'
        : '${controller.setup.seatLabel(step.record.seat)} · '
              '${describeMove(step.record.move)} · 进营 ${step.progress}/10';
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: accent.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 30,
            decoration: BoxDecoration(
              color: accent,
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
          const SizedBox(width: 8),
          Text(
            controller.setup.playerCount.label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

/// 复盘操作：拖动进度、前后翻看与自动播放。
class ReplayControls extends StatelessWidget {
  const ReplayControls({super.key, required this.controller});

  final ReplayController controller;

  @override
  Widget build(BuildContext context) {
    final total = controller.total;
    final enabled = total > 0;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: 3,
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
          ),
          child: Slider(
            value: controller.index.toDouble().clamp(0, total.toDouble()),
            max: total.toDouble(),
            divisions: total > 0 ? total : null,
            label: '${controller.index} / $total',
            onChanged: enabled
                ? (value) => controller.seekTo(value.round())
                : null,
          ),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton(
              tooltip: '回到开局',
              onPressed: controller.atStart ? null : controller.toStart,
              icon: const Icon(Icons.first_page),
            ),
            IconButton(
              tooltip: '上一手',
              onPressed: controller.atStart ? null : controller.previous,
              icon: const Icon(Icons.chevron_left),
            ),
            const SizedBox(width: 6),
            IconButton.filled(
              tooltip: controller.isPlaying ? '暂停' : '播放',
              onPressed: enabled ? controller.togglePlay : null,
              iconSize: 26,
              icon: Icon(controller.isPlaying ? Icons.pause : Icons.play_arrow),
            ),
            const SizedBox(width: 6),
            IconButton(
              tooltip: '下一手',
              onPressed: controller.atEnd ? null : controller.next,
              icon: const Icon(Icons.chevron_right),
            ),
            IconButton(
              tooltip: '跳到终局',
              onPressed: controller.atEnd ? null : controller.toEnd,
              icon: const Icon(Icons.last_page),
            ),
          ],
        ),
      ],
    );
  }
}

/// 棋谱面板：开局加每一手，点击直接跳到该进度。
class ReplayMoveList extends StatelessWidget {
  const ReplayMoveList({
    super.key,
    required this.controller,
    this.scrollController,
  });

  final ReplayController controller;

  /// 宽屏由页面持有并随进度滚动；浮层内传 null 即可。
  final ScrollController? scrollController;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) => _buildPanel(context),
    );
  }

  Widget _buildPanel(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: theme.colorScheme.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
            child: Row(
              children: [
                Text('棋谱', style: theme.textTheme.titleSmall),
                const Spacer(),
                Text(
                  '共 ${controller.total} 手',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: theme.colorScheme.outline),
          if (controller.hasBestMove) ...[
            _BestMoveBar(controller: controller),
            Divider(height: 1, color: theme.colorScheme.outline),
          ],
          Expanded(
            child: ListView.builder(
              controller: scrollController,
              padding: const EdgeInsets.symmetric(vertical: 6),
              itemExtent: kReplayRowExtent,
              itemCount: controller.total + 1,
              itemBuilder: (context, position) => _MoveTile(
                controller: controller,
                position: position,
                selected: controller.index == position,
                onTap: () => controller.seekTo(position),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 本局最佳着法：点击直接跳到那一手。
class _BestMoveBar extends StatelessWidget {
  const _BestMoveBar({required this.controller});

  final ReplayController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final step = controller.bestStep!;
    final number = controller.bestMoveNumber!;
    final suffix = step.landedInCamp ? ' · 进营' : '';
    return Material(
      color: theme.colorScheme.tertiary.withValues(alpha: 0.08),
      child: InkWell(
        onTap: () => controller.seekTo(number),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 8, 10, 8),
          child: Row(
            children: [
              Icon(
                Icons.auto_awesome,
                size: 15,
                color: theme.colorScheme.tertiary,
              ),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  '最佳着法 第 $number 手 · '
                  '${describeMove(step.record.move)}$suffix',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.tertiary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Icon(
                Icons.chevron_right,
                size: 16,
                color: theme.colorScheme.tertiary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MoveTile extends StatelessWidget {
  const _MoveTile({
    required this.controller,
    required this.position,
    required this.selected,
    required this.onTap,
  });

  final ReplayController controller;
  final int position;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isStart = position == 0;
    final step = isStart ? null : controller.steps[position - 1];
    final style = step == null ? null : playerStyleOf(step.record.seat);
    final accent = style?.main ?? theme.colorScheme.onSurfaceVariant;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      child: Material(
        color: selected ? accent.withValues(alpha: 0.12) : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: selected
                  ? Border.all(color: accent.withValues(alpha: 0.55))
                  : null,
            ),
            child: Row(
              children: [
                SizedBox(
                  width: 26,
                  child: Text(
                    isStart ? '—' : '$position',
                    textAlign: TextAlign.right,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ),
                const SizedBox(width: 9),
                Container(
                  width: 9,
                  height: 9,
                  decoration: BoxDecoration(
                    color: accent,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isStart
                            ? '开局'
                            : controller.setup.seatLabel(step!.record.seat),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: selected
                              ? FontWeight.w700
                              : FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        isStart
                            ? '初始营地布局'
                            : '${describeMove(step!.record.move)} · '
                                  '进营 ${step.progress}/10',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                if (controller.hasBestMove &&
                    position == controller.bestMoveNumber)
                  Padding(
                    padding: const EdgeInsets.only(right: 4),
                    child: Icon(
                      Icons.auto_awesome,
                      size: 14,
                      color: theme.colorScheme.tertiary,
                    ),
                  ),
                if (step != null && step.landedInCamp)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.tertiary.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '进营',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.tertiary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
