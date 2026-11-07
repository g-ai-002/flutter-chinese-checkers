import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import '../game/board_geometry.dart';
import '../game/checkers_board.dart';
import '../game/checkers_rules.dart';
import '../game/move_record.dart';
import 'game_models.dart';

/// 一局完整棋谱：对局设置、逐手记录与结果，可长期存档、导出与导入。
///
/// 分享码为 `TIAOQI1:<JSON>`，导入时会校验人数、座位与每一步的合法性，
/// 损坏或篡改的数据一律拒绝，避免坏棋谱进入棋谱库。
class ReplayArchive {
  ReplayArchive({
    required this.id,
    required this.savedAt,
    required this.setup,
    required this.winner,
    required this.duration,
    required List<MoveRecord> records,
  }) : records = List<MoveRecord>.unmodifiable(records);

  factory ReplayArchive.fromGame({
    required GameSetup setup,
    required List<MoveRecord> records,
    required int? winner,
    required Duration duration,
    DateTime? savedAt,
  }) {
    final stamp = savedAt ?? DateTime.now();
    return ReplayArchive(
      id: '${stamp.microsecondsSinceEpoch}',
      savedAt: stamp,
      setup: setup,
      winner: winner,
      duration: duration,
      records: records,
    );
  }

  static const String formatTag = 'TIAOQI-REPLAY';
  static const int formatVersion = 1;
  static const String codePrefix = 'TIAOQI1:';

  final String id;
  final DateTime savedAt;
  final GameSetup setup;
  final int? winner;
  final Duration duration;
  final List<MoveRecord> records;

  int get moves => records.length;

  bool get isDraw => winner == null;

  String get outcomeLabel => setup.outcomeLabelFor(winner);

  int get longestJump =>
      records.fold(0, (best, record) => math.max(best, record.move.jumpCount));

  /// 列表与导出用的标题，例如「2 人 · 人机对战」。
  String get title => '${setup.playerCount.label} · ${setup.mode.label}';

  Map<String, dynamic> toJson() => {
    'kind': formatTag,
    'version': formatVersion,
    'id': id,
    'savedAt': savedAt.toIso8601String(),
    'mode': setup.mode.name,
    'playerCount': setup.playerCount.count,
    'difficulty': setup.difficulty.name,
    'humanSeat': setup.humanSeat,
    'winner': winner,
    'durationMs': duration.inMilliseconds,
    'moves': [
      for (final record in records)
        [record.seat, record.move.from, record.move.landings, record.move.jump],
    ],
  };

  String encode() => '$codePrefix${jsonEncode(toJson())}';

  /// 解析分享码或等价的 JSON 文本，无法识别时返回 null。
  ///
  /// [verifyMoves] 为 false 时跳过合法性重放，仅用于读取本机已校验的存档。
  static ReplayArchive? decode(String text, {bool verifyMoves = true}) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return null;
    final payload = trimmed.startsWith(codePrefix)
        ? trimmed.substring(codePrefix.length).trim()
        : trimmed;
    try {
      final raw = jsonDecode(payload);
      if (raw is! Map) return null;
      return _fromJson(
        Map<String, dynamic>.from(raw),
        verifyMoves: verifyMoves,
      );
    } catch (_) {
      return null;
    }
  }

  static ReplayArchive? _fromJson(
    Map<String, dynamic> json, {
    required bool verifyMoves,
  }) {
    if (json['kind'] != formatTag) return null;
    final version = (json['version'] as num?)?.toInt();
    if (version == null || version < 1 || version > formatVersion) return null;

    final setup = _setupOf(json);
    if (setup == null) return null;

    final durationMs = (json['durationMs'] as num?)?.toInt();
    if (durationMs == null || durationMs < 0) return null;

    final records = _recordsOf(json['moves'], setup.players);
    if (records == null) return null;

    final winner = _winnerOf(json['winner'], setup.playerCount);
    // null 既可能是平局，也可能是越界座位，用原始字段区分两种情况。
    if (json['winner'] != null && winner == null) return null;

    if (verifyMoves && !_isLegalSequence(setup, records, winner)) return null;

    final savedAt =
        DateTime.tryParse(json['savedAt'] as String? ?? '') ?? DateTime.now();
    final id = json['id'];
    return ReplayArchive(
      id: id is String && id.isNotEmpty
          ? id
          : '${savedAt.microsecondsSinceEpoch}',
      savedAt: savedAt,
      setup: setup,
      winner: winner,
      duration: Duration(milliseconds: durationMs),
      records: records,
    );
  }

  /// 对局设置：人数、模式、难度与人类座位都必须落在合法范围内。
  static GameSetup? _setupOf(Map<String, dynamic> json) {
    final playerCount = PlayerCount.tryByCount(
      (json['playerCount'] as num?)?.toInt(),
    );
    final mode = PlayMode.tryByName(json['mode']);
    if (playerCount == null || mode == null) return null;
    final humanSeat = (json['humanSeat'] as num?)?.toInt() ?? 0;
    if (humanSeat < 0 || humanSeat >= playerCount.count) return null;
    return GameSetup(
      mode: mode,
      playerCount: playerCount,
      difficulty: Difficulty.byName(json['difficulty'] as String?),
      humanSeat: humanSeat,
    );
  }

  /// 胜者座位，越界或非整数返回 null；`winner` 为 null 表示平局。
  static int? _winnerOf(Object? raw, PlayerCount playerCount) {
    if (raw is! num) return null;
    final seat = raw.toInt();
    if (seat < 0 || seat >= playerCount.count) return null;
    return seat;
  }

  /// 逐手记录：孔位越界、路径重复或非跳子多步一律拒绝。
  static List<MoveRecord>? _recordsOf(Object? rawMoves, int players) {
    if (rawMoves is! List || rawMoves.isEmpty) return null;
    final holes = BoardGeometry.star().length;
    final records = <MoveRecord>[];
    for (final item in rawMoves) {
      final record = _moveOf(item, holes);
      if (record == null || record.seat >= players) return null;
      records.add(record);
    }
    return records;
  }

  static MoveRecord? _moveOf(Object? item, int holes) {
    if (item is! List || item.length != 4) return null;
    final seat = (item[0] as num?)?.toInt();
    final from = (item[1] as num?)?.toInt();
    final landings = item[2];
    final jump = item[3];
    if (seat == null || seat < 0 || from == null || from < 0 || from >= holes) {
      return null;
    }
    if (landings is! List || landings.isEmpty || jump is! bool) return null;
    final path = <int>[];
    for (final hole in landings) {
      final value = (hole as num?)?.toInt();
      if (value == null || value < 0 || value >= holes) return null;
      path.add(value);
    }
    if (path.contains(from) || path.toSet().length != path.length) return null;
    if (!jump && path.length != 1) return null;
    return MoveRecord(
      seat: seat,
      move: jump
          ? CheckersMove.jump(from, path)
          : CheckersMove.step(from, path.first),
    );
  }

  /// 从头重放一遍，确认每一手都由该座位合法走出，胜者也确实进营。
  static bool _isLegalSequence(
    GameSetup setup,
    List<MoveRecord> records,
    int? winner,
  ) {
    final geometry = BoardGeometry.star();
    final rules = CheckersRules(geometry);
    final board = CheckersBoard.initial(geometry, setup.seatArms);
    for (final record in records) {
      if (board.at(record.move.from) != record.seat) return false;
      final legal = rules
          .movesFrom(board, record.move.from)
          .any(
            (candidate) =>
                candidate.jump == record.move.jump &&
                listEquals(candidate.landings, record.move.landings),
          );
      if (!legal) return false;
      board.move(record.move.from, record.move.to);
    }
    if (winner != null &&
        !rules.hasWon(board, winner, setup.targetArmOf(winner))) {
      return false;
    }
    return true;
  }
}
