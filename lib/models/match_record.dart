import 'dart:math' as math;

import '../game/move_record.dart';
import '../utils/move_notation.dart';
import 'game_models.dart';

/// 一局结束后的可持久化摘要，用于对局统计与生涯回顾。
///
/// 只保留统计需要的字段，不存储完整棋谱，避免偏好存储随对局数量膨胀。
class MatchRecord {
  const MatchRecord({
    required this.playedAt,
    required this.mode,
    required this.playerCount,
    required this.difficulty,
    required this.humanSeat,
    required this.winner,
    required this.moves,
    required this.duration,
    required this.longestJump,
    required this.opening,
    required this.winnerMoves,
  });

  factory MatchRecord.fromGame({
    required GameSetup setup,
    required List<MoveRecord> records,
    required int? winner,
    required Duration duration,
    DateTime? playedAt,
  }) {
    var longestJump = 0;
    var winnerMoves = 0;
    for (final record in records) {
      longestJump = math.max(longestJump, record.move.jumpCount);
      if (winner != null && record.seat == winner) winnerMoves++;
    }
    return MatchRecord(
      playedAt: playedAt ?? DateTime.now(),
      mode: setup.mode,
      playerCount: setup.playerCount,
      difficulty: setup.difficulty,
      humanSeat: setup.humanSeat,
      winner: winner,
      moves: records.length,
      duration: duration,
      longestJump: longestJump,
      opening: records.isEmpty ? '' : describeMove(records.first.move),
      winnerMoves: winnerMoves,
    );
  }

  /// 从偏好存储的 JSON 恢复；字段缺失或越界时回退到安全值。
  factory MatchRecord.fromJson(Map<String, dynamic> json) {
    final playerCount = PlayerCount.byCount(
      (json['playerCount'] as num?)?.toInt(),
    );
    final rawWinner = (json['winner'] as num?)?.toInt();
    final winner =
        rawWinner != null && rawWinner >= 0 && rawWinner < playerCount.count
        ? rawWinner
        : null;
    final humanSeat = (json['humanSeat'] as num?)?.toInt() ?? 0;
    return MatchRecord(
      playedAt:
          DateTime.tryParse(json['playedAt'] as String? ?? '') ??
          DateTime.now(),
      mode: PlayMode.values.firstWhere(
        (value) => value.name == json['mode'],
        orElse: () => PlayMode.local,
      ),
      playerCount: playerCount,
      difficulty: Difficulty.byName(json['difficulty'] as String?),
      humanSeat: humanSeat >= 0 && humanSeat < playerCount.count
          ? humanSeat
          : 0,
      winner: winner,
      moves: math.max((json['moves'] as num?)?.toInt() ?? 0, 0),
      duration: Duration(
        milliseconds: math.max((json['durationMs'] as num?)?.toInt() ?? 0, 0),
      ),
      longestJump: math.max((json['longestJump'] as num?)?.toInt() ?? 0, 0),
      opening: json['opening'] as String? ?? '',
      winnerMoves: math.max((json['winnerMoves'] as num?)?.toInt() ?? 0, 0),
    );
  }

  /// 容错解析单条记录，损坏的数据直接丢弃，不影响其余记录。
  static MatchRecord? tryParse(Object? value) {
    if (value is! Map) return null;
    try {
      return MatchRecord.fromJson(Map<String, dynamic>.from(value));
    } catch (_) {
      return null;
    }
  }

  final DateTime playedAt;
  final PlayMode mode;
  final PlayerCount playerCount;
  final Difficulty difficulty;
  final int humanSeat;
  final int? winner;
  final int moves;
  final Duration duration;

  /// 本局最长连跳的跳数，单步为 0。
  final int longestJump;

  /// 首手类型，例如「连跳 ×2」，用于统计常用开局。
  final String opening;

  /// 获胜方走子的手数，配合 10 枚棋子计算入营效率。
  final int winnerMoves;

  GameSetup get setup => GameSetup(
    mode: mode,
    playerCount: playerCount,
    difficulty: difficulty,
    humanSeat: humanSeat,
  );

  bool get isDraw => winner == null;

  bool get isAiGame => mode == PlayMode.vsAi;

  bool get humanWon => isAiGame && winner == humanSeat;

  bool get humanLost => isAiGame && !isDraw && winner != humanSeat;

  /// 获胜方平均每枚棋子用了多少步，越小说明推进越干脆。
  double? get entryEfficiency => winnerMoves <= 0 ? null : winnerMoves / 10;

  /// 结果短标签：人机局为「胜 / 负 / 平局」，同屏局带上获胜玩家。
  String get outcomeLabel {
    final winner = this.winner;
    if (winner == null) return '平局';
    if (isAiGame) return winner == humanSeat ? '胜' : '负';
    return '${setup.seatLabel(winner)}胜';
  }

  Map<String, dynamic> toJson() => {
    'playedAt': playedAt.toIso8601String(),
    'mode': mode.name,
    'playerCount': playerCount.count,
    'difficulty': difficulty.name,
    'humanSeat': humanSeat,
    'winner': winner,
    'moves': moves,
    'durationMs': duration.inMilliseconds,
    'longestJump': longestJump,
    'opening': opening,
    'winnerMoves': winnerMoves,
  };
}
