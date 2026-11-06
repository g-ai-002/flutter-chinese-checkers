import 'board_geometry.dart';
import 'checkers_board.dart';

/// 一次走子：起点加上依次落脚的孔位。
///
/// 单步只有一站；连跳会记录每一跳的落脚点，便于逐跳播放动画。
class CheckersMove {
  const CheckersMove({
    required this.from,
    required this.landings,
    required this.jump,
  });

  factory CheckersMove.step(int from, int to) =>
      CheckersMove(from: from, landings: [to], jump: false);

  factory CheckersMove.jump(int from, List<int> landings) => CheckersMove(
    from: from,
    landings: List.unmodifiable(landings),
    jump: true,
  );

  final int from;
  final List<int> landings;
  final bool jump;

  int get to => landings.last;

  /// 跳过的孔位数量，单步为 0。
  int get jumpCount => jump ? landings.length : 0;

  /// 完整路径（含起点），绘制与动画使用。
  List<int> get path => [from, ...landings];

  /// 每一段的中点即被跳过的棋子，用于跳跃弧线。
  bool get isLongJump => jump && landings.length > 1;
}

/// 中国跳棋规则：单步、连跳、进营判定。
class CheckersRules {
  CheckersRules(this.geometry);

  final BoardGeometry geometry;

  /// 当前行棋方的全部合法着法，按「落点去重」，同一落点保留跳数最少的一条。
  List<CheckersMove> legalMoves(CheckersBoard board, int seat) {
    final moves = <CheckersMove>[];
    for (final hole in board.holesOf(seat)) {
      moves.addAll(movesFrom(board, hole));
    }
    return moves;
  }

  /// 指定棋子的合法着法：先单步，再搜索所有连跳落脚点。
  List<CheckersMove> movesFrom(CheckersBoard board, int hole) {
    final moves = <CheckersMove>[];
    for (var dir = 0; dir < kAxialDirections.length; dir++) {
      final target = geometry.step(hole, dir);
      if (target != null && board.isEmpty(target)) {
        moves.add(CheckersMove.step(hole, target));
      }
    }
    moves.addAll(_jumpMoves(board, hole));
    return moves;
  }

  /// 广度优先搜索连跳：每跳都必须跨过一枚棋子并落在空孔，落脚点不可重复。
  List<CheckersMove> _jumpMoves(CheckersBoard board, int from) {
    final result = <CheckersMove>[];
    final visited = <int>{from};
    final queue = <_JumpNode>[_JumpNode(from, const [])];

    while (queue.isNotEmpty) {
      final node = queue.removeAt(0);
      for (var dir = 0; dir < kAxialDirections.length; dir++) {
        final middle = geometry.step(node.hole, dir);
        if (middle == null || board.isEmpty(middle)) continue;
        final landing = geometry.step(middle, dir);
        if (landing == null || !board.isEmpty(landing)) continue;
        if (!visited.add(landing)) continue;
        final landings = [...node.landings, landing];
        result.add(CheckersMove.jump(from, landings));
        queue.add(_JumpNode(landing, landings));
      }
    }
    return result;
  }

  /// 从 [from] 之后开始，找到下一个仍有合法着法的座位。
  ///
  /// 全部座位都无棋可走时返回 -1；包含 [from] 自己，方便跳过已无子可动的座位。
  int nextSeat(CheckersBoard board, int from, int players) {
    for (var step = 1; step <= players; step++) {
      final seat = (from + step) % players;
      if (legalMoves(board, seat).isNotEmpty) return seat;
    }
    return -1;
  }

  /// 全部棋子都进入对面营地即获胜。
  bool hasWon(CheckersBoard board, int seat, int targetArm) {
    for (final hole in geometry.armHoles[targetArm]) {
      if (board.at(hole) != seat) return false;
    }
    return true;
  }

  /// 目标营地已被本方占据的棋子数，用于进度展示。
  int progress(CheckersBoard board, int seat, int targetArm) =>
      board.countInArm(geometry, seat, targetArm);
}

class _JumpNode {
  const _JumpNode(this.hole, this.landings);

  final int hole;
  final List<int> landings;
}
