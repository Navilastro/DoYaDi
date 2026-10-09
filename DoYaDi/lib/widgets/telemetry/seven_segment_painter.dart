import 'package:flutter/material.dart';

/// 7-Segment vites göstergesi CustomPainter.
///
/// N, R, 1-8 destekli. Segment geometrisi kodla çizilir (font değil).
/// Klasik LED 7-segment display stilinde.
class SevenSegmentPainter extends CustomPainter {
  /// Gösterilecek vites: 0=N, 1-8=ileri, 255=R
  final int gear;

  /// Segment rengi
  final Color activeColor;

  /// Kapalı segment rengi
  final Color dimColor;

  const SevenSegmentPainter({
    required this.gear,
    this.activeColor = const Color(0xFFFF1744),
    this.dimColor = const Color(0xFF1A0A0A),
  });

  // 7-segment kodlama: [a, b, c, d, e, f, g]
  //    ── a ──
  //   |       |
  //   f       b
  //   |       |
  //    ── g ──
  //   |       |
  //   e       c
  //   |       |
  //    ── d ──
  //
  static const Map<String, List<bool>> _segmentMap = {
    'N': [true, true, true, false, true, true, false],   // N benzeri
    'R': [false, false, false, false, true, false, true],    // r benzeri
    '0': [true, true, true, true, true, true, false],
    '1': [false, true, true, false, false, false, false],
    '2': [true, true, false, true, true, false, true],
    '3': [true, true, true, true, false, false, true],
    '4': [false, true, true, false, false, true, true],
    '5': [true, false, true, true, false, true, true],
    '6': [true, false, true, true, true, true, true],
    '7': [true, true, true, false, false, false, false],
    '8': [true, true, true, true, true, true, true],
    '?': [true, true, false, true, false, false, true],
  };

  String get _gearChar {
    if (gear == 0) return 'N';
    if (gear == 255) return 'R';
    if (gear >= 1 && gear <= 8) return gear.toString();
    return '?';
  }

  @override
  void paint(Canvas canvas, Size size) {
    final segments = _segmentMap[_gearChar] ?? _segmentMap['?']!;

    // Segment boyutları
    final w = size.width;
    final h = size.height;
    final thick = w * 0.15; // Segment kalınlığı
    final gap = thick * 0.2; // Segmentler arası boşluk
    final halfThick = thick / 2;

    // Segment pozisyonları (path olarak çizilir)
    final paths = <Path>[
      // a (üst yatay)
      _horizontalSegment(gap + halfThick, 0, w - gap - halfThick, thick),
      // b (sağ üst dikey)
      _verticalSegment(w - thick, gap + halfThick, w, h / 2 - gap),
      // c (sağ alt dikey)
      _verticalSegment(w - thick, h / 2 + gap, w, h - gap - halfThick),
      // d (alt yatay)
      _horizontalSegment(gap + halfThick, h - thick, w - gap - halfThick, h),
      // e (sol alt dikey)
      _verticalSegment(0, h / 2 + gap, thick, h - gap - halfThick),
      // f (sol üst dikey)
      _verticalSegment(0, gap + halfThick, thick, h / 2 - gap),
      // g (orta yatay)
      _horizontalSegment(gap + halfThick, h / 2 - halfThick, w - gap - halfThick, h / 2 + halfThick),
    ];

    for (int i = 0; i < 7; i++) {
      final isActive = segments[i];
      final paint = Paint()
        ..color = isActive ? activeColor : dimColor
        ..style = PaintingStyle.fill;

      canvas.drawPath(paths[i], paint);

      // Aktif segmentlere glow
      if (isActive) {
        final glowPaint = Paint()
          ..color = activeColor.withValues(alpha: 0.4)
          ..maskFilter = const MaskFilter.blur(BlurStyle.outer, 6);
        canvas.drawPath(paths[i], glowPaint);
      }
    }
  }

  Path _horizontalSegment(double x1, double y1, double x2, double y2) {
    final midY = (y1 + y2) / 2;
    final inset = (y2 - y1) / 2;
    return Path()
      ..moveTo(x1, midY)
      ..lineTo(x1 + inset, y1)
      ..lineTo(x2 - inset, y1)
      ..lineTo(x2, midY)
      ..lineTo(x2 - inset, y2)
      ..lineTo(x1 + inset, y2)
      ..close();
  }

  Path _verticalSegment(double x1, double y1, double x2, double y2) {
    final midX = (x1 + x2) / 2;
    final inset = (x2 - x1) / 2;
    return Path()
      ..moveTo(midX, y1)
      ..lineTo(x2, y1 + inset)
      ..lineTo(x2, y2 - inset)
      ..lineTo(midX, y2)
      ..lineTo(x1, y2 - inset)
      ..lineTo(x1, y1 + inset)
      ..close();
  }

  @override
  bool shouldRepaint(covariant SevenSegmentPainter old) =>
      old.gear != gear || old.activeColor != activeColor;
}
