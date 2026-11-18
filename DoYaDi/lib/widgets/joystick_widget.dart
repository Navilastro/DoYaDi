import 'package:flutter/material.dart';
import '../models/joystick_mode.dart';
import 'joystick/joystick_interactive.dart';
import 'joystick/joystick_painter.dart';
import 'looping_media_widget.dart';

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
  final String? baseMediaPath;
  final String? thumbMediaPath;

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
    this.baseMediaPath,
    this.thumbMediaPath,
  });

  @override
  Widget build(BuildContext context) {
    // Spawn tabanlı modlarda joystick sadece ghost görüntü gösterir.
    // Etkileşim JoystickSpawnLayer tarafından yönetilir.
    if (mode.isSpawnLike) {
      final hasBaseMedia = AppMediaHelper.hasMedia(baseMediaPath);
      final hasThumbMedia = AppMediaHelper.hasMedia(thumbMediaPath);
      final double diameter = radius * 2;
      final double thumbRadius = radius * 0.35;

      if (hasBaseMedia || hasThumbMedia) {
        return IgnorePointer(
          child: Opacity(
            opacity: ghostOpacity.clamp(0.0, 1.0),
            child: SizedBox(
              width: diameter,
              height: diameter,
              child: Stack(
                children: [
                  if (hasBaseMedia)
                    ClipOval(
                      child: SizedBox(
                        width: diameter,
                        height: diameter,
                        child: LoopingMediaWidget(
                          mediaPath: baseMediaPath,
                          fit: BoxFit.cover,
                        ),
                      ),
                    )
                  else
                    CustomPaint(
                      size: Size(diameter, diameter),
                      painter: JoystickPainter(
                        thumbPos: Offset.zero,
                        radius: radius,
                        baseColor: baseColor,
                        thumbColor: Colors.transparent,
                        thumbRadius: 0,
                        ghostOpacity: 1.0,
                      ),
                    ),
                  Positioned(
                    left: radius - thumbRadius,
                    top: radius - thumbRadius,
                    width: thumbRadius * 2,
                    height: thumbRadius * 2,
                    child: hasThumbMedia
                        ? ClipOval(
                            child: Container(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.white30,
                                  width: 1.5,
                                ),
                              ),
                              child: LoopingMediaWidget(
                                mediaPath: thumbMediaPath,
                                fit: BoxFit.cover,
                              ),
                            ),
                          )
                        : Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: thumbColor,
                            ),
                          ),
                  ),
                ],
              ),
            ),
          ),
        );
      }

      return IgnorePointer(
        child: SizedBox(
          width: diameter,
          height: diameter,
          child: CustomPaint(
            painter: JoystickPainter(
              thumbPos: Offset.zero,
              radius: radius,
              baseColor: baseColor,
              thumbColor: thumbColor,
              thumbRadius: thumbRadius,
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
      baseMediaPath: baseMediaPath,
      thumbMediaPath: thumbMediaPath,
    );
  }
}
