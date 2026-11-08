import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/settings_provider.dart';
import 'widgets/confirm_dialog.dart';
import 'widgets/stats_widgets.dart';

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

  Future<void> _confirmClear(BuildContext context, SettingsProvider settings) async {
    final confirmed = await showConfirmDialog(
      context,
      title: '清空对局统计？',
      message: '所有历史对局摘要都会被删除，且无法恢复。',
      confirmLabel: '清空',
    );
    if (!confirmed) return;
    await settings.clearMatches();
  }
}
