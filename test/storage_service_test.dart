import 'dart:convert';

import 'package:chinese_checkers/models/game_models.dart';
import 'package:chinese_checkers/models/match_record.dart';
import 'package:chinese_checkers/providers/settings_provider.dart';
import 'package:chinese_checkers/services/storage_service.dart';
import 'package:chinese_checkers/theme/app_theme.dart';
import 'package:chinese_checkers/utils/constants.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    StorageService.resetForTests();
  });

  test('没有保存过偏好时使用默认值', () async {
    final storage = await StorageService.instance;
    expect(storage.darkMode, isFalse);
    expect(storage.soundEnabled, isTrue);
    expect(storage.musicEnabled, isTrue);
    expect(storage.hapticsEnabled, isTrue);
    expect(storage.showHints, isTrue);
    expect(storage.playerCount, PlayerCount.two);
    expect(storage.difficulty, Difficulty.normal);
    expect(storage.boardThemeId, isNull);
    expect(boardThemeOf(storage.boardThemeId).id, 'jade');
  });

  test('偏好写入后可重新读取', () async {
    final storage = await StorageService.instance;
    await storage.setDarkMode(true);
    await storage.setSoundEnabled(false);
    await storage.setMusicEnabled(false);
    await storage.setHapticsEnabled(false);
    await storage.setShowHints(false);
    await storage.setBoardThemeId('ink');
    await storage.setPlayerCount(PlayerCount.six);
    await storage.setDifficulty(Difficulty.hard);
    await storage.setHumanSeat(4);

    StorageService.resetForTests();
    final reopened = await StorageService.instance;
    expect(reopened.darkMode, isTrue);
    expect(reopened.soundEnabled, isFalse);
    expect(reopened.musicEnabled, isFalse);
    expect(reopened.hapticsEnabled, isFalse);
    expect(reopened.showHints, isFalse);
    expect(reopened.boardThemeId, 'ink');
    expect(reopened.playerCount, PlayerCount.six);
    expect(reopened.difficulty, Difficulty.hard);
    expect(reopened.humanSeatFor(6), 4);
    expect(reopened.humanSeatFor(2), 0);
  });

  test('未知或越界的保存值回退到安全默认值', () async {
    SharedPreferences.setMockInitialValues({
      'board_theme': 'unknown',
      'difficulty': 'impossible',
      'player_count': 5,
    });
    final storage = await StorageService.instance;
    expect(boardThemeOf(storage.boardThemeId).id, 'jade');
    expect(storage.difficulty, Difficulty.normal);
    expect(storage.playerCount, PlayerCount.two);
  });

  test('设置变更会通知界面并同步音效开关', () async {
    final storage = await StorageService.instance;
    final settings = SettingsProvider(storage);
    var notified = 0;
    settings.addListener(() => notified++);

    await settings.setSoundEnabled(false);
    await settings.setHapticsEnabled(false);
    await settings.setBoardTheme(kBoardThemes[1]);
    await settings.setPlayerCount(PlayerCount.four);

    expect(notified, 4);
    expect(settings.soundEnabled, isFalse);
    expect(settings.hapticsEnabled, isFalse);
    expect(settings.boardTheme.id, 'wood');
    expect(settings.playerCount, PlayerCount.four);
    expect(settings.humanSeat, 0);
  });

  test('每种人数都有互不重叠且方向相反的营地', () {
    for (final count in PlayerCount.values) {
      final setup = GameSetup(mode: PlayMode.vsAi, playerCount: count);
      final arms = setup.seatArms;
      expect(arms.toSet(), hasLength(count.count));
      final targets = <int>{};
      for (var seat = 0; seat < count.count; seat++) {
        final target = setup.targetArmOf(seat);
        expect(target, isNot(arms[seat]));
        expect(targets.add(target), isTrue);
        expect(setup.seatLabel(seat), isNotEmpty);
      }
    }
  });

  MatchRecord record(int winner, {int moves = 40}) => MatchRecord(
    playedAt: DateTime(2026, 11, 5, 10, winner),
    mode: PlayMode.vsAi,
    playerCount: PlayerCount.two,
    difficulty: Difficulty.normal,
    humanSeat: 0,
    winner: winner,
    moves: moves,
    duration: const Duration(minutes: 3),
    longestJump: 2,
    opening: '连跳 ×2',
    winnerMoves: 28,
  );

  test('对局摘要按时间倒序保存，并可清空', () async {
    final storage = await StorageService.instance;
    await storage.addMatch(record(0));
    await storage.addMatch(record(1, moves: 55));

    final matches = storage.matches;
    expect(matches, hasLength(2));
    expect(matches.first.winner, 1);
    expect(matches.last.winner, 0);
    expect(matches.first.opening, '连跳 ×2');

    StorageService.resetForTests();
    final reopened = await StorageService.instance;
    expect(reopened.matches, hasLength(2));

    await reopened.clearMatches();
    expect(reopened.matches, isEmpty);
  });

  test('对局摘要只保留最近的上限数量', () async {
    final storage = await StorageService.instance;
    for (var i = 0; i < AppConstants.maxStoredMatches + 4; i++) {
      await storage.addMatch(record(i.isEven ? 0 : 1, moves: 20 + i));
    }

    final matches = storage.matches;
    expect(matches, hasLength(AppConstants.maxStoredMatches));
    expect(matches.first.moves, 20 + AppConstants.maxStoredMatches + 3);
    expect(matches.last.moves, 24);
  });

  test('损坏的摘要行被跳过，不影响其余记录', () async {
    SharedPreferences.setMockInitialValues({
      AppConstants.prefKeyMatches: [
        'not-json',
        jsonEncode(record(0).toJson()),
        '[]',
      ],
    });
    final storage = await StorageService.instance;

    expect(storage.matches, hasLength(1));
    expect(storage.matches.single.winner, 0);
  });

  test('记录对局会通知界面并刷新统计', () async {
    final storage = await StorageService.instance;
    final settings = SettingsProvider(storage);
    var notified = 0;
    settings.addListener(() => notified++);

    await settings.recordMatch(record(0));
    await settings.recordMatch(record(1));

    expect(notified, 2);
    expect(settings.matches, hasLength(2));
    expect(settings.matchSummary.total, 2);
    expect(settings.matchSummary.wins, 1);
  });
}
