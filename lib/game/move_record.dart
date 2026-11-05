import 'checkers_rules.dart';

/// 一条已完成的着法记录。
class MoveRecord {
  const MoveRecord({required this.seat, required this.move});

  final int seat;
  final CheckersMove move;
}
