import '../game/checkers_rules.dart';

String describeMove(CheckersMove move) {
  if (!move.jump) return '单步';
  if (move.landings.length == 1) return '单跳';
  return '连跳 ×${move.landings.length}';
}
