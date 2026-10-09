import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Yapay Ufuk (Attitude Director Indicator) CustomPainter.
///
/// Gyro verisinden pitch/roll → Canvas transform.
/// Gökyüzü (mavi) / Yer (kahve) gradient.
/// Pitch ladder çizgileri (-90° to +90°).
class ArtificialHorizonPainter extends CustomPainter {
  /// Pitch açısı (derece, negatif = burun yukarı)
  final double pitchDeg;

  /// Roll açısı (derece, pozitif = sağa yatık)
  final double rollDeg;

  const ArtificialHorizonPainter({
    required this.pitchDeg,
    required this.rollDeg,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final radius = math.min(cx, cy);

    // Daire maskesi (clip)
    canvas.save();
    canvas.clipRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(cx, cy), width: radius * 2, height: radius * 2),
        Radius.circular(radius),
      ),
    );

    // Roll rotasyonu
    canvas.translate(cx, cy);
    canvas.rotate(-rollDeg * math.pi / 180);
    canvas.translate(-cx, -cy);

    // Pitch ofseti (piksel cinsinden — 1° ≈ radius / 45)
    final pitchOffset = pitchDeg * (radius / 45);

    // ── Gökyüzü (Mavi) ──
    final skyPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.center,
        colors: [Color(0xFF1565C0), Color(0xFF42A5F5)],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawRect(
      Rect.fromLTWH(
        -radius,
        -radius + cy + pitchOffset - radius * 2,
        size.width + radius * 2,
        radius * 2,
      ),
      skyPaint,
    );

    // ── Yer (Kahverengi) ──
    final groundPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.center,
        end: Alignment.bottomCenter,
        colors: [Color(0xFF795548), Color(0xFF4E342E)],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawRect(
      Rect.fromLTWH(
        -radius,
        cy + pitchOffset,
        size.width + radius * 2,
        radius * 2,
      ),
      groundPaint,
    );

    // ── Ufuk Çizgisi ──
    final horizonPaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 2;
    canvas.drawLine(
      Offset(-radius, cy + pitchOffset),
      Offset(size.width + radius, cy + pitchOffset),
      horizonPaint,
    );

    // ── Pitch Ladder ──
    final ladderPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.7)
      ..strokeWidth = 1;
    final textStyle = TextStyle(
      color: Colors.white.withValues(alpha: 0.7),
      fontSize: 10,
      fontFamily: 'monospace',
    );

    for (int deg = -80; deg <= 80; deg += 10) {
      if (deg == 0) continue;
      final y = cy + pitchOffset - deg * (radius / 45);
      final lineWidth = deg % 20 == 0 ? radius * 0.5 : radius * 0.25;

      // Çizgi segmentleri (ortadan kesilmiş)
      canvas.drawLine(
        Offset(cx - lineWidth, y),
        Offset(cx - lineWidth * 0.3, y),
        ladderPaint,
      );
      canvas.drawLine(
        Offset(cx + lineWidth * 0.3, y),
        Offset(cx + lineWidth, y),
        ladderPaint,
      );

      // Derece etiketi (yalnızca 20° aralıkları)
      if (deg % 20 == 0) {
        final tp = TextPainter(
          text: TextSpan(text: '${deg.abs()}', style: textStyle),
          textDirection: TextDirection.ltr,
        )..layout();
        tp.paint(canvas, Offset(cx + lineWidth + 4, y - tp.height / 2));
        tp.paint(canvas, Offset(cx - lineWidth - tp.width - 4, y - tp.height / 2));
      }
    }

    canvas.restore();

    // ── Sabit Uçak Sembolü (Orta) ──
    final symbolPaint = Paint()
      ..color = const Color(0xFFFFEB3B)
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    // Sol kanat
    canvas.drawLine(
      Offset(cx - radius * 0.35, cy),
      Offset(cx - radius * 0.12, cy),
      symbolPaint,
    );
    // Sağ kanat
    canvas.drawLine(
      Offset(cx + radius * 0.12, cy),
      Offset(cx + radius * 0.35, cy),
      symbolPaint,
    );
    // Merkez nokta
    canvas.drawCircle(Offset(cx, cy), 4, symbolPaint);

    // ── Roll Göstergesi (Üst Arc) ──
    final rollArcPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.5)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    canvas.drawArc(
      Rect.fromCenter(center: Offset(cx, cy), width: radius * 1.85, height: radius * 1.85),
      -math.pi * 0.85,
      math.pi * 0.7,
      false,
      rollArcPaint,
    );

    // Roll üçgeni
    final trianglePaint = Paint()
      ..color = const Color(0xFFFFEB3B)
      ..style = PaintingStyle.fill;
    final triPath = Path()
      ..moveTo(cx, cy - radius * 0.95)
      ..lineTo(cx - 6, cy - radius * 0.88)
      ..lineTo(cx + 6, cy - radius * 0.88)
      ..close();
    canvas.save();
    canvas.translate(cx, cy);
    canvas.rotate(-rollDeg * math.pi / 180);
    canvas.translate(-cx, -cy);
    canvas.drawPath(triPath, trianglePaint);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant ArtificialHorizonPainter old) =>
      old.pitchDeg != pitchDeg || old.rollDeg != rollDeg;
}
