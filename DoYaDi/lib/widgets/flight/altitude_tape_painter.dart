import 'package:flutter/material.dart';

/// İrtifa Bandı (Altitude Tape) CustomPainter.
///
/// Uçuş MFD'deki dikey irtifa göstergesi.
/// Kayan şerit üzerinde irtifa değerleri (feet) gösterilir.
class AltitudeTapePainter extends CustomPainter {
  /// Mevcut irtifa (feet)
  final double altitudeFt;

  /// Gösterilecek irtifa aralığı (yarıçap)
  final double range;

  const AltitudeTapePainter({
    required this.altitudeFt,
    this.range = 500,
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

    final pixelsPerFt = h / (range * 2);

    // Gösterilecek irtifa aralığı
    final minAlt = ((altitudeFt - range) / 100).floor() * 100;
    final maxAlt = ((altitudeFt + range) / 100).ceil() * 100;

    for (int alt = minAlt; alt <= maxAlt; alt += 20) {
      if (alt < 0) continue;
      final y = cy - (alt - altitudeFt) * pixelsPerFt;

      if (y < -20 || y > h + 20) continue;

      if (alt % 100 == 0) {
        // Ana çizgi + sayı
        canvas.drawLine(Offset(w * 0.25, y), Offset(w * 0.5, y), linePaint);

        final tp = TextPainter(
          text: TextSpan(text: '$alt', style: textStyle),
          textDirection: TextDirection.ltr,
        )..layout();
        tp.paint(canvas, Offset(w - tp.width - 4, y - tp.height / 2));
      } else if (alt % 50 == 0) {
        // Ara çizgi
        canvas.drawLine(
          Offset(w * 0.25, y),
          Offset(w * 0.4, y),
          linePaint..color = Colors.white.withValues(alpha: 0.3),
        );
      }
    }

    // ── Mevcut irtifa kutusu ──
    final boxPaint = Paint()
      ..color = const Color(0xFF1A1A2E)
      ..style = PaintingStyle.fill;
    final boxBorder = Paint()
      ..color = const Color(0xFF00E676)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    final boxRect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset(w * 0.6, cy), width: w * 0.75, height: 28),
      const Radius.circular(4),
    );
    canvas.drawRRect(boxRect, boxPaint);
    canvas.drawRRect(boxRect, boxBorder);

    // İrtifa değeri
    final altText = TextPainter(
      text: TextSpan(
        text: altitudeFt.toStringAsFixed(0),
        style: const TextStyle(
          color: Color(0xFF00E676),
          fontSize: 15,
          fontWeight: FontWeight.bold,
          fontFamily: 'monospace',
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    altText.paint(
      canvas,
      Offset(w * 0.6 - altText.width / 2, cy - altText.height / 2),
    );

    // ── Sağ kenar çizgisi ──
    final edgePaint = Paint()
      ..color = const Color(0xFF00E676).withValues(alpha: 0.3)
      ..strokeWidth = 1;
    canvas.drawLine(Offset(w * 0.25, 0), Offset(w * 0.25, h), edgePaint);

    // ── Etiket ──
    final labelTp = TextPainter(
      text: TextSpan(
        text: 'FT',
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.4),
          fontSize: 9,
          letterSpacing: 1.5,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    labelTp.paint(canvas, Offset(w - labelTp.width - 4, h - labelTp.height - 4));
  }

  @override
  bool shouldRepaint(covariant AltitudeTapePainter old) =>
      old.altitudeFt != altitudeFt;
}
