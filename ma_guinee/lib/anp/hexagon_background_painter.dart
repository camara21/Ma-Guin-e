import 'package:flutter/material.dart';
import 'dart:math' as math;

/// ===============================================================
///   HEXAGON BACKGROUND PAINTER
///   Motif hexagonal holographique (fond animé style ANP)
/// ===============================================================
class HexagonBackgroundPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.blue.withOpacity(0.10)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;

    const double hexSize = 22; // rayon hexagone
    final double w = size.width;
    final double h = size.height;

    // Décalage entre les hexagones
    final double horiz = hexSize * 1.5;
    final double vert = hexSize * 1.732; // √3 * r

    for (double y = 0; y < h + vert; y += vert) {
      for (double x = 0; x < w + horiz; x += horiz) {
        // Décalage une ligne sur deux
        final double dx = ((y ~/ vert) % 2 == 0) ? x : x + hexSize * 0.75;

        _drawHexagon(canvas, Offset(dx, y), hexSize, paint);
      }
    }
  }

  void _drawHexagon(Canvas c, Offset center, double r, Paint paint) {
    final Path path = Path();

    for (int i = 0; i < 6; i++) {
      final double angle = (i * 60) * math.pi / 180.0;
      final double px = center.dx + r * math.cos(angle);
      final double py = center.dy + r * math.sin(angle);

      if (i == 0) {
        path.moveTo(px, py);
      } else {
        path.lineTo(px, py);
      }
    }

    path.close();
    c.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// ===============================================================
///   SCAN RING PAINTER
///   Anneaux holographiques autour du bouton SCAN
/// ===============================================================
class ScanRingPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);

    // cercle externe
    final outer = Paint()
      ..color = Colors.white.withOpacity(0.7)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;

    canvas.drawCircle(center, 40, outer);

    // arcs lumineux
    final middle = Paint()
      ..color = Colors.cyanAccent.withOpacity(0.7)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    final rect = Rect.fromCircle(center: center, radius: 46);

    for (int i = 0; i < 4; i++) {
      final double start = (i * 90 + 10) * math.pi / 180;
      canvas.drawArc(rect, start, 0.70, false, middle);
    }

    // petit cercle intérieur
    final inner = Paint()
      ..color = Colors.white.withOpacity(0.35)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    canvas.drawCircle(center, 26, inner);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
