import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/game_models.dart';
import '../models/match_record.dart';
import '../models/match_summary.dart';
import '../models/replay_archive.dart';
import '../services/music_service.dart';
import '../services/sound_service.dart';
import '../services/storage_service.dart';
import '../theme/app_theme.dart';

/// 用户偏好：主题、棋盘配色、人数、难度、座位与音效。
class SettingsProvider extends ChangeNotifier {
  SettingsProvider(this._storage) {
    _syncFeedback();
  }

  final StorageService _storage;

  bool get darkMode => _storage.darkMode;
  Future<void> setDarkMode(bool value) =>
      _update(() => _storage.setDarkMode(value));

  bool get soundEnabled => _storage.soundEnabled;
  Future<void> setSoundEnabled(bool value) => _update(() async {
    await _storage.setSoundEnabled(value);
    _syncFeedback();
  });

  bool get musicEnabled => _storage.musicEnabled;
  Future<void> setMusicEnabled(bool value) => _update(() async {
    await _storage.setMusicEnabled(value);
    // 音频启停不阻塞开关反馈，加载失败时 MusicService 自行记录日志。
    unawaited(MusicService.setEnabled(value));
  });

  bool get hapticsEnabled => _storage.hapticsEnabled;
  Future<void> setHapticsEnabled(bool value) => _update(() async {
    await _storage.setHapticsEnabled(value);
    _syncFeedback();
  });

  bool get showHints => _storage.showHints;
  Future<void> setShowHints(bool value) =>
      _update(() => _storage.setShowHints(value));

  BoardTheme get boardTheme => boardThemeOf(_storage.boardThemeId);
  Future<void> setBoardTheme(BoardTheme value) =>
      _update(() => _storage.setBoardThemeId(value.id));

  PlayerCount get playerCount => _storage.playerCount;
  Future<void> setPlayerCount(PlayerCount value) =>
      _update(() => _storage.setPlayerCount(value));

  Difficulty get difficulty => _storage.difficulty;
  Future<void> setDifficulty(Difficulty value) =>
      _update(() => _storage.setDifficulty(value));

  int get humanSeat => _storage.humanSeatFor(playerCount.count);
  Future<void> setHumanSeat(int value) =>
      _update(() => _storage.setHumanSeat(value));

  List<MatchRecord> get matches => _storage.matches;

  MatchSummary? _summary;

  /// 生涯聚合只随对局记录变化，首页与统计页共用同一份结果。
  MatchSummary get matchSummary =>
      _summary ??= MatchSummary.fromRecords(matches);

  Future<void> recordMatch(MatchRecord record) async {
    await _storage.addMatch(record);
    _summary = null;
    notifyListeners();
  }

  Future<void> clearMatches() async {
    await _storage.clearMatches();
    _summary = null;
    notifyListeners();
  }

  List<ReplayArchive> get replays => _storage.replays;

  Future<void> saveReplay(ReplayArchive archive) async {
    await _storage.addReplay(archive);
    notifyListeners();
  }

  Future<void> removeReplay(String id) async {
    await _storage.removeReplay(id);
    notifyListeners();
  }

  Future<void> clearReplays() async {
    await _storage.clearReplays();
    notifyListeners();
  }

  void _syncFeedback() =>
      SoundService.configure(sound: soundEnabled, haptics: hapticsEnabled);

  /// 写入偏好后统一通知界面，避免每个 setter 重复一遍。
  Future<void> _update(Future<void> Function() write) async {
    await write();
    notifyListeners();
  }
}
