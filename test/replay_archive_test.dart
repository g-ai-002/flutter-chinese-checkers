import 'dart:convert';

import 'package:chinese_checkers/models/game_models.dart';
import 'package:chinese_checkers/models/replay_archive.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/replay_fixtures.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Map<String, dynamic> tampered(ReplayArchive archive) =>
      jsonDecode(archive.encode().substring(ReplayArchive.codePrefix.length))
          as Map<String, dynamic>;

  test('完整棋谱编码后可以原样还原', () {
    final archive = sampleArchive(
      setup: const GameSetup(
        mode: PlayMode.vsAi,
        playerCount: PlayerCount.four,
        difficulty: Difficulty.hard,
        humanSeat: 2,
      ),
      count: 10,
      duration: const Duration(minutes: 5, seconds: 8),
    );

    final decoded = ReplayArchive.decode(archive.encode())!;

    expect(decoded.id, archive.id);
    expect(decoded.savedAt, archive.savedAt);
    expect(decoded.setup.mode, PlayMode.vsAi);
    expect(decoded.setup.playerCount, PlayerCount.four);
    expect(decoded.setup.difficulty, Difficulty.hard);
    expect(decoded.setup.humanSeat, 2);
    expect(decoded.winner, isNull);
    expect(decoded.duration, const Duration(minutes: 5, seconds: 8));
    expect(decoded.moves, 10);
    for (var i = 0; i < archive.moves; i++) {
      expect(decoded.records[i].seat, archive.records[i].seat);
      expect(decoded.records[i].move.from, archive.records[i].move.from);
      expect(
        decoded.records[i].move.landings,
        archive.records[i].move.landings,
      );
      expect(decoded.records[i].move.jump, archive.records[i].move.jump);
    }
  });

  test('分享码省略前缀也能解析，标题与结果标签正确', () {
    final archive = sampleArchive();
    final payload = archive.encode().substring(ReplayArchive.codePrefix.length);

    final decoded = ReplayArchive.decode('  $payload  ')!;

    expect(decoded.title, '2 人 · 同屏对战');
    expect(decoded.outcomeLabel, '平局');
    expect(decoded.isDraw, isTrue);
    expect(decoded.longestJump, archive.longestJump);
  });

  test('人机棋谱的结果标签区分胜负', () {
    const setup = GameSetup(
      mode: PlayMode.vsAi,
      playerCount: PlayerCount.two,
      humanSeat: 1,
    );
    final win = sampleArchive(setup: setup, winner: 1);
    final loss = sampleArchive(setup: setup, winner: 0);

    expect(win.outcomeLabel, '胜');
    expect(loss.outcomeLabel, '负');
  });

  test('导入时拒绝被篡改的走子', () {
    final archive = sampleArchive();
    final json = tampered(archive);
    final moves = json['moves'] as List<dynamic>;
    final second = List<dynamic>.from(moves[1] as List<dynamic>);
    // 1 号座位的第一手改成从黑格跳到不在规则内的孔位。
    second[1] = 0;
    second[2] = [5];
    second[3] = false;
    moves[1] = second;

    expect(ReplayArchive.decode(jsonEncode(json)), isNull);
  });

  test('导入时拒绝人数、座位与版本非法', () {
    final json = tampered(sampleArchive());

    expect(
      ReplayArchive.decode(jsonEncode({...json, 'playerCount': 5})),
      isNull,
    );
    expect(ReplayArchive.decode(jsonEncode({...json, 'humanSeat': 9})), isNull);
    expect(ReplayArchive.decode(jsonEncode({...json, 'winner': 9})), isNull);
    expect(ReplayArchive.decode(jsonEncode({...json, 'version': 99})), isNull);
    expect(
      ReplayArchive.decode(jsonEncode({...json, 'kind': 'other'})),
      isNull,
    );
  });

  test('导入时拒绝空棋谱、坏 JSON 与无关文本', () {
    expect(ReplayArchive.decode(''), isNull);
    expect(ReplayArchive.decode('   '), isNull);
    expect(ReplayArchive.decode('hello'), isNull);
    expect(ReplayArchive.decode('TIAOQI1:{'), isNull);

    final json = tampered(sampleArchive());
    expect(ReplayArchive.decode(jsonEncode({...json, 'moves': []})), isNull);
  });

  test('宣称获胜但棋子未全部进营的棋谱被拒绝', () {
    final archive = sampleArchive(winner: 0);

    expect(ReplayArchive.decode(archive.encode()), isNull);
  });

  test('读取本机存档时跳过合法性重放', () {
    final archive = sampleArchive(winner: 0);

    final decoded = ReplayArchive.decode(archive.encode(), verifyMoves: false);

    expect(decoded, isNotNull);
    expect(decoded!.moves, 6);
  });
}
