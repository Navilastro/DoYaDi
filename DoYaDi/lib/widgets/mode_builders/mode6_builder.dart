part of '../driving_mode_builders.dart';
extension _Mode6BuilderExt<T extends StatefulWidget> on DrivingModeBuildMixin<T> {
  // ──────────────────────────────────────────────────────────────────────────
  Widget buildMode6(AppSettings s, Size size) {
    final sensor = SensorManager();
    final steerRad = steeringAngle * 75.0 * math.pi / 180.0;

    final gasBg = s.separatePedalBg ? s.rightPedalBgColor : s.pedalBgColor;
    final gasBgMedia = s.separatePedalBg ? s.rightPedalBgMediaPath : s.pedalBarBgMediaPath;
    final brakeBg = s.separatePedalBg ? s.leftPedalBgColor : s.pedalBgColor;
    final brakeBgMedia = s.separatePedalBg ? s.leftPedalBgMediaPath : s.pedalBarBgMediaPath;

    Widget buildTouchBtn({
      required String label,
      required IconData icon,
      required Color iconColor,
      required Color bgColor,
      required Color borderColor,
      required bool isPressed,
      String? mediaPath,
    }) {
      final hasMedia = AppMediaHelper.hasMedia(mediaPath);
      final fg = hasMedia ? Colors.white : s.contrastTextFor(bgColor);
      final labelRow = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: hasMedia ? Colors.white : iconColor, size: 16),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: fg,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      );
      if (!hasMedia) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: isPressed ? bgColor.withValues(alpha: 0.8) : bgColor,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: borderColor.withValues(alpha: 0.5)),
          ),
          child: labelRow,
        );
      }
      return ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Stack(
          children: [
            Positioned.fill(
              child: LoopingMediaWidget(mediaPath: mediaPath, fit: BoxFit.cover),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: isPressed ? bgColor.withValues(alpha: 0.45) : Colors.transparent,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: borderColor.withValues(alpha: 0.7)),
              ),
              child: BlurredTextChip(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                child: labelRow,
              ),
            ),
          ],
        ),
      );
    }

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
        child: CustomizablePedalIcon(
          fillPercentage: gasPedalIconValue,
          baseColor: s.gasIconColor,
          isGas: true,
          mediaPath: s.mod6AccelIconsMediaPath,
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
        child: CustomizablePedalIcon(
          fillPercentage: brakePedalIconValue,
          baseColor: s.brakeIconColor,
          isGas: false,
          mediaPath: s.mod6AccelIconsMediaPath,
        ),
      );
    } else {
      // Bar (varsayılan)
      gasControl = Listener(
        onPointerDown: (e) => onPedalDown(e, true, tapKey: s.gasTap),
        onPointerMove: (e) => onPedalMove(e, s),
        onPointerUp: onPedalUp,
        onPointerCancel: onPedalUp,
        child: CustomizablePedalBar(
          fillPercentage: gasPercentage,
          baseColor: s.gasColor,
          bgColor: gasBg,
          yetsoreColor: s.yetsoreColor,
          fillMediaPath: s.gasBarMediaPath,
          bgMediaPath: gasBgMedia,
          yetsoreMediaPath: s.yetsoreMediaPath,
        ),
      );
      brakeControl = Listener(
        onPointerDown: (e) => onPedalDown(e, false, tapKey: s.brakeTap),
        onPointerMove: (e) => onPedalMove(e, s),
        onPointerUp: onPedalUp,
        onPointerCancel: onPedalUp,
        child: CustomizablePedalBar(
          fillPercentage: brakePercentage,
          baseColor: s.brakeColor,
          bgColor: brakeBg,
          yetsoreColor: s.yetsoreColor,
          fillMediaPath: s.brakeBarMediaPath,
          bgMediaPath: brakeBgMedia,
          yetsoreMediaPath: s.yetsoreMediaPath,
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
            rimColor: s.steeringWheelColor,
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
          child: buildTouchBtn(
            label: 'DEBRİYAJ',
            icon: Icons.tune,
            iconColor: s.clutchColor,
            bgColor: s.clutchButtonColor,
            borderColor: s.clutchColor,
            isPressed: pressedKeys.contains(s.clutchKey),
            mediaPath: s.mod6ButtonsMediaPath,
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
            child: CustomizablePedalIcon(
              fillPercentage: clutchIconValue,
              baseColor: s.clutchIconColor,
              isGas: false,
              mediaPath: s.mod6AccelIconsMediaPath,
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
                child: CustomizablePedalBar(
                  fillPercentage: clutchPercentage,
                  baseColor: s.clutchColor,
                  bgColor: s.pedalBgColor,
                  yetsoreColor: s.clutchYetsoreColor,
                  fillMediaPath: s.clutchBarMediaPath,
                  bgMediaPath: s.pedalBarBgMediaPath,
                  yetsoreMediaPath: s.yetsoreMediaPath,
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
                child: CustomizablePedalBar(
                  fillPercentage: handbrakePercentage,
                  baseColor: s.handbrakeColor,
                  bgColor: s.pedalBgColor,
                  yetsoreColor: s.handbrakeYetsoreColor,
                  fillMediaPath: s.handbrakeBarMediaPath,
                  bgMediaPath: s.pedalBarBgMediaPath,
                  yetsoreMediaPath: s.yetsoreMediaPath,
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
          child: buildTouchBtn(
            label: 'EL FRENİ',
            icon: Icons.sports_motorsports,
            iconColor: s.handbrakeColor,
            bgColor: s.handbrakeButtonColor,
            borderColor: s.handbrakeColor,
            isPressed: pressedKeys.contains(s.handbrakeKey),
            mediaPath: s.mod6ButtonsMediaPath,
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

    return _withTrackPoint(
      s,
      size,
      Stack(
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
            final hasHornMedia = AppMediaHelper.hasMedia(s.mod6HornMediaPath);
            final hornColor = s.mod6HornColor;
            final hornFg = hasHornMedia ? Colors.white : s.contrastTextFor(hornColor);

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
                child: ClipOval(
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      if (hasHornMedia)
                        LoopingMediaWidget(
                          mediaPath: s.mod6HornMediaPath,
                          fit: BoxFit.cover,
                        ),
                      Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: hasHornMedia
                              ? (isHornPressed
                                  ? hornColor.withValues(alpha: 0.45)
                                  : Colors.transparent)
                              : hornColor.withValues(alpha: isHornPressed ? 0.85 : 0.30),
                          border: Border.all(
                            color: hornColor.withValues(alpha: isHornPressed ? 1.0 : 0.7),
                            width: isHornPressed ? 2.5 : 1.5,
                          ),
                        ),
                        child: Center(
                          child: hasHornMedia
                              ? BlurredTextChip(
                                  borderRadius: BorderRadius.circular(20),
                                  padding: const EdgeInsets.all(6),
                                  child: Icon(
                                    Icons.volume_up,
                                    color: hornFg,
                                    size: isHornPressed ? 22 : 18,
                                  ),
                                )
                              : Icon(
                                  Icons.volume_up,
                                  color: hornFg.withValues(alpha: isHornPressed ? 1.0 : 0.75),
                                  size: isHornPressed ? 22 : 18,
                                ),
                        ),
                      ),
                    ],
                  ),
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
    ),
    mode: 6,
  );
  }
}
