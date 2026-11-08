import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../flame/checkers_game.dart';
import '../game/replay_controller.dart';
import '../models/replay_archive.dart';
import '../providers/settings_provider.dart';
import '../services/log_service.dart';
import '../utils/constants.dart';
import 'widgets/board_stage.dart';
import 'widgets/replay_exchange.dart';
import 'widgets/replay_widgets.dart';

class ReplayPage extends StatefulWidget {
  const ReplayPage({super.key, required this.archive});

  final ReplayArchive archive;

  @override
  State<ReplayPage> createState() => _ReplayPageState();
}

class _ReplayPageState extends State<ReplayPage> {
  late final ReplayController _replay;
  late final CheckersGame _game;
  final ScrollController _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _replay = ReplayController(setup: widget.archive.setup, records: widget.archive.records);
    _game = CheckersGame(
      source: _replay,
      theme: context.read<SettingsProvider>().boardTheme,
      showHints: false,
      logicRate: context.read<SettingsProvider>().logicRate,
    );
    _replay.addListener(_syncScroll);
    LogService.info(
      '查看复盘: ${widget.archive.setup.playerCount.label}, '
      '${widget.archive.moves} 手',
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _game.theme = context.read<SettingsProvider>().boardTheme;
  }

  @override
  void dispose() {
    _replay.removeListener(_syncScroll);
    _replay.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _syncScroll() {
    if (!_scroll.hasClients) return;
    final target = (_replay.index * kReplayRowExtent).clamp(0.0, _scroll.position.maxScrollExtent);
    _scroll.animateTo(target, duration: const Duration(milliseconds: 180), curve: Curves.easeOut);
  }

  Widget _banner() {
    return ListenableBuilder(
      listenable: _replay,
      builder: (context, _) => ReplayBanner(controller: _replay),
    );
  }

  Widget _controls() {
    return ListenableBuilder(
      listenable: _replay,
      builder: (context, _) => ReplayControls(controller: _replay),
    );
  }

  void _openMoveSheet() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => SizedBox(
        height: MediaQuery.sizeOf(sheetContext).height * 0.62,
        child: ReplayMoveList(controller: _replay),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= kGameWideBreakpoint;
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: '返回',
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.arrow_back),
        ),
        title: const Text('对局复盘'),
        actions: [
          if (!wide)
            IconButton(
              tooltip: '棋谱',
              onPressed: _openMoveSheet,
              icon: const Icon(Icons.list_alt, size: 21),
            ),
          IconButton(
            tooltip: '导出棋谱',
            onPressed: () => showReplayExportDialog(context, widget.archive),
            icon: const Icon(Icons.ios_share, size: 20),
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: SafeArea(top: false, child: wide ? _buildWide() : _buildCompact()),
    );
  }

  Widget _buildWide() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: Column(
              children: [
                _banner(),
                const SizedBox(height: 10),
                Expanded(
                  child: BoardStage(game: _game, gameKey: const ValueKey('replay-board')),
                ),
                const SizedBox(height: 10),
                _controls(),
              ],
            ),
          ),
          const SizedBox(width: 20),
          SizedBox(
            width: 300,
            child: ReplayMoveList(controller: _replay, scrollController: _scroll),
          ),
        ],
      ),
    );
  }

  Widget _buildCompact() {
    // 矮窗口把高度让给棋盘：收起顶部进度条，进度仍可在棋谱浮层里查看。
    final short = MediaQuery.sizeOf(context).height < 560;
    return Column(
      children: [
        if (!short) ...[
          Padding(padding: const EdgeInsets.fromLTRB(12, 4, 12, 0), child: _banner()),
          const SizedBox(height: 8),
        ],
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: BoardStage(game: _game, gameKey: const ValueKey('replay-board')),
          ),
        ),
        Padding(padding: const EdgeInsets.fromLTRB(12, 4, 12, 10), child: _controls()),
      ],
    );
  }
}
