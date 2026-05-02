import 'dart:math' as math;
import 'package:flutter/material.dart';

// ─────────────────────────────────────────────
// PedalPainter — Gaz / Fren bar göstergesi
// ─────────────────────────────────────────────
class PedalPainter extends CustomPainter {
  final double fillPercentage; // 0.0 – 1.0
  final Color baseColor;       // Gaz: yeşil, Fren: kırmızı
  final Color bgColor;         // Koyu lacivert arka plan
  final Color yetsoreColor;    // %70+ geri bildirim rengi

  PedalPainter({
    required this.fillPercentage,
    required this.baseColor,
    required this.bgColor,
    required this.yetsoreColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // 1) Arka plan
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..color = bgColor,
    );

    if (fillPercentage <= 0.0) return;

    final double fillHeight = size.height * fillPercentage;
    final double yTop = size.height - fillHeight;

    // 2) Ana renk (gaz/fren)
    canvas.drawRect(
      Rect.fromLTWH(0, yTop, size.width, fillHeight),
      Paint()..color = baseColor,
    );

    // 3) Yetsore (sarı) — %70'ten itibaren lineer interpolasyon ile
    //    Max yükseklik: barın %20'si
    if (fillPercentage >= 0.7) {
      final double fraction = ((fillPercentage - 0.7) / 0.3).clamp(0.0, 1.0);
      final double yellowHeight = fraction * size.height * 0.20;
      if (yellowHeight > 0) {
        canvas.drawRect(
          Rect.fromLTWH(0, size.height - yellowHeight, size.width, yellowHeight),
          Paint()..color = yetsoreColor,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant PedalPainter old) =>
      old.fillPercentage != fillPercentage ||
      old.baseColor != baseColor ||
      old.bgColor != bgColor ||
      old.yetsoreColor != yetsoreColor;
}

// ─────────────────────────────────────────────
// SteeringPainter — Direksiyon göstergesi
// ─────────────────────────────────────────────
// Çizginin dönme noktası (pivot) ekranda görünen en alt-orta nokta.
// angle: -1.0 (tam sol) .. 0.0 (dik) .. +1.0 (tam sağ)
// Tam çevrildiğinde (|angle| ≈ 1) L şekli oluşur.
class SteeringPainter extends CustomPainter {
  final double angle;          // -1.0 .. 1.0
  final Color indicatorColor;
  final Color bgColor;
  /// Cihaz pitch açısı (derece). 0 = yatay, 90 = dik
  final double pitch;

  /// Görsel maksimum sapma açısı (radyan). ~75°
  static const double _maxAngle = 75.0 * math.pi / 180.0;

  /// L şeklinin yatay kolunun uzunluğu (pivot'tan itibaren, ekran genişliğine bağlı)
  static const double _lArmRatio = 0.15; // kutunun genişliğinin %15'i

  SteeringPainter({
    required this.angle,
    required this.indicatorColor,
    required this.bgColor,
    this.pitch = 0.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Arka plan çizilmeyecek
    // canvas.drawRect(
    //   Rect.fromLTWH(0, 0, size.width, size.height),
    //   Paint()..color = bgColor,
    // );

    final pivot = Offset(size.width / 2, size.height);
    // 3D derinlik efekti: cihaz öne eğilince çizgi uzar (gaz), geri çekilince kısalır (fren)
    final double depthScale = 1.0 + (pitch / 90.0).clamp(-0.5, 0.5);
    final double lineLength = size.height * 0.85 * depthScale;
    final double rotAngle = angle * _maxAngle;

    final paint = Paint()
      ..color = indicatorColor
      ..strokeWidth = 4.0
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    canvas.save();
    canvas.translate(pivot.dx, pivot.dy);
    canvas.rotate(rotAngle);

    // Ana dikey çizgi (yukarı doğru)
    canvas.drawLine(Offset.zero, Offset(0, -lineLength), paint);

    // L kolu: angle tam sağ veya tam sol'a yaklaştıkça belirginleşir
    final double lFraction = (angle.abs() - 0.7).clamp(0.0, 0.3) / 0.3;
    if (lFraction > 0) {
      final double lArmLen = size.width * _lArmRatio * lFraction;
      // Sağa döndüyse kol sola (negatif x), sola döndüyse sağa
      final double dir = angle >= 0 ? -1.0 : 1.0;
      canvas.drawLine(Offset.zero, Offset(dir * lArmLen, 0), paint);
    }

    canvas.restore();

    // Merkez nokta göstergesi (küçük daire)
    canvas.drawCircle(
      pivot,
      5.0,
      Paint()..color = indicatorColor,
    );
  }

  @override
  bool shouldRepaint(covariant SteeringPainter old) =>
      old.angle != angle ||
      old.pitch != pitch ||
      old.indicatorColor != indicatorColor ||
      old.bgColor != bgColor;
}

// ─────────────────────────────────────────────
// TapAreaPainter — Mod 2/3/4 tıklama alanları
// ─────────────────────────────────────────────
class TapAreaPainter extends CustomPainter {
  final bool isPressed;
  final Color baseColor;
  final String label;

  TapAreaPainter({
    required this.isPressed,
    required this.baseColor,
    required this.label,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final bgColor = isPressed
        ? baseColor.withValues(alpha: 0.55)
        : baseColor.withValues(alpha: 0.18);

    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..color = bgColor,
    );

    // Kenarlık
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()
        ..color = baseColor.withValues(alpha: 0.5)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0,
    );

    // Etiket
    final textPainter = TextPainter(
      text: TextSpan(
        text: label,
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.75),
          fontSize: math.min(size.width, size.height) * 0.18,
          fontWeight: FontWeight.w600,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: size.width);

    textPainter.paint(
      canvas,
      Offset(
        (size.width - textPainter.width) / 2,
        (size.height - textPainter.height) / 2,
      ),
    );
  }

  @override
  bool shouldRepaint(covariant TapAreaPainter old) =>
      old.isPressed != isPressed || old.baseColor != baseColor || old.label != label;
}
