import 'dart:async';
import 'dart:math' as math;

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
import 'widgets/game_hud.dart';

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
      LogService.info('残局通关: ${challenge.id}, $moves 步, $stars 星');
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

  /// 只刷新依赖对局状态的小区域，棋盘画布不参与重建。
  Widget _watch(Widget Function() builder) {
    return ListenableBuilder(
      listenable: _controller,
      builder: (context, _) => builder(),
    );
  }

  String get _title {
    final challenge = widget.setup.challenge;
    if (challenge == null) {
      return '${widget.setup.playerCount.label} · ${widget.setup.mode.label}';
    }
    return '第 ${challengeIndexOf(challenge) + 1} 关 · ${challenge.name}';
  }

  @override
  Widget build(BuildContext context) {
    final challenge = widget.setup.challenge;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final leave = await confirmLeaveGame(context);
        if (!mounted || !leave) return;
        Navigator.of(this.context).pop();
      },
      child: Scaffold(
        body: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final wide = constraints.maxWidth >= kGameWideBreakpoint;
              final dense = constraints.maxHeight < 700;
              // 右侧为复盘 / 玩法按钮留出位置，标题在其中省略而不是被压住。
              final rightReserve = challenge == null ? 112.0 : 62.0;
              final hudMaxWidth = math.max(
                180.0,
                constraints.maxWidth - 20 - rightReserve,
              );
              final hudWidth = math.min(230.0, hudMaxWidth);
              return Stack(
                children: [
                  // 棋盘独占整个可用区域，四周信息全部叠在它上面。
                  Positioned.fill(
                    child: BoardStage(
                      game: _game,
                      gameKey: const ValueKey('board'),
                      maxWidth: double.infinity,
                    ),
                  ),
                  Positioned(
                    left: 10,
                    top: 8,
                    child: ConstrainedBox(
                      constraints: BoxConstraints(maxWidth: hudMaxWidth),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              HudButton(
                                icon: Icons.arrow_back,
                                tooltip: '返回',
                                onPressed: _leave,
                              ),
                              const SizedBox(width: 8),
                              Flexible(
                                child: HudPanel(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 9,
                                  ),
                                  child: Text(
                                    _title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleSmall,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          _watch(
                            () => challenge == null
                                ? TurnHud(
                                    controller: _controller,
                                    width: hudWidth,
                                    dense: dense,
                                  )
                                : ChallengeHud(
                                    controller: _controller,
                                    level: challenge,
                                    width: hudWidth,
                                  ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Positioned(
                    right: 10,
                    top: 8,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (challenge == null) ...[
                              _watch(
                                () => HudButton(
                                  icon: Icons.history,
                                  tooltip: _controller.isFinished
                                      ? '复盘'
                                      : '复盘（终局后可查看）',
                                  onPressed: _controller.isFinished
                                      ? _openReplay
                                      : null,
                                ),
                              ),
                              const SizedBox(width: 6),
                            ],
                            HudButton(
                              icon: Icons.info_outline,
                              tooltip: '玩法说明',
                              onPressed: () => showRulesDialog(context),
                            ),
                          ],
                        ),
                        if (challenge != null) ...[
                          const SizedBox(height: 8),
                          HudButton(
                            icon: Icons.flag_outlined,
                            tooltip: '查看关卡目标',
                            label: '关卡目标',
                            onPressed: () =>
                                showChallengeBriefDialog(context, challenge),
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (challenge == null)
                    Positioned(
                      left: 10,
                      bottom: 10,
                      child: dense
                          ? HudButton(
                              icon: Icons.leaderboard_outlined,
                              tooltip: '对局进度',
                              onPressed: () => showPlayerProgressDialog(
                                context,
                                _controller,
                              ),
                            )
                          : _watch(
                              () => PlayersHud(
                                controller: _controller,
                                width: wide ? 132 : 122,
                                showTitle: wide,
                              ),
                            ),
                    ),
                  Positioned(
                    right: 10,
                    bottom: 10,
                    child: _watch(
                      () => ActionDock(
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
            },
          ),
        ),
      ),
    );
  }
}
