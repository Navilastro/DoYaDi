import 'package:flutter/material.dart';
import '../models/joystick_mode.dart';
import 'joystick/joystick_interactive.dart';
import 'joystick/joystick_painter.dart';

/// Xbox-tarzı analog joystick widget'ı — mode dispatcher (facade).
///
/// [onChanged]: normalize edilmiş (-1..1, -1..1) x,y delta değeri döner.
/// [radius]: Joystick dış dairesinin yarıçapı (piksel).
/// [mode]: Çalışma modu (fixed, floatingBase, spawn, floatingSpawn).
///
/// Spawn tabanlı modlarda bu widget sadece ghost görüntü gösterir; gerçek
/// etkileşim [JoystickSpawnLayer] tarafından yönetilir.
class JoystickWidget extends StatelessWidget {
  final void Function(double x, double y) onChanged;
  final double radius;
  final Color baseColor;
  final Color thumbColor;
  final double deadzone;
  final JoystickMode mode;

  /// Spawn modda ghost opaklığı (0.0 = görünmez, 1.0 = tam görünür).
  /// Spawn layer aktifken 0, değilken ~0.2 olarak kullanılır.
  final double ghostOpacity;

  const JoystickWidget({
    super.key,
    required this.onChanged,
    this.radius = 60.0,
    this.baseColor = const Color(0xFF1A1A4E),
    this.thumbColor = const Color(0xFF40E0D0),
    this.deadzone = 0.08,
    this.mode = JoystickMode.fixed,
    this.ghostOpacity = 1.0,
  });

  @override
  Widget build(BuildContext context) {
    // Spawn tabanlı modlarda joystick sadece ghost görüntü gösterir.
    // Etkileşim JoystickSpawnLayer tarafından yönetilir.
    if (mode.isSpawnLike) {
      return IgnorePointer(
        child: SizedBox(
          width: radius * 2,
          height: radius * 2,
          child: CustomPaint(
            painter: JoystickPainter(
              thumbPos: Offset.zero,
              radius: radius,
              baseColor: baseColor,
              thumbColor: thumbColor,
              thumbRadius: radius * 0.35,
              ghostOpacity: ghostOpacity,
            ),
          ),
        ),
      );
    }

    // Fixed ve FloatingBase modları tek widget ile yönetilir.
    return JoystickInteractive(
      onChanged: onChanged,
      radius: radius,
      baseColor: baseColor,
      thumbColor: thumbColor,
      deadzone: deadzone,
      ghostOpacity: ghostOpacity,
      floating: mode.isFloating,
    );
  }
}
