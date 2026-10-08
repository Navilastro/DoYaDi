part of '../driving_mode_builders.dart';
extension _Mode0To4BuilderExt<T extends StatefulWidget> on DrivingModeBuildMixin<T> {
  // ──────────────────────────────────────────────────────────────────────────
  // MOD 0: Tek ekran, orta çizgiden sağ-gaz sol-fren
  // ──────────────────────────────────────────────────────────────────────────
  Widget buildMode0(AppSettings s, Size size) {
    return _withTrackPoint(s, size, Stack(
      children: [
        // Tam ekran Listener — gaz/fren
        Positioned.fill(
          child: Listener(
            behavior: HitTestBehavior.opaque,
            onPointerDown: (e) => onPedalDown(
              e,
              e.localPosition.dx >= size.width / 2,
              tapKey: e.localPosition.dx >= size.width / 2 ? s.gasTap : s.brakeTap,
            ),
            onPointerMove: (e) => onPedalMove(e, s),
            onPointerUp: onPedalUp,
            onPointerCancel: onPedalUp,
            child: RepaintBoundary(
              child: CustomPaint(
                painter: Mode0Painter(
                  gasPercentage: gasPercentage,
                  brakePercentage: brakePercentage,
                  isGas: mod0IsGas,
                  hasActive: mod0ActivePointer != null,
                  gasColor: s.gasColor,
                  brakeColor: s.brakeColor,
                  bgColor: s.pedalBgColor,
                  yetsoreColor: s.yetsoreColor,
                ),
                child: const SizedBox.expand(),
              ),
            ),
          ),
        ),

        // Center divider line
        Positioned(
          left: size.width / 2 - 1,
          top: 0,
          bottom: 0,
          width: 2,
          child: Container(color: Colors.white12),
        ),
      ],
    ));
  }

  // ──────────────────────────────────────────────────────────────────────────
  // MOD 1: Sol Fren | Sağ Gaz
  // ──────────────────────────────────────────────────────────────────────────
  Widget buildMode1(AppSettings s, Size size) {
    return _withTrackPoint(s, size, Row(
      children: [
        // Left side - Brake
        Expanded(
          child: Stack(
            children: [
              Positioned.fill(
                child: Listener(
                  behavior: HitTestBehavior.opaque,
                  onPointerDown: (e) => onPedalDown(e, false, tapKey: s.brakeTap),
                  onPointerMove: (e) => onPedalMove(e, s),
                  onPointerUp: onPedalUp,
                  onPointerCancel: onPedalUp,
                  child: RepaintBoundary(
                    child: CustomPaint(
                      painter: PedalPainter(
                        fillPercentage: brakePercentage,
                        baseColor: s.brakeColor,
                        bgColor: s.pedalBgColor,
                        yetsoreColor: s.yetsoreColor,
                      ),
                      child: const SizedBox.expand(),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        // Right side - Gas
        Expanded(
          child: Stack(
            children: [
              Positioned.fill(
                child: Listener(
                  behavior: HitTestBehavior.opaque,
                  onPointerDown: (e) => onPedalDown(e, true, tapKey: s.gasTap),
                  onPointerMove: (e) => onPedalMove(e, s),
                  onPointerUp: onPedalUp,
                  onPointerCancel: onPedalUp,
                  child: RepaintBoundary(
                    child: CustomPaint(
                      painter: PedalPainter(
                        fillPercentage: gasPercentage,
                        baseColor: s.gasColor,
                        bgColor: s.pedalBgColor,
                        yetsoreColor: s.yetsoreColor,
                      ),
                      child: const SizedBox.expand(),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    ));
  }

  // ──────────────────────────────────────────────────────────────────────────
  // MOD 2: %30 Fren | %40 Orta 2x2 kare butonlar | %30 Gaz
  // ──────────────────────────────────────────────────────────────────────────
  Widget buildMode2(AppSettings s, Size size) {
    return _withTrackPoint(s, size, Row(
      children: [
        SizedBox(
          width: size.width * 0.30,
          child: buildPedalColumn(s, isBrake: true, tapKey: s.brakeTap),
        ),
        SizedBox(
          width: size.width * 0.40,
          child: buildMiddle2x2(
            s,
            k1: s.m2Key1,
            k2: s.m2Key2,
            k3: s.m2Key3,
            k4: s.m2Key4,
          ),
        ),
        SizedBox(
          width: size.width * 0.30,
          child: buildPedalColumn(s, isBrake: false, tapKey: s.gasTap),
        ),
      ],
    ));
  }

  // ──────────────────────────────────────────────────────────────────────────
  // MOD 3: Mod 2 + Orta alt ek tuş
  // ──────────────────────────────────────────────────────────────────────────
  Widget buildMode3(AppSettings s, Size size) {
    return _withTrackPoint(s, size, Row(
      children: [
        SizedBox(
          width: size.width * 0.30,
          child: buildPedalColumn(s, isBrake: true, tapKey: s.brakeTap),
        ),
        SizedBox(
          width: size.width * 0.40,
          child: buildMiddle2x2(
            s,
            k1: s.m3Key1,
            k2: s.m3Key2,
            k3: s.m3Key3,
            k4: s.m3Key4,
            k5: s.m3Key5,
          ),
        ),
        SizedBox(
          width: size.width * 0.30,
          child: buildPedalColumn(s, isBrake: false, tapKey: s.gasTap),
        ),
      ],
    ));
  }

  // ──────────────────────────────────────────────────────────────────────────
  // MOD 4: Mod 3 ama alt tam genişlik tuş
  // ──────────────────────────────────────────────────────────────────────────
  Widget buildMode4(AppSettings s, Size size) {
    return _withTrackPoint(s, size, Column(
      children: [
        Expanded(
          child: Row(
            children: [
              SizedBox(
                width: size.width * 0.30,
                child: buildPedalColumn(s, isBrake: true, tapKey: s.brakeTap),
              ),
              SizedBox(
                width: size.width * 0.40,
                child: buildMiddle2x2(
                  s,
                  k1: s.m4Key1,
                  k2: s.m4Key2,
                  k3: s.m4Key3,
                  k4: s.m4Key4,
                ),
              ),
              SizedBox(
                width: size.width * 0.30,
                child: buildPedalColumn(
                  s,
                  isBrake: false,
                  tapKey: s.gasTap,
                ),
              ),
            ],
          ),
        ),
        // Alt tam genişlik tuş
        SizedBox(
          height: size.height * 0.18,
          child: TapZone(
            label: '${AppTranslations.getText('key_prefix')} ${s.m4KeyBottom}',
            color: s.detailColor,
            isActive: pressedKeys.contains(s.m4KeyBottom),
            onDown: () => handleButtonDown(s.m4KeyBottom),
            onUp: () => handleButtonUp(s.m4KeyBottom),
          ),
        ),
      ],
    ));
  }
}
