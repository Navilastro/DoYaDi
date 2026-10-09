import 'package:flutter/material.dart';

/// Merkez Retikül (Crosshair) CustomPainter.
///
/// Uçuş stick ekranının merkezinde trim sıfırlama noktasını gösterir.
/// İç içe daireler ve artı işareti ile.
class CrosshairPainter extends CustomPainter {
  /// Retikül rengi
  final Color color;

  /// Mevcut pitch/roll sapması (-1.0 .. 1.0)
  final double offsetX;
  final double offsetY;

  const CrosshairPainter({
    this.color = const Color(0xFF40E0D0),
    this.offsetX = 0.0,
    this.offsetY = 0.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final radius = size.width < size.height ? size.width / 2 : size.height / 2;

    // ── Dış daire ──
    final outerPaint = Paint()
      ..color = color.withValues(alpha: 0.2)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    canvas.drawCircle(Offset(cx, cy), radius * 0.9, outerPaint);

    // ── Orta daire ──
    final midPaint = Paint()
      ..color = color.withValues(alpha: 0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    canvas.drawCircle(Offset(cx, cy), radius * 0.5, midPaint);

    // ── Artı çizgileri ──
    final crossPaint = Paint()
      ..color = color.withValues(alpha: 0.3)
      ..strokeWidth = 1;

    // Yatay çizgi (kesikli — merkezdeki boşluk)
    canvas.drawLine(
      Offset(cx - radius * 0.9, cy),
      Offset(cx - radius * 0.15, cy),
      crossPaint,
    );
    canvas.drawLine(
      Offset(cx + radius * 0.15, cy),
      Offset(cx + radius * 0.9, cy),
      crossPaint,
    );

    // Dikey çizgi
    canvas.drawLine(
      Offset(cx, cy - radius * 0.9),
      Offset(cx, cy - radius * 0.15),
      crossPaint,
    );
    canvas.drawLine(
      Offset(cx, cy + radius * 0.15),
      Offset(cx, cy + radius * 0.9),
      crossPaint,
    );

    // ── Sapma göstergesi ──
    final dotX = cx + offsetX * radius * 0.85;
    final dotY = cy + offsetY * radius * 0.85;
    final dotPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(dotX, dotY), 5, dotPaint);

    // Parlaklık
    final glowPaint = Paint()
      ..color = color.withValues(alpha: 0.3)
      ..maskFilter = const MaskFilter.blur(BlurStyle.outer, 6);
    canvas.drawCircle(Offset(dotX, dotY), 5, glowPaint);
  }

  @override
  bool shouldRepaint(covariant CrosshairPainter old) =>
      old.offsetX != offsetX || old.offsetY != offsetY || old.color != color;
}
