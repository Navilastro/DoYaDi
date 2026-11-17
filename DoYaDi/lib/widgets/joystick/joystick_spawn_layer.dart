import 'package:flutter/material.dart';
import 'joystick_controller.dart';
import 'joystick_painter.dart';
import '../looping_media_widget.dart';

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
  final String? baseMediaPath;
  final String? thumbMediaPath;

  const JoystickSpawnInfo({
    required this.originCenter,
    required this.radius,
    required this.isLeft,
    required this.baseColor,
    required this.thumbColor,
    this.baseMediaPath,
    this.thumbMediaPath,
  });
}

/// Tek bir aktif parmak (pointer) için spawn edilmiş joystick durumu.
class _ActiveSpawnState {
  final JoystickSpawnInfo info;
  final Offset spawnCenter;
  final JoystickController controller;
  Offset baseOffset = Offset.zero;
  Offset thumbPos = Offset.zero;

  _ActiveSpawnState({
    required this.info,
    required this.spawnCenter,
    required this.controller,
  });

  Offset get visualCenter => spawnCenter + baseOffset;
}

/// Spawn (Belirme) modu şeffaf katmanı (Multi-Touch / Çift Joystick Destekli).
///
/// Ekranda boş alana dokunulduğunda, dokunma noktasının tüm joystick'lerin
/// orijinal merkezlerine olan mesafesini karşılaştırır (Voronoi mantığı).
/// En yakın joystick (henüz başka bir parmakla aktif değilse) dokunulan noktada
/// anlık olarak belirir ve aktifleşir. Sol ve Sağ joystick aynı anda bağımsız
/// iki parmakla kullanılabilir.
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

  /// Aktif spawn durumu dışarıya bildirilir (orijinal ghost gizleme/gösterme için).
  final void Function(bool leftActive, bool rightActive)? onActiveChanged;

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
  /// Pointer ID -> Aktif spawn durumu (Sol ve Sağ aynı anda aktif olabilir).
  final Map<int, _ActiveSpawnState> _activeSpawns = {};

  bool _isSideActive(bool isLeft) {
    return _activeSpawns.values.any((s) => s.info.isLeft == isLeft);
  }

  void _notifyActiveChanged() {
    widget.onActiveChanged?.call(
      _isSideActive(true),
      _isSideActive(false),
    );
  }

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

  void _update(int pointer, Offset localPosition) {
    final state = _activeSpawns[pointer];
    if (state == null) return;

    // Mevcut merkez = spawn noktası + base kayması
    final currentCenter = state.spawnCenter + state.baseOffset;
    final delta = localPosition - currentCenter;
    final clamped = state.controller.clamp(delta);

    // Floating etkinse: thumb sınıra dayandığında base'i kaydır
    if (widget.floatingEnabled && delta.distance > state.info.radius) {
      final overflow = delta - (delta / delta.distance * state.info.radius);
      state.baseOffset += overflow;
    }

    setState(() => state.thumbPos = clamped);

    final (nx, ny) = state.controller.normalize(clamped);
    if (state.info.isLeft) {
      widget.onJoy0Changed(nx, ny);
    } else {
      widget.onJoy1Changed(nx, ny);
    }
  }

  void _resetPointer(int pointer) {
    final removed = _activeSpawns.remove(pointer);
    if (removed == null) return;

    if (removed.info.isLeft) {
      widget.onJoy0Changed(0, 0);
    } else {
      widget.onJoy1Changed(0, 0);
    }

    setState(() {});
    _notifyActiveChanged();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        // Şeffaf dokunma yakalama katmanı (Multi-Touch)
        Positioned.fill(
          child: Listener(
            behavior: HitTestBehavior.translucent,
            onPointerDown: (e) {
              if (_activeSpawns.containsKey(e.pointer)) return;

              final nearest = _findNearest(e.localPosition);
              if (nearest == null) return;

              // Bu joystick (sol veya sağ) zaten başka bir parmak tarafından kullanılıyorsa yoksay
              if (_isSideActive(nearest.isLeft)) return;

              _activeSpawns[e.pointer] = _ActiveSpawnState(
                info: nearest,
                spawnCenter: e.localPosition,
                controller: JoystickController(
                  radius: nearest.radius,
                  deadzone: 0.08,
                ),
              );

              _notifyActiveChanged();
              setState(() {});
            },
            onPointerMove: (e) {
              if (!_activeSpawns.containsKey(e.pointer)) return;
              _update(e.pointer, e.localPosition);
            },
            onPointerUp: (e) {
              if (!_activeSpawns.containsKey(e.pointer)) return;
              _resetPointer(e.pointer);
            },
            onPointerCancel: (e) {
              if (!_activeSpawns.containsKey(e.pointer)) return;
              _resetPointer(e.pointer);
            },
            child: const SizedBox.expand(),
          ),
        ),

        // Spawn edilen tüm aktif joystick görselleri (Sol ve Sağ aynı anda çizilebilir)
        for (final spawn in _activeSpawns.values)
          Positioned(
            left: spawn.visualCenter.dx - spawn.info.radius,
            top: spawn.visualCenter.dy - spawn.info.radius,
            child: IgnorePointer(
              child: _buildSpawnVisual(spawn),
            ),
          ),
      ],
    );
  }

  Widget _buildSpawnVisual(_ActiveSpawnState spawn) {
    final radius = spawn.info.radius;
    final diameter = radius * 2;
    final thumbRadius = radius * 0.35;
    final hasBaseMedia = AppMediaHelper.hasMedia(spawn.info.baseMediaPath);
    final hasThumbMedia = AppMediaHelper.hasMedia(spawn.info.thumbMediaPath);

    if (!hasBaseMedia && !hasThumbMedia) {
      return SizedBox(
        width: diameter,
        height: diameter,
        child: CustomPaint(
          painter: JoystickPainter(
            thumbPos: spawn.thumbPos,
            radius: radius,
            baseColor: spawn.info.baseColor,
            thumbColor: spawn.info.thumbColor,
            thumbRadius: thumbRadius,
            ghostOpacity: 1.0,
          ),
        ),
      );
    }

    final thumbCenter = Offset(radius, radius) + spawn.thumbPos;
    return SizedBox(
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
                  mediaPath: spawn.info.baseMediaPath,
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
                baseColor: spawn.info.baseColor,
                thumbColor: Colors.transparent,
                thumbRadius: 0,
                ghostOpacity: 1.0,
              ),
            ),
          Positioned(
            left: thumbCenter.dx - thumbRadius,
            top: thumbCenter.dy - thumbRadius,
            width: thumbRadius * 2,
            height: thumbRadius * 2,
            child: hasThumbMedia
                ? ClipOval(
                    child: LoopingMediaWidget(
                      mediaPath: spawn.info.thumbMediaPath,
                      fit: BoxFit.cover,
                    ),
                  )
                : Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: spawn.info.thumbColor,
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
