import 'dart:math' as math;
import 'dart:ui';

/// Joystick ortak hesaplama mantığı.
///
/// Deadzone, clamp ve normalize işlemlerini tüm modlar için tek noktada yönetir.
class JoystickController {
  final double radius;
  final double deadzone;

  const JoystickController({
    required this.radius,
    this.deadzone = 0.08,
  });

  /// Ham offset'i yarıçap sınırına kısıtlar.
  Offset clamp(Offset raw) {
    final dist = raw.distance;
    if (dist <= radius) return raw;
    return raw / dist * radius;
  }

  /// Kısıtlanmış offset'i -1..1 aralığına normalize eder (deadzone uygulanmış).
  ///
  /// Dönen değer: `(nx, ny)` — her ikisi de -1.0 ile 1.0 arasında.
  (double, double) normalize(Offset clamped) {
    double nx = clamped.dx / radius;
    double ny = clamped.dy / radius;

    final dist = math.sqrt(nx * nx + ny * ny);
    if (dist < deadzone) {
      return (0.0, 0.0);
    }

    // Deadzone sonrası rescale
    final scaled = (dist - deadzone) / (1.0 - deadzone);
    nx = nx / dist * scaled;
    ny = ny / dist * scaled;

    return (nx.clamp(-1.0, 1.0), ny.clamp(-1.0, 1.0));
  }

  /// Tek adımda clamp + normalize.
  (double, double) process(Offset rawDelta) {
    final clamped = clamp(rawDelta);
    return normalize(clamped);
  }
}
