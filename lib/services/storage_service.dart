import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/challenge_result.dart';
import '../models/game_models.dart';
import '../models/match_record.dart';
import '../models/replay_archive.dart';
import '../utils/constants.dart';

/// 轻量偏好存储：写入失败时静默忽略，不影响对局主流程。
class StorageService {
  static StorageService? _instance;
  SharedPreferences? _prefs;
  List<MatchRecord>? _matches;
  _ReplayCache? _replays;
  Map<String, ChallengeResult>? _challenges;

  StorageService._();

  static Future<StorageService> get instance async {
    if (_instance != null) return _instance!;
    final service = StorageService._();
    service._prefs = await SharedPreferences.getInstance();
    _instance = service;
    return service;
  }

  /// 仅供测试：清空单例，配合 SharedPreferences 的 mock 数据使用。
  static void resetForTests() => _instance = null;

  SharedPreferences get _p {
    final prefs = _prefs;
    if (prefs == null) throw StateError('StorageService 尚未初始化');
    return prefs;
  }

  Future<void> _write(
    Future<bool> Function(SharedPreferences prefs) action,
  ) async {
    try {
      await action(_p);
    } catch (_) {}
  }

  bool get darkMode => _p.getBool(AppConstants.prefKeyDarkMode) ?? false;
  Future<void> setDarkMode(bool value) =>
      _write((p) => p.setBool(AppConstants.prefKeyDarkMode, value));

  bool get soundEnabled => _p.getBool(AppConstants.prefKeySound) ?? true;
  Future<void> setSoundEnabled(bool value) =>
      _write((p) => p.setBool(AppConstants.prefKeySound, value));

  bool get musicEnabled => _p.getBool(AppConstants.prefKeyMusic) ?? true;
  Future<void> setMusicEnabled(bool value) =>
      _write((p) => p.setBool(AppConstants.prefKeyMusic, value));

  bool get hapticsEnabled => _p.getBool(AppConstants.prefKeyHaptics) ?? true;
  Future<void> setHapticsEnabled(bool value) =>
      _write((p) => p.setBool(AppConstants.prefKeyHaptics, value));

  bool get showHints => _p.getBool(AppConstants.prefKeyShowHints) ?? true;
  Future<void> setShowHints(bool value) =>
      _write((p) => p.setBool(AppConstants.prefKeyShowHints, value));

  /// 棋盘主题 id，未知值由 `boardThemeOf` 回退到默认主题。
  String? get boardThemeId => _p.getString(AppConstants.prefKeyBoardTheme);
  Future<void> setBoardThemeId(String value) =>
      _write((p) => p.setString(AppConstants.prefKeyBoardTheme, value));

  PlayerCount get playerCount =>
      PlayerCount.byCount(_p.getInt(AppConstants.prefKeyPlayerCount));
  Future<void> setPlayerCount(PlayerCount value) =>
      _write((p) => p.setInt(AppConstants.prefKeyPlayerCount, value.count));

  Difficulty get difficulty =>
      Difficulty.byName(_p.getString(AppConstants.prefKeyDifficulty));
  Future<void> setDifficulty(Difficulty value) =>
      _write((p) => p.setString(AppConstants.prefKeyDifficulty, value.name));

  int humanSeatFor(int players) {
    final seat = _p.getInt(AppConstants.prefKeyHumanSeat) ?? 0;
    return seat >= 0 && seat < players ? seat : 0;
  }

  Future<void> setHumanSeat(int value) =>
      _write((p) => p.setInt(AppConstants.prefKeyHumanSeat, value));

  /// 已保存的对局摘要，按时间倒序；损坏的记录会被跳过。
  ///
  /// 解析结果会缓存到下一次写入，界面重建时不必反复解码 JSON。
  List<MatchRecord> get matches {
    final cached = _matches;
    if (cached != null) return cached;
    final lines =
        _p.getStringList(AppConstants.prefKeyMatches) ?? const <String>[];
    final records = <MatchRecord>[];
    for (final line in lines) {
      try {
        final record = MatchRecord.tryParse(jsonDecode(line));
        if (record != null) records.add(record);
      } catch (_) {}
    }
    return _matches = List.unmodifiable(records);
  }

  /// 追加一局摘要，只保留最近 [AppConstants.maxStoredMatches] 局。
  Future<void> addMatch(MatchRecord record) => _write((p) {
    final lines = p.getStringList(AppConstants.prefKeyMatches) ?? <String>[];
    // 先失效缓存再写入：写入失败时下次读取也能拿到存储里的真实内容。
    _matches = null;
    return p.setStringList(
      AppConstants.prefKeyMatches,
      _trimmed([
        jsonEncode(record.toJson()),
        ...lines,
      ], AppConstants.maxStoredMatches),
    );
  });

  Future<void> clearMatches() => _write((p) {
    _matches = null;
    return p.remove(AppConstants.prefKeyMatches);
  });

  /// 棋谱库，按保存时间倒序；损坏的棋谱会被跳过。
  ///
  /// 原始文本与解析结果一起缓存：界面重建、增删棋谱都不必重新解码整库，
  /// 未改动的棋谱也能保持写入时的原始文本。
  List<ReplayArchive> get replays => _replayCache.archives;

  _ReplayCache get _replayCache {
    final cached = _replays;
    if (cached != null) return cached;
    final stored = _p.getStringList(AppConstants.prefKeyReplays) ?? const [];
    final lines = <String>[];
    final archives = <ReplayArchive>[];
    for (final line in stored) {
      final archive = ReplayArchive.decode(line, verifyMoves: false);
      if (archive == null) continue;
      lines.add(line);
      archives.add(archive);
    }
    return _replays = _ReplayCache(lines: lines, archives: archives);
  }

  /// 追加一份棋谱，只保留最近 [AppConstants.maxStoredReplays] 局。
  Future<void> addReplay(ReplayArchive archive) => _write((p) {
    final cached = _replayCache;
    final lines = <String>[archive.encode()];
    for (var i = 0; i < cached.archives.length; i++) {
      if (cached.archives[i].id != archive.id) lines.add(cached.lines[i]);
    }
    return _commitReplays(p, lines);
  });

  Future<void> removeReplay(String id) => _write((p) {
    final cached = _replayCache;
    final lines = <String>[
      for (var i = 0; i < cached.archives.length; i++)
        if (cached.archives[i].id != id) cached.lines[i],
    ];
    return _commitReplays(p, lines);
  });

  Future<void> clearReplays() => _write((p) {
    _replays = null;
    return p.remove(AppConstants.prefKeyReplays);
  });

  /// 残局最佳成绩，按关卡 id 索引；损坏的记录会被跳过。
  Map<String, ChallengeResult> get challengeResults {
    final cached = _challenges;
    if (cached != null) return cached;
    final stored =
        _p.getStringList(AppConstants.prefKeyChallenges) ?? const <String>[];
    final results = <String, ChallengeResult>{};
    for (final line in stored) {
      try {
        final result = ChallengeResult.tryParse(jsonDecode(line));
        if (result != null) results[result.levelId] = result;
      } catch (_) {}
    }
    return _challenges = Map.unmodifiable(results);
  }

  /// 只有成绩更好时才覆盖：星级更高，或同星级步数更少。
  Future<void> saveChallengeResult(ChallengeResult result) => _write((p) {
    final merged = <String, ChallengeResult>{...challengeResults};
    final old = merged[result.levelId];
    if (old == null || result.beats(old)) merged[result.levelId] = result;
    _challenges = null;
    return p.setStringList(AppConstants.prefKeyChallenges, [
      for (final item in merged.values) jsonEncode(item.toJson()),
    ]);
  });

  Future<void> clearChallengeResults() => _write((p) {
    _challenges = null;
    return p.remove(AppConstants.prefKeyChallenges);
  });

  Future<bool> _commitReplays(SharedPreferences p, List<String> lines) {
    _replays = null;
    return p.setStringList(
      AppConstants.prefKeyReplays,
      _trimmed(lines, AppConstants.maxStoredReplays),
    );
  }

  /// 按上限截断，超出部分从尾部丢弃（列表头部是最新的记录）。
  static List<String> _trimmed(Iterable<String> lines, int limit) =>
      lines.take(limit).toList(growable: false);
}

/// 棋谱库的读取缓存：原始文本与解析结果一一对应，增删时按同一下标过滤。
class _ReplayCache {
  _ReplayCache({
    required List<String> lines,
    required List<ReplayArchive> archives,
  }) : lines = List.unmodifiable(lines),
       archives = List.unmodifiable(archives);

  final List<String> lines;
  final List<ReplayArchive> archives;
}
