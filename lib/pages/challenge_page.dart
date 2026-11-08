import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../game/challenge_levels.dart';
import '../models/challenge_result.dart';
import '../models/game_models.dart';
import '../providers/settings_provider.dart';
import 'game_page.dart';
import 'widgets/challenge_widgets.dart';
import 'widgets/confirm_dialog.dart';

class ChallengePage extends StatelessWidget {
  const ChallengePage({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    return Scaffold(
      appBar: AppBar(
        title: const Text('残局挑战'),
        actions: [
          IconButton(
            tooltip: '重置进度',
            onPressed: settings.challengeCompleted == 0 ? null : () => _reset(context, settings),
            icon: const Icon(Icons.restart_alt, size: 21),
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
        children: [
          _SummaryCard(settings: settings),
          const SizedBox(height: 6),
          for (final tier in ChallengeTier.values) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 18, 4, 8),
              child: Text(
                tier.label,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  letterSpacing: 1,
                ),
              ),
            ),
            for (final entry in _levelsOf(tier))
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _LevelTile(
                  level: entry.level,
                  index: entry.index,
                  result: settings.challengeResultOf(entry.level),
                  unlocked: _unlocked(entry.index, settings),
                  onTap: () => _start(context, entry.level),
                ),
              ),
          ],
          const SizedBox(height: 6),
          Text(
            '障碍子不会移动，但可以跨越。填满目标营地即通关，步数越少星级越高。',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall
                ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant, height: 1.6),
          ),
        ],
      ),
    );
  }

  List<({ChallengeLevel level, int index})> _levelsOf(ChallengeTier tier) => [
    for (var i = 0; i < kChallengeLevels.length; i++)
      if (kChallengeLevels[i].tier == tier) (level: kChallengeLevels[i], index: i),
  ];

  bool _unlocked(int index, SettingsProvider settings) =>
      index == 0 || settings.challengeResults.containsKey(kChallengeLevels[index - 1].id);

  Future<void> _start(BuildContext context, ChallengeLevel level) async {
    final setup = GameSetup.forChallenge(level);
    await Navigator.of(context)
        .push(MaterialPageRoute<void>(builder: (_) => GamePage(setup: setup)));
  }

  Future<void> _reset(BuildContext context, SettingsProvider settings) async {
    final confirmed = await showConfirmDialog(
      context,
      title: '重置挑战进度？',
      message: '已获得的星级与最佳步数会被清空，关卡重新锁定。',
      confirmLabel: '重置',
    );
    if (confirmed) await settings.clearChallengeResults();
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.settings});

  final SettingsProvider settings;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final stars = settings.challengeStars;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.colorScheme.outline),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(Icons.flag_outlined, color: theme.colorScheme.primary, size: 23),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '已通关 ${settings.challengeCompleted}/${kChallengeLevels.length}',
                  style: theme.textTheme.titleSmall,
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.star_rounded, size: 16, color: Color(0xFFE0A526)),
                    const SizedBox(width: 3),
                    Text(
                      '$stars / ${settings.maxChallengeStars} 星',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Text(
            '逐关解锁',
            style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

class _LevelTile extends StatelessWidget {
  const _LevelTile({
    required this.level,
    required this.index,
    required this.result,
    required this.unlocked,
    required this.onTap,
  });

  final ChallengeLevel level;
  final int index;
  final ChallengeResult? result;
  final bool unlocked;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = unlocked ? theme.colorScheme.primary : theme.colorScheme.onSurfaceVariant;
    return Material(
      color: theme.colorScheme.surface,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        key: ValueKey('challenge-${level.id}'),
        onTap: unlocked ? onTap : null,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: theme.colorScheme.outline),
          ),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: unlocked
                    ? Text(
                        '${index + 1}',
                        style: theme.textTheme.titleSmall?.copyWith(
                          color: accent,
                          fontWeight: FontWeight.w700,
                        ),
                      )
                    : Icon(Icons.lock_outline, size: 18, color: accent),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            level.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.titleSmall,
                          ),
                        ),
                        ChallengeStars(stars: result?.stars ?? 0, size: 15),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      unlocked
                          ? result == null
                                ? level.hint
                                : '最佳 ${result!.moves} 步 · 参考 ${level.parMoves} 步'
                          : '通关上一关后解锁',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Icon(Icons.chevron_right, color: accent.withValues(alpha: 0.7)),
            ],
          ),
        ),
      ),
    );
  }
}
