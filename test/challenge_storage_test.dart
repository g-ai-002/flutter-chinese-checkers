import 'package:chinese_checkers/game/challenge_levels.dart';
import 'package:chinese_checkers/models/challenge_result.dart';
import 'package:chinese_checkers/providers/settings_provider.dart';
import 'package:chinese_checkers/services/storage_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    StorageService.resetForTests();
  });

  test('残局成绩写入后可重新读取', () async {
    final storage = await StorageService.instance;
    await storage.saveChallengeResult(
      const ChallengeResult(levelId: 'starter-1', stars: 2, moves: 6),
    );

    StorageService.resetForTests();
    final reopened = await StorageService.instance;
    final result = reopened.challengeResults['starter-1']!;
    expect(result.stars, 2);
    expect(result.moves, 6);
  });

  test('只有星级更高或同星级步数更少才覆盖旧成绩', () async {
    final storage = await StorageService.instance;
    await storage.saveChallengeResult(
      const ChallengeResult(levelId: 'starter-1', stars: 2, moves: 6),
    );
    await storage.saveChallengeResult(
      const ChallengeResult(levelId: 'starter-1', stars: 1, moves: 4),
    );
    expect(storage.challengeResults['starter-1']!.stars, 2);

    await storage.saveChallengeResult(
      const ChallengeResult(levelId: 'starter-1', stars: 2, moves: 5),
    );
    expect(storage.challengeResults['starter-1']!.moves, 5);

    await storage.saveChallengeResult(
      const ChallengeResult(levelId: 'starter-1', stars: 3, moves: 9),
    );
    expect(storage.challengeResults['starter-1']!.stars, 3);
  });

  test('损坏的成绩记录被跳过，重置后清空', () async {
    SharedPreferences.setMockInitialValues({
      'challenge_progress': [
        'not json',
        '{"id":"starter-1","stars":4,"moves":3}',
        '{"id":"starter-2","stars":3,"moves":6}',
      ],
    });
    final storage = await StorageService.instance;
    expect(storage.challengeResults.keys, ['starter-2']);

    await storage.clearChallengeResults();
    expect(storage.challengeResults, isEmpty);
  });

  test('偏好层汇总通关数与总星数', () async {
    final storage = await StorageService.instance;
    final settings = SettingsProvider(storage);
    expect(settings.challengeCompleted, 0);
    expect(settings.challengeStars, 0);
    expect(settings.maxChallengeStars, kChallengeLevels.length * 3);

    await settings.saveChallengeResult(
      const ChallengeResult(levelId: 'starter-1', stars: 3, moves: 4),
    );
    await settings.saveChallengeResult(
      const ChallengeResult(levelId: 'starter-2', stars: 2, moves: 6),
    );
    expect(settings.challengeCompleted, 2);
    expect(settings.challengeStars, 5);
    expect(
      settings.challengeResultOf(kChallengeLevels.first)!.stars,
      3,
    );
  });
}
