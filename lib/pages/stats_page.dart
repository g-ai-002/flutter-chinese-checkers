import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/match_record.dart';
import '../models/match_summary.dart';
import '../providers/settings_provider.dart';
import '../theme/player_palette.dart';
import '../utils/formatters.dart';

/// 对局统计：生涯概览、人机战绩、亮点与最近对局。
class StatsPage extends StatelessWidget {
  const StatsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final matches = settings.matches;
    final summary = MatchSummary.fromRecords(matches);
    return Scaffold(
      appBar: AppBar(
        title: const Text('对局统计'),
        actions: [
          if (matches.isNotEmpty)
            IconButton(
              tooltip: '清空统计',
              onPressed: () => _confirmClear(context, settings),
              icon: const Icon(Icons.delete_outline, size: 21),
            ),
          const SizedBox(width: 6),
        ],
      ),
      body: SafeArea(
        top: false,
        child: matches.isEmpty
            ? const _EmptyStats()
            : Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 760),
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 6, 16, 28),
                    children: [
                      _MetricGrid(summary: summary),
                      const SizedBox(height: 14),
                      _AiRecordPanel(summary: summary),
                      const SizedBox(height: 14),
                      _HighlightsPanel(summary: summary),
                      const SizedBox(height: 14),
                      _RecentMatches(records: matches.take(8).toList()),
                    ],
                  ),
                ),
              ),
      ),
    );
  }

  Future<void> _confirmClear(
    BuildContext context,
    SettingsProvider settings,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('清空对局统计？'),
        content: const Text('所有历史对局摘要都会被删除，且无法恢复。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('清空'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await settings.clearMatches();
  }
}

class _EmptyStats extends StatelessWidget {
  const _EmptyStats();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.query_stats,
              size: 52,
              color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
            ),
            const SizedBox(height: 16),
            Text('还没有对局记录', style: theme.textTheme.titleMedium),
            const SizedBox(height: 6),
            Text(
              '完成一局后会自动记录在这里，\n包括胜负、步数、用时与本局亮点。',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                height: 1.6,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MetricGrid extends StatelessWidget {
  const _MetricGrid({required this.summary});

  final MatchSummary summary;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final cards = [
      _MetricCard(
        icon: Icons.sports_esports_outlined,
        color: colors.primary,
        label: '总对局',
        value: '${summary.total}',
        hint: '人机 ${summary.aiGames} · 同屏 ${summary.localGames}',
      ),
      _MetricCard(
        icon: Icons.percent,
        color: colors.tertiary,
        label: '人机胜率',
        value: summary.aiGames == 0 ? '—' : '${summary.winPercent}%',
        hint: summary.aiGames == 0
            ? '尚未进行人机对局'
            : '${summary.wins} 胜 ${summary.draws} 平 ${summary.losses} 负',
      ),
      _MetricCard(
        icon: Icons.timeline,
        color: colors.secondary,
        label: '平均步数',
        value: '${summary.averageMoves}',
        hint: '每局平均步数',
      ),
      _MetricCard(
        icon: Icons.schedule,
        color: colors.primary,
        label: '平均用时',
        value: formatDuration(summary.averageDuration),
        hint: '每局平均用时',
      ),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 620 ? 4 : 2;
        return GridView.count(
          crossAxisCount: columns,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: columns == 4 ? 1.55 : 1.75,
          children: cards,
        );
      },
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.icon,
    required this.color,
    required this.label,
    required this.value,
    required this.hint,
  });

  final IconData icon;
  final Color color;
  final String label;
  final String value;
  final String hint;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: theme.colorScheme.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 15, color: color),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
          const Spacer(),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.titleLarge?.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          const SizedBox(height: 1),
          Text(
            hint,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall?.copyWith(
              fontSize: 11,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _AiRecordPanel extends StatelessWidget {
  const _AiRecordPanel({required this.summary});

  final MatchSummary summary;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final segments = [
      (summary.wins, colors.primary),
      (summary.draws, colors.outlineVariant),
      (summary.losses, colors.error),
    ];
    return _Panel(
      title: '人机战绩',
      trailing: summary.aiGames == 0 ? null : Text('${summary.aiGames} 局'),
      child: summary.aiGames == 0
          ? Text(
              '还没有和电脑交手，去首页开一局人机对战吧。',
              style: theme.textTheme.bodySmall?.copyWith(
                color: colors.onSurfaceVariant,
              ),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: SizedBox(
                    height: 9,
                    child: Row(
                      children: [
                        for (final (count, color) in segments)
                          if (count > 0)
                            Expanded(
                              flex: count,
                              child: ColoredBox(color: color),
                            ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    _RecordLegend(
                      color: colors.primary,
                      label: '胜',
                      value: summary.wins,
                    ),
                    _RecordLegend(
                      color: colors.outlineVariant,
                      label: '平',
                      value: summary.draws,
                    ),
                    _RecordLegend(
                      color: colors.error,
                      label: '负',
                      value: summary.losses,
                    ),
                    const Spacer(),
                    Text(
                      '胜率 ${summary.winPercent}%',
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
    );
  }
}

class _RecordLegend extends StatelessWidget {
  const _RecordLegend({
    required this.color,
    required this.label,
    required this.value,
  });

  final Color color;
  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(right: 16),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 5),
          Text(
            '$label $value',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _HighlightsPanel extends StatelessWidget {
  const _HighlightsPanel({required this.summary});

  final MatchSummary summary;

  @override
  Widget build(BuildContext context) {
    final efficiency = summary.entryEfficiency;
    return _Panel(
      title: '生涯亮点',
      child: Column(
        children: [
          _HighlightRow(
            icon: Icons.bolt,
            label: '人机最快获胜',
            value: summary.fastestWinMoves == null
                ? '—'
                : '${summary.fastestWinMoves} 步',
          ),
          _HighlightRow(
            icon: Icons.auto_awesome,
            label: '最长连跳',
            value: summary.longestJump > 0 ? '×${summary.longestJump}' : '—',
          ),
          _HighlightRow(
            icon: Icons.grid_on,
            label: '常用开局',
            value: summary.favoriteOpening == null
                ? '—'
                : '${summary.favoriteOpening} · '
                      '${summary.favoriteOpeningCount} 次',
          ),
          _HighlightRow(
            icon: Icons.speed,
            label: '入营效率',
            value: efficiency == null
                ? '—'
                : '${efficiency.toStringAsFixed(1)} 步/子',
            note: efficiency == null ? null : '获胜方平均每子步数',
            last: true,
          ),
        ],
      ),
    );
  }
}

class _HighlightRow extends StatelessWidget {
  const _HighlightRow({
    required this.icon,
    required this.label,
    required this.value,
    this.note,
    this.last = false,
  });

  final IconData icon;
  final String label;
  final String value;
  final String? note;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        border: last
            ? null
            : Border(bottom: BorderSide(color: colors.outlineVariant)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 17, color: colors.secondary),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: theme.textTheme.bodyMedium),
                if (note != null)
                  Text(
                    note!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontSize: 11,
                      color: colors.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
          ),
          Text(
            value,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _RecentMatches extends StatelessWidget {
  const _RecentMatches({required this.records});

  final List<MatchRecord> records;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return _Panel(
      title: '最近对局',
      trailing: Text(
        '最近 ${records.length} 场',
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 6),
      child: Column(
        children: [for (final record in records) _MatchTile(record: record)],
      ),
    );
  }
}

class _MatchTile extends StatelessWidget {
  const _MatchTile({required this.record});

  final MatchRecord record;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final accent = _accentColor(colors);
    final meta = StringBuffer(record.mode.label);
    meta.write(' · ${record.playerCount.label}');
    if (record.isAiGame) meta.write(' · ${record.difficulty.label}');
    final detail = StringBuffer(formatShortDateTime(record.playedAt));
    detail.write(' · ${record.moves} 步 · ${formatDuration(record.duration)}');
    if (record.longestJump > 0) {
      detail.write(' · 连跳 ×${record.longestJump}');
    }
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(10, 9, 10, 9),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.13),
              borderRadius: BorderRadius.circular(7),
            ),
            child: Text(
              record.outcomeLabel,
              style: theme.textTheme.labelSmall?.copyWith(
                color: accent,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  meta.toString(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  detail.toString(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontSize: 11,
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _accentColor(ColorScheme colors) {
    if (record.isDraw) return colors.onSurfaceVariant;
    if (record.isAiGame) {
      return record.humanWon ? colors.primary : colors.error;
    }
    return playerStyleOf(record.winner!).main;
  }
}

class _Panel extends StatelessWidget {
  const _Panel({
    required this.title,
    required this.child,
    this.trailing,
    this.padding = const EdgeInsets.fromLTRB(14, 12, 14, 12),
  });

  final String title;
  final Widget child;
  final Widget? trailing;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.colorScheme.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text(title, style: theme.textTheme.titleSmall),
              const Spacer(),
              ?trailing,
            ],
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}
