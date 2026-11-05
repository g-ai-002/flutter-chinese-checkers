import 'dart:convert';

import 'package:chinese_checkers/game/checkers_rules.dart';
import 'package:chinese_checkers/game/move_record.dart';
import 'package:chinese_checkers/models/game_models.dart';
import 'package:chinese_checkers/models/match_record.dart';
import 'package:chinese_checkers/models/match_summary.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const aiSetup = GameSetup(
    mode: PlayMode.vsAi,
    playerCount: PlayerCount.two,
    difficulty: Difficulty.hard,
  );

  MatchRecord buildRecord({
    PlayMode mode = PlayMode.vsAi,
    PlayerCount count = PlayerCount.two,
    Difficulty difficulty = Difficulty.normal,
    int humanSeat = 0,
    int? winner = 0,
    int moves = 40,
    Duration duration = const Duration(minutes: 3),
    int longestJump = 0,
    String opening = '单步',
    int winnerMoves = 30,
    DateTime? playedAt,
  }) {
    return MatchRecord(
      playedAt: playedAt ?? DateTime(2026, 11, 5, 10, 30),
      mode: mode,
      playerCount: count,
      difficulty: difficulty,
      humanSeat: humanSeat,
      winner: winner,
      moves: moves,
      duration: duration,
      longestJump: longestJump,
      opening: opening,
      winnerMoves: winnerMoves,
    );
  }

  test('从对局记录计算最长连跳、获胜方步数与开局', () {
    final records = [
      MoveRecord(seat: 0, move: CheckersMove.step(0, 1)),
      MoveRecord(seat: 1, move: CheckersMove.jump(2, const [4, 6, 8])),
      MoveRecord(seat: 0, move: CheckersMove.step(1, 2)),
      MoveRecord(seat: 1, move: CheckersMove.jump(9, const [11])),
    ];

    final record = MatchRecord.fromGame(
      setup: aiSetup,
      records: records,
      winner: 1,
      duration: const Duration(minutes: 2, seconds: 5),
      playedAt: DateTime(2026, 11, 5, 9),
    );

    expect(record.moves, 4);
    expect(record.longestJump, 3);
    expect(record.winnerMoves, 2);
    expect(record.opening, '单步');
    expect(record.winner, 1);
    expect(record.duration, const Duration(minutes: 2, seconds: 5));
    expect(record.playedAt, DateTime(2026, 11, 5, 9));
    expect(record.entryEfficiency, 0.2);
    expect(record.outcomeLabel, '负');
  });

  test('JSON 往返保留统计字段', () {
    final record = buildRecord(
      count: PlayerCount.four,
      winner: 2,
      humanSeat: 2,
      longestJump: 4,
      opening: '连跳 ×4',
      winnerMoves: 33,
    );
    final restored = MatchRecord.tryParse(
      jsonDecode(jsonEncode(record.toJson())),
    )!;

    expect(restored.playedAt, record.playedAt);
    expect(restored.mode, record.mode);
    expect(restored.playerCount, record.playerCount);
    expect(restored.difficulty, record.difficulty);
    expect(restored.humanSeat, 2);
    expect(restored.winner, 2);
    expect(restored.moves, record.moves);
    expect(restored.duration, record.duration);
    expect(restored.longestJump, 4);
    expect(restored.opening, '连跳 ×4');
    expect(restored.winnerMoves, 33);
    expect(restored.entryEfficiency, 3.3);
  });

  test('损坏或越界的记录回退到安全值', () {
    expect(MatchRecord.tryParse(null), isNull);
    expect(MatchRecord.tryParse('broken'), isNull);

    final restored = MatchRecord.tryParse({
      'mode': 'unknown',
      'playerCount': 5,
      'difficulty': 'impossible',
      'winner': 9,
      'humanSeat': 7,
      'moves': -3,
      'durationMs': -100,
      'longestJump': -1,
    })!;

    expect(restored.mode, PlayMode.local);
    expect(restored.playerCount, PlayerCount.two);
    expect(restored.difficulty, Difficulty.normal);
    expect(restored.winner, isNull);
    expect(restored.humanSeat, 0);
    expect(restored.moves, 0);
    expect(restored.duration, Duration.zero);
    expect(restored.longestJump, 0);
    expect(restored.opening, '');
    expect(restored.entryEfficiency, isNull);
    expect(restored.outcomeLabel, '平局');
  });

  test('人机与同屏的结果标签符合各自视角', () {
    expect(buildRecord().outcomeLabel, '胜');
    expect(buildRecord(winner: 1).outcomeLabel, '负');
    expect(buildRecord(winner: null).outcomeLabel, '平局');
    expect(buildRecord(mode: PlayMode.local, winner: 1).outcomeLabel, '玩家 2胜');
  });

  test('空记录聚合为全零统计', () {
    final summary = MatchSummary.fromRecords(const []);

    expect(summary.isEmpty, isTrue);
    expect(summary.total, 0);
    expect(summary.winRate, 0);
    expect(summary.winPercent, 0);
    expect(summary.averageMoves, 0);
    expect(summary.averageDuration, Duration.zero);
    expect(summary.fastestWinMoves, isNull);
    expect(summary.longestJump, 0);
    expect(summary.favoriteOpening, isNull);
    expect(summary.entryEfficiency, isNull);
  });

  test('聚合人机胜负、平均步数用时与最快获胜', () {
    final summary = MatchSummary.fromRecords([
      buildRecord(
        winner: 1,
        moves: 60,
        duration: const Duration(minutes: 4),
        winnerMoves: 35,
      ),
      buildRecord(
        winner: null,
        moves: 120,
        duration: const Duration(minutes: 5),
        winnerMoves: 0,
      ),
      buildRecord(moves: 50, longestJump: 3, opening: '连跳 ×3'),
    ]);

    expect(summary.total, 3);
    expect(summary.aiGames, 3);
    expect(summary.localGames, 0);
    expect(summary.wins, 1);
    expect(summary.draws, 1);
    expect(summary.losses, 1);
    expect(summary.winPercent, 33);
    expect(summary.averageMoves, 77);
    expect(summary.averageDuration, const Duration(minutes: 4));
    expect(summary.fastestWinMoves, 50);
    expect(summary.longestJump, 3);
    expect(summary.favoriteOpening, '单步');
    expect(summary.favoriteOpeningCount, 2);
    expect(summary.entryEfficiency, closeTo(3.25, 0.001));
  });

  test('同屏对局计入总局数但不影响人机胜率', () {
    final summary = MatchSummary.fromRecords([
      buildRecord(mode: PlayMode.local, winner: 1),
      buildRecord(mode: PlayMode.local, winner: null, winnerMoves: 0),
      buildRecord(moves: 44, winnerMoves: 32),
    ]);

    expect(summary.total, 3);
    expect(summary.aiGames, 1);
    expect(summary.localGames, 2);
    expect(summary.wins, 1);
    expect(summary.winPercent, 100);
  });
}
