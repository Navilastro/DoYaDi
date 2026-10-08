part of '../driving_mode_builders.dart';
extension _Mode6BuilderExt<T extends StatefulWidget> on DrivingModeBuildMixin<T> {
  // ──────────────────────────────────────────────────────────────────────────
  Widget buildMode6(AppSettings s, Size size) {
    final sensor = SensorManager();
    final steerRad = steeringAngle * 75.0 * math.pi / 180.0;

    // Pedal kontrol widget'ı (Bar veya İkon)
    Widget gasControl;
    Widget brakeControl;

    if (s.mod6PedalStyle == 1) {
      // Pedal İkonu (Listener ile dokunma ve hafif sürükleme kesilmelerini önler)
      gasControl = Listener(
        behavior: HitTestBehavior.opaque,
        onPointerDown: (_) {
          gasPedalIconPressed = true;
          _startPedalIconAcceleration(true, s);
          HapticManager().triggerLight(s);
        },
        onPointerMove: (_) {
          // Parmağın hafif kayması/titremesi ivmelenmeyi KESMEZ.
        },
        onPointerUp: (_) {
          gasPedalIconPressed = false;
          setState(() {
            gasPedalIconValue = 0.0;
            gasPercentage = 0.0;
          });
        },
        onPointerCancel: (_) {
          gasPedalIconPressed = false;
          setState(() {
            gasPedalIconValue = 0.0;
            gasPercentage = 0.0;
          });
        },
        child: RepaintBoundary(
          child: CustomPaint(
            painter: PedalIconPainter(
              fillPercentage: gasPedalIconValue,
              baseColor: s.gasIconColor,
              isGas: true,
            ),
            child: const SizedBox.expand(),
          ),
        ),
      );
      brakeControl = Listener(
        behavior: HitTestBehavior.opaque,
        onPointerDown: (_) {
          brakePedalIconPressed = true;
          _startPedalIconAcceleration(false, s);
          HapticManager().triggerLight(s);
        },
        onPointerMove: (_) {
          // Parmağın hafif kayması/titremesi ivmelenmeyi KESMEZ.
        },
        onPointerUp: (_) {
          brakePedalIconPressed = false;
          setState(() {
            brakePedalIconValue = 0.0;
            brakePercentage = 0.0;
          });
        },
        onPointerCancel: (_) {
          brakePedalIconPressed = false;
          setState(() {
            brakePedalIconValue = 0.0;
            brakePercentage = 0.0;
          });
        },
        child: RepaintBoundary(
          child: CustomPaint(
            painter: PedalIconPainter(
              fillPercentage: brakePedalIconValue,
              baseColor: s.brakeIconColor,
              isGas: false,
            ),
            child: const SizedBox.expand(),
          ),
        ),
      );
    } else {
      // Bar (varsayılan)
      gasControl = Listener(
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
      );
      brakeControl = Listener(
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
      );
    }

    // ── Direksiyon Kontrolü ──
    Widget steeringWidget;
    if (s.mod6SteeringStyle == 1) {
      // Dinamik Sabit Direksiyon (Varsayılan)
      final deg = sensor.pitchDeg; // direksiyon açı hesabı
      steeringWidget = RepaintBoundary(
        child: CustomPaint(
          painter: DynamicSteeringWheelPainter(
            steeringRatio: steeringAngle,
            totalAngleDegrees: deg * (s.steeringAngle / 180.0),
            turnRightColor: s.steeringTurnRightColor,
            turnLeftColor: s.steeringTurnLeftColor,
            baseColor: s.steeringWheelColor,
          ),
          child: const SizedBox.expand(),
        ),
      );
    } else {
      // Dönen Direksiyon
      steeringWidget = RepaintBoundary(
        child: CustomPaint(
          painter: SteeringWheelPainter(
            angle: steerRad,
            fullTurns: sensor.fullTurns,
            rimColor: s.steeringIndicatorColor,
          ),
          child: const SizedBox.expand(),
        ),
      );
    }

    // ── Debriyaj Kontrolü (Opsiyonel) ──
    Widget? clutchWidget;
    if (s.mod6EnableClutch) {
      if (s.clutchType == 0) {
        // Buton
        clutchWidget = Listener(
          onPointerDown: (_) {
            handleButtonDown(s.clutchKey);
            HapticManager().triggerLight(s);
          },
          onPointerUp: (_) => handleButtonUp(s.clutchKey),
          onPointerCancel: (_) => handleButtonUp(s.clutchKey),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: pressedKeys.contains(s.clutchKey)
                  ? s.clutchButtonColor.withValues(alpha: 0.8)
                  : s.clutchButtonColor,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: s.clutchColor.withValues(alpha: 0.5)),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.tune, color: Colors.cyanAccent, size: 16),
                SizedBox(width: 6),
                Text(
                  'DEBRİYAJ',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        );
      } else if (s.clutchType == 2) {
        // İkon (İvmelenmeli)
        clutchWidget = Listener(
          behavior: HitTestBehavior.opaque,
          onPointerDown: (_) {
            clutchIconPressed = true;
            startClutchIconAcceleration(s);
            HapticManager().triggerLight(s);
          },
          onPointerUp: (_) {
            clutchIconPressed = false;
            setState(() {
              clutchIconValue = 0.0;
              clutchPercentage = 0.0;
            });
          },
          onPointerCancel: (_) {
            clutchIconPressed = false;
            setState(() {
              clutchIconValue = 0.0;
              clutchPercentage = 0.0;
            });
          },
          child: SizedBox(
            width: 70,
            height: 70,
            child: CustomPaint(
              painter: PedalIconPainter(
                fillPercentage: clutchIconValue,
                baseColor: s.clutchIconColor,
                isGas: false,
              ),
            ),
          ),
        );
      } else {
        // Bar (Slider) - Gerçek Dikey Analog Kaydırıcı
        clutchWidget = SizedBox(
          width: 60,
          height: 120,
          child: Builder(
            builder: (bctx) {
              return Listener(
                behavior: HitTestBehavior.opaque,
                onPointerDown: (e) {
                  final box = bctx.findRenderObject() as RenderBox?;
                  if (box != null) {
                    final localPos = box.globalToLocal(e.position);
                    final pct = (1.0 - (localPos.dy / box.size.height)).clamp(0.0, 1.0);
                    setState(() => clutchPercentage = pct);
                  }
                  HapticManager().triggerLight(s);
                },
                onPointerMove: (e) {
                  final box = bctx.findRenderObject() as RenderBox?;
                  if (box != null) {
                    final localPos = box.globalToLocal(e.position);
                    final pct = (1.0 - (localPos.dy / box.size.height)).clamp(0.0, 1.0);
                    setState(() => clutchPercentage = pct);
                  }
                },
                onPointerUp: (_) => setState(() => clutchPercentage = 0.0),
                onPointerCancel: (_) => setState(() => clutchPercentage = 0.0),
                child: CustomPaint(
                  painter: PedalPainter(
                    fillPercentage: clutchPercentage,
                    baseColor: s.clutchColor,
                    bgColor: s.pedalBgColor,
                    yetsoreColor: s.clutchYetsoreColor,
                  ),
                ),
              );
            },
          ),
        );
      }
    }

    // ── El Freni Kontrolü (Opsiyonel) ──
    Widget? handbrakeWidget;
    if (s.mod6EnableHandbrake) {
      if (s.handbrakeType == 1) {
        // Bar (Slider) - Gerçek Dikey Analog Kaydırıcı (Sağ Analog Yatay Eksene Gönderilir)
        handbrakeWidget = SizedBox(
          width: 60,
          height: 120,
          child: Builder(
            builder: (bctx) {
              return Listener(
                behavior: HitTestBehavior.opaque,
                onPointerDown: (e) {
                  final box = bctx.findRenderObject() as RenderBox?;
                  if (box != null) {
                    final localPos = box.globalToLocal(e.position);
                    final pct = (1.0 - (localPos.dy / box.size.height)).clamp(0.0, 1.0);
                    setState(() => handbrakePercentage = pct);
                  }
                  HapticManager().triggerLight(s);
                },
                onPointerMove: (e) {
                  final box = bctx.findRenderObject() as RenderBox?;
                  if (box != null) {
                    final localPos = box.globalToLocal(e.position);
                    final pct = (1.0 - (localPos.dy / box.size.height)).clamp(0.0, 1.0);
                    setState(() => handbrakePercentage = pct);
                  }
                },
                onPointerUp: (_) => setState(() => handbrakePercentage = 0.0),
                onPointerCancel: (_) => setState(() => handbrakePercentage = 0.0),
                child: CustomPaint(
                  painter: PedalPainter(
                    fillPercentage: handbrakePercentage,
                    baseColor: s.handbrakeColor,
                    bgColor: s.pedalBgColor,
                    yetsoreColor: s.handbrakeYetsoreColor,
                  ),
                ),
              );
            },
          ),
        );
      } else {
        // Buton (Dijital Tuş)
        handbrakeWidget = Listener(
          onPointerDown: (_) {
            handleButtonDown(s.handbrakeKey);
            HapticManager().triggerLight(s);
          },
          onPointerUp: (_) => handleButtonUp(s.handbrakeKey),
          onPointerCancel: (_) => handleButtonUp(s.handbrakeKey),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: pressedKeys.contains(s.handbrakeKey)
                  ? s.handbrakeButtonColor.withValues(alpha: 0.8)
                  : s.handbrakeButtonColor,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: s.handbrakeColor.withValues(alpha: 0.5)),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.sports_motorsports, color: Colors.redAccent, size: 16),
                SizedBox(width: 6),
                Text(
                  'EL FRENİ',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        );
      }
    }

    // Helper: Slot ID -> Widget Map
    Widget? getSlotWidget(int slotId) {
      if (slotId == 1) return brakeControl;
      if (slotId == 2) return gasControl;
      if (slotId == 3 && s.mod6EnableClutch) return clutchWidget;
      if (slotId == 4 && s.mod6EnableHandbrake) return handbrakeWidget;
      return null;
    }

    final leftWidget = getSlotWidget(s.mod6SlotLeft);
    final leftInnerWidget = getSlotWidget(s.mod6SlotLeftInner);
    final rightInnerWidget = getSlotWidget(s.mod6SlotRightInner);
    final rightWidget = getSlotWidget(s.mod6SlotRight);

    // Helper: Slot Widget'ını alta ortalayarak sarmala
    Widget wrapSlotWidget(Widget child) {
      return Align(
        alignment: Alignment.bottomCenter,
        child: child,
      );
    }

    return Stack(
      children: [
        // ── 3. ORTA ALAN: Direksiyon Simidi (Ekranın %32'si - Ortada) ──
        Positioned(
          left: size.width * 0.34,
          right: size.width * 0.34,
          top: 0,
          bottom: 0,
          child: steeringWidget,
        ),

        // ── DIREKSİYON GÖBEĞİNDEKİ KORNA BUTONU (Mavi Göbek Çapında) ──
        Builder(
          builder: (_) {
            final minDim = math.min(size.width, size.height);
            final hubDiameter = (minDim / 2.2) * 0.70; // Mavi göbek çapı
            final isHornPressed = pressedKeys.contains(s.mod6HornKey);

            return Positioned(
              left: (size.width - hubDiameter) / 2,
              top: (size.height - hubDiameter) / 2,
              width: hubDiameter,
              height: hubDiameter,
              child: Listener(
                behavior: HitTestBehavior.opaque,
                onPointerDown: (_) {
                  handleButtonDown(s.mod6HornKey);
                  HapticManager().triggerMedium(s);
                },
                onPointerUp: (_) => handleButtonUp(s.mod6HornKey),
                onPointerCancel: (_) => handleButtonUp(s.mod6HornKey),
                child: Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isHornPressed
                        ? Colors.cyanAccent.withValues(alpha: 0.35)
                        : Colors.transparent,
                    border: isHornPressed
                        ? Border.all(color: Colors.cyanAccent, width: 2)
                        : null,
                  ),
                  child: isHornPressed
                      ? const Center(
                          child: Icon(Icons.volume_up, color: Colors.cyanAccent, size: 20),
                        )
                      : null,
                ),
              ),
            );
          },
        ),

        // ── 1. SOL DIŞ SLOT (Sol Kenar - Daha Büyük Ölçek: %17 genişlik, %82 yükseklik) ──
        if (leftWidget != null)
          Positioned(
            left: size.width * 0.01,
            bottom: size.height * 0.02,
            width: size.width * 0.17,
            height: size.height * 0.82,
            child: wrapSlotWidget(leftWidget),
          ),

        // ── 2. SOL İÇ SLOT (Orta-Sol - Daha Küçük Ölçek: %15 genişlik, %68 yükseklik) ──
        if (leftInnerWidget != null)
          Positioned(
            left: size.width * 0.185,
            bottom: size.height * 0.02,
            width: size.width * 0.15,
            height: size.height * 0.68,
            child: wrapSlotWidget(leftInnerWidget),
          ),

        // ── 4. SAĞ İÇ SLOT (Orta-Sağ - Daha Küçük Ölçek: %15 genişlik, %68 yükseklik) ──
        if (rightInnerWidget != null)
          Positioned(
            right: size.width * 0.185,
            bottom: size.height * 0.02,
            width: size.width * 0.15,
            height: size.height * 0.68,
            child: wrapSlotWidget(rightInnerWidget),
          ),

        // ── 5. SAĞ DIŞ SLOT (Sağ Kenar - Daha Büyük Ölçek: %17 genişlik, %82 yükseklik) ──
        if (rightWidget != null)
          Positioned(
            right: size.width * 0.01,
            bottom: size.height * 0.02,
            width: size.width * 0.17,
            height: size.height * 0.82,
            child: wrapSlotWidget(rightWidget),
          ),
      ],
    );
  }
}
