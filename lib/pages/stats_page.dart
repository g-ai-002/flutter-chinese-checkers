import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/settings_provider.dart';
import 'widgets/stats_widgets.dart';

/// 对局统计：生涯概览、人机战绩、亮点与最近对局。
class StatsPage extends StatelessWidget {
  const StatsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final matches = settings.matches;
    final summary = settings.matchSummary;
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
            ? const StatsEmptyState()
            : Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 760),
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 6, 16, 28),
                    children: [
                      StatsMetricGrid(summary: summary),
                      const SizedBox(height: 14),
                      AiRecordPanel(summary: summary),
                      const SizedBox(height: 14),
                      StatsHighlightsPanel(summary: summary),
                      const SizedBox(height: 14),
                      RecentMatchesPanel(records: matches.take(8).toList()),
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
