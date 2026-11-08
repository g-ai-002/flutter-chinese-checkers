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
import '../utils/board_orientation.dart';
import '../utils/constants.dart';
import 'replay_page.dart';
import 'widgets/board_stage.dart';
import 'widgets/challenge_widgets.dart';
import 'widgets/confirm_dialog.dart';
import 'widgets/game_dialogs.dart';
import 'widgets/game_hud.dart';
import 'widgets/game_layout.dart';

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
  Size? _orientationSize;

  @override
  void initState() {
    super.initState();
    final settings = context.read<SettingsProvider>();
    _controller = CheckersController(setup: widget.setup, allowUndo: !widget.setup.isChallenge);
    _game = CheckersGame(
      source: _controller,
      theme: settings.boardTheme,
      showHints: settings.showHints,
      logicRate: settings.logicRate,
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
    // 关掉对局页时一并收回方向控制并停掉棋盘渲染，不留后台任务。
    BoardOrientation.restore();
    _game.shutdown();
    _controller.dispose();
    super.dispose();
  }

  /// 窄屏按网格比例锁定横竖屏；尺寸变化时才请求平台，避免每帧调用。
  void _syncOrientation(Size size) {
    if (_orientationSize == size) return;
    _orientationSize = size;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) BoardOrientation.apply(size);
    });
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
    Navigator.of(context)
        .push(MaterialPageRoute<void>(builder: (_) => ReplayPage(archive: archive)));
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
      MaterialPageRoute<void>(builder: (_) => GamePage(setup: GameSetup.forChallenge(level))),
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
    return ListenableBuilder(listenable: _controller, builder: (context, _) => builder());
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
              _syncOrientation(constraints.biggest);
              final layout = GameLayout.resolve(
                size: constraints.biggest,
                challenge: challenge != null,
                players: widget.setup.players,
                showProgressTitle: wide,
              );
              // 浮层尺寸固定，字号最多放大到 1.3 倍，避免撑破布局。
              return MediaQuery.withClampedTextScaling(
                maxScaleFactor: 1.3,
                child: Stack(
                  children: [
                    // 棋盘独占可用区域；竖屏时上下信息带由 BoardStage 让出。
                    Positioned.fill(
                      child: BoardStage(
                        game: _game,
                        gameKey: const ValueKey('board'),
                        maxWidth: double.infinity,
                        padding: layout.boardInsets,
                      ),
                    ),
                    Positioned(
                      left: layout.left,
                      top: layout.top,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(
                            width: layout.titleWidth,
                            child: Row(
                              children: [
                                HudButton(icon: Icons.arrow_back, tooltip: '返回', onPressed: _leave),
                                const SizedBox(width: 8),
                                Flexible(
                                  child: HudPanel(
                                    key: const ValueKey('hud-title'),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 9,
                                    ),
                                    child: Text(
                                      _title,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: Theme.of(context).textTheme.titleSmall,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 8),
                          _watch(
                            () => challenge == null
                                ? TurnHud(
                                    key: const ValueKey('hud-status'),
                                    controller: _controller,
                                    width: layout.hudWidth,
                                    dense: layout.dense,
                                  )
                                : ChallengeHud(
                                    key: const ValueKey('hud-status'),
                                    controller: _controller,
                                    level: challenge,
                                    width: layout.hudWidth,
                                  ),
                          ),
                        ],
                      ),
                    ),
                    Positioned(
                      right: layout.rightTop,
                      top: layout.top,
                      child: Column(
                        key: const ValueKey('hud-tools'),
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (challenge == null) ...[
                                _watch(
                                  () => HudButton(
                                    icon: Icons.history,
                                    tooltip: _controller.isFinished ? '复盘' : '复盘（终局后可查看）',
                                    onPressed: _controller.isFinished ? _openReplay : null,
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
                              onPressed: () => showChallengeBriefDialog(context, challenge),
                            ),
                          ],
                        ],
                      ),
                    ),
                    if (challenge == null)
                      Positioned(
                        left: layout.progressLeft,
                        bottom: layout.bottom,
                        child: layout.progressButton
                            ? HudButton(
                                key: const ValueKey('hud-progress'),
                                icon: Icons.leaderboard_outlined,
                                tooltip: '对局进度',
                                onPressed: () => showPlayerProgressDialog(context, _controller),
                              )
                            : _watch(
                                () => PlayersHud(
                                  key: const ValueKey('hud-progress'),
                                  controller: _controller,
                                  width: layout.progressWidth,
                                  showTitle: wide && !layout.dense,
                                ),
                              ),
                      ),
                    Positioned(
                      left: layout.dockLeft,
                      bottom: layout.bottom,
                      child: _watch(
                        () => ActionDock(
                          key: const ValueKey('hud-actions'),
                          controller: _controller,
                          onHint: _controller.requestHint,
                          onUndo: _controller.undo,
                          onRestart: _requestRestart,
                          showUndo: challenge == null,
                          compact: layout.compactDock,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
