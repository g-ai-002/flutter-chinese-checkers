import 'dart:math' as math;

import 'match_record.dart';

/// 生涯统计：由最近的对局记录聚合而来，本身不持久化。
class MatchSummary {
  const MatchSummary({
    required this.total,
    required this.aiGames,
    required this.localGames,
    required this.wins,
    required this.losses,
    required this.draws,
    required this.averageMoves,
    required this.averageDuration,
    required this.fastestWinMoves,
    required this.longestJump,
    required this.favoriteOpening,
    required this.favoriteOpeningCount,
    required this.entryEfficiency,
  });

  factory MatchSummary.fromRecords(List<MatchRecord> records) {
    if (records.isEmpty) {
      return const MatchSummary(
        total: 0,
        aiGames: 0,
        localGames: 0,
        wins: 0,
        losses: 0,
        draws: 0,
        averageMoves: 0,
        averageDuration: Duration.zero,
        fastestWinMoves: null,
        longestJump: 0,
        favoriteOpening: null,
        favoriteOpeningCount: 0,
        entryEfficiency: null,
      );
    }

    var aiGames = 0;
    var localGames = 0;
    var wins = 0;
    var losses = 0;
    var draws = 0;
    var totalMoves = 0;
    var totalMicros = 0;
    var longestJump = 0;
    int? fastestWinMoves;
    var efficiencySum = 0.0;
    var efficiencyCount = 0;
    final openings = <String, int>{};

    for (final record in records) {
      totalMoves += record.moves;
      totalMicros += record.duration.inMicroseconds;
      longestJump = math.max(longestJump, record.longestJump);

      if (record.isAiGame) {
        aiGames++;
        if (record.isDraw) {
          draws++;
        } else if (record.humanWon) {
          wins++;
          final fastest = fastestWinMoves;
          fastestWinMoves = fastest == null
              ? record.moves
              : math.min(fastest, record.moves);
        } else {
          losses++;
        }
      } else {
        localGames++;
      }

      if (record.opening.isNotEmpty) {
        openings[record.opening] = (openings[record.opening] ?? 0) + 1;
      }
      final efficiency = record.entryEfficiency;
      if (efficiency != null) {
        efficiencySum += efficiency;
        efficiencyCount++;
      }
    }

    // 记录按时间倒序保存，同频开局保留最近一次遇到的那个。
    String? favoriteOpening;
    var favoriteOpeningCount = 0;
    for (final record in records) {
      final count = openings[record.opening] ?? 0;
      if (record.opening.isNotEmpty && count > favoriteOpeningCount) {
        favoriteOpening = record.opening;
        favoriteOpeningCount = count;
      }
    }

    return MatchSummary(
      total: records.length,
      aiGames: aiGames,
      localGames: localGames,
      wins: wins,
      losses: losses,
      draws: draws,
      averageMoves: (totalMoves / records.length).round(),
      averageDuration: Duration(microseconds: totalMicros ~/ records.length),
      fastestWinMoves: fastestWinMoves,
      longestJump: longestJump,
      favoriteOpening: favoriteOpening,
      favoriteOpeningCount: favoriteOpeningCount,
      entryEfficiency: efficiencyCount == 0
          ? null
          : efficiencySum / efficiencyCount,
    );
  }

  final int total;
  final int aiGames;
  final int localGames;
  final int wins;
  final int losses;
  final int draws;
  final int averageMoves;
  final Duration averageDuration;

  /// 人机局中最少步数的一场胜利，没有获胜过时为 null。
  final int? fastestWinMoves;
  final int longestJump;
  final String? favoriteOpening;
  final int favoriteOpeningCount;

  /// 获胜方平均每枚棋子消耗的步数。
  final double? entryEfficiency;

  bool get isEmpty => total == 0;

  /// 人机胜率，平局计入总场次。
  double get winRate => aiGames == 0 ? 0 : wins / aiGames;

  int get winPercent => (winRate * 100).round();
}
