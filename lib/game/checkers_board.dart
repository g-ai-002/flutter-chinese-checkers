import 'board_geometry.dart';

/// 棋盘局面：每个孔位记录占据者座位号，-1 表示空位。
class CheckersBoard {
  CheckersBoard(List<int> cells) : cells = List<int>.of(cells);

  /// 开局：每位玩家的棋子填满自己的营地。
  factory CheckersBoard.initial(BoardGeometry geometry, List<int> seatArms) {
    final cells = List<int>.filled(geometry.length, -1);
    for (var seat = 0; seat < seatArms.length; seat++) {
      for (final hole in geometry.armHoles[seatArms[seat]]) {
        cells[hole] = seat;
      }
    }
    return CheckersBoard(cells);
  }

  /// 仅供测试与存档：从「孔位 -> 座位」列表恢复。
  factory CheckersBoard.fromPieces(
    BoardGeometry geometry,
    Map<int, int> pieces,
  ) {
    final cells = List<int>.filled(geometry.length, -1);
    pieces.forEach((hole, seat) => cells[hole] = seat);
    return CheckersBoard(cells);
  }

  final List<int> cells;

  int get length => cells.length;

  int at(int hole) => cells[hole];

  bool isEmpty(int hole) => cells[hole] < 0;

  bool isOccupied(int hole) => cells[hole] >= 0;

  void move(int from, int to) {
    cells[to] = cells[from];
    cells[from] = -1;
  }

  CheckersBoard copy() => CheckersBoard(cells);

  /// 某位玩家在指定营地的棋子数量。
  int countInArm(BoardGeometry geometry, int seat, int arm) {
    var count = 0;
    for (final hole in geometry.armHoles[arm]) {
      if (cells[hole] == seat) count++;
    }
    return count;
  }

  List<int> holesOf(int seat) {
    final result = <int>[];
    for (var hole = 0; hole < cells.length; hole++) {
      if (cells[hole] == seat) result.add(hole);
    }
    return result;
  }
}
