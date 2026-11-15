import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';

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

/// 单枚棋子贴图的方框（单位：孔距），比绘制方框略大，旋转后阴影不会被裁掉。
const double _spriteBox = 1.6;

/// Flame 棋盘组件：绘制六角星棋盘、棋子、可走提示与走子动画，并处理点击。
class BoardComponent extends PositionComponent with TapCallbacks {
  BoardComponent({required this.source, required this.theme, required this.showHints});

  final BoardSource source;
  final ValueListenable<BoardTheme> theme;
  final bool showHints;

  /// 选中呼吸高亮的持续秒数：之后保持静态，空闲时不再满帧重绘。
  static const double selectionPulseSeconds = 3.0;

  /// 单张贴图的最大像素数；更大的窗口退回 Picture 重放，避免分配超大纹理。
  static const int maxRasterPixels = 8 * 1024 * 1024;

  double _scale = 0;

  /// 当前渲染的物理像素比例：贴图按物理像素光栅化，绘制时保持 1:1。
  double _pixelRatio = 1;
  Offset _origin = Offset.zero;
  late final double _rotation = _rotationForHome();
  late final double _cosRotation = math.cos(_rotation);
  late final double _sinRotation = math.sin(_rotation);
  int _seenHistory = 0;
  late final double _leadIn =
      source.animationLeadIn.inMicroseconds / Duration.microsecondsPerSecond;
  late CheckersBoard _mirror;
  final MoveAnimator _animator = MoveAnimator();
  double _time = 0;
  int? _pulseHole;
  double _pulseStart = 0;

  /// 底板按「孔距 = 1」的模型坐标录制，窗口尺寸变化只需换一个矩阵。
  ui.Picture? _boardLayer;
  int _boardBuilds = 0;

  /// 底板贴图：重放 Picture 每帧都要重新光栅化 121 个渐变孔位与底板柔光，
  /// 换成贴图后每帧只剩一次 1:1 的矩形绘制。窗口还在连续缩放时先继续重放
  /// Picture，等同一尺寸出现两帧再升级成贴图，避免拖动窗口时每帧新建纹理。
  ui.Image? _boardImage;
  double _boardImageScale = 0;
  double? _boardPendingScale;
  int _boardRasters = 0;

  /// 棋子原型与贴图：整盘棋子改为逐枚画小贴图，不再录整盘棋子层与动画层；
  /// 窗口缩放只重做最多 6 张小图，走子动画每帧只补画移动中的那一枚。
  final Map<int, ui.Picture> _spritePictures = {};
  final Map<int, ui.Image> _sprites = {};
  double _spritePixels = 0;
  int _spriteRasters = 0;

  final Paint _boardPaint = Paint()..filterQuality = FilterQuality.none;
  final Paint _spritePaint = Paint()..filterQuality = FilterQuality.none;

  BoardGeometry get _geometry => source.geometry;

  @override
  Future<void> onLoad() async {
    _mirror = source.board.copy();
    _seenHistory = source.history.length;
    _pulseHole = source.selectedHole;
    theme.addListener(_invalidate);
  }

  @override
  void onRemove() {
    theme.removeListener(_invalidate);
    _animator.clear();
    _disposeBoardLayer();
    _disposeSpriteImages();
    for (final picture in _spritePictures.values) {
      picture.dispose();
    }
    _spritePictures.clear();
    super.onRemove();
  }

  void _invalidate() {
    // 棋子贴图只跟座位配色有关，换棋盘配色不必重做。
    _disposeBoardLayer();
  }

  void _disposeBoardLayer() {
    _boardLayer?.dispose();
    _boardLayer = null;
    _disposeBoardImage();
  }

  void _disposeBoardImage() {
    _boardImage?.dispose();
    _boardImage = null;
    _boardImageScale = 0;
    _boardPendingScale = null;
  }

  void _disposeSpriteImages() {
    for (final image in _sprites.values) {
      image.dispose();
    }
    _sprites.clear();
  }

  @override
  void update(double dt) {
    super.update(dt);
    _time += dt;
    _trackSelection();
    _syncHistory();
    _animator.advance(dt);
  }

  /// 记住本次选子从哪一刻开始：呼吸高亮只持续 [selectionPulseSeconds]。
  void _trackSelection() {
    final hole = source.selectedHole;
    if (hole == _pulseHole) return;
    _pulseHole = hole;
    _pulseStart = _time;
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
    final scale = math.min(size.x / (_contentHalfWidth * 2), size.y / (_contentHalfHeight * 2));
    if (scale <= 0) return;
    _scale = scale;
    _pixelRatio = ui.PlatformDispatcher.instance.implicitView?.devicePixelRatio ?? 1;
    _origin = Offset(size.x / 2, size.y / 2);
    _ensureLayers();

    final anim = _animator.current;
    final cells = anim?.cells ?? source.board.cells;
    _drawBoard(canvas);
    if (anim == null) {
      _inModelSpace(canvas, () {
        _drawSelection(canvas, cells);
        _drawTargets(canvas);
        _drawHint(canvas);
      });
    } else if (anim.previewing) {
      _inModelSpace(canvas, () => _drawCue(canvas, anim));
    }
    _drawPieces(canvas, cells, anim);
  }

  /// 在「孔距 = 1」的模型坐标里绘制，静态贴图与矢量提示共用同一套孔位。
  void _inModelSpace(Canvas canvas, VoidCallback draw) {
    canvas
      ..save()
      ..translate(_origin.dx, _origin.dy)
      ..rotate(_rotation)
      ..scale(_scale);
    draw();
    canvas.restore();
  }

  /// 把模型坐标录制的 Picture 光栅化成贴图。
  ///
  /// [transform] 负责把模型坐标摆进贴图像素坐标（含棋盘旋转），之后按 1:1
  /// 绘制时与直接重放 Picture 的画面一致。
  ui.Image _rasterize(
    ui.Picture picture,
    int width,
    int height,
    void Function(Canvas canvas) transform,
  ) {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    transform(canvas);
    canvas.drawPicture(picture);
    final wrapper = recorder.endRecording();
    final image = wrapper.toImageSync(width, height);
    wrapper.dispose();
    return image;
  }

  void _drawBoard(Canvas canvas) {
    final layer = _boardLayer;
    if (layer == null) return;
    final image = _boardRaster();
    if (image == null) {
      _inModelSpace(canvas, () => canvas.drawPicture(layer));
      return;
    }
    _blit(canvas, image, _origin, _boardPaint);
  }

  /// 按物理像素 1:1 画出贴图：贴图按当前像素尺寸光栅化，不能再被缩放。
  void _blit(Canvas canvas, ui.Image image, Offset center, Paint paint) {
    canvas.drawImageRect(
      image,
      Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
      Rect.fromCenter(
        center: center,
        width: image.width / _pixelRatio,
        height: image.height / _pixelRatio,
      ),
      paint,
    );
  }

  /// 底板贴图：尺寸不变时一直复用，尺寸还在连续变化时先重放 Picture。
  ui.Image? _boardRaster() {
    final layer = _boardLayer;
    if (layer == null) return null;
    final pixelScale = _scale * _pixelRatio;
    final cached = _boardImage;
    if (cached != null) {
      if (_boardImageScale == pixelScale) return cached;
      _disposeBoardImage();
    }
    final width = (_origin.dx * 2 * _pixelRatio).round();
    final height = (_origin.dy * 2 * _pixelRatio).round();
    if (width <= 0 || height <= 0 || width * height > maxRasterPixels) {
      return null;
    }
    // 拖动窗口缩放时尺寸每帧都变，先用 Picture 顶上；同一尺寸出现两帧再光栅化。
    if (_boardPendingScale != pixelScale) {
      _boardPendingScale = pixelScale;
      return null;
    }
    _boardPendingScale = null;
    final image = _rasterize(layer, width, height, (canvas) {
      canvas
        ..translate(width / 2, height / 2)
        ..rotate(_rotation)
        ..scale(pixelScale);
    });
    _boardImage = image;
    _boardImageScale = pixelScale;
    _boardRasters++;
    return image;
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

  /// 孔位在模型坐标中的位置，绘制时由画布统一缩放。
  Offset _point(int hole) {
    final h = _geometry.holes[hole];
    return Offset(h.x, h.y);
  }

  /// 底板、营地底色与孔位不随对局变化，按模型坐标缓存为一张图片。
  void _ensureLayers() {
    if (_boardLayer != null) return;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    _paintPlate(canvas);
    _paintCamps(canvas);
    _paintHoles(canvas);
    _boardLayer = recorder.endRecording();
    _boardBuilds++;
  }

  void _paintPlate(Canvas canvas) {
    final palette = theme.value;
    final path = Path();
    path.addPolygon(<Offset>[
      for (final p in BoardGeometry.starOutline()) Offset(p[0], p[1]),
    ], true);

    canvas.drawPath(
      path.shift(const Offset(0, 0.16)),
      Paint()
        ..color = Colors.black.withValues(alpha: 0.22)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 0.32),
    );

    canvas.drawPath(
      path,
      Paint()
        ..shader = ui.Gradient.linear(const Offset(0, -7), const Offset(0, 7), [
          palette.plateTop,
          palette.plateBottom,
        ]),
    );
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.06
        ..color = palette.plateEdge,
    );
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.14
        ..color = Colors.white.withValues(alpha: 0.06),
    );
    // 顶部一抹柔光，让深色底板不至于发闷。
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(0, -4.4), width: 12, height: 5.4),
      Paint()
        ..shader = ui.Gradient.radial(const Offset(0, -4.4), 6, [
          Colors.white.withValues(alpha: 0.10),
          Colors.white.withValues(alpha: 0),
        ]),
    );
  }

  void _paintCamps(Canvas canvas) {
    for (var seat = 0; seat < source.players; seat++) {
      final color = playerStyleOf(seat).main;
      final arm = source.setup.seatArms[seat];
      for (final hole in _geometry.armHoles[arm]) {
        canvas.drawCircle(_point(hole), 0.78, Paint()..color = color.withValues(alpha: 0.16));
      }
      // 对面营地用空心圆标注目标，与自家营地实心色块区分。
      final goal = source.setup.targetArmOf(seat);
      final tip = _geometry.tipHole(goal);
      canvas.drawCircle(
        _point(tip),
        0.52,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.055
          ..color = color.withValues(alpha: 0.85),
      );
    }
  }

  void _paintHoles(Canvas canvas) {
    final palette = theme.value;
    for (final hole in _geometry.holes) {
      final center = _point(hole.index);
      const radius = _holeRadius;
      canvas.drawCircle(
        center + const Offset(0, 0.035),
        radius,
        Paint()..color = Colors.black.withValues(alpha: 0.20),
      );
      canvas.drawCircle(
        center,
        radius,
        Paint()
          ..shader = ui.Gradient.radial(
            center + const Offset(-radius * 0.3, -radius * 0.35),
            radius * 1.5,
            [palette.holeFill, palette.holeInner],
          ),
      );
      canvas.drawCircle(
        center,
        radius,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.018
          ..color = palette.holeEdge.withValues(alpha: 0.9),
      );
    }
  }

  void _drawSelection(Canvas canvas, List<int> cells) {
    final hole = source.selectedHole;
    if (hole == null || cells[hole] < 0) return;
    final center = _point(hole);
    final style = playerStyleOf(cells[hole]);
    const radius = 0.47;
    canvas.drawCircle(
      center,
      radius + 0.05,
      Paint()
        ..color = Colors.black.withValues(alpha: 0.35)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.13,
    );
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = style.light
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.07,
    );
    final pulse = 0.5 + 0.5 * math.sin(_time * 3.4);
    final elapsed = _pulseHole == hole ? _time - _pulseStart : 0.0;
    final settle = 1 - (elapsed / selectionPulseSeconds).clamp(0.0, 1.0);
    canvas.drawCircle(
      center,
      radius + 0.06 + pulse * 0.03 * settle,
      Paint()..color = style.light.withValues(alpha: 0.18 + pulse * settle * 0.12),
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
    final lead = anim.leadIn <= 0 ? 1.0 : (anim.elapsed / anim.leadIn).clamp(0.0, 1.0);
    final pulse = 0.5 - 0.5 * math.cos(lead * math.pi * 2.4);
    canvas.drawCircle(
      center,
      0.44,
      Paint()..color = style.light.withValues(alpha: 0.16 + 0.14 * pulse),
    );
    canvas.drawCircle(
      center,
      0.5 + 0.12 * pulse,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.07
        ..color = style.light.withValues(alpha: 0.9),
    );
    canvas.drawCircle(
      center,
      0.58 + 0.2 * pulse,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.03
        ..color = style.light.withValues(alpha: 0.5 * (1 - pulse)),
    );
  }

  /// 可落点：单步画小圆点，连跳落点画双环，方便区分。
  void _drawTargets(Canvas canvas) {
    if (!showHints) return;
    // 每帧只取一次快照，避免重复复制可落点表。
    final targets = source.targets;
    if (targets.isEmpty) return;
    for (final entry in targets.entries) {
      final center = _point(entry.key);
      final jump = entry.value.jumpCount > 0;
      if (jump) {
        canvas.drawCircle(
          center,
          0.37,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 0.045
            ..color = Colors.white.withValues(alpha: 0.65),
        );
        canvas.drawCircle(center, 0.12, Paint()..color = Colors.white.withValues(alpha: 0.85));
      } else {
        canvas.drawCircle(center, 0.13, Paint()..color = Colors.white.withValues(alpha: 0.72));
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
      ..strokeWidth = 0.055
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final path = hint.path;
    final points = [for (final hole in path) _point(hole)];
    if (points.length < 2) return;

    canvas.drawCircle(
      points.first,
      0.5,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.05
        ..color = color.withValues(alpha: 0.9),
    );

    for (var i = 0; i < points.length - 1; i++) {
      final start = points[i];
      final end = points[i + 1];
      final delta = end - start;
      final length = delta.distance;
      if (length < 0.1) continue;
      final dir = delta / length;
      final from = start + dir * 0.48;
      final to = end - dir * 0.48;
      canvas.drawLine(from, to, paint);
      if (i == points.length - 2) _drawArrowHead(canvas, to, delta, color);
    }
  }

  void _drawArrowHead(Canvas canvas, Offset tip, Offset delta, Color color) {
    final angle = math.atan2(delta.dy, delta.dx);
    const head = 0.24;
    final path = Path()
      ..moveTo(tip.dx, tip.dy)
      ..lineTo(tip.dx - head * math.cos(angle - 0.45), tip.dy - head * math.sin(angle - 0.45))
      ..lineTo(tip.dx - head * math.cos(angle + 0.45), tip.dy - head * math.sin(angle + 0.45))
      ..close();
    canvas.drawPath(path, Paint()..color = color);
  }

  /// 棋子一律画小贴图：静止时逐枚贴图，动画期间跳过移动中的那一枚再补画。
  ///
  /// 贴图已把棋盘旋转烘进图像，因此按组件坐标 1:1 绘制，
  /// 不再是「整盘录成一层 Picture 每帧重放」。
  void _drawPieces(Canvas canvas, List<int> cells, MoveAnimation? anim) {
    final moving = anim?.move.to;
    for (var hole = 0; hole < cells.length; hole++) {
      final seat = cells[hole];
      if (seat < 0 || hole == moving) continue;
      _drawPiece(canvas, _toScreen(_point(hole)), seat);
    }
    if (anim == null) return;
    final position = _animPosition(anim) - Offset(0, _animLift(anim));
    _drawPiece(canvas, _toScreen(position), cells[moving!]);
  }

  /// 模型坐标 → 组件内坐标（含旋转与缩放）。
  Offset _toScreen(Offset model) {
    return _origin +
        Offset(
          (model.dx * _cosRotation - model.dy * _sinRotation) * _scale,
          (model.dx * _sinRotation + model.dy * _cosRotation) * _scale,
        );
  }

  Offset _animPosition(MoveAnimation anim) {
    final path = anim.path;
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
    final path = anim.path;
    final segments = path.length - 1;
    final scaled = anim.progress * segments;
    final local = scaled - scaled.floor();
    return math.sin(local * math.pi) * 0.30;
  }

  double _ease(double t) => t * t * (3 - 2 * t);

  void _drawPiece(Canvas canvas, Offset center, int seat) {
    _blit(canvas, _pieceRaster(seat), center, _spritePaint);
  }

  /// 单枚棋子的贴图：按像素边长缓存，窗口缩放只重做这几张小图。
  ui.Image _pieceRaster(int seat) {
    final pixels = math.max(8, (_spriteBox * _scale * _pixelRatio).round());
    if (pixels != _spritePixels) {
      _spritePixels = pixels.toDouble();
      _disposeSpriteImages();
    }
    final cached = _sprites[seat];
    if (cached != null) return cached;
    final picture = _spritePictures[seat] ??= _recordSprite(seat);
    final image = _rasterize(picture, pixels, pixels, (canvas) {
      canvas
        ..translate(pixels / 2, pixels / 2)
        ..rotate(_rotation)
        ..scale(pixels / _spriteBox);
    });
    _sprites[seat] = image;
    _spriteRasters++;
    return image;
  }

  /// 棋子原型按「孔距 = 1」、以原点为中心录制，旋转与缩放交给贴图。
  ui.Picture _recordSprite(int seat) {
    final style = playerStyleOf(seat);
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    const center = Offset.zero;
    const radius = _pieceRadius;

    canvas.drawCircle(
      center + const Offset(0, 0.05),
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

    return recorder.endRecording();
  }

  @override
  void onTapDown(TapDownEvent event) {
    if (_scale <= 0) return;
    final raw = Offset(event.localPosition.x, event.localPosition.y) - _origin;
    final cos = math.cos(-_rotation);
    final sin = math.sin(-_rotation);
    // 换算到「孔距 = 1」的模型坐标，与绘制共用同一套孔位。
    final local = Offset(raw.dx * cos - raw.dy * sin, raw.dx * sin + raw.dy * cos) / _scale;
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
    if (best < 0 || bestDistance > 0.62) return;
    final before = source.history.length;
    final selectedBefore = source.selectedHole;
    source.tapHole(best);
    if (source.history.length == before &&
        source.selectedHole != selectedBefore &&
        source.selectedHole != null) {
      SoundService.play(GameSound.select);
    }
  }

  /// 底板层重新录制的次数，用于验证窗口缩放复用了模型坐标缓存。
  @visibleForTesting
  int get boardLayerBuilds => _boardBuilds;

  /// 底板光栅化成贴图的次数，用于验证静止尺寸下每帧复用同一张纹理。
  @visibleForTesting
  int get boardRasters => _boardRasters;

  /// 棋子贴图光栅化的次数，用于验证整组棋子共用几张缓存贴图。
  @visibleForTesting
  int get spriteRasters => _spriteRasters;

  /// 当前是否已经用贴图绘制底板（而不是重放 Picture）。
  @visibleForTesting
  bool get boardRasterized => _boardImage != null;

  /// 当前是否需要持续刷新：走子动画，或选中棋子仍在呼吸高亮。
  ///
  /// 高亮淡出后不再请求帧，空闲检测才能停掉渲染循环。
  bool get wantsFrames {
    if (_animator.isAnimating) return true;
    final hole = source.selectedHole;
    if (hole == null) return false;
    // 刚选中的棋子还没经过 update，先按高亮起点计时。
    if (hole != _pulseHole) return true;
    return _time - _pulseStart < selectionPulseSeconds;
  }

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
