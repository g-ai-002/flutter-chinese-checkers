import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/replay_archive.dart';
import '../providers/settings_provider.dart';
import '../services/log_service.dart';
import 'replay_page.dart';
import 'widgets/archive_widgets.dart';
import 'widgets/replay_exchange.dart';

/// 棋谱库：浏览终局自动存档的棋谱，支持导入、导出与删除。
class ArchivePage extends StatelessWidget {
  const ArchivePage({super.key});

  @override
  Widget build(BuildContext context) {
    final replays = context.watch<SettingsProvider>().replays;
    return Scaffold(
      appBar: AppBar(
        title: const Text('棋谱库'),
        actions: [
          IconButton(
            tooltip: '导入棋谱',
            onPressed: () => _import(context),
            icon: const Icon(Icons.input, size: 20),
          ),
          if (replays.isNotEmpty)
            IconButton(
              tooltip: '清空棋谱',
              onPressed: () => _clear(context),
              icon: const Icon(Icons.delete_outline, size: 21),
            ),
          const SizedBox(width: 6),
        ],
      ),
      body: SafeArea(
        top: false,
        child: replays.isEmpty
            ? ArchiveEmptyState(onImport: () => _import(context))
            : Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 760),
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 6, 16, 28),
                    itemCount: replays.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final archive = replays[index];
                      return ReplayArchiveTile(
                        archive: archive,
                        onOpen: () => _open(context, archive),
                        onExport: () =>
                            showReplayExportDialog(context, archive),
                        onDelete: () => _delete(context, archive),
                      );
                    },
                  ),
                ),
              ),
      ),
    );
  }

  void _open(BuildContext context, ReplayArchive archive) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => ReplayPage(archive: archive)),
    );
  }

  Future<void> _import(BuildContext context) async {
    final archive = await showReplayImportDialog(context);
    if (archive == null || !context.mounted) return;
    final settings = context.read<SettingsProvider>();
    await settings.saveReplay(archive);
    LogService.info('导入棋谱: ${archive.title}, ${archive.moves} 手');
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text('已导入 ${archive.moves} 手棋谱')));
  }

  Future<void> _delete(BuildContext context, ReplayArchive archive) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('删除这份棋谱？'),
        content: const Text('删除后无法恢复，分享出去的棋谱码仍可重新导入。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    await context.read<SettingsProvider>().removeReplay(archive.id);
    LogService.info('删除棋谱: ${archive.title}, ${archive.moves} 手');
  }

  Future<void> _clear(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('清空棋谱库？'),
        content: const Text('所有存档棋谱都会被删除，且无法恢复。'),
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
    if (confirmed != true || !context.mounted) return;
    await context.read<SettingsProvider>().clearReplays();
    LogService.info('清空棋谱库');
  }
}
