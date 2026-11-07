import '../models/game_models.dart';
import 'board_geometry.dart';
import 'checkers_board.dart';
import 'checkers_rules.dart';
import 'move_record.dart';

/// 棋盘渲染与点击所需的对局视图，实时对局与复盘共用。
abstract interface class BoardSource {
  BoardGeometry get geometry;

  GameSetup get setup;

  int get players;

  CheckersBoard get board;

  /// 已发生的着法；复盘时只包含当前进度之前的着法。
  List<MoveRecord> get history;

  int? get selectedHole;

  Map<int, CheckersMove> get targets;

  CheckersMove? get hintMove;

  /// 新增着法从 [history] 的哪个序号开始补播动画。
  ///
  /// 实时对局返回 0，新增着法依次播放；复盘逐手前进时只播放最后一手，
  /// 批量跳转与后退返回 [history] 的长度，棋盘直接切到目标局面。
  int get animationStartIndex;

  /// 走子动画开始前的预高亮时长。
  ///
  /// 实时对局为 0；复盘逐手播放时留出一小段时间高亮即将移动的棋子，
  /// 让目光先落到它身上，再启动走子动画。
  Duration get animationLeadIn;

  void tapHole(int hole);
}
