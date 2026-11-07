import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/game_models.dart';
import '../models/match_summary.dart';
import '../providers/settings_provider.dart';
import '../utils/constants.dart';
import 'archive_page.dart';
import 'challenge_page.dart';
import 'game_page.dart';
import 'settings_page.dart';
import 'stats_page.dart';
import 'widgets/game_dialogs.dart';
import 'widgets/setup_sheet.dart';
import 'widgets/star_preview.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: isDark
                ? const [Color(0xFF1B2320), Color(0xFF101413)]
                : const [Color(0xFFFBF7EC), Color(0xFFEDE6D4)],
          ),
        ),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final wide = constraints.maxWidth >= kHomeWideBreakpoint;
              final horizontal = constraints.maxWidth >= kHomePaddingBreakpoint
                  ? 36.0
                  : 20.0;
              return SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(horizontal, 10, horizontal, 28),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 880),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const _TopBar(),
                        const SizedBox(height: 16),
                        if (wide)
                          Row(
                            children: [
                              SizedBox(
                                width: math.min(
                                  300,
                                  constraints.maxWidth * 0.36,
                                ),
                                child: StarPreview(theme: settings.boardTheme),
                              ),
                              const SizedBox(width: 32),
                              Expanded(child: _HeroText(settings: settings)),
                            ],
                          )
                        else ...[
                          Center(
                            child: SizedBox(
                              width: math.min(280, constraints.maxWidth * 0.78),
                              child: StarPreview(theme: settings.boardTheme),
                            ),
                          ),
                          const SizedBox(height: 20),
                          _HeroText(settings: settings),
                        ],
                        const SizedBox(height: 28),
                        _ModeCard(
                          icon: Icons.smart_toy_outlined,
                          color: theme.colorScheme.primary,
                          title: PlayMode.vsAi.label,
                          subtitle:
                              '${settings.playerCount.label} · '
                              '${settings.difficulty.label}难度 · 自动接管电脑回合',
                          onTap: () => _start(context, settings, PlayMode.vsAi),
                        ),
                        const SizedBox(height: 12),
                        _ModeCard(
                          icon: Icons.groups_outlined,
                          color: theme.colorScheme.tertiary,
                          title: PlayMode.local.label,
                          subtitle: '同一台设备轮流落子 · 支持 2 / 3 / 4 / 6 人',
                          onTap: () =>
                              _start(context, settings, PlayMode.local),
                        ),
                        const SizedBox(height: 12),
                        _ModeCard(
                          icon: Icons.flag_outlined,
                          color: theme.colorScheme.secondary,
                          title: '残局挑战',
                          subtitle: settings.challengeCompleted == 0
                              ? '${settings.maxChallengeStars ~/ 3} 道残局 · '
                                    '限步通关 · 逐关解锁'
                              : '已通关 ${settings.challengeCompleted}/'
                                    '${settings.maxChallengeStars ~/ 3} · '
                                    '${settings.challengeStars} 星',
                          onTap: () => _openChallenge(context),
                        ),
                        const SizedBox(height: 12),
                        _ModeCard(
                          icon: Icons.collections_bookmark_outlined,
                          color: theme.colorScheme.secondary,
                          title: '棋谱库',
                          subtitle: settings.replays.isEmpty
                              ? '终局自动存档 · 分享码导入导出'
                              : '已存 ${settings.replays.length} 局 · '
                                    '分享码导入导出',
                          onTap: () => _openArchive(context),
                        ),
                        const SizedBox(height: 12),
                        _StatsCard(
                          summary: settings.matchSummary,
                          onTap: () => _openStats(context),
                        ),
                        const SizedBox(height: 18),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            TextButton.icon(
                              onPressed: () => showRulesDialog(context),
                              icon: const Icon(
                                Icons.menu_book_outlined,
                                size: 18,
                              ),
                              label: const Text('玩法说明'),
                            ),
                            const SizedBox(width: 8),
                            TextButton.icon(
                              onPressed: () => _openSettings(context),
                              icon: const Icon(Icons.tune, size: 18),
                              label: const Text('设置'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Center(
                          child: Text(
                            'v${AppConstants.version} · 本地运行，无需联网',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Future<void> _start(
    BuildContext context,
    SettingsProvider settings,
    PlayMode mode,
  ) async {
    final setup = await showGameSetupSheet(
      context,
      mode: mode,
      settings: settings,
    );
    if (setup == null || !context.mounted) return;
    await Navigator.of(context)
        .push(MaterialPageRoute<void>(builder: (_) => GamePage(setup: setup)));
  }

  void _openSettings(BuildContext context) {
    Navigator.of(context)
        .push(MaterialPageRoute<void>(builder: (_) => const SettingsPage()));
  }

  void _openStats(BuildContext context) {
    Navigator.of(context)
        .push(MaterialPageRoute<void>(builder: (_) => const StatsPage()));
  }

  void _openArchive(BuildContext context) {
    Navigator.of(context)
        .push(MaterialPageRoute<void>(builder: (_) => const ArchivePage()));
  }

  void _openChallenge(BuildContext context) {
    Navigator.of(context)
        .push(MaterialPageRoute<void>(builder: (_) => const ChallengePage()));
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: theme.colorScheme.primary,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            Icons.blur_on,
            size: 20,
            color: theme.colorScheme.onPrimary,
          ),
        ),
        const SizedBox(width: 10),
        Text(
          AppConstants.appName,
          style: theme.textTheme.titleMedium?.copyWith(letterSpacing: 1.5),
        ),
        const Spacer(),
        IconButton(
          tooltip: '设置',
          onPressed: () => Navigator.of(
            context,
          ).push(MaterialPageRoute<void>(builder: (_) => const SettingsPage())),
          icon: const Icon(Icons.settings_outlined, size: 21),
        ),
      ],
    );
  }
}

class _HeroText extends StatelessWidget {
  const _HeroText({required this.settings});

  final SettingsProvider settings;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '六角星上的\n连跳博弈',
          style: theme.textTheme.headlineMedium?.copyWith(
            height: 1.25,
            letterSpacing: 3,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          '中国跳棋 · 单步与连跳，十枚棋子抢先进入对面营地。'
          '支持人机对战与 2 / 3 / 4 / 6 人同屏轮流。',
          style: theme.textTheme.bodyMedium?.copyWith(
            height: 1.7,
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 16),
        const Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _Tag(icon: Icons.bolt, text: '连跳加速'),
            _Tag(icon: Icons.screen_rotation_alt, text: '跨端自适应'),
            _Tag(icon: Icons.offline_bolt, text: '离线可玩'),
          ],
        ),
      ],
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface.withValues(alpha: 0.75),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: theme.colorScheme.outline),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: theme.colorScheme.primary),
          const SizedBox(width: 5),
          Text(text, style: theme.textTheme.bodySmall),
        ],
      ),
    );
  }
}

class _StatsCard extends StatelessWidget {
  const _StatsCard({required this.summary, required this.onTap});

  final MatchSummary summary;
  final VoidCallback onTap;

  String get _subtitle {
    if (summary.total == 0) return '完成第一局后查看胜率与亮点';
    final parts = <String>['已下 ${summary.total} 局'];
    if (summary.aiGames > 0) {
      parts.add('人机胜率 ${summary.winPercent}%');
    } else {
      parts.add('同屏 ${summary.localGames} 局');
    }
    if (summary.longestJump > 0) {
      parts.add('最长连跳 ×${summary.longestJump}');
    }
    return parts.join(' · ');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = theme.colorScheme.secondary;
    return Material(
      color: theme.colorScheme.surface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: theme.colorScheme.outline),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.13),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.query_stats, color: color, size: 21),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('对局统计', style: theme.textTheme.titleSmall),
                    const SizedBox(height: 2),
                    Text(
                      _subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ModeCard extends StatelessWidget {
  const _ModeCard({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.surface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: theme.colorScheme.outline),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.13),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(icon, color: color, size: 23),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: theme.textTheme.titleSmall),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
