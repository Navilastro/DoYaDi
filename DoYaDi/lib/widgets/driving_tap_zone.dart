import 'package:flutter/material.dart';
import 'driving_painters.dart';

/// Basit tıklama alanı widget'ı
class TapZone extends StatefulWidget {
  final String label;
  final Color color;
  final VoidCallback onDown;
  final VoidCallback onUp;

  const TapZone({
    super.key,
    required this.label,
    required this.color,
    required this.onDown,
    required this.onUp,
  });

  @override
  State<TapZone> createState() => _TapZoneState();
}

class _TapZoneState extends State<TapZone> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: (_) {
        setState(() => _pressed = true);
        widget.onDown();
      },
      onPointerUp: (_) {
        setState(() => _pressed = false);
        widget.onUp();
      },
      onPointerCancel: (_) {
        setState(() => _pressed = false);
        widget.onUp();
      },
      child: SizedBox(
        width: double.infinity,
        height: double.infinity,
        child: RepaintBoundary(
          child: CustomPaint(
            painter: TapAreaPainter(
              isPressed: _pressed,
              baseColor: widget.color,
              label: widget.label,
            ),
          ),
        ),
      ),
    );
  }
}

/// Mod 0 özel painter — tam ekran, gaz veya fren rengi
class Mode0Painter extends CustomPainter {
  final double gasPercentage;
  final double brakePercentage;
  final bool isGas;
  final bool hasActive;
  final Color gasColor;
  final Color brakeColor;
  final Color bgColor;
  final Color yetsoreColor;

  Mode0Painter({
    required this.gasPercentage,
    required this.brakePercentage,
    required this.isGas,
    required this.hasActive,
    required this.gasColor,
    required this.brakeColor,
    required this.bgColor,
    required this.yetsoreColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Arka plan
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..color = bgColor,
    );

    if (!hasActive) return;

    final double pct = isGas ? gasPercentage : brakePercentage;
    final Color baseColor = isGas ? gasColor : brakeColor;

    if (pct <= 0) return;

    final double fillH = size.height * pct;
    canvas.drawRect(
      Rect.fromLTWH(0, size.height - fillH, size.width, fillH),
      Paint()..color = baseColor,
    );

    // Yetsore
    if (pct >= 0.7) {
      final double fraction = ((pct - 0.7) / 0.3).clamp(0.0, 1.0);
      final double yH = fraction * size.height * 0.20;
      if (yH > 0) {
        canvas.drawRect(
          Rect.fromLTWH(0, size.height - yH, size.width, yH),
          Paint()..color = yetsoreColor,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant Mode0Painter old) =>
      old.gasPercentage != gasPercentage ||
      old.brakePercentage != brakePercentage ||
      old.isGas != isGas ||
      old.hasActive != hasActive;
}
