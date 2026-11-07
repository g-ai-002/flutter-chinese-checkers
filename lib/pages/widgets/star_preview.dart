import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../game/board_geometry.dart';
import '../../game/checkers_board.dart';
import '../../theme/app_theme.dart';
import '../../theme/player_palette.dart';

class StarPreview extends StatelessWidget {
  const StarPreview({super.key, required this.theme, this.players = 6});

  final BoardTheme theme;
  final int players;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 14 / 16,
      child: CustomPaint(painter: _StarPreviewPainter(theme, players)),
    );
  }
}

class _StarPreviewPainter extends CustomPainter {
  _StarPreviewPainter(this.theme, this.players);

  final BoardTheme theme;
  final int players;

  static final BoardGeometry _geometry = BoardGeometry.star();
  static final Map<int, CheckersBoard> _boards = {};

  @override
  void paint(Canvas canvas, Size size) {
    final scale = math.min(size.width / 14, size.height / 16);
    if (scale <= 0) return;
    canvas.save();
    canvas.translate(size.width / 2, size.height / 2);
    _paintPlate(canvas, scale);
    _paintHoles(canvas, scale);
    _paintPieces(canvas, scale);
    canvas.restore();
  }

  void _paintPlate(Canvas canvas, double scale) {
    final path = Path()
      ..addPolygon(<Offset>[
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
  }

  void _paintHoles(Canvas canvas, double scale) {
    for (final hole in _geometry.holes) {
      final center = Offset(hole.x * scale, hole.y * scale);
      canvas.drawCircle(
        center,
        scale * 0.36,
        Paint()..color = theme.holeFill.withValues(alpha: 0.92),
      );
      canvas.drawCircle(
        center,
        scale * 0.36,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = scale * 0.02
          ..color = theme.holeEdge,
      );
    }
  }

  void _paintPieces(Canvas canvas, double scale) {
    final board = _boards.putIfAbsent(
      players,
      () => CheckersBoard.initial(
        _geometry,
        List<int>.generate(players, (seat) => seat),
      ),
    );
    for (var hole = 0; hole < board.length; hole++) {
      final seat = board.at(hole);
      if (seat < 0) continue;
      final center = Offset(
        _geometry.holes[hole].x * scale,
        _geometry.holes[hole].y * scale,
      );
      final style = playerStyleOf(seat);
      final radius = scale * 0.31;
      canvas.drawCircle(
        center + Offset(0, scale * 0.04),
        radius,
        Paint()
          ..color = Colors.black.withValues(alpha: 0.25)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, scale * 0.05),
      );
      canvas.drawCircle(
        center,
        radius,
        Paint()
          ..shader = ui.Gradient.linear(
            center + Offset(-radius * 0.6, -radius * 0.7),
            center + Offset(radius * 0.6, radius * 0.7),
            [style.light, style.main, style.dark],
            [0, 0.52, 1],
          ),
      );
      canvas.drawCircle(
        center,
        radius,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = scale * 0.035
          ..color = style.dark,
      );
      canvas.drawOval(
        Rect.fromCenter(
          center: center + Offset(-radius * 0.28, -radius * 0.34),
          width: radius * 0.62,
          height: radius * 0.36,
        ),
        Paint()..color = Colors.white.withValues(alpha: 0.28),
      );
    }
  }

  @override
  bool shouldRepaint(_StarPreviewPainter oldDelegate) =>
      oldDelegate.theme.id != theme.id || oldDelegate.players != players;
}
