import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../flame/checkers_game.dart';
import '../game/move_record.dart';
import '../game/replay_controller.dart';
import '../models/game_models.dart';
import '../providers/settings_provider.dart';
import '../services/log_service.dart';
import '../theme/player_palette.dart';
import '../utils/constants.dart';
import '../utils/move_notation.dart';
import 'widgets/board_stage.dart';

/// 对局复盘：逐手回看已结束的对局，也可以自动播放。
class ReplayPage extends StatefulWidget {
  const ReplayPage({super.key, required this.setup, required this.records});

  final GameSetup setup;
  final List<MoveRecord> records;

  @override
  State<ReplayPage> createState() => _ReplayPageState();
}

class _ReplayPageState extends State<ReplayPage> {
  static const double _rowExtent = 62;

  late final ReplayController _replay;
  late final CheckersGame _game;
  final ScrollController _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _replay = ReplayController(setup: widget.setup, records: widget.records);
    _game = CheckersGame(
      source: _replay,
      theme: context.read<SettingsProvider>().boardTheme,
      showHints: false,
    );
    _replay.addListener(_onReplayChanged);
    LogService.info(
      '查看复盘: ${widget.setup.playerCount.label}, '
      '${widget.records.length} 手',
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _game.theme = context.read<SettingsProvider>().boardTheme;
  }

  @override
  void dispose() {
    _replay.removeListener(_onReplayChanged);
    _replay.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _onReplayChanged() {
    if (!mounted) return;
    setState(() {});
    final controller = _scroll;
    if (!controller.hasClients) return;
    final target = (_replay.index * _rowExtent).clamp(
      0.0,
      controller.position.maxScrollExtent,
    );
    controller.animateTo(
      target,
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
    );
  }

  void _openMoveSheet() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => SizedBox(
        height: MediaQuery.sizeOf(sheetContext).height * 0.62,
        child: _MoveListPanel(
          controller: _replay,
          scrollController: null,
          onSeek: _replay.seekTo,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= kGameWideBreakpoint;
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: '返回',
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.arrow_back),
        ),
        title: const Text('对局复盘'),
        actions: [
          if (!wide)
            IconButton(
              tooltip: '棋谱',
              onPressed: _openMoveSheet,
              icon: const Icon(Icons.list_alt, size: 21),
            ),
          const SizedBox(width: 6),
        ],
      ),
      body: SafeArea(top: false, child: wide ? _buildWide() : _buildCompact()),
    );
  }

  Widget _buildWide() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: Column(
              children: [
                _ReplayBanner(controller: _replay),
                const SizedBox(height: 10),
                Expanded(
                  child: BoardStage(
                    game: _game,
                    gameKey: const ValueKey('replay-board'),
                  ),
                ),
                const SizedBox(height: 10),
                ReplayControls(controller: _replay),
              ],
            ),
          ),
          const SizedBox(width: 20),
          SizedBox(
            width: 300,
            child: _MoveListPanel(
              controller: _replay,
              scrollController: _scroll,
              onSeek: _replay.seekTo,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompact() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 4, 12, 0),
          child: _ReplayBanner(controller: _replay),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: BoardStage(
              game: _game,
              gameKey: const ValueKey('replay-board'),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 4, 12, 10),
          child: ReplayControls(controller: _replay),
        ),
      ],
    );
  }
}

class _ReplayBanner extends StatelessWidget {
  const _ReplayBanner({required this.controller});

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

class _MoveListPanel extends StatelessWidget {
  const _MoveListPanel({
    required this.controller,
    required this.scrollController,
    required this.onSeek,
  });

  final ReplayController controller;
  final ScrollController? scrollController;
  final ValueChanged<int> onSeek;

  @override
  Widget build(BuildContext context) {
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
          Expanded(
            child: ListView.builder(
              controller: scrollController,
              padding: const EdgeInsets.symmetric(vertical: 6),
              itemExtent: 62,
              itemCount: controller.total + 1,
              itemBuilder: (context, position) => _MoveTile(
                controller: controller,
                position: position,
                selected: controller.index == position,
                onTap: () => onSeek(position),
              ),
            ),
          ),
        ],
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
