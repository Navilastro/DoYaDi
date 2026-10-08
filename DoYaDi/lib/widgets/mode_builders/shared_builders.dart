part of '../driving_mode_builders.dart';
extension _SharedBuildersExt<T extends StatefulWidget> on DrivingModeBuildMixin<T> {
  // ──────────────────────────────────────────────────────────────────────────
  // Yardımcılar
  // ──────────────────────────────────────────────────────────────────────────

  /// TrackPoint (Mini Joystick) wrapper (Mod 0-4 için)
  Widget _withTrackPoint(AppSettings s, Size size, Widget child) {
    if (!s.gyroLookEnabled || s.gyroLookStyle != 1) return child;
    
    final double joySize = 40.0; // küçük kırmızı nokta
    return Stack(
      children: [
        child,
        Positioned(
          left: (size.width - joySize) / 2,
          top: (size.height - joySize) / 2,
          width: joySize,
          height: joySize,
          child: Opacity(
            opacity: 0.6,
            child: JoystickWidget(
              radius: joySize / 2,
              baseColor: Colors.black.withValues(alpha: 0.1),
              thumbColor: Colors.redAccent,
              mode: JoystickMode.fixed,
              onChanged: (x, y) {
                setState(() {
                  joy1x = x;
                  joy1y = y;
                });
              },
            ),
          ),
        ),
      ],
    );
  }

  /// Pedal sütunu (fren veya gaz)
  Widget buildPedalColumn(
    AppSettings s, {
    required bool isBrake,
    required int tapKey,
  }) {
    return Stack(
      children: [
        Positioned.fill(
          child: Listener(
            behavior: HitTestBehavior.opaque,
            onPointerDown: (e) => onPedalDown(e, !isBrake, tapKey: tapKey),
            onPointerMove: (e) => onPedalMove(e, s),
            onPointerUp: onPedalUp,
            onPointerCancel: onPedalUp,
            child: RepaintBoundary(
              child: CustomPaint(
                painter: PedalPainter(
                  fillPercentage: isBrake ? brakePercentage : gasPercentage,
                  baseColor: isBrake ? s.brakeColor : s.gasColor,
                  bgColor: s.pedalBgColor,
                  yetsoreColor: s.yetsoreColor,
                ),
                child: const SizedBox.expand(),
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// 2x2 center grid (k1-k4) + opsiyonel k5
  Widget buildMiddle2x2(
    AppSettings s, {
    required int k1,
    required int k2,
    required int k3,
    required int k4,
    int? k5,
  }) {
    final color = s.detailColor;
    return Column(
      children: [
        Expanded(
          child: Row(
            children: [
              Expanded(
                child: TapZone(
                  label: '${AppTranslations.getText('key_prefix')} $k1',
                  color: color,
                  isActive: pressedKeys.contains(k1),
                  onDown: () => handleButtonDown(k1),
                  onUp: () => handleButtonUp(k1),
                ),
              ),
              Expanded(
                child: TapZone(
                  label: '${AppTranslations.getText('key_prefix')} $k2',
                  color: color,
                  isActive: pressedKeys.contains(k2),
                  onDown: () => handleButtonDown(k2),
                  onUp: () => handleButtonUp(k2),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: Row(
            children: [
              Expanded(
                child: TapZone(
                  label: '${AppTranslations.getText('key_prefix')} $k3',
                  color: color,
                  isActive: pressedKeys.contains(k3),
                  onDown: () => handleButtonDown(k3),
                  onUp: () => handleButtonUp(k3),
                ),
              ),
              Expanded(
                child: TapZone(
                  label: '${AppTranslations.getText('key_prefix')} $k4',
                  color: color,
                  isActive: pressedKeys.contains(k4),
                  onDown: () => handleButtonDown(k4),
                  onUp: () => handleButtonUp(k4),
                ),
              ),
            ],
          ),
        ),
        if (k5 != null)
          Expanded(
            child: TapZone(
              label: '${AppTranslations.getText('key_prefix')} $k5',
              color: color,
              isActive: pressedKeys.contains(k5),
              onDown: () => handleButtonDown(k5),
              onUp: () => handleButtonUp(k5),
            ),
          ),
      ],
    );
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Pedal İkonu İvmelenme Yardımcısı
  // ──────────────────────────────────────────────────────────────────────────
  void _startPedalIconAcceleration(bool isGas, AppSettings s) {
    final rate = s.pedalIconAccelerationRate; // saniye (0→%100)
    // Her frame'de güncelleme yap (60 Hz tick'te çağrılır)
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _pedalIconAccelTick(isGas, rate);
    });
  }

  void _pedalIconAccelTick(bool isGas, double rate) {
    if (!mounted) return;
    final pressed = isGas ? gasPedalIconPressed : brakePedalIconPressed;
    if (!pressed) return;

    setState(() {
      final increment = 1.0 / (rate * 60); // 60 fps varsayımı
      if (isGas) {
        gasPedalIconValue = (gasPedalIconValue + increment).clamp(0.0, 1.0);
        gasPercentage = gasPedalIconValue;
      } else {
        brakePedalIconValue = (brakePedalIconValue + increment).clamp(0.0, 1.0);
        brakePercentage = brakePedalIconValue;
      }
    });

    // Sonraki frame'i planla
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _pedalIconAccelTick(isGas, rate);
    });
  }

  // ──────────────────────────────────────────────────────────────────────────
  // MOD 6: Görsel Sürüş — Direksiyon simidi + Gaz/Fren
}
