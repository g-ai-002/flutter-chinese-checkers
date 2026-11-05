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

  /// 双方按「能跳就跳」走子，直到出现第一手跳跃，用于覆盖最佳着法。
  List<MoveRecord> recordsUntilJump({int limit = 200}) {
    final geometry = BoardGeometry.star();
    final board = CheckersBoard.initial(geometry, setup.seatArms);
    final rules = CheckersRules(geometry);
    final records = <MoveRecord>[];
    var seat = 0;
    for (var i = 0; i < limit; i++) {
      final moves = rules.legalMoves(board, seat);
      CheckersMove? jump;
      for (final move in moves) {
        if (move.jump) {
          jump = move;
          break;
        }
      }
      final move = jump ?? moves.first;
      board.move(move.from, move.to);
      records.add(MoveRecord(seat: seat, move: move));
      seat = (seat + 1) % setup.players;
      if (jump != null) return records;
    }
    fail('前 $limit 手内没有出现跳跃');
  }

  /// 只走单步，确保没有跳跃亮点。
  List<MoveRecord> stepRecords(int count) {
    final geometry = BoardGeometry.star();
    final board = CheckersBoard.initial(geometry, setup.seatArms);
    final rules = CheckersRules(geometry);
    final records = <MoveRecord>[];
    var seat = 0;
    for (var i = 0; i < count; i++) {
      final move = rules
          .legalMoves(board, seat)
          .firstWhere((candidate) => !candidate.jump);
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

  test('前后反复跳转后局面与从头重放一致', () {
    final records = sampleRecords(8);
    final replay = ReplayController(setup: setup, records: records);
    final geometry = replay.geometry;

    List<int> expectedAt(int count) {
      final board = CheckersBoard.initial(geometry, setup.seatArms);
      for (var i = 0; i < count; i++) {
        board.move(records[i].move.from, records[i].move.to);
      }
      return board.cells;
    }

    replay.seekTo(6);
    expect(replay.board.cells, expectedAt(6));
    expect(replay.history, hasLength(6));

    replay.seekTo(2);
    expect(replay.board.cells, expectedAt(2));
    expect(replay.history, hasLength(2));

    replay.next();
    expect(replay.board.cells, expectedAt(3));

    replay.toEnd();
    expect(replay.board.cells, expectedAt(8));

    replay.toStart();
    expect(replay.board.cells, expectedAt(0));
    replay.dispose();
  });

  test('手动跳转暂停播放并只通知一次', () {
    final replay = ReplayController(
      setup: setup,
      records: sampleRecords(4),
      playInterval: const Duration(milliseconds: 200),
    );
    replay.toEnd();
    replay.play();
    expect(replay.isPlaying, isTrue);

    var notifications = 0;
    replay.addListener(() => notifications++);
    replay.seekTo(2);

    expect(notifications, 1);
    expect(replay.isPlaying, isFalse);
    expect(replay.index, 2);
    replay.dispose();
  });

  test('空棋谱保持开局且无法播放', () {
    final replay = ReplayController(setup: setup, records: const []);
    var notifications = 0;
    replay.addListener(() => notifications++);

    replay.play();
    replay.next();
    replay.previous();
    replay.toEnd();

    expect(replay.index, 0);
    expect(replay.total, 0);
    expect(replay.atStart, isTrue);
    expect(replay.atEnd, isTrue);
    expect(replay.currentStep, isNull);
    expect(replay.isPlaying, isFalse);
    expect(notifications, 0);
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

  test('最佳着法定位到评分最高的一手并可跳转', () {
    final records = recordsUntilJump();
    final replay = ReplayController(setup: setup, records: records);

    expect(replay.hasBestMove, isTrue);
    expect(replay.bestMoveNumber, isNotNull);
    expect(replay.bestStep, isNotNull);
    expect(replay.bestStep!.score, greaterThan(0));

    var expected = 0;
    for (var i = 1; i < replay.steps.length; i++) {
      if (replay.steps[i].score > replay.steps[expected].score) expected = i;
    }
    expect(replay.bestMoveNumber, expected + 1);

    replay.seekTo(replay.bestMoveNumber!);
    expect(replay.index, replay.bestMoveNumber);
    expect(replay.currentStep, same(replay.bestStep));
    replay.dispose();
  });

  test('进营手比普通连跳得分更高', () {
    final replay = ReplayController(setup: setup, records: recordsUntilJump());
    for (final step in replay.steps) {
      final expected =
          step.progressGain * 100 +
          step.record.move.jumpCount * 10 +
          (step.landedInCamp ? 5 : 0);
      expect(step.score, expected);
    }
    replay.dispose();
  });

  test('纯单步开局没有最佳着法亮点', () {
    final replay = ReplayController(setup: setup, records: stepRecords(2));
    expect(replay.steps.every((step) => step.score == 0), isTrue);
    expect(replay.hasBestMove, isFalse);
    replay.dispose();
  });

  test('空棋谱没有最佳着法', () {
    final replay = ReplayController(setup: setup, records: const []);
    expect(replay.bestMoveNumber, isNull);
    expect(replay.bestStep, isNull);
    expect(replay.hasBestMove, isFalse);
    replay.dispose();
  });
}
