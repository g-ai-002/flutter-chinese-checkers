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

  /// 是否把新增着法排进动画队列；复盘直接切换局面，不需要补播。
  bool get supportsMoveAnimation;

  void tapHole(int hole);
}
