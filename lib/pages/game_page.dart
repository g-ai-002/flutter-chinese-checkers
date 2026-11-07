import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../flame/checkers_game.dart';
import '../game/challenge_levels.dart';
import '../game/checkers_controller.dart';
import '../models/challenge_result.dart';
import '../models/game_models.dart';
import '../models/match_record.dart';
import '../models/replay_archive.dart';
import '../providers/settings_provider.dart';
import '../services/log_service.dart';
import '../services/sound_service.dart';
import '../utils/constants.dart';
import 'replay_page.dart';
import 'widgets/board_stage.dart';
import 'widgets/challenge_widgets.dart';
import 'widgets/confirm_dialog.dart';
import 'widgets/game_dialogs.dart';
import 'widgets/players_panel.dart';
import 'widgets/surface_card.dart';

class GamePage extends StatefulWidget {
  const GamePage({super.key, required this.setup});

  final GameSetup setup;

  @override
  State<GamePage> createState() => _GamePageState();
}

class _GamePageState extends State<GamePage> {
  late final CheckersController _controller;
  late final CheckersGame _game;
  int _seenMoves = 0;
  bool _resultShown = false;

  @override
  void initState() {
    super.initState();
    final settings = context.read<SettingsProvider>();
    _controller = CheckersController(
      setup: widget.setup,
      allowUndo: !widget.setup.isChallenge,
    );
    _game = CheckersGame(
      source: _controller,
      theme: settings.boardTheme,
      showHints: settings.showHints,
    );
    _controller.addListener(_onControllerChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _controller.start();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _game.theme = context.read<SettingsProvider>().boardTheme;
  }

  @override
  void dispose() {
    _controller.removeListener(_onControllerChanged);
    _controller.dispose();
    super.dispose();
  }

  void _onControllerChanged() {
    if (!mounted) return;
    final count = _controller.history.length;
    if (count > _seenMoves) {
      final move = _controller.lastMove;
      if (move != null) {
        SoundService.play(move.jump ? GameSound.jump : GameSound.step);
      }
    }
    _seenMoves = count;

    if (_controller.isFinished) {
      if (_resultShown) return;
      _resultShown = true;
      if (_controller.winner != null) SoundService.play(GameSound.win);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _showResult();
      });
    } else {
      _resultShown = false;
    }
  }

  void _openReplay() {
    if (_controller.history.isEmpty) return;
    _openArchive(_archive());
  }

  void _openArchive(ReplayArchive archive) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => ReplayPage(archive: archive)),
    );
  }

  /// 当前对局的完整棋谱，复盘与终局存档共用。
  ReplayArchive _archive() => ReplayArchive.fromGame(
    setup: widget.setup,
    records: _controller.records,
    winner: _controller.winner,
    duration: _controller.duration,
  );

  void _showResult() {
    final challenge = widget.setup.challenge;
    if (challenge != null) {
      _showChallengeResult(challenge);
      return;
    }
    final settings = context.read<SettingsProvider>();
    final record = MatchRecord.fromGame(
      setup: widget.setup,
      records: _controller.records,
      winner: _controller.winner,
      duration: _controller.duration,
    );
    final archive = _archive();
    unawaited(settings.recordMatch(record));
    unawaited(settings.saveReplay(archive));
    LogService.info(
      '记录对局: ${record.outcomeLabel}, ${record.moves} 步, '
      '最长连跳 ${record.longestJump}, 用时 ${record.duration.inSeconds}s',
    );
    LogService.info('存档棋谱: ${archive.title}, ${archive.moves} 手');
    showGameResultDialog(
      context,
      record: record,
      onReplay: () {
        Navigator.of(context).pop();
        _openArchive(archive);
      },
      onRestart: () {
        Navigator.of(context).pop();
        _controller.restart();
        _seenMoves = 0;
      },
      onHome: () {
        Navigator.of(context).pop();
        Navigator.of(context).pop();
      },
    );
  }

  /// 残局结算：成功后保存最佳成绩并解锁下一关。
  void _showChallengeResult(ChallengeLevel challenge) {
    final settings = context.read<SettingsProvider>();
    final success = _controller.winner != null;
    final moves = _controller.history.length;
    final stars = success ? challenge.starsFor(moves) : 0;
    if (success) {
      unawaited(
        settings.saveChallengeResult(
          ChallengeResult(levelId: challenge.id, stars: stars, moves: moves),
        ),
      );
      LogService.info(
        '残局通关: ${challenge.id}, $moves 步, $stars 星',
      );
    } else {
      LogService.info('残局失败: ${challenge.id}, 预算 ${challenge.moveLimit} 步');
    }
    final next = success ? challengeAfter(challenge) : null;
    showChallengeResultDialog(
      context,
      level: challenge,
      success: success,
      moves: moves,
      onBack: () => Navigator.of(context).pop(),
      onRetry: () {
        _controller.restart();
        _seenMoves = 0;
      },
      onNext: next == null ? null : () => _openLevel(next),
    );
  }

  void _openLevel(ChallengeLevel level) {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => GamePage(setup: GameSetup.forChallenge(level)),
      ),
    );
  }

  Future<void> _requestRestart() async {
    if (widget.setup.isChallenge || _controller.isFinished) {
      _controller.restart();
      _seenMoves = 0;
      return;
    }
    final confirmed = await showConfirmDialog(
      context,
      title: '重新开始？',
      message: '当前对局的走子记录会被清空。',
      confirmLabel: '重新开始',
    );
    if (!confirmed || !mounted) return;
    _controller.restart();
    _seenMoves = 0;
  }

  Future<void> _leave() async {
    if (_controller.isFinished) {
      Navigator.of(context).pop();
      return;
    }
    final leave = await confirmLeaveGame(context);
    if (leave && mounted) Navigator.of(context).pop();
  }

  /// 只刷新依赖对局状态的小区域，棋盘画布不参与整页重建。
  Widget _watch(Widget Function() builder) {
    return ListenableBuilder(
      listenable: _controller,
      builder: (context, _) => builder(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final leave = await confirmLeaveGame(context);
        if (!mounted || !leave) return;
        Navigator.of(this.context).pop();
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            tooltip: '返回',
            onPressed: _leave,
            icon: const Icon(Icons.arrow_back),
          ),
          title: Text(
            widget.setup.challenge == null
                ? '${widget.setup.playerCount.label} · ${widget.setup.mode.label}'
                : '第 ${challengeIndexOf(widget.setup.challenge!) + 1} 关 · '
                      '${widget.setup.challenge!.name}',
          ),
          actions: [
            if (widget.setup.challenge == null)
              _watch(
                () => IconButton(
                  tooltip: _controller.isFinished ? '复盘' : '复盘（终局后可查看）',
                  onPressed: _controller.isFinished ? _openReplay : null,
                  icon: const Icon(Icons.history, size: 21),
                ),
              ),
            IconButton(
              tooltip: '玩法说明',
              onPressed: () => showRulesDialog(context),
              icon: const Icon(Icons.info_outline, size: 21),
            ),
            const SizedBox(width: 6),
          ],
        ),
        body: SafeArea(
          top: false,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final wide = constraints.maxWidth >= kGameWideBreakpoint;
              return wide ? _buildWide(theme) : _buildCompact();
            },
          ),
        ),
      ),
    );
  }

  Widget _buildWide(ThemeData theme) {
    final challenge = widget.setup.challenge;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: Column(
              children: [
                if (challenge == null)
                  _watch(() => TurnBanner(controller: _controller))
                else
                  _watch(
                    () => ChallengeStatusBar(
                      controller: _controller,
                      level: challenge,
                    ),
                  ),
                const SizedBox(height: 10),
                Expanded(
                  child: BoardStage(
                    game: _game,
                    gameKey: const ValueKey('board'),
                  ),
                ),
                const SizedBox(height: 10),
                _watch(
                  () => GameActionBar(
                    controller: _controller,
                    onHint: _controller.requestHint,
                    onUndo: _controller.undo,
                    onRestart: _requestRestart,
                    showUndo: challenge == null,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 20),
          SizedBox(
            width: 300,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 4),
                Text(
                  challenge == null ? '对局进度' : '关卡目标',
                  style: theme.textTheme.titleSmall,
                ),
                const SizedBox(height: 10),
                if (challenge == null)
                  _watch(
                    () => PlayerStandings(
                      controller: _controller,
                      vertical: true,
                    ),
                  )
                else
                  _watch(
                    () => _ChallengeBrief(level: challenge),
                  ),
                const Spacer(),
                _Legend(theme: theme),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompact() {
    final challenge = widget.setup.challenge;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 4, 12, 0),
          child: challenge == null
              ? _watch(() => TurnBanner(controller: _controller))
              : _watch(
                  () => ChallengeStatusBar(
                    controller: _controller,
                    level: challenge,
                  ),
                ),
        ),
        if (challenge == null) ...[
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: _watch(() => PlayerStandings(controller: _controller)),
          ),
        ],
        const SizedBox(height: 4),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: BoardStage(game: _game, gameKey: const ValueKey('board')),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 4, 12, 10),
          child: _watch(
            () => GameActionBar(
              controller: _controller,
              onHint: _controller.requestHint,
              onUndo: _controller.undo,
              onRestart: _requestRestart,
              showUndo: challenge == null,
            ),
          ),
        ),
      ],
    );
  }
}

/// 宽屏残局的关卡说明：参考步数、星级门槛与障碍提示。
class _ChallengeBrief extends StatelessWidget {
  const _ChallengeBrief({required this.level});

  final ChallengeLevel level;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final style = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
      height: 1.6,
    );
    return SurfaceCard(
      title: '把 10 枚棋子送进上方营地',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(level.hint, style: style),
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(
                Icons.star_rounded,
                size: 18,
                color: Color(0xFFE0A526),
              ),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  '三星 ≤ ${level.parMoves} 步 · '
                  '两星 ≤ ${level.parMoves + 2} 步',
                  style: style,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text('障碍子可跨越，不会移动。', style: style),
        ],
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend({required this.theme});

  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    final colors = theme.colorScheme;
    return SurfaceCard(
      title: '怎么看',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _LegendRow(
            marker: Container(
              width: 9,
              height: 9,
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
            ),
            text: '圆点是单步可落位置',
          ),
          const SizedBox(height: 8),
          _LegendRow(
            marker: Container(
              width: 13,
              height: 13,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.8),
                  width: 2,
                ),
              ),
            ),
            text: '双环是连跳可落位置',
          ),
          const SizedBox(height: 8),
          _LegendRow(
            marker: Container(
              width: 9,
              height: 9,
              decoration: BoxDecoration(
                color: colors.tertiary,
                shape: BoxShape.circle,
              ),
            ),
            text: '营地底色的对面即目标',
          ),
        ],
      ),
    );
  }
}

class _LegendRow extends StatelessWidget {
  const _LegendRow({required this.marker, required this.text});

  final Widget marker;
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        SizedBox(width: 15, child: Center(child: marker)),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }
}
