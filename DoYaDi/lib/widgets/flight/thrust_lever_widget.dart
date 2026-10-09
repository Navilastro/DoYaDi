import 'package:flutter/material.dart';

/// İtki Çubuğu (Thrust Lever) Widget'ı.
///
/// Idle → %50 → Mil Power → Afterburner kilit detent'leri ile
/// dikey sürüklenebilir itki kontrolcüsü.
class ThrustLeverWidget extends StatefulWidget {
  /// Mevcut itki değeri (0.0 - 1.0)
  final double value;

  /// Değer değiştiğinde çağrılır
  final ValueChanged<double> onChanged;

  /// Detent sayısı (2-8)
  final int detents;

  /// Çubuk rengi
  final Color color;

  /// Detent'lere yapışma kuvveti (0=yok, 1=tam)
  final double snapStrength;

  const ThrustLeverWidget({
    super.key,
    required this.value,
    required this.onChanged,
    this.detents = 4,
    this.color = const Color(0xFF40E0D0),
    this.snapStrength = 0.3,
  });

  @override
  State<ThrustLeverWidget> createState() => _ThrustLeverWidgetState();
}

class _ThrustLeverWidgetState extends State<ThrustLeverWidget> {
  bool _dragging = false;

  List<double> get _detentPositions {
    final list = <double>[];
    for (int i = 0; i < widget.detents; i++) {
      list.add(i / (widget.detents - 1));
    }
    return list;
  }

  List<String> get _detentLabels {
    if (widget.detents == 4) {
      return ['IDLE', 'MIL', 'MAX', 'A/B'];
    }
    final labels = <String>[];
    for (int i = 0; i < widget.detents; i++) {
      labels.add('${(i * 100 / (widget.detents - 1)).toStringAsFixed(0)}%');
    }
    return labels;
  }

  double _snapToDetent(double raw) {
    if (widget.snapStrength <= 0) return raw;
    final detents = _detentPositions;
    double closest = 0;
    double minDist = 1.0;
    for (final d in detents) {
      final dist = (raw - d).abs();
      if (dist < minDist) {
        minDist = dist;
        closest = d;
      }
    }
    // Yapışma aralığı
    final snapRange = widget.snapStrength * (1.0 / (widget.detents - 1)) * 0.4;
    if (minDist < snapRange) return closest;
    return raw;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final trackHeight = constraints.maxHeight - 40; // Üst/alt padding

        return GestureDetector(
          onVerticalDragStart: (_) => setState(() => _dragging = true),
          onVerticalDragUpdate: (details) {
            final raw = 1.0 - ((details.localPosition.dy - 20) / trackHeight).clamp(0.0, 1.0);
            widget.onChanged(_snapToDetent(raw));
          },
          onVerticalDragEnd: (_) => setState(() => _dragging = false),
          child: CustomPaint(
            painter: _ThrustLeverPainter(
              value: widget.value,
              detentPositions: _detentPositions,
              detentLabels: _detentLabels,
              color: widget.color,
              isDragging: _dragging,
            ),
            child: const SizedBox.expand(),
          ),
        );
      },
    );
  }
}

class _ThrustLeverPainter extends CustomPainter {
  final double value;
  final List<double> detentPositions;
  final List<String> detentLabels;
  final Color color;
  final bool isDragging;

  const _ThrustLeverPainter({
    required this.value,
    required this.detentPositions,
    required this.detentLabels,
    required this.color,
    required this.isDragging,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final trackLeft = w * 0.35;
    final trackWidth = w * 0.3;
    final trackTop = 20.0;
    final trackHeight = h - 40;

    // ── Ray ──
    final trackPaint = Paint()
      ..color = const Color(0xFF1A1A2E)
      ..style = PaintingStyle.fill;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(trackLeft, trackTop, trackWidth, trackHeight),
        const Radius.circular(6),
      ),
      trackPaint,
    );

    // ── Dolgu ──
    final fillHeight = value * trackHeight;
    final fillPaint = Paint()
      ..color = color.withValues(alpha: 0.25)
      ..style = PaintingStyle.fill;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(
          trackLeft,
          trackTop + trackHeight - fillHeight,
          trackWidth,
          fillHeight,
        ),
        const Radius.circular(6),
      ),
      fillPaint,
    );

    // ── Detent çizgileri ──
    final detentPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.3)
      ..strokeWidth = 1;
    final labelStyle = TextStyle(
      color: Colors.white.withValues(alpha: 0.5),
      fontSize: 9,
      fontFamily: 'monospace',
    );

    for (int i = 0; i < detentPositions.length; i++) {
      final y = trackTop + (1.0 - detentPositions[i]) * trackHeight;
      canvas.drawLine(
        Offset(trackLeft - 8, y),
        Offset(trackLeft, y),
        detentPaint,
      );

      if (i < detentLabels.length) {
        final tp = TextPainter(
          text: TextSpan(text: detentLabels[i], style: labelStyle),
          textDirection: TextDirection.ltr,
        )..layout();
        tp.paint(canvas, Offset(trackLeft - tp.width - 12, y - tp.height / 2));
      }
    }

    // ── Handle ──
    final handleY = trackTop + (1.0 - value) * trackHeight;
    final handlePaint = Paint()
      ..color = isDragging ? color : color.withValues(alpha: 0.8)
      ..style = PaintingStyle.fill;

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(trackLeft + trackWidth / 2, handleY),
          width: trackWidth + 16,
          height: 20,
        ),
        const Radius.circular(4),
      ),
      handlePaint,
    );

    if (isDragging) {
      final glowPaint = Paint()
        ..color = color.withValues(alpha: 0.3)
        ..maskFilter = const MaskFilter.blur(BlurStyle.outer, 8);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset(trackLeft + trackWidth / 2, handleY),
            width: trackWidth + 16,
            height: 20,
          ),
          const Radius.circular(4),
        ),
        glowPaint,
      );
    }

    // ── Yüzde etiketi ──
    final pctTp = TextPainter(
      text: TextSpan(
        text: '${(value * 100).toStringAsFixed(0)}%',
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.bold,
          fontFamily: 'monospace',
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    pctTp.paint(
      canvas,
      Offset(
        trackLeft + trackWidth + 12,
        handleY - pctTp.height / 2,
      ),
    );
  }

  @override
  bool shouldRepaint(covariant _ThrustLeverPainter old) =>
      old.value != value || old.isDragging != isDragging;
}
