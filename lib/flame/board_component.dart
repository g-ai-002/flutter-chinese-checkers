import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../game/board_geometry.dart';
import '../game/checkers_board.dart';
import '../game/checkers_controller.dart';
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
    required this.controller,
    required this.theme,
    required this.showHints,
  });

  final CheckersController controller;
  final ValueListenable<BoardTheme> theme;
  final bool showHints;

  double _scale = 0;
  Offset _origin = Offset.zero;
  double _rotation = 0;
  int _seenHistory = 0;
  late CheckersBoard _mirror;
  final MoveAnimator _animator = MoveAnimator();
  double _time = 0;

  double _cacheScale = 0;
  String _cacheKey = '';
  ui.Picture? _boardLayer;
  final Map<int, ui.Picture> _sprites = {};
  double _spriteScale = 0;

  BoardGeometry get _geometry => controller.geometry;

  @override
  Future<void> onLoad() async {
    _mirror = controller.board.copy();
    _seenHistory = controller.history.length;
    theme.addListener(_invalidate);
  }

  @override
  void onRemove() {
    theme.removeListener(_invalidate);
    _animator.clear();
    _disposeLayers();
    super.onRemove();
  }

  void _invalidate() {
    _cacheKey = '';
    _cacheScale = 0;
    _spriteScale = 0;
    for (final sprite in _sprites.values) {
      sprite.dispose();
    }
    _sprites.clear();
  }

  void _disposeLayers() {
    _boardLayer?.dispose();
    _boardLayer = null;
  }

  @override
  void update(double dt) {
    super.update(dt);
    _time += dt;
    _syncHistory();
    _animator.advance(dt);
  }

  /// 把控制器新增的着法逐手补进动画队列，每手保存走完后的局面快照。
  void _syncHistory() {
    final records = controller.history;
    if (records.length < _seenHistory) {
      _seenHistory = records.length;
      _mirror = controller.board.copy();
      _animator.clear();
      return;
    }
    if (records.length == _seenHistory) return;
    for (var i = _seenHistory; i < records.length; i++) {
      final move = records[i].move;
      _mirror.move(move.from, move.to);
      _animator.enqueue(move, _mirror.cells);
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
    final cells = anim?.cells ?? controller.board.cells;
    canvas.save();
    canvas.translate(_origin.dx, _origin.dy);
    canvas.rotate(_rotation);
    final layer = _boardLayer;
    if (layer != null) canvas.drawPicture(layer);
    if (anim == null) {
      _drawSelection(canvas, cells);
      _drawTargets(canvas);
      _drawHint(canvas);
    }
    _drawPieces(canvas, cells, anim);
    canvas.restore();
  }

  /// 人机对战把自己的营地转到棋盘正下方，前进方向朝上更符合直觉。
  double _rotationForHome() {
    if (controller.setup.mode != PlayMode.vsAi) return 0;
    final seat = controller.setup.humanSeat.clamp(0, controller.players - 1);
    final arm = controller.setup.seatArms[seat];
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
    final key = '${theme.value.id}-${controller.setup.seatArms.join(',')}';
    if (_boardLayer != null &&
        (_cacheScale - scale).abs() < 0.01 &&
        _cacheKey == key) {
      return;
    }
    _disposeLayers();
    _cacheScale = scale;
    _cacheKey = key;
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
    for (var seat = 0; seat < controller.players; seat++) {
      final color = playerStyleOf(seat).main;
      final arm = controller.setup.seatArms[seat];
      for (final hole in _geometry.armHoles[arm]) {
        canvas.drawCircle(
          _point(hole),
          scale * 0.78,
          Paint()..color = color.withValues(alpha: 0.16),
        );
      }
      // 对面营地用空心圆标注目标，与自家营地实心色块区分。
      final goal = controller.setup.targetArmOf(seat);
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
    final hole = controller.selectedHole;
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

  /// 可落点：单步画小圆点，连跳落点画双环，方便区分。
  void _drawTargets(Canvas canvas) {
    if (!showHints || controller.targetHoles.isEmpty) return;
    for (final entry in controller.targets.entries) {
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
    final hint = controller.hintMove;
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
    final before = controller.history.length;
    final selectedBefore = controller.selectedHole;
    controller.tapHole(best);
    if (controller.history.length == before &&
        controller.selectedHole != selectedBefore &&
        controller.selectedHole != null) {
      SoundService.play(GameSound.select);
    }
  }

  @visibleForTesting
  double get boardScale => _scale;
}
