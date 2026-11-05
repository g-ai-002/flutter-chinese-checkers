import 'package:chinese_checkers/game/board_geometry.dart';
import 'package:chinese_checkers/game/checkers_board.dart';
import 'package:chinese_checkers/game/checkers_rules.dart';
import 'package:chinese_checkers/game/move_record.dart';
import 'package:chinese_checkers/game/replay_controller.dart';
import 'package:chinese_checkers/models/game_models.dart';
import 'package:chinese_checkers/utils/move_notation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const setup = GameSetup(mode: PlayMode.local, playerCount: PlayerCount.two);

  List<MoveRecord> sampleRecords(int count) {
    final geometry = BoardGeometry.star();
    final board = CheckersBoard.initial(geometry, setup.seatArms);
    final rules = CheckersRules(geometry);
    final records = <MoveRecord>[];
    var seat = 0;
    for (var i = 0; i < count; i++) {
      final move = rules.legalMoves(board, seat).first;
      board.move(move.from, move.to);
      records.add(MoveRecord(seat: seat, move: move));
      seat = (seat + 1) % setup.players;
    }
    return records;
  }

  test('开局状态为初始营地，历史为空', () {
    final replay = ReplayController(setup: setup, records: sampleRecords(4));

    expect(replay.index, 0);
    expect(replay.total, 4);
    expect(replay.atStart, isTrue);
    expect(replay.atEnd, isFalse);
    expect(replay.history, isEmpty);
    expect(replay.currentStep, isNull);
    expect(replay.supportsMoveAnimation, isFalse);
    expect(replay.board.holesOf(0), hasLength(10));
    expect(replay.board.holesOf(1), hasLength(10));
    replay.dispose();
  });

  test('逐手前进与后退重建出对应局面', () {
    final records = sampleRecords(6);
    final replay = ReplayController(setup: setup, records: records);
    final geometry = replay.geometry;
    final expected = CheckersBoard.initial(geometry, setup.seatArms);

    for (var i = 0; i < records.length; i++) {
      final move = records[i].move;
      expected.move(move.from, move.to);
      replay.next();

      expect(replay.index, i + 1);
      expect(replay.history, hasLength(i + 1));
      expect(replay.board.cells, expected.cells);
      expect(replay.currentStep!.record.seat, records[i].seat);
      expect(
        replay.steps[i].progress,
        replay.board.countInArm(
          geometry,
          records[i].seat,
          setup.targetArmOf(records[i].seat),
        ),
      );
    }

    replay.previous();
    expect(replay.index, records.length - 1);
    expect(replay.atEnd, isFalse);

    replay.toStart();
    expect(replay.index, 0);
    expect(replay.board.holesOf(0), hasLength(10));
    expect(replay.history, isEmpty);
    replay.dispose();
  });

  test('跳转越界时收敛到有效范围', () {
    final replay = ReplayController(setup: setup, records: sampleRecords(3));

    replay.seekTo(99);
    expect(replay.index, 3);
    expect(replay.atEnd, isTrue);

    replay.next();
    expect(replay.index, 3);

    replay.seekTo(-5);
    expect(replay.index, 0);

    replay.previous();
    expect(replay.index, 0);
    replay.dispose();
  });

  test('自动播放逐手推进，到终点自动停止', () async {
    final replay = ReplayController(
      setup: setup,
      records: sampleRecords(3),
      playInterval: const Duration(milliseconds: 12),
    );
    replay.play();
    expect(replay.isPlaying, isTrue);

    await Future<void>.delayed(const Duration(milliseconds: 120));

    expect(replay.index, 3);
    expect(replay.isPlaying, isFalse);
    replay.dispose();
  });

  test('手动跳转会暂停自动播放，终局再次播放从头开始', () async {
    final replay = ReplayController(
      setup: setup,
      records: sampleRecords(3),
      playInterval: const Duration(milliseconds: 12),
    );
    replay.toEnd();
    replay.play();

    expect(replay.isPlaying, isTrue);
    expect(replay.index, 0);

    replay.next();
    expect(replay.isPlaying, isFalse);
    expect(replay.index, 1);

    replay.toEnd();
    replay.play();
    expect(replay.index, 0);

    replay.pause();
    expect(replay.isPlaying, isFalse);
    replay.dispose();
  });

  test('复盘只读，点击棋盘不改变局面', () {
    final replay = ReplayController(setup: setup, records: sampleRecords(2));
    replay.next();
    final before = List<int>.of(replay.board.cells);

    replay.tapHole(0);
    replay.tapHole(replay.board.cells.indexOf(-1));

    expect(replay.board.cells, before);
    expect(replay.index, 1);
    replay.dispose();
  });

  test('着法描述区分单步、单跳与连跳', () {
    expect(describeMove(CheckersMove.step(0, 1)), '单步');
    expect(describeMove(CheckersMove.jump(0, const [2])), '单跳');
    expect(describeMove(CheckersMove.jump(0, const [2, 4, 6])), '连跳 ×3');
  });
}
