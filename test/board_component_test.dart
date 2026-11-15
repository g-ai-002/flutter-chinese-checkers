import 'dart:ui' as ui;

import 'package:chinese_checkers/flame/board_component.dart';
import 'package:chinese_checkers/game/board_geometry.dart';
import 'package:chinese_checkers/game/checkers_board.dart';
import 'package:chinese_checkers/game/checkers_controller.dart';
import 'package:chinese_checkers/game/checkers_rules.dart';
import 'package:chinese_checkers/game/replay_controller.dart';
import 'package:chinese_checkers/models/game_models.dart';
import 'package:chinese_checkers/theme/app_theme.dart';
import 'package:flame/components.dart';
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
    final board = BoardComponent(source: source, theme: theme, showHints: false);
    await board.onLoad();
    board.update(0);
    return board;
  }

  test('实时对局的新增着法全部进入动画队列', () async {
    final controller = CheckersController(setup: setup);
    final theme = ValueNotifier<BoardTheme>(kBoardThemes.first);
    final board = BoardComponent(source: controller, theme: theme, showHints: false);
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

  test('复盘逐手前进先高亮起点棋子，实时对局不预高亮', () async {
    final replay = ReplayController(setup: setup, records: sampleRecords(3));
    final theme = ValueNotifier<BoardTheme>(kBoardThemes.first);
    final board = await buildBoard(replay, theme);
    final from = replay.steps.first.record.move.from;

    replay.next();
    board.update(0);
    expect(board.isPreviewing, isTrue);
    expect(board.previewHole, from);
    expect(board.isAnimating, isTrue);

    // 预高亮结束后才开始移动棋子。
    board.update(ReplayController.leadIn.inMilliseconds / 1000 + 0.01);
    expect(board.isPreviewing, isFalse);
    expect(board.isAnimating, isTrue);

    board.update(1);
    expect(board.isAnimating, isFalse);
    replay.dispose();

    final controller = CheckersController(setup: setup);
    final live = BoardComponent(source: controller, theme: theme, showHints: false);
    await live.onLoad();
    live.update(0);
    final move = controller.rules.legalMoves(controller.board, 0).first;
    controller.applyMove(move);
    live.update(0);
    expect(controller.animationLeadIn, Duration.zero);
    expect(live.isPreviewing, isFalse);
    expect(live.previewHole, isNull);

    controller.dispose();
    theme.dispose();
  });

  test('静止帧复用棋子贴图，走子后不再重建', () async {
    final controller = CheckersController(setup: setup);
    final theme = ValueNotifier<BoardTheme>(kBoardThemes.first);
    final board = BoardComponent(source: controller, theme: theme, showHints: true);
    await board.onLoad();
    board.size = Vector2(680, 777);
    board.update(0);

    _render(board);
    final sprites = board.spriteRasters;
    expect(sprites, 2);
    _render(board);
    _render(board);
    expect(board.spriteRasters, sprites);
    expect(board.wantsFrames, isFalse);

    // 选中棋子会持续呼吸高亮，需要保持刷新。
    controller.tapHole(controller.board.holesOf(0).first);
    expect(board.wantsFrames, isTrue);

    // 走子后静止帧与动画帧都复用同一组棋子贴图。
    final move = controller.rules.legalMoves(controller.board, 0).first;
    controller.applyMove(move);
    board.update(0);
    expect(board.isAnimating, isTrue);
    _render(board);
    expect(board.spriteRasters, sprites);

    board.update(10);
    _render(board);
    expect(board.isAnimating, isFalse);
    expect(board.spriteRasters, sprites);

    controller.dispose();
    theme.dispose();
  });

  test('窗口尺寸变化时复用模型坐标层，稳定后再换底板贴图', () async {
    final controller = CheckersController(setup: setup);
    final theme = ValueNotifier<BoardTheme>(kBoardThemes.first);
    final board = BoardComponent(source: controller, theme: theme, showHints: true);
    await board.onLoad();
    board.size = Vector2(680, 777);
    board.update(0);

    _render(board);
    _render(board);
    final boardBuilds = board.boardLayerBuilds;
    final rasters = board.boardRasters;
    expect(boardBuilds, 1);
    expect(rasters, 1);
    expect(board.boardRasterized, isTrue);

    // 拖动窗口改变尺寸只换缩放矩阵：底板不重录，尺寸还在变时先重放 Picture。
    board.size = Vector2(640, 731);
    _render(board);
    expect(board.boardLayerBuilds, boardBuilds);
    expect(board.boardRasterized, isFalse);

    // 尺寸稳定一帧后升级成新贴图，之后每帧复用同一张。
    _render(board);
    expect(board.boardRasters, rasters + 1);
    expect(board.boardRasterized, isTrue);
    _render(board);
    expect(board.boardRasters, rasters + 1);

    // 换配色后底板重录并重新光栅化，棋子贴图不受影响。
    final sprites = board.spriteRasters;
    theme.value = kBoardThemes.last;
    _render(board);
    expect(board.boardLayerBuilds, boardBuilds + 1);
    _render(board);
    expect(board.boardRasters, rasters + 2);
    expect(board.spriteRasters, sprites);

    controller.dispose();
    theme.dispose();
  });

  test('走子动画每帧复用底板贴图，只额外画移动中的棋子', () async {
    const six = GameSetup(mode: PlayMode.local, playerCount: PlayerCount.six);
    final controller = CheckersController(setup: six);
    final theme = ValueNotifier<BoardTheme>(kBoardThemes.first);
    final board = BoardComponent(source: controller, theme: theme, showHints: false);
    await board.onLoad();
    board.size = Vector2(600, 686);
    board.update(0);

    _render(board);
    _render(board);
    final rasters = board.boardRasters;
    final sprites = board.spriteRasters;
    expect(sprites, 6);
    expect(board.boardRasterized, isTrue);

    controller.applyMove(controller.rules.legalMoves(controller.board, 0).first);
    board.update(0);
    _render(board);
    expect(board.isAnimating, isTrue);

    // 整段动画的每一帧都不新建贴图。
    for (var i = 0; i < 5; i++) {
      board.update(0.02);
      _render(board);
    }
    expect(board.boardRasters, rasters);
    expect(board.spriteRasters, sprites);

    board.update(10);
    _render(board);
    expect(board.isAnimating, isFalse);
    expect(board.boardRasters, rasters);

    controller.dispose();
    theme.dispose();
  });

  test('底板贴图与直接重放 Picture 的画面一致', () async {
    final controller = CheckersController(setup: setup);
    final theme = ValueNotifier<BoardTheme>(kBoardThemes.first);
    final board = BoardComponent(source: controller, theme: theme, showHints: true);
    await board.onLoad();
    board.size = Vector2(680, 777);
    board.update(0);

    // 第一帧还在重放 Picture，第二帧升级为贴图：两帧画面应几乎完全相同。
    final vector = await _renderPixels(board);
    expect(board.boardRasterized, isFalse);
    final raster = await _renderPixels(board);
    expect(board.boardRasterized, isTrue);

    var maxDelta = 0;
    var mismatched = 0;
    for (var i = 0; i < vector.length; i++) {
      final delta = (vector[i] - raster[i]).abs();
      if (delta > 0) mismatched++;
      if (delta > maxDelta) maxDelta = delta;
    }
    expect(maxDelta, lessThanOrEqualTo(2));
    expect(mismatched / vector.length, lessThan(0.005));

    controller.dispose();
    theme.dispose();
  });

  test('选中呼吸高亮限时，淡出后不再请求帧', () async {
    final controller = CheckersController(setup: setup);
    final theme = ValueNotifier<BoardTheme>(kBoardThemes.first);
    final board = BoardComponent(source: controller, theme: theme, showHints: false);
    await board.onLoad();
    board.size = Vector2(680, 777);
    board.update(0);

    controller.tapHole(controller.board.holesOf(0).first);
    expect(board.wantsFrames, isTrue);

    board.update(0.5);
    expect(board.wantsFrames, isTrue);

    board.update(BoardComponent.selectionPulseSeconds);
    expect(board.wantsFrames, isFalse);

    // 换一枚棋子会重新开始高亮。
    final other = controller.board.holesOf(0).last;
    controller.tapHole(other);
    expect(board.wantsFrames, isTrue);
    board.update(0);
    expect(board.wantsFrames, isTrue);

    // 高亮淡出后同样不再请求帧。
    board.update(BoardComponent.selectionPulseSeconds);
    expect(board.wantsFrames, isFalse);

    controller.dispose();
    theme.dispose();
  });
}

void _render(BoardComponent board) {
  final recorder = ui.PictureRecorder();
  board.render(ui.Canvas(recorder));
  recorder.endRecording().dispose();
}

/// 按物理像素把棋盘渲染成 RGBA 字节，用于比对贴图与矢量绘制是否一致。
Future<Uint8List> _renderPixels(BoardComponent board) async {
  final ratio = ui.PlatformDispatcher.instance.implicitView?.devicePixelRatio ?? 1;
  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(recorder)..scale(ratio);
  board.render(canvas);
  final picture = recorder.endRecording();
  final image = await picture.toImage(
    (board.size.x * ratio).round(),
    (board.size.y * ratio).round(),
  );
  final data = await image.toByteData();
  image.dispose();
  picture.dispose();
  return data!.buffer.asUint8List();
}
