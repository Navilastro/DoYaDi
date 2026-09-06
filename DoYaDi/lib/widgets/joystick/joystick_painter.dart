import 'package:flutter/material.dart';

/// Joystick çizim katmanı.
///
/// [ghostOpacity] > 0 olduğunda yarı saydam "hayalet" modda çizilir
/// (spawn modda joystick aktif değilken).
class JoystickPainter extends CustomPainter {
  final Offset thumbPos;
  final double radius;
  final Color baseColor;
  final Color thumbColor;
  final double thumbRadius;
  final double ghostOpacity;

  JoystickPainter({
    required this.thumbPos,
    required this.radius,
    required this.baseColor,
    required this.thumbColor,
    required this.thumbRadius,
    this.ghostOpacity = 1.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(radius, radius);
    final double alpha = ghostOpacity;

    // Dış daire — arka plan
    canvas.drawCircle(
      center,
      radius,
      Paint()..color = baseColor.withValues(alpha: alpha),
    );

    // Dış daire — kenarlık
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = thumbColor.withValues(alpha: 0.35 * alpha)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0,
    );

    // Yatay/dikey referans çizgileri
    final axisPaint = Paint()
      ..color = thumbColor.withValues(alpha: 0.2 * alpha)
      ..strokeWidth = 1.0;
    canvas.drawLine(
      Offset(center.dx - radius * 0.8, center.dy),
      Offset(center.dx + radius * 0.8, center.dy),
      axisPaint,
    );
    canvas.drawLine(
      Offset(center.dx, center.dy - radius * 0.8),
      Offset(center.dx, center.dy + radius * 0.8),
      axisPaint,
    );

    // Thumb
    final thumbCenter = center + thumbPos;
    // Gölge
    canvas.drawCircle(
      thumbCenter + const Offset(2, 3),
      thumbRadius,
      Paint()..color = Colors.black.withValues(alpha: 0.38 * alpha),
    );
    // Thumb dolgu
    canvas.drawCircle(
      thumbCenter,
      thumbRadius,
      Paint()..color = thumbColor.withValues(alpha: alpha),
    );
    // Thumb iç parlaklık
    canvas.drawCircle(
      thumbCenter - Offset(thumbRadius * 0.25, thumbRadius * 0.25),
      thumbRadius * 0.35,
      Paint()..color = Colors.white.withValues(alpha: 0.3 * alpha),
    );
  }

  @override
  bool shouldRepaint(covariant JoystickPainter old) =>
      old.thumbPos != thumbPos ||
      old.baseColor != baseColor ||
      old.thumbColor != thumbColor ||
      old.ghostOpacity != ghostOpacity;
}
