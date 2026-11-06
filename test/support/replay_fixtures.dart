import 'package:chinese_checkers/game/board_geometry.dart';
import 'package:chinese_checkers/game/checkers_board.dart';
import 'package:chinese_checkers/game/checkers_rules.dart';
import 'package:chinese_checkers/game/move_record.dart';
import 'package:chinese_checkers/models/game_models.dart';
import 'package:chinese_checkers/models/replay_archive.dart';

const GameSetup localTwo = GameSetup(
  mode: PlayMode.local,
  playerCount: PlayerCount.two,
);

/// 依次给各座位挑第一步合法着法，生成一段真实可重放的棋谱。
List<MoveRecord> sampleRecords(GameSetup setup, {int count = 6}) {
  final geometry = BoardGeometry.star();
  final board = CheckersBoard.initial(geometry, setup.seatArms);
  final rules = CheckersRules(geometry);
  final records = <MoveRecord>[];
  var seat = 0;
  for (var i = 0; i < count; i++) {
    final move = rules.legalMoves(board, seat).first;
    board.move(move.from, move.to);
    records.add(MoveRecord(seat: seat, move: move));
    seat = (seat + 1) % setup.players;
  }
  return records;
}

/// 一份结构完整的棋谱，时间与 id 固定，便于断言。
ReplayArchive sampleArchive({
  GameSetup setup = localTwo,
  int count = 6,
  int? winner,
  Duration duration = const Duration(minutes: 3, seconds: 20),
  DateTime? savedAt,
}) {
  final stamp = savedAt ?? DateTime(2026, 11, 7, 1, 2, 3);
  return ReplayArchive.fromGame(
    setup: setup,
    records: sampleRecords(setup, count: count),
    winner: winner,
    duration: duration,
    savedAt: stamp,
  );
}
