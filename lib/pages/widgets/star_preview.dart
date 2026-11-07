import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

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

  @override
  void paint(Canvas canvas, Size size) {
    final scale = math.min(size.width / 14, size.height / 16);
    canvas
      ..save()
      ..translate(size.width / 2, size.height / 2);
    final path = Path()
      ..addPolygon([
        for (final p in BoardGeometry.starOutline())
          Offset(p[0] * scale, p[1] * scale),
      ], true);
    canvas.drawPath(
      path.shift(Offset(0, scale * 0.18)),
      Paint()
        ..color = Colors.black.withValues(alpha: 0.18)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, scale * 0.26),
    );
    canvas.drawPath(
      path,
      Paint()
        ..shader = ui.Gradient.linear(
          Offset(0, -scale * 7),
          Offset(0, scale * 7),
          [theme.plateTop, theme.plateBottom],
        ),
    );
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = scale * 0.06
        ..color = theme.plateEdge,
    );
    for (var arm = 0; arm < 6; arm++) {
      final color = playerStyleOf(arm).main.withValues(alpha: 0.20);
      for (final hole in _geometry.armHoles[arm]) {
        final point = _geometry.holes[hole];
        canvas.drawCircle(
          Offset(point.x * scale, point.y * scale),
          scale * 0.62,
          Paint()..color = color,
        );
      }
    }
    for (final hole in _geometry.holes) {
      canvas.drawCircle(
        Offset(hole.x * scale, hole.y * scale),
        scale * 0.36,
        Paint()..color = theme.holeFill.withValues(alpha: 0.92),
      );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_StarPreviewPainter oldDelegate) =>
      oldDelegate.theme.id != theme.id;
}
