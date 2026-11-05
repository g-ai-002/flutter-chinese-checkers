import '../game/checkers_rules.dart';

/// 复盘中一手棋的简短描述。
String describeMove(CheckersMove move) {
  if (!move.jump) return '单步';
  if (move.landings.length == 1) return '单跳';
  return '连跳 ×${move.landings.length}';
}
