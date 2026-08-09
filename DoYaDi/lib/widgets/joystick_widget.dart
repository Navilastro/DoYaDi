import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Xbox-tarzı analog joystick widget'ı.
/// [onChanged]: normalize edilmiş (-1..1, -1..1) x,y delta değeri döner.
/// [radius]: Joystick dış dairesinin yarıçapı (piksel).
class JoystickWidget extends StatefulWidget {
  final void Function(double x, double y) onChanged;
  final double radius;
  final Color baseColor;
  final Color thumbColor;
  final double deadzone; // 0.0 - 0.3 arasında önerilen

  const JoystickWidget({
    super.key,
    required this.onChanged,
    this.radius = 60.0,
    this.baseColor = const Color(0xFF1A1A4E),
    this.thumbColor = const Color(0xFF40E0D0),
    this.deadzone = 0.08,
  });

  @override
  State<JoystickWidget> createState() => _JoystickWidgetState();
}

class _JoystickWidgetState extends State<JoystickWidget> {
  Offset _thumbPos = Offset.zero; // -radius..+radius
  int? _activePointer;

  Offset _clamp(Offset raw) {
    final dist = raw.distance;
    if (dist <= widget.radius) return raw;
    return raw / dist * widget.radius;
  }

  void _update(Offset local) {
    final center = Offset(widget.radius, widget.radius);
    final delta = local - center;
    final clamped = _clamp(delta);
    setState(() => _thumbPos = clamped);

    double nx = clamped.dx / widget.radius;
    double ny = clamped.dy / widget.radius;

    // Deadzone uygula
    final dist = math.sqrt(nx * nx + ny * ny);
    if (dist < widget.deadzone) {
      nx = 0;
      ny = 0;
    } else {
      // Deadzone sonrası rescale
      final scaled = (dist - widget.deadzone) / (1.0 - widget.deadzone);
      nx = nx / dist * scaled;
      ny = ny / dist * scaled;
    }

    widget.onChanged(nx.clamp(-1.0, 1.0), ny.clamp(-1.0, 1.0));
  }

  void _reset() {
    setState(() => _thumbPos = Offset.zero);
    widget.onChanged(0, 0);
    _activePointer = null;
  }

  @override
  Widget build(BuildContext context) {
    final double size = widget.radius * 2;
    final double thumbRadius = widget.radius * 0.35;

    return Listener(
      onPointerDown: (e) {
        if (_activePointer != null) return;
        _activePointer = e.pointer;
        _update(e.localPosition);
      },
      onPointerMove: (e) {
        if (e.pointer != _activePointer) return;
        _update(e.localPosition);
      },
      onPointerUp: (e) {
        if (e.pointer != _activePointer) return;
        _reset();
      },
      onPointerCancel: (e) {
        if (e.pointer != _activePointer) return;
        _reset();
      },
      child: SizedBox(
        width: size,
        height: size,
        child: CustomPaint(
          painter: _JoystickPainter(
            thumbPos: _thumbPos,
            radius: widget.radius,
            baseColor: widget.baseColor,
            thumbColor: widget.thumbColor,
            thumbRadius: thumbRadius,
          ),
        ),
      ),
    );
  }
}

class _JoystickPainter extends CustomPainter {
  final Offset thumbPos;
  final double radius;
  final Color baseColor;
  final Color thumbColor;
  final double thumbRadius;

  _JoystickPainter({
    required this.thumbPos,
    required this.radius,
    required this.baseColor,
    required this.thumbColor,
    required this.thumbRadius,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(radius, radius);

    // Dış daire — arka plan
    canvas.drawCircle(
      center,
      radius,
      Paint()..color = baseColor,
    );

    // Dış daire — kenarlık
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = thumbColor.withValues(alpha: 0.35)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0,
    );

    // Yatay/dikey çizgiler (referans)
    final axisPaint = Paint()
      ..color = thumbColor.withValues(alpha: 0.2)
      ..strokeWidth = 1.0;
    canvas.drawLine(Offset(center.dx - radius * 0.8, center.dy),
        Offset(center.dx + radius * 0.8, center.dy), axisPaint);
    canvas.drawLine(Offset(center.dx, center.dy - radius * 0.8),
        Offset(center.dx, center.dy + radius * 0.8), axisPaint);

    // Thumb
    final thumbCenter = center + thumbPos;
    // Gölge
    canvas.drawCircle(
      thumbCenter + const Offset(2, 3),
      thumbRadius,
      Paint()..color = Colors.black38,
    );
    // Thumb dolgu
    canvas.drawCircle(
      thumbCenter,
      thumbRadius,
      Paint()..color = thumbColor,
    );
    // Thumb iç parlaklık
    canvas.drawCircle(
      thumbCenter - Offset(thumbRadius * 0.25, thumbRadius * 0.25),
      thumbRadius * 0.35,
      Paint()..color = Colors.white.withValues(alpha: 0.3),
    );
  }

  @override
  bool shouldRepaint(covariant _JoystickPainter old) =>
      old.thumbPos != thumbPos ||
      old.baseColor != baseColor ||
      old.thumbColor != thumbColor;
}
