import 'package:flutter/material.dart';
import 'joystick_controller.dart';
import 'joystick_painter.dart';

/// Joystick spawn bilgisi — orijinal merkez ve görsel bilgileri tutar.
class JoystickSpawnInfo {
  /// Joystick'in orijinal merkez konumu (piksel cinsinden, ekran üzerinde).
  final Offset originCenter;

  /// Joystick yarıçapı (piksel).
  final double radius;

  /// true: sol joystick, false: sağ joystick
  final bool isLeft;

  final Color baseColor;
  final Color thumbColor;

  const JoystickSpawnInfo({
    required this.originCenter,
    required this.radius,
    required this.isLeft,
    required this.baseColor,
    required this.thumbColor,
  });
}

/// Spawn (Belirme) modu şeffaf katmanı.
///
/// Ekranda boş alana dokunulduğunda, dokunma noktasının tüm joystick'lerin
/// orijinal merkezlerine olan mesafesini karşılaştırır (Voronoi mantığı).
/// En yakın joystick dokunulan noktada anlık olarak belirir ve aktifleşir.
///
/// floatingEnabled true olduğunda, spawn edilen joystick floating base
/// davranışı gösterir: thumb sınıra dayandığında base parmağı takip eder.
class JoystickSpawnLayer extends StatefulWidget {
  /// Ekrandaki tüm joystick'lerin spawn bilgileri.
  final List<JoystickSpawnInfo> joystickInfos;

  /// Sol joystick değişim callback'i.
  final void Function(double x, double y) onJoy0Changed;

  /// Sağ joystick değişim callback'i.
  final void Function(double x, double y) onJoy1Changed;

  /// Aktif spawn bilgisi dışarıya bildirilir (gizleme/gösterme için).
  /// Parametre: aktif joystick isLeft değeri, null ise hiçbiri aktif değil.
  final void Function(bool? activeIsLeft)? onActiveChanged;

  /// true: spawn + floating base birleşik modu.
  /// false (varsayılan): klasik spawn — base sabit kalır.
  final bool floatingEnabled;

  const JoystickSpawnLayer({
    super.key,
    required this.joystickInfos,
    required this.onJoy0Changed,
    required this.onJoy1Changed,
    this.onActiveChanged,
    this.floatingEnabled = false,
  });

  @override
  State<JoystickSpawnLayer> createState() => _JoystickSpawnLayerState();
}

class _JoystickSpawnLayerState extends State<JoystickSpawnLayer> {
  /// Aktif spawn noktası (dokunulan nokta) — joystick bu noktada çizilir.
  Offset? _spawnCenter;

  /// Floating base offset (orijinal spawn noktasından kayma).
  Offset _baseOffset = Offset.zero;

  /// Aktif spawn'a ait joystick bilgisi.
  JoystickSpawnInfo? _activeInfo;

  /// Thumb pozisyonu.
  Offset _thumbPos = Offset.zero;

  int? _activePointer;
  JoystickController? _controller;

  /// En yakın joystick'i bul (Voronoi / Euclidean mesafe).
  JoystickSpawnInfo? _findNearest(Offset touchPoint) {
    if (widget.joystickInfos.isEmpty) return null;

    JoystickSpawnInfo? nearest;
    double minDist = double.infinity;

    for (final info in widget.joystickInfos) {
      final dist = (touchPoint - info.originCenter).distance;
      if (dist < minDist) {
        minDist = dist;
        nearest = info;
      }
    }

    return nearest;
  }

  void _update(Offset localPosition) {
    if (_spawnCenter == null || _activeInfo == null || _controller == null) {
      return;
    }

    // Mevcut merkez = spawn noktası + base kayması
    final currentCenter = _spawnCenter! + _baseOffset;
    final delta = localPosition - currentCenter;
    final clamped = _controller!.clamp(delta);

    // Floating etkinse: thumb sınıra dayandığında base'i kaydır
    if (widget.floatingEnabled && delta.distance > _activeInfo!.radius) {
      final overflow =
          delta - (delta / delta.distance * _activeInfo!.radius);
      _baseOffset += overflow;
    }

    setState(() => _thumbPos = clamped);

    final (nx, ny) = _controller!.normalize(clamped);
    if (_activeInfo!.isLeft) {
      widget.onJoy0Changed(nx, ny);
    } else {
      widget.onJoy1Changed(nx, ny);
    }
  }

  void _reset() {
    if (_activeInfo != null) {
      if (_activeInfo!.isLeft) {
        widget.onJoy0Changed(0, 0);
      } else {
        widget.onJoy1Changed(0, 0);
      }
    }

    setState(() {
      _spawnCenter = null;
      _baseOffset = Offset.zero;
      _activeInfo = null;
      _thumbPos = Offset.zero;
      _activePointer = null;
      _controller = null;
    });

    widget.onActiveChanged?.call(null);
  }

  @override
  Widget build(BuildContext context) {
    // Görsel merkezin son konumu (spawn noktası + floating kayması)
    final Offset? visualCenter =
        _spawnCenter != null ? _spawnCenter! + _baseOffset : null;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        // Şeffaf dokunma yakalama katmanı
        Positioned.fill(
          child: Listener(
            behavior: HitTestBehavior.translucent,
            onPointerDown: (e) {
              if (_activePointer != null) return;

              final nearest = _findNearest(e.localPosition);
              if (nearest == null) return;

              _activePointer = e.pointer;
              _activeInfo = nearest;
              _spawnCenter = e.localPosition;
              _baseOffset = Offset.zero;
              _controller = JoystickController(
                radius: nearest.radius,
                deadzone: 0.08,
              );

              widget.onActiveChanged?.call(nearest.isLeft);

              // İlk dokunma — thumb merkezde
              setState(() => _thumbPos = Offset.zero);
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
            child: const SizedBox.expand(),
          ),
        ),

        // Spawn edilen joystick görseli
        if (visualCenter != null && _activeInfo != null)
          Positioned(
            left: visualCenter.dx - _activeInfo!.radius,
            top: visualCenter.dy - _activeInfo!.radius,
            child: IgnorePointer(
              child: SizedBox(
                width: _activeInfo!.radius * 2,
                height: _activeInfo!.radius * 2,
                child: CustomPaint(
                  painter: JoystickPainter(
                    thumbPos: _thumbPos,
                    radius: _activeInfo!.radius,
                    baseColor: _activeInfo!.baseColor,
                    thumbColor: _activeInfo!.thumbColor,
                    thumbRadius: _activeInfo!.radius * 0.35,
                    ghostOpacity: 1.0,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
