import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'joystick_controller.dart';
import 'joystick_painter.dart';

/// Birleşik joystick widget'ı — Sabit (Fixed) ve Sürüklenen (Floating) modları
/// tek widget'ta yönetir.
///
/// [floating] false ise sabit mod: joystick merkezi yerinden oynamaz.
/// [floating] true ise sürükleme modu: thumb sınıra dayanınca base kayar,
/// parmak kalktığında spring animasyonuyla orijinal yerine döner.
class JoystickInteractive extends StatefulWidget {
  final void Function(double x, double y) onChanged;
  final double radius;
  final Color baseColor;
  final Color thumbColor;
  final double deadzone;
  final double ghostOpacity;

  /// true: floating base davranışı (base parmağı takip eder).
  /// false: sabit mod (base yerinden oynamaz).
  final bool floating;

  const JoystickInteractive({
    super.key,
    required this.onChanged,
    required this.radius,
    this.baseColor = const Color(0xFF1A1A4E),
    this.thumbColor = const Color(0xFF40E0D0),
    this.deadzone = 0.08,
    this.ghostOpacity = 1.0,
    this.floating = false,
  });

  @override
  State<JoystickInteractive> createState() => _JoystickInteractiveState();
}

class _JoystickInteractiveState extends State<JoystickInteractive>
    with TickerProviderStateMixin {
  /// Joystick tabanının (merkezinin) orijinal konumdan kayma miktarı.
  /// Sabit modda daima Offset.zero kalır.
  Offset _baseOffset = Offset.zero;

  /// Thumb pozisyonu — kayan merkeze göre hesaplanır.
  Offset _thumbPos = Offset.zero;

  int? _activePointer;
  late JoystickController _controller;

  // Spring animasyon (yalnızca floating modda kullanılır)
  AnimationController? _springAnimX;
  AnimationController? _springAnimY;

  @override
  void initState() {
    super.initState();
    _controller = JoystickController(
      radius: widget.radius,
      deadzone: widget.deadzone,
    );
  }

  @override
  void didUpdateWidget(covariant JoystickInteractive oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.radius != widget.radius ||
        oldWidget.deadzone != widget.deadzone) {
      _controller = JoystickController(
        radius: widget.radius,
        deadzone: widget.deadzone,
      );
    }
  }

  @override
  void dispose() {
    _springAnimX?.dispose();
    _springAnimY?.dispose();
    super.dispose();
  }

  void _update(Offset localPosition) {
    final originalCenter = Offset(widget.radius, widget.radius);
    final currentCenter = originalCenter + _baseOffset;
    final delta = localPosition - currentCenter;
    final clamped = _controller.clamp(delta);

    // Floating modda: thumb sınıra dayandığında base'i kaydır
    if (widget.floating && delta.distance > widget.radius) {
      final overflow = delta - (delta / delta.distance * widget.radius);
      _baseOffset += overflow;
    }

    setState(() => _thumbPos = clamped);

    final (nx, ny) = _controller.normalize(clamped);
    widget.onChanged(nx, ny);
  }

  void _reset() {
    setState(() => _thumbPos = Offset.zero);
    widget.onChanged(0, 0);
    _activePointer = null;

    // Floating modda spring ile geri dön, sabit modda zaten Offset.zero
    if (widget.floating) {
      _animateBaseBack();
    }
  }

  void _animateBaseBack() {
    _springAnimX?.dispose();
    _springAnimY?.dispose();

    final startX = _baseOffset.dx;
    final startY = _baseOffset.dy;

    if (startX.abs() < 0.5 && startY.abs() < 0.5) {
      setState(() => _baseOffset = Offset.zero);
      return;
    }

    const spring = SpringDescription(
      mass: 1.0,
      stiffness: 300.0,
      damping: 22.0, // ~0.75 damping ratio
    );

    // X ekseni spring
    _springAnimX = AnimationController.unbounded(vsync: this);
    final simX = SpringSimulation(spring, startX, 0.0, 0.0);
    _springAnimX!.addListener(() {
      if (!mounted) return;
      setState(() {
        _baseOffset = Offset(_springAnimX!.value, _baseOffset.dy);
      });
    });
    _springAnimX!.animateWith(simX);

    // Y ekseni spring
    _springAnimY = AnimationController.unbounded(vsync: this);
    final simY = SpringSimulation(spring, startY, 0.0, 0.0);
    _springAnimY!.addListener(() {
      if (!mounted) return;
      setState(() {
        _baseOffset = Offset(_baseOffset.dx, _springAnimY!.value);
      });
    });
    _springAnimY!.animateWith(simY);
  }

  @override
  Widget build(BuildContext context) {
    final double size = widget.radius * 2;
    final double thumbRadius = widget.radius * 0.35;

    return Listener(
      behavior: HitTestBehavior.opaque,
      onPointerDown: (e) {
        if (_activePointer != null) return;
        _activePointer = e.pointer;
        // Floating modda: devam eden spring animasyonlarını durdur
        if (widget.floating) {
          _springAnimX?.stop();
          _springAnimY?.stop();
        }
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
        child: widget.floating
            ? Transform.translate(
                offset: _baseOffset,
                child: _buildPainter(thumbRadius),
              )
            : _buildPainter(thumbRadius),
      ),
    );
  }

  Widget _buildPainter(double thumbRadius) {
    return CustomPaint(
      painter: JoystickPainter(
        thumbPos: _thumbPos,
        radius: widget.radius,
        baseColor: widget.baseColor,
        thumbColor: widget.thumbColor,
        thumbRadius: thumbRadius,
        ghostOpacity: widget.ghostOpacity,
      ),
    );
  }
}
