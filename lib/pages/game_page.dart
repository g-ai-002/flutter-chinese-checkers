import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../flame/checkers_game.dart';
import '../game/checkers_controller.dart';
import '../models/game_models.dart';
import '../models/match_record.dart';
import '../providers/settings_provider.dart';
import '../services/log_service.dart';
import '../services/sound_service.dart';
import '../utils/constants.dart';
import 'replay_page.dart';
import 'widgets/board_stage.dart';
import 'widgets/game_dialogs.dart';
import 'widgets/players_panel.dart';

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
    _controller = CheckersController(setup: widget.setup);
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
    setState(() {});
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
      SoundService.play(GameSound.win);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _showResult();
      });
    } else {
      _resultShown = false;
    }
  }

  void _openReplay() {
    final records = _controller.records;
    if (records.isEmpty) return;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ReplayPage(setup: widget.setup, records: records),
      ),
    );
  }

  void _showResult() {
    final record = MatchRecord.fromGame(
      setup: widget.setup,
      records: _controller.records,
      winner: _controller.winner,
      duration: _controller.duration,
    );
    unawaited(context.read<SettingsProvider>().recordMatch(record));
    LogService.info(
      '记录对局: ${record.outcomeLabel}, ${record.moves} 步, '
      '最长连跳 ${record.longestJump}, 用时 ${record.duration.inSeconds}s',
    );
    showGameResultDialog(
      context,
      record: record,
      onReplay: () {
        Navigator.of(context).pop();
        _openReplay();
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

  Future<void> _requestRestart() async {
    if (_controller.isFinished) {
      _controller.restart();
      _seenMoves = 0;
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('重新开始？'),
        content: const Text('当前对局的走子记录会被清空。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('重新开始'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
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
            '${widget.setup.playerCount.label} · ${widget.setup.mode.label}',
          ),
          actions: [
            IconButton(
              tooltip: _controller.isFinished ? '复盘' : '复盘（终局后可查看）',
              onPressed: _controller.isFinished ? _openReplay : null,
              icon: const Icon(Icons.history, size: 21),
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
              return wide ? _buildWide(theme) : _buildCompact(theme);
            },
          ),
        ),
      ),
    );
  }

  Widget _buildWide(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: Column(
              children: [
                TurnBanner(controller: _controller),
                const SizedBox(height: 10),
                Expanded(
                  child: BoardStage(
                    game: _game,
                    gameKey: const ValueKey('board'),
                  ),
                ),
                const SizedBox(height: 10),
                GameActionBar(
                  controller: _controller,
                  onHint: _controller.requestHint,
                  onUndo: _controller.undo,
                  onRestart: _requestRestart,
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
                Text('对局进度', style: theme.textTheme.titleSmall),
                const SizedBox(height: 10),
                PlayerStandings(controller: _controller, vertical: true),
                const Spacer(),
                _Legend(theme: theme),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompact(ThemeData theme) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 4, 12, 0),
          child: TurnBanner(controller: _controller),
        ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: PlayerStandings(controller: _controller),
        ),
        const SizedBox(height: 4),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: BoardStage(game: _game, gameKey: const ValueKey('board')),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 4, 12, 10),
          child: GameActionBar(
            controller: _controller,
            onHint: _controller.requestHint,
            onUndo: _controller.undo,
            onRestart: _requestRestart,
          ),
        ),
      ],
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend({required this.theme});

  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    final colors = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colors.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('怎么看', style: theme.textTheme.titleSmall),
          const SizedBox(height: 10),
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
