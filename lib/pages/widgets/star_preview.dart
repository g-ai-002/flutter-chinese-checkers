import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:material_ui/material_ui.dart';

import '../../game/board_geometry.dart';
import '../../theme/app_theme.dart';
import '../../theme/player_palette.dart';

/// 首页装饰：用棋盘几何画一枚小型星形棋盘，随配色变化。
class StarPreview extends StatelessWidget {
  const StarPreview({super.key, required this.theme});

  final BoardTheme theme;

  @override
  Widget build(BuildContext context) => AspectRatio(
    aspectRatio: 14 / 16,
    child: CustomPaint(painter: _StarPreviewPainter(theme)),
  );
}

class _StarPreviewPainter extends CustomPainter {
  _StarPreviewPainter(this.theme);

  final BoardTheme theme;

  static final BoardGeometry _geometry = BoardGeometry.star();

  /// 预览图按孔距为 1 的模型坐标缓存，窗口缩放只需重设矩阵。
  ui.Picture? _picture;

  @override
  void paint(Canvas canvas, Size size) {
    final scale = math.min(size.width / 14, size.height / 16);
    canvas
      ..save()
      ..translate(size.width / 2, size.height / 2)
      ..scale(scale)
      ..drawPicture(_picture ??= _record())
      ..restore();
  }

  ui.Picture _record() {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final path = Path()
      ..addPolygon([for (final p in BoardGeometry.starOutline()) Offset(p[0], p[1])], true);
    canvas.drawPath(
      path.shift(const Offset(0, 0.18)),
      Paint()
        ..color = Colors.black.withValues(alpha: 0.18)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 0.26),
    );
    canvas.drawPath(
      path,
      Paint()
        ..shader = ui.Gradient.linear(const Offset(0, -7), const Offset(0, 7), [
          theme.plateTop,
          theme.plateBottom,
        ]),
    );
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.06
        ..color = theme.plateEdge,
    );
    for (var arm = 0; arm < 6; arm++) {
      final color = playerStyleOf(arm).main.withValues(alpha: 0.20);
      for (final hole in _geometry.armHoles[arm]) {
        canvas.drawCircle(_point(hole), 0.62, Paint()..color = color);
      }
    }
    for (final hole in _geometry.holes) {
      canvas.drawCircle(
        _point(hole.index),
        0.36,
        Paint()..color = theme.holeFill.withValues(alpha: 0.92),
      );
    }
    return recorder.endRecording();
  }

  Offset _point(int hole) {
    final h = _geometry.holes[hole];
    return Offset(h.x, h.y);
  }

  @override
  bool shouldRepaint(_StarPreviewPainter oldDelegate) => oldDelegate.theme.id != theme.id;
}
