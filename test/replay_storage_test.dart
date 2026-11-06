import 'package:chinese_checkers/models/replay_archive.dart';
import 'package:chinese_checkers/providers/settings_provider.dart';
import 'package:chinese_checkers/services/storage_service.dart';
import 'package:chinese_checkers/utils/constants.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/replay_fixtures.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    StorageService.resetForTests();
  });

  test('保存的棋谱按时间倒序读取，解析结果会被缓存', () async {
    final storage = await StorageService.instance;
    final older = sampleArchive(savedAt: DateTime(2026, 11, 1, 9));
    final newer = sampleArchive(savedAt: DateTime(2026, 11, 2, 9));

    await storage.addReplay(older);
    await storage.addReplay(newer);

    expect(storage.replays.map((e) => e.id), [newer.id, older.id]);
    expect(identical(storage.replays, storage.replays), isTrue);
    expect(storage.replays.first.setup.playerCount.count, 2);
    expect(storage.replays.first.moves, 6);
  });

  test('棋谱库只保留最近 20 局，最旧的被丢弃', () async {
    final storage = await StorageService.instance;
    final archives = [
      for (var i = 0; i < 22; i++)
        sampleArchive(savedAt: DateTime(2026).add(Duration(minutes: i))),
    ];

    for (final archive in archives) {
      await storage.addReplay(archive);
    }

    final saved = storage.replays;
    expect(saved, hasLength(AppConstants.maxStoredReplays));
    expect(saved.first.id, archives.last.id);
    expect(saved.last.id, archives[2].id);
  });

  test('删除单局与清空棋谱库', () async {
    final storage = await StorageService.instance;
    final first = sampleArchive(savedAt: DateTime(2026, 1, 1, 9));
    final second = sampleArchive(savedAt: DateTime(2026, 1, 2, 9));
    await storage.addReplay(first);
    await storage.addReplay(second);

    await storage.removeReplay(second.id);
    expect(storage.replays.map((e) => e.id), [first.id]);

    await storage.clearReplays();
    expect(storage.replays, isEmpty);
  });

  test('损坏的棋谱行会被跳过，不影响其余存档', () async {
    final valid = sampleArchive();
    SharedPreferences.setMockInitialValues({
      AppConstants.prefKeyReplays: [
        'not a replay',
        '{"kind":"TIAOQI-REPLAY","version":1}',
        valid.encode(),
      ],
    });
    StorageService.resetForTests();

    final storage = await StorageService.instance;
    expect(storage.replays, hasLength(1));
    expect(storage.replays.single.id, valid.id);
  });

  test('偏好层保存棋谱后立即刷新列表并通知界面', () async {
    final storage = await StorageService.instance;
    final settings = SettingsProvider(storage);
    var notified = 0;
    settings.addListener(() => notified++);
    final archive = sampleArchive();

    await settings.saveReplay(archive);

    expect(settings.replays.single.id, archive.id);
    expect(notified, 1);

    await settings.removeReplay(archive.id);
    expect(settings.replays, isEmpty);

    await settings.saveReplay(archive);
    await settings.clearReplays();
    expect(settings.replays, isEmpty);
  });

  test('重复导入同一份棋谱只保留一条', () async {
    final storage = await StorageService.instance;
    final archive = sampleArchive();

    await storage.addReplay(archive);
    await storage.addReplay(ReplayArchive.decode(archive.encode())!);

    expect(storage.replays, hasLength(1));
  });
}
