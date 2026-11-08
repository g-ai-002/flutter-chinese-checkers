import 'package:flutter/material.dart';

import '../../models/game_models.dart';
import '../../models/replay_archive.dart';
import '../../utils/formatters.dart';

class ArchiveEmptyState extends StatelessWidget {
  const ArchiveEmptyState({super.key, required this.onImport});

  final VoidCallback onImport;

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
              Icons.collections_bookmark_outlined,
              size: 52,
              color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
            ),
            const SizedBox(height: 16),
            Text('还没有存档棋谱', style: theme.textTheme.titleMedium),
            const SizedBox(height: 6),
            Text(
              '对局结束后会自动存一份完整棋谱，\n也可以导入别人分享的棋谱码。',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                height: 1.6,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 18),
            OutlinedButton.icon(
              onPressed: onImport,
              icon: const Icon(Icons.input, size: 18),
              label: const Text('导入棋谱'),
            ),
          ],
        ),
      ),
    );
  }
}

class ReplayArchiveTile extends StatelessWidget {
  const ReplayArchiveTile({
    super.key,
    required this.archive,
    required this.onOpen,
    required this.onExport,
    required this.onDelete,
  });

  final ReplayArchive archive;
  final VoidCallback onOpen;
  final VoidCallback onExport;
  final VoidCallback onDelete;

  String get _title {
    if (archive.setup.mode != PlayMode.vsAi) return archive.title;
    return '${archive.title} · ${archive.setup.difficulty.label}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.surface,
      borderRadius: BorderRadius.circular(14),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onOpen,
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 12, 6, 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: theme.colorScheme.outline),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.history, size: 21, color: theme.colorScheme.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${formatShortDateTime(archive.savedAt)} · '
                      '${archive.moves} 步 · ${formatDuration(archive.duration)}',
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
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color:
                      (archive.isDraw
                              ? theme.colorScheme.onSurfaceVariant
                              : theme.colorScheme.tertiary)
                          .withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  archive.outcomeLabel,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: archive.isDraw
                        ? theme.colorScheme.onSurfaceVariant
                        : theme.colorScheme.tertiary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              PopupMenuButton<String>(
                tooltip: '棋谱操作',
                icon: const Icon(Icons.more_vert, size: 20),
                onSelected: (value) {
                  if (value == 'export') {
                    onExport();
                  } else if (value == 'delete') {
                    onDelete();
                  }
                },
                itemBuilder: (context) => const [
                  PopupMenuItem(value: 'export', child: Text('导出棋谱')),
                  PopupMenuItem(value: 'delete', child: Text('删除')),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
