import 'package:chinese_checkers/flame/board_component.dart';
import 'package:chinese_checkers/game/board_geometry.dart';
import 'package:chinese_checkers/game/checkers_board.dart';
import 'package:chinese_checkers/game/checkers_controller.dart';
import 'package:chinese_checkers/game/checkers_rules.dart';
import 'package:chinese_checkers/game/replay_controller.dart';
import 'package:chinese_checkers/models/game_models.dart';
import 'package:chinese_checkers/theme/app_theme.dart';
import 'package:flutter/foundation.dart';
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

  Future<BoardComponent> buildBoard(
    ReplayController source,
    ValueNotifier<BoardTheme> theme,
  ) async {
    final board = BoardComponent(
      source: source,
      theme: theme,
      showHints: false,
    );
    await board.onLoad();
    board.update(0);
    return board;
  }

  test('实时对局的新增着法全部进入动画队列', () async {
    final controller = CheckersController(setup: setup);
    final theme = ValueNotifier<BoardTheme>(kBoardThemes.first);
    final board = BoardComponent(
      source: controller,
      theme: theme,
      showHints: false,
    );
    await board.onLoad();
    board.update(0);
    expect(board.isAnimating, isFalse);

    final move = controller.rules.legalMoves(controller.board, 0).first;
    controller.applyMove(move);
    board.update(0);

    expect(board.isAnimating, isTrue);
    expect(board.pendingAnimations, 1);

    board.update(1);
    expect(board.isAnimating, isFalse);

    controller.dispose();
    theme.dispose();
  });

  test('复盘逐手前进播放动画，批量跳转与后退直接切换', () async {
    final replay = ReplayController(setup: setup, records: sampleRecords(5));
    final theme = ValueNotifier<BoardTheme>(kBoardThemes.first);
    final board = await buildBoard(replay, theme);

    replay.next();
    board.update(0);
    expect(board.isAnimating, isTrue);
    expect(board.pendingAnimations, 1);

    // 动画未播完时直接跳到终点，应丢弃进行中的动画，不残留旧局面。
    replay.toEnd();
    board.update(0);
    expect(board.isAnimating, isFalse);

    replay.previous();
    board.update(0);
    expect(board.isAnimating, isFalse);

    replay.next();
    board.update(0);
    expect(board.isAnimating, isTrue);

    replay.dispose();
    theme.dispose();
  });

  test('复盘自动播放逐手补播动画', () async {
    final replay = ReplayController(
      setup: setup,
      records: sampleRecords(3),
      playInterval: const Duration(milliseconds: 10),
    );
    final theme = ValueNotifier<BoardTheme>(kBoardThemes.first);
    final board = await buildBoard(replay, theme);

    replay.play();
    await Future<void>.delayed(const Duration(milliseconds: 20));
    board.update(0);

    expect(replay.index, greaterThan(0));
    expect(board.isAnimating, isTrue);

    replay.dispose();
    theme.dispose();
  });
}
