import 'package:flutter/material.dart';

/// Hız Bandı (Speed Tape) CustomPainter.
///
/// Uçuş MFD'deki dikey hız göstergesi.
/// Kayan şerit üzerinde hız değerleri gösterilir.
class SpeedTapePainter extends CustomPainter {
  /// Mevcut hız (knots)
  final double speedKnots;

  /// Gösterilecek maks hız aralığı (yarıçap)
  final double range;

  const SpeedTapePainter({
    required this.speedKnots,
    this.range = 60,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final cy = h / 2;

    // ── Arka plan ──
    final bgPaint = Paint()..color = const Color(0xFF0A0A18);
    canvas.drawRect(Rect.fromLTWH(0, 0, w, h), bgPaint);

    // ── Kayan şerit ──
    final linePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.5)
      ..strokeWidth = 1;

    final textStyle = TextStyle(
      color: Colors.white.withValues(alpha: 0.8),
      fontSize: 11,
      fontFamily: 'monospace',
    );

    final pixelsPerKnot = h / (range * 2);

    // Gösterilecek hız aralığı
    final minSpeed = (speedKnots - range).floor();
    final maxSpeed = (speedKnots + range).ceil();

    for (int spd = minSpeed; spd <= maxSpeed; spd++) {
      if (spd < 0) continue;
      final y = cy - (spd - speedKnots) * pixelsPerKnot;

      if (y < -20 || y > h + 20) continue;

      if (spd % 10 == 0) {
        // Ana çizgi + sayı
        canvas.drawLine(Offset(w * 0.5, y), Offset(w * 0.75, y), linePaint);

        final tp = TextPainter(
          text: TextSpan(text: '$spd', style: textStyle),
          textDirection: TextDirection.ltr,
        )..layout();
        tp.paint(canvas, Offset(4, y - tp.height / 2));
      } else if (spd % 5 == 0) {
        // Ara çizgi
        canvas.drawLine(
          Offset(w * 0.6, y),
          Offset(w * 0.75, y),
          linePaint..color = Colors.white.withValues(alpha: 0.3),
        );
      }
    }

    // ── Mevcut hız kutusu ──
    final boxPaint = Paint()
      ..color = const Color(0xFF1A1A2E)
      ..style = PaintingStyle.fill;
    final boxBorder = Paint()
      ..color = const Color(0xFF40E0D0)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    final boxRect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset(w * 0.4, cy), width: w * 0.75, height: 28),
      const Radius.circular(4),
    );
    canvas.drawRRect(boxRect, boxPaint);
    canvas.drawRRect(boxRect, boxBorder);

    // Hız değeri
    final speedText = TextPainter(
      text: TextSpan(
        text: speedKnots.toStringAsFixed(0),
        style: const TextStyle(
          color: Color(0xFF40E0D0),
          fontSize: 15,
          fontWeight: FontWeight.bold,
          fontFamily: 'monospace',
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    speedText.paint(
      canvas,
      Offset(w * 0.4 - speedText.width / 2, cy - speedText.height / 2),
    );

    // ── Sol kenar çizgisi ──
    final edgePaint = Paint()
      ..color = const Color(0xFF40E0D0).withValues(alpha: 0.3)
      ..strokeWidth = 1;
    canvas.drawLine(Offset(w * 0.75, 0), Offset(w * 0.75, h), edgePaint);

    // ── Etiket ──
    final labelTp = TextPainter(
      text: TextSpan(
        text: 'KTS',
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.4),
          fontSize: 9,
          letterSpacing: 1.5,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    labelTp.paint(canvas, Offset(4, h - labelTp.height - 4));
  }

  @override
  bool shouldRepaint(covariant SpeedTapePainter old) =>
      old.speedKnots != speedKnots;
}
