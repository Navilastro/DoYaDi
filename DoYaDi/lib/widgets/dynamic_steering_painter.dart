import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Mod 6 için Dinamik Sabit Direksiyon CustomPainter.
/// Direksiyon kendi etrafında DÖNMEZ; cihaz eğildikçe simidin içi
/// dönüş yönüne göre sağa veya sola canlı renk dolgusu ile dolar.
/// 360° (1 tur) aşıldığında sağ veya solda tur sayacı (+1, +2...) görünür.
class DynamicSteeringWheelPainter extends CustomPainter {
  /// Direksiyon açı oranı: 0.0 (düz), >0 (sağa), <0 (sola).
  /// Örn: 1.0 = tam sağ eşik, 2.0 = 2 tur sağ.
  final double steeringRatio;

  /// Toplam direksiyon açısı (derece cinsinden, örn 180°, 540°, 900°)
  final double totalAngleDegrees;

  /// Sağa dönüş dolgu rengi
  final Color turnRightColor;

  /// Sola dönüş dolgu rengi
  final Color turnLeftColor;

  /// Arka plan / mat direksiyon rengi
  final Color baseColor;

  DynamicSteeringWheelPainter({
    required this.steeringRatio,
    required this.totalAngleDegrees,
    required this.turnRightColor,
    required this.turnLeftColor,
    this.baseColor = const Color(0xFF222234),
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2.2;
    final strokeWidth = radius * 0.22;

    // ── 1. Mat Gri Sabit Direksiyon Tabanı (Rim Base) ──
    final basePaint = Paint()
      ..color = baseColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, basePaint);

    // Dış ve İç İnce Çerçeve Halka Sınırları
    final borderPaint = Paint()
      ..color = Colors.white10
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    canvas.drawCircle(center, radius + strokeWidth / 2, borderPaint);
    canvas.drawCircle(center, radius - strokeWidth / 2, borderPaint);

    // ── 2. Direksiyon Göbeği ve Kolları (Spokes & Hub) ──
    final hubPaint = Paint()
      ..color = const Color(0xFF181826)
      ..style = PaintingStyle.fill;
    final hubBorderPaint = Paint()
      ..color = Colors.cyanAccent.withValues(alpha: 0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    final hubRadius = radius * 0.35;
    canvas.drawCircle(center, hubRadius, hubPaint);
    canvas.drawCircle(center, hubRadius, hubBorderPaint);

    // 3 Kollu Direksiyon Simidi Kolları (Sol, Sağ, Alt)
    final spokePaint = Paint()
      ..color = const Color(0xFF2C2C40)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth * 0.65
      ..strokeCap = StrokeCap.butt;

    // Sol kol (90° + 135° = 225°)
    final leftSpokeEnd = Offset(
      center.dx + (radius - strokeWidth / 2) * math.cos(math.pi * 0.9),
      center.dy + (radius - strokeWidth / 2) * math.sin(math.pi * 0.9),
    );
    canvas.drawLine(center, leftSpokeEnd, spokePaint);

    // Sağ kol
    final rightSpokeEnd = Offset(
      center.dx + (radius - strokeWidth / 2) * math.cos(math.pi * 0.1),
      center.dy + (radius - strokeWidth / 2) * math.sin(math.pi * 0.1),
    );
    canvas.drawLine(center, rightSpokeEnd, spokePaint);

    // Alt kol
    final bottomSpokeEnd = Offset(
      center.dx,
      center.dy + (radius - strokeWidth / 2),
    );
    canvas.drawLine(center, bottomSpokeEnd, spokePaint);

    // ── 3. Dinamik Renk Dolgusu (Arc Fill) ──
    final absRatio = steeringRatio.abs();
    if (absRatio > 0.01) {
      final isRight = steeringRatio > 0;
      final fillColor = isRight ? turnRightColor : turnLeftColor;

      // 1. tur dolgu açısı (0 ile 2*pi arası)
      double sweepAngle = (absRatio.clamp(0.0, 1.0)) * math.pi * 0.95;
      if (!isRight) sweepAngle = -sweepAngle;

      final fillPaint = Paint()
        ..color = fillColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth * 0.9
        ..strokeCap = StrokeCap.round;

      // Glow Efekti
      final glowPaint = Paint()
        ..color = fillColor.withValues(alpha: 0.4)
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth * 1.3
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);

      final rect = Rect.fromCircle(center: center, radius: radius);
      const startAngle = -math.pi / 2; // Top (12 o'clock)

      canvas.drawArc(rect, startAngle, sweepAngle, false, glowPaint);
      canvas.drawArc(rect, startAngle, sweepAngle, false, fillPaint);

      // Merkez Üst Çizgi (Center Stripe)
      final stripePaint = Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4.0;
      canvas.drawLine(
        Offset(center.dx, center.dy - radius - strokeWidth / 2),
        Offset(center.dx, center.dy - radius + strokeWidth / 2),
        stripePaint,
      );
    }

    // ── 4. Tur Sayacı (Turn Indicator: +1, +2...) ──
    final turns = (totalAngleDegrees.abs() / 360.0).floor();
    if (turns >= 1) {
      final isRight = steeringRatio > 0;
      final badgeColor = isRight ? turnRightColor : turnLeftColor;
      final text = '+$turns';

      final TextPainter tp = TextPainter(
        text: TextSpan(
          text: text,
          style: const TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();

      final badgeWidth = tp.width + 16;
      final badgeHeight = tp.height + 8;

      // Badge Konumu: Sağa dönüşte sağ tarafta, sola dönüşte sol tarafta
      final badgeX = isRight
          ? center.dx + radius + strokeWidth + 8
          : center.dx - radius - strokeWidth - badgeWidth - 8;
      final badgeY = center.dy - badgeHeight / 2;

      final badgeRect = RRect.fromRectAndRadius(
        Rect.fromLTWH(badgeX, badgeY, badgeWidth, badgeHeight),
        const Radius.circular(12),
      );

      // Glow arkası
      final badgeGlow = Paint()
        ..color = badgeColor.withValues(alpha: 0.5)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
      canvas.drawRRect(badgeRect, badgeGlow);

      // Gövde
      final badgeBg = Paint()..color = badgeColor;
      canvas.drawRRect(badgeRect, badgeBg);

      // Metin
      tp.paint(
        canvas,
        Offset(badgeX + 8, badgeY + 4),
      );
    }
  }

  @override
  bool shouldRepaint(covariant DynamicSteeringWheelPainter oldDelegate) {
    return oldDelegate.steeringRatio != steeringRatio ||
        oldDelegate.totalAngleDegrees != totalAngleDegrees ||
        oldDelegate.turnRightColor != turnRightColor ||
        oldDelegate.turnLeftColor != turnLeftColor ||
        oldDelegate.baseColor != baseColor;
  }
}
