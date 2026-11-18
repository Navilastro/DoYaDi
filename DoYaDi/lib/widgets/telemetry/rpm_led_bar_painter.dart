import 'package:flutter/material.dart';

/// F1 RPM LED Barı CustomPainter.
///
/// 15 segment: [0-5] Yeşil → [6-10] Sarı → [11-13] Kırmızı → [14] Yanıp Sönen Mavi
/// RepaintBoundary ile izole edilmelidir.
/// Telemetri RPM byte'ından (0-255) segment sayısına haritalanır.
class RpmLedBarPainter extends CustomPainter {
  /// RPM yüzdesi (0.0 - 1.0)
  final double rpmFraction;

  /// Animasyon değeri (yanıp sönme için, 0.0-1.0 sinüs dalgası)
  final double blinkPhase;

  /// Özelleştirilebilir gradyan durak renkleri
  final Color lowColor;
  final Color midColor;
  final Color highColor;
  final Color limColor;

  static const int _segmentCount = 15;
  static const double _segmentGap = 3.0;
  static const double _cornerRadius = 3.0;

  const RpmLedBarPainter({
    required this.rpmFraction,
    this.blinkPhase = 1.0,
    this.lowColor = const Color(0xFF00E676),
    this.midColor = const Color(0xFFFFEB3B),
    this.highColor = const Color(0xFFFF1744),
    this.limColor = const Color(0xFFFF0000),
  });

  Color _segmentColorAt(int index) {
    if (index <= 5) {
      return Color.lerp(lowColor, midColor, index / 7.5)!;
    }
    if (index <= 10) {
      return Color.lerp(midColor, highColor, (index - 5) / 6.0)!;
    }
    if (index < 14) {
      return Color.lerp(highColor, limColor, (index - 11) / 5.0)!;
    }
    return limColor;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final activeSegments = (rpmFraction * _segmentCount).ceil().clamp(0, _segmentCount);
    final segmentWidth =
        (size.width - (_segmentCount - 1) * _segmentGap) / _segmentCount;
    final segmentHeight = size.height;

    for (int i = 0; i < _segmentCount; i++) {
      final isActive = i < activeSegments;
      final segCol = _segmentColorAt(i);
      final x = i * (segmentWidth + _segmentGap);
      final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(x, 0, segmentWidth, segmentHeight),
        const Radius.circular(_cornerRadius),
      );

      Color color;
      if (isActive) {
        color = segCol;
        // Son segment (14) — yanıp söner
        if (i == 14) {
          color = color.withValues(alpha: 0.3 + 0.7 * blinkPhase);
        }
      } else {
        color = Color.lerp(const Color(0xFF14141E), segCol, 0.16)!;
      }

      final paint = Paint()
        ..color = color
        ..style = PaintingStyle.fill;

      canvas.drawRRect(rect, paint);

      // Aktif segmentlere parlaklık efekti
      if (isActive) {
        final glowPaint = Paint()
          ..color = segCol.withValues(alpha: 0.3)
          ..maskFilter = const MaskFilter.blur(BlurStyle.outer, 4);
        canvas.drawRRect(rect, glowPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant RpmLedBarPainter old) =>
      old.rpmFraction != rpmFraction || old.blinkPhase != blinkPhase;
}
