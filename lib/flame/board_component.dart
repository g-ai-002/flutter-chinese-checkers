import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../game/board_geometry.dart';
import '../game/board_source.dart';
import '../game/checkers_board.dart';
import '../models/game_models.dart';
import '../services/sound_service.dart';
import '../theme/app_theme.dart';
import '../theme/player_palette.dart';
import 'move_animator.dart';

/// 棋盘绘制尺寸（单位：孔距）。
const double _contentHalfWidth = 7.0;
const double _contentHalfHeight = 8.0;
const double _pieceRadius = 0.4;
const double _holeRadius = 0.44;

/// Flame 棋盘组件：绘制六角星棋盘、棋子、可走提示与走子动画，并处理点击。
class BoardComponent extends PositionComponent with TapCallbacks {
  BoardComponent({
    required this.source,
    required this.theme,
    required this.showHints,
  });

  final BoardSource source;
  final ValueListenable<BoardTheme> theme;
  final bool showHints;

  double _scale = 0;
  Offset _origin = Offset.zero;
  double _rotation = 0;
  int _seenHistory = 0;
  late final double _leadIn =
      source.animationLeadIn.inMicroseconds / Duration.microsecondsPerSecond;
  late CheckersBoard _mirror;
  final MoveAnimator _animator = MoveAnimator();
  double _time = 0;

  double _cacheScale = 0;
  ui.Picture? _boardLayer;
  final Map<int, ui.Picture> _sprites = {};
  double _spriteScale = 0;

  /// 棋子层按当前局面录成一张 Picture，静止时不再逐枚绘制。
  ui.Picture? _piecesLayer;
  CheckersBoard? _piecesBoard;
  int _piecesHistory = -1;
  BoardTheme? _piecesTheme;
  double _piecesScale = 0;
  int _piecesBuilds = 0;

  BoardGeometry get _geometry => source.geometry;

  @override
  Future<void> onLoad() async {
    _mirror = source.board.copy();
    _seenHistory = source.history.length;
    theme.addListener(_invalidate);
  }

  @override
  void onRemove() {
    theme.removeListener(_invalidate);
    _animator.clear();
    _disposeLayers();
    _disposePieces();
    super.onRemove();
  }

  void _invalidate() {
    _cacheScale = 0;
    _spriteScale = 0;
    _disposeLayers();
    _disposePieces();
    for (final sprite in _sprites.values) {
      sprite.dispose();
    }
    _sprites.clear();
  }

  void _disposeLayers() {
    _boardLayer?.dispose();
    _boardLayer = null;
  }

  void _disposePieces() {
    _piecesLayer?.dispose();
    _piecesLayer = null;
    _piecesBoard = null;
    _piecesHistory = -1;
  }

  @override
  void update(double dt) {
    super.update(dt);
    _time += dt;
    _syncHistory();
    _animator.advance(dt);
  }

  /// 把棋盘源新增的着法补进动画队列，每手保存走完后的局面快照。
  ///
  /// 只有 [BoardSource.animationStartIndex] 之后的新增着法才播放动画：
  /// 复盘逐手前进只播最后一手，拖动进度条或批量跳转则直接切换局面。
  /// 历史变短（复盘后退）时整体重建镜像并清空队列。
  void _syncHistory() {
    final records = source.history;
    if (records.length < _seenHistory) {
      _seenHistory = records.length;
      _mirror = source.board.copy();
      _animator.clear();
      return;
    }
    if (records.length == _seenHistory) return;
    final animateFrom = source.animationStartIndex.clamp(0, records.length);
    if (animateFrom > _seenHistory) {
      // 跨越了多手：丢掉进行中的动画，直接切到目标局面。
      _animator.clear();
    }
    for (var i = _seenHistory; i < records.length; i++) {
      final move = records[i].move;
      _mirror.move(move.from, move.to);
      if (i >= animateFrom) {
        _animator.enqueue(move, _mirror.cells, leadIn: _leadIn);
      }
    }
    _seenHistory = records.length;
  }

  @override
  void render(Canvas canvas) {
    if (size.x <= 0 || size.y <= 0) return;
    final scale = math.min(
      size.x / (_contentHalfWidth * 2),
      size.y / (_contentHalfHeight * 2),
    );
    if (scale <= 0) return;
    _scale = scale;
    _origin = Offset(size.x / 2, size.y / 2);
    if (_sprites.isNotEmpty && (_spriteScale - scale).abs() > 0.01) {
      for (final sprite in _sprites.values) {
        sprite.dispose();
      }
      _sprites.clear();
    }
    _spriteScale = scale;
    _rotation = _rotationForHome();
    _ensureLayers(scale);

    final anim = _animator.current;
    final cells = anim?.cells ?? source.board.cells;
    canvas.save();
    canvas.translate(_origin.dx, _origin.dy);
    canvas.rotate(_rotation);
    final layer = _boardLayer;
    if (layer != null) canvas.drawPicture(layer);
    if (anim == null) {
      _drawSelection(canvas, cells);
      _drawTargets(canvas);
      _drawHint(canvas);
    } else if (anim.previewing) {
      _drawCue(canvas, anim);
    }
    _drawPieces(canvas, cells, anim);
    canvas.restore();
  }

  /// 人机对战把自己的营地转到棋盘正下方，前进方向朝上更符合直觉。
  double _rotationForHome() {
    if (source.setup.mode != PlayMode.vsAi) return 0;
    final seat = source.setup.humanSeat.clamp(0, source.players - 1);
    final arm = source.setup.seatArms[seat];
    final tip = _geometry.holes[_geometry.tipHole(arm)];
    final base = math.atan2(tip.y, tip.x);
    return math.pi / 2 - base;
  }

  Offset _point(int hole) {
    final h = _geometry.holes[hole];
    return Offset(h.x * _scale, h.y * _scale);
  }

  /// 底板、营地底色与孔位不随对局变化，随尺寸缓存为一张图片。
  void _ensureLayers(double scale) {
    if (_boardLayer != null && (_cacheScale - scale).abs() < 0.01) return;
    _disposeLayers();
    _cacheScale = scale;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    _paintPlate(canvas, scale);
    _paintCamps(canvas, scale);
    _paintHoles(canvas, scale);
    _boardLayer = recorder.endRecording();
  }

  void _paintPlate(Canvas canvas, double scale) {
    final palette = theme.value;
    final path = Path();
    path.addPolygon(<Offset>[
      for (final p in BoardGeometry.starOutline())
        Offset(p[0] * scale, p[1] * scale),
    ], true);

    canvas.drawPath(
      path.shift(const Offset(0, 0.16)),
      Paint()
        ..color = Colors.black.withValues(alpha: 0.22)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, scale * 0.32),
    );

    canvas.drawPath(
      path,
      Paint()
        ..shader = ui.Gradient.linear(
          Offset(0, -scale * 7),
          Offset(0, scale * 7),
          [palette.plateTop, palette.plateBottom],
        ),
    );
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = scale * 0.06
        ..color = palette.plateEdge,
    );
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = scale * 0.14
        ..color = Colors.white.withValues(alpha: 0.06),
    );
    // 顶部一抹柔光，让深色底板不至于发闷。
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(0, -scale * 4.4),
        width: scale * 12,
        height: scale * 5.4,
      ),
      Paint()
        ..shader = ui.Gradient.radial(Offset(0, -scale * 4.4), scale * 6, [
          Colors.white.withValues(alpha: 0.10),
          Colors.white.withValues(alpha: 0),
        ]),
    );
  }

  void _paintCamps(Canvas canvas, double scale) {
    for (var seat = 0; seat < source.players; seat++) {
      final color = playerStyleOf(seat).main;
      final arm = source.setup.seatArms[seat];
      for (final hole in _geometry.armHoles[arm]) {
        canvas.drawCircle(
          _point(hole),
          scale * 0.78,
          Paint()..color = color.withValues(alpha: 0.16),
        );
      }
      // 对面营地用空心圆标注目标，与自家营地实心色块区分。
      final goal = source.setup.targetArmOf(seat);
      final tip = _geometry.tipHole(goal);
      canvas.drawCircle(
        _point(tip),
        scale * 0.52,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = scale * 0.055
          ..color = color.withValues(alpha: 0.85),
      );
    }
  }

  void _paintHoles(Canvas canvas, double scale) {
    final palette = theme.value;
    for (final hole in _geometry.holes) {
      final center = _point(hole.index);
      final radius = scale * _holeRadius;
      canvas.drawCircle(
        center + Offset(0, scale * 0.035),
        radius,
        Paint()..color = Colors.black.withValues(alpha: 0.20),
      );
      canvas.drawCircle(
        center,
        radius,
        Paint()
          ..shader = ui.Gradient.radial(
            center + Offset(-radius * 0.3, -radius * 0.35),
            radius * 1.5,
            [palette.holeFill, palette.holeInner],
          ),
      );
      canvas.drawCircle(
        center,
        radius,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = scale * 0.018
          ..color = palette.holeEdge.withValues(alpha: 0.9),
      );
    }
  }

  void _drawSelection(Canvas canvas, List<int> cells) {
    final hole = source.selectedHole;
    if (hole == null || cells[hole] < 0) return;
    final center = _point(hole);
    final style = playerStyleOf(cells[hole]);
    final radius = _scale * 0.47;
    canvas.drawCircle(
      center,
      radius + _scale * 0.05,
      Paint()
        ..color = Colors.black.withValues(alpha: 0.35)
        ..style = PaintingStyle.stroke
        ..strokeWidth = _scale * 0.13,
    );
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = style.light
        ..style = PaintingStyle.stroke
        ..strokeWidth = _scale * 0.07,
    );
    final pulse = 0.5 + 0.5 * math.sin(_time * 3.4);
    canvas.drawCircle(
      center,
      radius + _scale * (0.06 + pulse * 0.03),
      Paint()..color = style.light.withValues(alpha: 0.18 + pulse * 0.12),
    );
  }

  /// 复盘逐手播放前的预高亮：让即将移动的棋子先亮起来。
  ///
  /// 这一步不改变局面，只画在起点棋子周围，给玩家一个眼神落点。
  void _drawCue(Canvas canvas, MoveAnimation anim) {
    final seat = anim.cells[anim.move.to];
    if (seat < 0) return;
    final style = playerStyleOf(seat);
    final center = _point(anim.move.from);
    final lead = anim.leadIn <= 0
        ? 1.0
        : (anim.elapsed / anim.leadIn).clamp(0.0, 1.0);
    final pulse = 0.5 - 0.5 * math.cos(lead * math.pi * 2.4);
    canvas.drawCircle(
      center,
      _scale * 0.44,
      Paint()..color = style.light.withValues(alpha: 0.16 + 0.14 * pulse),
    );
    canvas.drawCircle(
      center,
      _scale * (0.5 + 0.12 * pulse),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = _scale * 0.07
        ..color = style.light.withValues(alpha: 0.9),
    );
    canvas.drawCircle(
      center,
      _scale * (0.58 + 0.2 * pulse),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = _scale * 0.03
        ..color = style.light.withValues(alpha: 0.5 * (1 - pulse)),
    );
  }

  /// 可落点：单步画小圆点，连跳落点画双环，方便区分。
  void _drawTargets(Canvas canvas) {
    if (!showHints || source.targets.isEmpty) return;
    for (final entry in source.targets.entries) {
      final center = _point(entry.key);
      final jump = entry.value.jumpCount > 0;
      if (jump) {
        canvas.drawCircle(
          center,
          _scale * 0.37,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = _scale * 0.045
            ..color = Colors.white.withValues(alpha: 0.65),
        );
        canvas.drawCircle(
          center,
          _scale * 0.12,
          Paint()..color = Colors.white.withValues(alpha: 0.85),
        );
      } else {
        canvas.drawCircle(
          center,
          _scale * 0.13,
          Paint()..color = Colors.white.withValues(alpha: 0.72),
        );
      }
    }
  }

  /// 提示着法：金色折线沿连跳路径指向落点。
  void _drawHint(Canvas canvas) {
    final hint = source.hintMove;
    if (hint == null) return;
    const color = Color(0xFFE9C46A);
    final paint = Paint()
      ..color = color
      ..strokeWidth = _scale * 0.055
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final path = hint.path;
    final points = [for (final hole in path) _point(hole)];
    if (points.length < 2) return;

    canvas.drawCircle(
      points.first,
      _scale * 0.5,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = _scale * 0.05
        ..color = color.withValues(alpha: 0.9),
    );

    for (var i = 0; i < points.length - 1; i++) {
      final start = points[i];
      final end = points[i + 1];
      final delta = end - start;
      final length = delta.distance;
      if (length < 1) continue;
      final dir = delta / length;
      final from = start + dir * (_scale * 0.48);
      final to = end - dir * (_scale * 0.48);
      canvas.drawLine(from, to, paint);
      if (i == points.length - 2) _drawArrowHead(canvas, to, delta, color);
    }
  }

  void _drawArrowHead(Canvas canvas, Offset tip, Offset delta, Color color) {
    final angle = math.atan2(delta.dy, delta.dx);
    final head = _scale * 0.24;
    final path = Path()
      ..moveTo(tip.dx, tip.dy)
      ..lineTo(
        tip.dx - head * math.cos(angle - 0.45),
        tip.dy - head * math.sin(angle - 0.45),
      )
      ..lineTo(
        tip.dx - head * math.cos(angle + 0.45),
        tip.dy - head * math.sin(angle + 0.45),
      )
      ..close();
    canvas.drawPath(path, Paint()..color = color);
  }

  void _drawPieces(Canvas canvas, List<int> cells, MoveAnimation? anim) {
    if (anim == null) {
      _ensurePieces();
      final layer = _piecesLayer;
      if (layer != null) {
        canvas.drawPicture(layer);
        return;
      }
    }
    final hiddenHole = anim?.move.to;
    for (var hole = 0; hole < cells.length; hole++) {
      final seat = cells[hole];
      if (seat < 0 || hole == hiddenHole) continue;
      _drawPiece(canvas, _point(hole), seat);
    }
    if (anim == null) return;
    final position = _animPosition(anim);
    final lift = _animLift(anim);
    _drawPiece(canvas, position - Offset(0, lift), cells[anim.move.to]);
  }

  /// 局面静止时把全部棋子录成一张 Picture。
  ///
  /// 缓存键只需覆盖「棋盘对象 + 着法数 + 尺寸 + 配色」：实时对局每走一手
  /// 着法数都会增加，悔棋与复盘回退会换掉棋盘对象，因此不会读到旧局面。
  void _ensurePieces() {
    final board = source.board;
    final scale = _scale;
    if (_piecesLayer != null &&
        identical(_piecesBoard, board) &&
        _piecesHistory == source.history.length &&
        (_piecesScale - scale).abs() < 0.001 &&
        _piecesTheme == theme.value) {
      return;
    }
    _disposePieces();
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final cells = board.cells;
    for (var hole = 0; hole < cells.length; hole++) {
      final seat = cells[hole];
      if (seat < 0) continue;
      _drawPiece(canvas, _point(hole), seat);
    }
    _piecesLayer = recorder.endRecording();
    _piecesBoard = board;
    _piecesHistory = source.history.length;
    _piecesTheme = theme.value;
    _piecesScale = scale;
    _piecesBuilds++;
  }

  Offset _animPosition(MoveAnimation anim) {
    final path = anim.move.path;
    final segments = path.length - 1;
    final scaled = anim.progress * segments;
    final index = math.min(segments - 1, scaled.floor());
    final local = _ease(scaled - index);
    final from = _point(path[index]);
    final to = _point(path[index + 1]);
    return Offset.lerp(from, to, local)!;
  }

  double _animLift(MoveAnimation anim) {
    if (!anim.move.jump) return 0;
    final path = anim.move.path;
    final segments = path.length - 1;
    final scaled = anim.progress * segments;
    final local = scaled - scaled.floor();
    return math.sin(local * math.pi) * _scale * 0.30;
  }

  double _ease(double t) => t * t * (3 - 2 * t);

  void _drawPiece(Canvas canvas, Offset center, int seat) {
    final sprite = _pieceSprite(seat);
    final box = _scale * 1.4;
    canvas.save();
    canvas.translate(center.dx - box / 2, center.dy - box / 2);
    canvas.drawPicture(sprite);
    canvas.restore();
  }

  /// 单枚棋子录成小图，动画期间只做平移缩放。
  ui.Picture _pieceSprite(int seat) {
    final cached = _sprites[seat];
    if (cached != null) return cached;
    final style = playerStyleOf(seat);
    const box = 1.4;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.scale(_scale);
    const center = Offset(box / 2, box / 2);
    const radius = _pieceRadius;

    canvas.drawCircle(
      const Offset(0.7, 0.75),
      radius * 1.02,
      Paint()
        ..color = Colors.black.withValues(alpha: 0.34)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 0.07),
    );
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..shader = ui.Gradient.linear(
          center + const Offset(-radius * 0.55, -radius * 0.65),
          center + const Offset(radius * 0.55, radius * 0.7),
          [style.light, style.main, style.dark],
          [0, 0.52, 1],
        ),
    );
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.045
        ..color = style.dark,
    );
    canvas.drawCircle(
      center,
      radius * 0.62,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.022
        ..color = Colors.white.withValues(alpha: 0.22),
    );
    canvas.drawOval(
      Rect.fromCenter(
        center: center + const Offset(-radius * 0.30, -radius * 0.34),
        width: radius * 0.66,
        height: radius * 0.40,
      ),
      Paint()..color = Colors.white.withValues(alpha: 0.30),
    );
    canvas.drawCircle(
      center + const Offset(-radius * 0.12, -radius * 0.16),
      radius * 0.10,
      Paint()..color = Colors.white.withValues(alpha: 0.40),
    );

    final picture = recorder.endRecording();
    _sprites[seat] = picture;
    return picture;
  }

  @override
  void onTapDown(TapDownEvent event) {
    if (_scale <= 0) return;
    final raw = Offset(event.localPosition.x, event.localPosition.y) - _origin;
    final cos = math.cos(-_rotation);
    final sin = math.sin(-_rotation);
    final local = Offset(
      raw.dx * cos - raw.dy * sin,
      raw.dx * sin + raw.dy * cos,
    );
    var best = -1;
    var bestDistance = double.infinity;
    for (final hole in _geometry.holes) {
      final delta = _point(hole.index) - local;
      final distance = delta.distance;
      if (distance < bestDistance) {
        bestDistance = distance;
        best = hole.index;
      }
    }
    if (best < 0 || bestDistance > _scale * 0.62) return;
    final before = source.history.length;
    final selectedBefore = source.selectedHole;
    source.tapHole(best);
    if (source.history.length == before &&
        source.selectedHole != selectedBefore &&
        source.selectedHole != null) {
      SoundService.play(GameSound.select);
    }
  }

  @visibleForTesting
  double get boardScale => _scale;

  /// 棋子层重新录制的次数，用于验证静止帧复用了缓存。
  @visibleForTesting
  int get pieceLayerBuilds => _piecesBuilds;

  /// 当前是否需要持续刷新：走子动画或选中棋子的呼吸高亮。
  bool get wantsFrames => _animator.isAnimating || source.selectedHole != null;

  @visibleForTesting
  bool get isAnimating => _animator.isAnimating;

  /// 当前是否处于走子前的预高亮阶段。
  @visibleForTesting
  bool get isPreviewing => _animator.current?.previewing ?? false;

  /// 预高亮阶段被点亮的起点孔位，没有预高亮时为 null。
  @visibleForTesting
  int? get previewHole {
    final anim = _animator.current;
    return anim != null && anim.previewing ? anim.move.from : null;
  }

  @visibleForTesting
  int get pendingAnimations => _animator.pending;
}
