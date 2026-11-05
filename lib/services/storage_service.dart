import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/game_models.dart';
import '../models/match_record.dart';
import '../utils/constants.dart';

/// 轻量偏好存储：写入失败时静默忽略，不影响对局主流程。
class StorageService {
  static StorageService? _instance;
  SharedPreferences? _prefs;

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

  /// 人类座位（0 起），超出当前人数时回退到 0。
  int humanSeatFor(int players) {
    final seat = _p.getInt(AppConstants.prefKeyHumanSeat) ?? 0;
    return seat >= 0 && seat < players ? seat : 0;
  }

  Future<void> setHumanSeat(int value) =>
      _write((p) => p.setInt(AppConstants.prefKeyHumanSeat, value));

  /// 已保存的对局摘要，按时间倒序；损坏的记录会被跳过。
  List<MatchRecord> get matches {
    final lines =
        _p.getStringList(AppConstants.prefKeyMatches) ?? const <String>[];
    final records = <MatchRecord>[];
    for (final line in lines) {
      try {
        final record = MatchRecord.tryParse(jsonDecode(line));
        if (record != null) records.add(record);
      } catch (_) {}
    }
    return List.unmodifiable(records);
  }

  /// 追加一局摘要，只保留最近 [AppConstants.maxStoredMatches] 局。
  Future<void> addMatch(MatchRecord record) => _write((p) async {
    final lines = p.getStringList(AppConstants.prefKeyMatches) ?? <String>[];
    final next = <String>[jsonEncode(record.toJson()), ...lines];
    if (next.length > AppConstants.maxStoredMatches) {
      next.removeRange(AppConstants.maxStoredMatches, next.length);
    }
    return p.setStringList(AppConstants.prefKeyMatches, next);
  });

  Future<void> clearMatches() =>
      _write((p) => p.remove(AppConstants.prefKeyMatches));
}
