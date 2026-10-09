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

  static const int _segmentCount = 15;
  static const double _segmentGap = 3.0;
  static const double _cornerRadius = 3.0;

  // Segment renkleri
  static const List<Color> _segmentColors = [
    Color(0xFF00E676), // 0 - Yeşil
    Color(0xFF00E676), // 1
    Color(0xFF00E676), // 2
    Color(0xFF66BB6A), // 3
    Color(0xFF66BB6A), // 4
    Color(0xFF66BB6A), // 5
    Color(0xFFFFEB3B), // 6 - Sarı
    Color(0xFFFFEB3B), // 7
    Color(0xFFFFC107), // 8
    Color(0xFFFFC107), // 9
    Color(0xFFFF9800), // 10
    Color(0xFFFF1744), // 11 - Kırmızı
    Color(0xFFFF1744), // 12
    Color(0xFFD50000), // 13
    Color(0xFF448AFF), // 14 - Mavi (yanıp sönen)
  ];

  static const List<Color> _dimColors = [
    Color(0xFF1B3A1B),
    Color(0xFF1B3A1B),
    Color(0xFF1B3A1B),
    Color(0xFF1B3A1B),
    Color(0xFF1B3A1B),
    Color(0xFF1B3A1B),
    Color(0xFF3A3A1B),
    Color(0xFF3A3A1B),
    Color(0xFF3A3A1B),
    Color(0xFF3A3A1B),
    Color(0xFF3A3A1B),
    Color(0xFF3A1B1B),
    Color(0xFF3A1B1B),
    Color(0xFF3A1B1B),
    Color(0xFF1B2A3A),
  ];

  const RpmLedBarPainter({
    required this.rpmFraction,
    this.blinkPhase = 1.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final activeSegments = (rpmFraction * _segmentCount).ceil().clamp(0, _segmentCount);
    final segmentWidth =
        (size.width - (_segmentCount - 1) * _segmentGap) / _segmentCount;
    final segmentHeight = size.height;

    for (int i = 0; i < _segmentCount; i++) {
      final isActive = i < activeSegments;
      final x = i * (segmentWidth + _segmentGap);
      final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(x, 0, segmentWidth, segmentHeight),
        const Radius.circular(_cornerRadius),
      );

      Color color;
      if (isActive) {
        color = _segmentColors[i];
        // Son segment (14) — yanıp söner
        if (i == 14) {
          color = color.withValues(alpha: 0.3 + 0.7 * blinkPhase);
        }
      } else {
        color = _dimColors[i];
      }

      final paint = Paint()
        ..color = color
        ..style = PaintingStyle.fill;

      canvas.drawRRect(rect, paint);

      // Aktif segmentlere parlaklık efekti
      if (isActive) {
        final glowPaint = Paint()
          ..color = _segmentColors[i].withValues(alpha: 0.3)
          ..maskFilter = const MaskFilter.blur(BlurStyle.outer, 4);
        canvas.drawRRect(rect, glowPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant RpmLedBarPainter old) =>
      old.rpmFraction != rpmFraction || old.blinkPhase != blinkPhase;
}
