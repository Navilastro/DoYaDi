part of '../driving_mode_builders.dart';
extension _SharedBuildersExt<T extends StatefulWidget> on DrivingModeBuildMixin<T> {
  // ──────────────────────────────────────────────────────────────────────────
  // Yardımcılar
  // ──────────────────────────────────────────────────────────────────────────

  /// TrackPoint (Mini Joystick) ve Kare Merkezleme Butonu wrapper'ı.
  /// Mod 0, 1, 2, 3, 4, 6 ve 7'de geçerlidir.
  /// Mod 6 ve 7'deki butonlarla çakışmayacak şekilde ama olabildiğince merkezde yerleşir.
  Widget _withTrackPoint(
    AppSettings s,
    Size size,
    Widget child, {
    int mode = 0,
  }) {
    const supportedModes = [0, 1, 2, 3, 4, 6, 7];
    final bool isModeSupported = supportedModes.contains(mode);

    final bool showTrackPoint = isModeSupported && s.gyroLookEnabled && s.gyroLookStyle == 1;
    final bool showRecenterBtn = isModeSupported && s.gyroCenterMode == 3;

    if (!showTrackPoint && !showRecenterBtn) return child;

    const double joySize = 40.0;
    const double gap = 8.0;
    final double centerX = size.width / 2;
    final double centerY = size.height / 2;

    // Y ekseni hesaplama (Mod 6 ve 7 butonlarıyla çakışmayacak şekilde ama olabildiğince merkezde)
    double targetY;
    if (mode == 6) {
      // Mod 6: Ortada direksiyon korna butonu var (hubDiameter)
      final minDim = math.min(size.width, size.height);
      final hubDiameter = (minDim / 2.2) * 0.70;
      final hubTop = (size.height - hubDiameter) / 2;
      // Korna dairesinin hemen üstünde
      targetY = hubTop - joySize - 10.0;
    } else if (mode == 7) {
      // Mod 7: Ortada 4 buton var. En üstteki buton: bottomY - 55 (bottomY = size.height - 130)
      final double bottomY = size.height - 130;
      final double topButtonTop = bottomY - 55;
      // 4 butonun hemen üstünde
      targetY = topButtonTop - joySize - 10.0;
    } else {
      // Mod 0, 1, 2, 3, 4: Tam ortada
      targetY = centerY - joySize / 2;
    }

    final List<Widget> overlays = [];

    if (showTrackPoint && showRecenterBtn) {
      // İkisi birden aktif: Yan yana, ekran merkezine simetrik
      final double trackPointLeft = centerX - joySize - (gap / 2);
      final double recenterBtnLeft = centerX + (gap / 2);

      overlays.add(
        Positioned(
          left: trackPointLeft,
          top: targetY,
          width: joySize,
          height: joySize,
          child: _buildTrackPointWidget(joySize),
        ),
      );

      overlays.add(
        Positioned(
          left: recenterBtnLeft,
          top: targetY,
          width: joySize,
          height: joySize,
          child: _buildMiniRecenterButton(s, joySize),
        ),
      );
    } else if (showTrackPoint) {
      // Sadece TrackPoint aktif: Tam merkezde
      overlays.add(
        Positioned(
          left: centerX - joySize / 2,
          top: targetY,
          width: joySize,
          height: joySize,
          child: _buildTrackPointWidget(joySize),
        ),
      );
    } else if (showRecenterBtn) {
      // Sadece Kare Merkezleme Butonu aktif: Tam merkezde
      overlays.add(
        Positioned(
          left: centerX - joySize / 2,
          top: targetY,
          width: joySize,
          height: joySize,
          child: _buildMiniRecenterButton(s, joySize),
        ),
      );
    }

    return Stack(
      children: [
        child,
        ...overlays,
      ],
    );
  }

  Widget _buildTrackPointWidget(double joySize) {
    return Opacity(
      opacity: 0.65,
      child: JoystickWidget(
        radius: joySize / 2,
        baseColor: Colors.black.withValues(alpha: 0.2),
        thumbColor: Colors.redAccent,
        mode: JoystickMode.fixed,
        onChanged: (x, y) {
          setState(() {
            joy1x = x;
            joy1y = y;
          });
        },
      ),
    );
  }

  Widget _buildMiniRecenterButton(AppSettings s, double size) {
    return Opacity(
      opacity: 0.8,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          SensorManager().recenterGyro();
          HapticManager().triggerMedium(s);
        },
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: const Color(0xFF0E1322).withValues(alpha: 0.85),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: s.detailColor.withValues(alpha: 0.75),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.45),
                blurRadius: 6,
                spreadRadius: 1,
              ),
            ],
          ),
          child: Center(
            child: Icon(
              Icons.center_focus_strong,
              color: s.detailColor,
              size: size * 0.55,
            ),
          ),
        ),
      ),
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
