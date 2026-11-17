part of '../driving_mode_builders.dart';

/// Mod 9 — Arcade Uçuş & Savaş Kontrolcüsü (Flight Stick / HOTAS)
/// War Thunder, DCS (Arcade) ve Microsoft Flight Simulator (Arcade) için özel tasarım:
///   - Sol Analog X (sThumbLX) : Roll  (Yatış — Sensör Roll veya HUD Dokunmatik Yoke)
///   - Sol Analog Y (sThumbLY) : Pitch (Yunuslama — Sensör Pitch veya HUD Dokunmatik Yoke)
///   - Sağ Tetik (RT / Gaz)    : İtki Kolu (Throttle %0–%100 + WEP / Afterburner)
///   - Sol Tetik (LT / Fren)   : Hava Freni / Tekerlek Freni (Airbrake)
///   - Sağ Analog (RX / RY)    : Serbest Bakış (Free Look Hat / Sensörle Bakış) veya Dümen (Yaw)
///   - LB / RB (1 / 2)         : Sol / Sağ Dümen (Rudder Pedals)
///   - A / B / X / Y (5/6/7/8) : Makineli Top, Füze/Bomba, Hedef Kilit, Flare/Chaff
///   - D-Pad & L3/Back/Start   : Flap Kademesi, İniş Takımı (Gear), Kamera Değiştir, Harita
extension _Mode9BuilderExt<T extends StatefulWidget> on DrivingModeBuildMixin<T> {
  Widget buildMode9(AppSettings s, Size size) {
    final sm = SensorManager();
    final throttleCol = s.mod9ThrottleColor;
    final wepCol = s.mod9WepColor;
    final avionicsCol = s.mod9AvionicsColor;
    final rudderCol = s.mod9RudderColor;
    final hudCol = s.mod9HudColor;
    final fireCol = s.mod9FireBtnColor;
    final weaponCol = s.mod9WeaponBtnColor;
    final hatCol = s.mod9HatSwitchColor;
    final hasBgMedia = AppMediaHelper.hasMedia(s.modeBackgroundMedia(9));
    final pageTxt = hasBgMedia
        ? Colors.white
        : s.contrastTextFor(s.modeBackgroundColor(9));

    final double activeRoll = flightTouchStickActive
        ? flightTouchRoll.clamp(-1.0, 1.0)
        : sm.flightRoll.clamp(-1.0, 1.0);
    final double activePitch = flightTouchStickActive
        ? flightTouchPitch.clamp(-1.0, 1.0)
        : sm.flightPitch.clamp(-1.0, 1.0);
    final double activeYaw = flightRudderTouch.abs() > 0.01
        ? flightRudderTouch.clamp(-1.0, 1.0)
        : sm.flightYaw.clamp(-1.0, 1.0);

    final double displayRollDeg = flightTouchStickActive
        ? activeRoll * 45.0
        : sm.flightRollDeg;
    final double displayPitchDeg = flightTouchStickActive
        ? activePitch * 45.0
        : sm.flightPitchDeg;
    final double displayYawDeg = flightRudderTouch.abs() > 0.01
        ? activeYaw * 35.0
        : sm.flightYawDeg;

    final bool isGunsFiring = pressedKeys.contains(s.m9FireKey);
    final bool isMissileFiring = pressedKeys.contains(s.m9MissileKey) ||
        pressedKeys.contains(s.m9HeavyGunKey) ||
        pressedKeys.contains(s.m9BombKey);
    final bool isWep = gasPercentage >= 0.95;

    return Container(
      color: Colors.transparent,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ══════════════════════════════════════════════════════════════
              // SOL PANEL: HOTAS İTKİ KOLU (THROTTLE), DÜMEN (YAW) & UÇUŞ SİSTEMLERİ
              // ══════════════════════════════════════════════════════════════
              SizedBox(
                width: 158,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // ── Sütun 1: Kademeli İtki Kolu (Throttle + WEP) ──
                    Expanded(
                      flex: 5,
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0A0F1D).withValues(alpha: 0.88),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: isWep
                                ? wepCol.withValues(alpha: 0.8)
                                : throttleCol.withValues(alpha: 0.35),
                            width: isWep ? 1.5 : 1.0,
                          ),
                        ),
                        child: Column(
                          children: [
                            // WEP / 100% Hızlı Tuş
                            GestureDetector(
                              onTap: () {
                                setState(() {
                                  gasPercentage = 1.0;
                                  flightWepActive = true;
                                });
                                HapticManager().triggerMedium(s);
                              },
                              child: Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(vertical: 4),
                                decoration: BoxDecoration(
                                  color: isWep
                                      ? wepCol.withValues(alpha: 0.28)
                                      : wepCol.withValues(alpha: 0.08),
                                  borderRadius: BorderRadius.circular(7),
                                  border: Border.all(
                                    color: isWep
                                        ? wepCol
                                        : wepCol.withValues(alpha: 0.45),
                                  ),
                                ),
                                child: Text(
                                  isWep ? '🔥 WEP' : 'WEP %100',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: isWep
                                        ? wepCol
                                        : wepCol.withValues(alpha: 0.85),
                                    fontSize: 9,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0.8,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 4),
                            // İtki Sürgüsü
                            Expanded(
                              child: ThrustLeverWidget(
                                value: gasPercentage.clamp(0.0, 1.0),
                                onChanged: (v) {
                                  setState(() {
                                    gasPercentage = v.clamp(0.0, 1.0);
                                    flightWepActive = gasPercentage >= 0.95;
                                  });
                                },
                                detents: s.flightThrustDetents,
                                color: isWep ? wepCol : throttleCol,
                              ),
                            ),
                            const SizedBox(height: 4),
                            // IDLE 0% Hızlı Kesme Tuşu
                            GestureDetector(
                              onTap: () {
                                setState(() {
                                  gasPercentage = 0.0;
                                  flightWepActive = false;
                                });
                                HapticManager().triggerLight(s);
                              },
                              child: Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(vertical: 4),
                                decoration: BoxDecoration(
                                  color: gasPercentage <= 0.01
                                      ? Colors.amber.withValues(alpha: 0.18)
                                      : Colors.white.withValues(alpha: 0.04),
                                  borderRadius: BorderRadius.circular(7),
                                  border: Border.all(
                                    color: gasPercentage <= 0.01
                                        ? Colors.amber
                                        : Colors.white24,
                                  ),
                                ),
                                child: Text(
                                  'IDLE %0',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: gasPercentage <= 0.01
                                        ? Colors.amber
                                        : Colors.white60,
                                    fontSize: 9,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),

                    // ── Sütun 2: Sistem Anahtarları (FLAP, GEAR, AIRBRAKE) + Dümen ──
                    Expanded(
                      flex: 4,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // FLAP Kademe Tuşu
                          Expanded(
                            child: _buildAvionicsButton(
                              label: flightFlapStage == 0
                                  ? 'FLAP: UP'
                                  : flightFlapStage == 1
                                  ? 'FLAP: CMB'
                                  : 'FLAP: LND',
                              subLabel:
                                  '${_shortFlightKeyLabel(s.m9FlapDownKey)}/${_shortFlightKeyLabel(s.m9FlapUpKey)}',
                              icon: Icons.layers,
                              isActive: flightFlapStage > 0,
                              activeColor: avionicsCol,
                              onTap: () {
                                setState(() {
                                  flightFlapStage = (flightFlapStage + 1) % 3;
                                });
                                // Flap açma veya toplama
                                final targetKey = flightFlapStage == 0
                                    ? s.m9FlapUpKey
                                    : s.m9FlapDownKey;
                                if (targetKey > 0) fireKey(targetKey);
                                HapticManager().triggerLight(s);
                              },
                            ),
                          ),
                          const SizedBox(height: 5),

                          // GEAR (İniş Takımı)
                          Expanded(
                            child: _buildAvionicsButton(
                              label: flightGearDown ? 'GEAR: DN' : 'GEAR: UP',
                              subLabel: _shortFlightKeyLabel(s.m9GearKey),
                              icon: Icons.flight_land,
                              isActive: flightGearDown,
                              activeColor: avionicsCol,
                              onTap: () {
                                setState(() {
                                  flightGearDown = !flightGearDown;
                                });
                                if (s.m9GearKey > 0) fireKey(s.m9GearKey);
                                HapticManager().triggerMedium(s);
                              },
                            ),
                          ),
                          const SizedBox(height: 5),

                          // AIRBRAKE / WHEEL BRAKE (LT + Atanan Tuş)
                          Expanded(
                            child: Listener(
                              onPointerDown: (_) {
                                setState(() {
                                  flightAirbrakeActive = !flightAirbrakeActive;
                                  brakePercentage = flightAirbrakeActive ? 1.0 : 0.0;
                                  if (s.m9AirbrakeKey > 0) {
                                    if (flightAirbrakeActive) {
                                      pressedKeys.add(s.m9AirbrakeKey);
                                    } else {
                                      pressedKeys.remove(s.m9AirbrakeKey);
                                    }
                                  }
                                });
                                HapticManager().triggerMedium(s);
                              },
                              child: _buildAvionicsCardContent(
                                label: flightAirbrakeActive ? 'BRK: ON' : 'AIRBRK',
                                subLabel: s.m9AirbrakeKey > 0
                                    ? 'LT + ${_shortFlightKeyLabel(s.m9AirbrakeKey)}'
                                    : 'LT',
                                icon: Icons.air,
                                isActive: flightAirbrakeActive || brakePercentage > 0.1,
                                activeColor: avionicsCol,
                              ),
                            ),
                          ),
                          const SizedBox(height: 5),

                          // SOL / SAĞ DÜMEN (RUDDER / YAW)
                          SizedBox(
                            height: 56,
                            child: Column(
                              children: [
                                BlurredTextChip(
                                  enabled: hasBgMedia,
                                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                  child: Text(
                                    'DÜMEN (YAW)',
                                    style: TextStyle(
                                      color: pageTxt.withValues(alpha: 0.65),
                                      fontSize: 8,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 0.8,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Expanded(
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: _buildRudderPedalButton(
                                          label: '◄ ${_shortFlightKeyLabel(s.m9RudderLeftKey)}',
                                          isActive: flightRudderTouch < -0.1,
                                          color: rudderCol,
                                          onDown: () {
                                            setState(() {
                                              flightRudderTouch = -1.0;
                                              if (s.m9RudderLeftKey > 0) {
                                                pressedKeys.add(s.m9RudderLeftKey);
                                              }
                                            });
                                            HapticManager().triggerLight(s);
                                          },
                                          onUp: () {
                                            setState(() {
                                              if (flightRudderTouch < 0) {
                                                flightRudderTouch = 0.0;
                                              }
                                              if (s.m9RudderLeftKey > 0) {
                                                pressedKeys.remove(s.m9RudderLeftKey);
                                              }
                                            });
                                          },
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      Expanded(
                                        child: _buildRudderPedalButton(
                                          label: '${_shortFlightKeyLabel(s.m9RudderRightKey)} ►',
                                          isActive: flightRudderTouch > 0.1,
                                          color: rudderCol,
                                          onDown: () {
                                            setState(() {
                                              flightRudderTouch = 1.0;
                                              if (s.m9RudderRightKey > 0) {
                                                pressedKeys.add(s.m9RudderRightKey);
                                              }
                                            });
                                            HapticManager().triggerLight(s);
                                          },
                                          onUp: () {
                                            setState(() {
                                              if (flightRudderTouch > 0) {
                                                flightRudderTouch = 0.0;
                                              }
                                              if (s.m9RudderRightKey > 0) {
                                                pressedKeys.remove(s.m9RudderRightKey);
                                              }
                                            });
                                          },
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 8),

              // ══════════════════════════════════════════════════════════════
              // ORTA PANEL: ARCADE SAVAŞ HUD RETİKÜLÜ & SANAL YOKE (DOKUNMATİK + SENSÖR)
              // ══════════════════════════════════════════════════════════════
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF070B14).withValues(alpha: 0.88),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isGunsFiring || isMissileFiring
                          ? fireCol.withValues(alpha: 0.85)
                          : hudCol.withValues(alpha: 0.35),
                      width: 1.3,
                    ),
                  ),
                  child: Column(
                    children: [
                      // ── Üst Kokpit Barı: Başlık + Pitch Invert + Trim/Kalibrasyon ──
                      Padding(
                        padding: const EdgeInsets.fromLTRB(10, 6, 10, 4),
                        child: Row(
                          children: [
                            Flexible(
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 7,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: hudCol.withValues(alpha: 0.14),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: hudCol.withValues(alpha: 0.4)),
                                ),
                                child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        flightTouchStickActive
                                            ? Icons.touch_app
                                            : Icons.screen_rotation,
                                        size: 12,
                                        color: hudCol,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        flightTouchStickActive
                                            ? 'DOKUNMATİK YOKE'
                                            : 'SENSÖR HOTAS',
                                        style: TextStyle(
                                          color: hudCol,
                                          fontSize: 9,
                                          fontWeight: FontWeight.w800,
                                          letterSpacing: 0.8,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            // PITCH INVERT Butonu (Uçak Lövyeli / Normal)
                            GestureDetector(
                              onTap: () {
                                setState(() {
                                  sm.flightInvertPitch = !sm.flightInvertPitch;
                                });
                                HapticManager().triggerLight(s);
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: sm.flightInvertPitch
                                      ? Colors.amber.withValues(alpha: 0.16)
                                      : Colors.white.withValues(alpha: 0.06),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: sm.flightInvertPitch
                                        ? Colors.amber
                                        : Colors.white24,
                                  ),
                                ),
                                child: Text(
                                  sm.flightInvertPitch
                                      ? AppTranslations.getText('flight_pitch_invert')
                                      : AppTranslations.getText('flight_pitch_normal'),
                                  style: TextStyle(
                                    color: sm.flightInvertPitch
                                        ? Colors.amber
                                        : Colors.white70,
                                    fontSize: 9,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            // TRIM / UFUK SIFIRLA (Kalibrasyon)
                            GestureDetector(
                              onTap: () {
                                sm.calibrateFlightStick();
                                setState(() {
                                  flightTouchStickActive = false;
                                  flightTouchRoll = 0.0;
                                  flightTouchPitch = 0.0;
                                });
                                HapticManager().triggerMedium(s);
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 9,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF00E676).withValues(alpha: 0.16),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: const Color(0xFF00E676),
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      Icons.filter_center_focus,
                                      size: 12,
                                      color: Color(0xFF00E676),
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      AppTranslations.getText('flight_trim_reset'),
                                      style: const TextStyle(
                                        color: Color(0xFF00E676),
                                        fontSize: 9,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      // ── Orta: İnteraktif HUD (Sensör + Dokunmatik Mouse-Aim / Yoke) ──
                      Expanded(
                        child: LayoutBuilder(
                          builder: (ctx, constraints) {
                            final hudW = constraints.maxWidth;
                            final hudH = constraints.maxHeight;
                            final maxR = math.min(hudW, hudH) * 0.42;

                            void updateTouchStick(Offset localPos) {
                              final cx = hudW / 2;
                              final cy = hudH / 2;
                              final dx = ((localPos.dx - cx) / maxR).clamp(-1.0, 1.0);
                              final dy = ((localPos.dy - cy) / maxR).clamp(-1.0, 1.0);
                              setState(() {
                                flightTouchStickActive = true;
                                flightTouchRoll = dx;
                                flightTouchPitch = sm.flightInvertPitch ? dy : -dy;
                              });
                            }

                            return Listener(
                              onPointerDown: (e) => updateTouchStick(e.localPosition),
                              onPointerMove: (e) => updateTouchStick(e.localPosition),
                              onPointerUp: (_) {
                                setState(() {
                                  flightTouchStickActive = false;
                                  flightTouchRoll = 0.0;
                                  flightTouchPitch = 0.0;
                                });
                              },
                              onPointerCancel: (_) {
                                setState(() {
                                  flightTouchStickActive = false;
                                  flightTouchRoll = 0.0;
                                  flightTouchPitch = 0.0;
                                });
                              },
                              child: Stack(
                                children: [
                                  RepaintBoundary(
                                    child: CustomPaint(
                                      painter: CrosshairPainter(
                                        color: hudCol,
                                        offsetX: activeRoll,
                                        offsetY: activePitch,
                                        rollDeg: displayRollDeg,
                                        pitchDeg: displayPitchDeg,
                                        yawOffset: activeYaw,
                                        isFiring: isGunsFiring || isMissileFiring,
                                        isTargetLocked: flightTargetLocked,
                                      ),
                                      child: const SizedBox.expand(),
                                    ),
                                  ),
                                  // Sol alt ipucu
                                  Positioned(
                                    left: 10,
                                    bottom: 4,
                                    child: Text(
                                      'Telefonu eğin veya HUD üzerinde sürükleyin',
                                      style: TextStyle(
                                        color: Colors.white.withValues(alpha: 0.35),
                                        fontSize: 8.5,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),

                      // ── Alt Telemetri Şeridi ──
                      Padding(
                        padding: const EdgeInsets.fromLTRB(8, 2, 8, 6),
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _buildHudReadout(
                                'THR',
                                isWep
                                    ? 'WEP ${(gasPercentage * 100).toStringAsFixed(0)}%'
                                    : '${(gasPercentage * 100).toStringAsFixed(0)}%',
                                isWep ? wepCol : throttleCol,
                              ),
                              const SizedBox(width: 6),
                              _buildHudReadout(
                                'PITCH',
                                '${displayPitchDeg >= 0 ? '+' : ''}${displayPitchDeg.toStringAsFixed(1)}°',
                                hudCol,
                              ),
                              const SizedBox(width: 6),
                              _buildHudReadout(
                                'ROLL',
                                '${displayRollDeg >= 0 ? '+' : ''}${displayRollDeg.toStringAsFixed(1)}°',
                                hudCol,
                              ),
                              const SizedBox(width: 6),
                              _buildHudReadout(
                                'YAW',
                                '${displayYawDeg >= 0 ? '+' : ''}${displayYawDeg.toStringAsFixed(1)}°',
                                hudCol,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(width: 8),

              // ══════════════════════════════════════════════════════════════
              // SAĞ PANEL: SAVAŞ SİLAHLARI (WT / DCS) & SERBEST BAKIŞ (FREE LOOK HAT)
              // ══════════════════════════════════════════════════════════════
              SizedBox(
                width: 162,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // ── 1. BİRİNCİL TETİK: TOP / MAKİNELİ ──
                    Expanded(
                      flex: 3,
                      child: Listener(
                        onPointerDown: (_) {
                          if (s.m9FireKey > 0) {
                            setState(() => pressedKeys.add(s.m9FireKey));
                          }
                          HapticManager().triggerHeavy(s);
                        },
                        onPointerUp: (_) {
                          if (s.m9FireKey > 0) {
                            setState(() => pressedKeys.remove(s.m9FireKey));
                          }
                        },
                        onPointerCancel: (_) {
                          if (s.m9FireKey > 0) {
                            setState(() => pressedKeys.remove(s.m9FireKey));
                          }
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 90),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: isGunsFiring
                                  ? [
                                      fireCol,
                                      Color.lerp(fireCol, Colors.black, 0.25)!,
                                    ]
                                  : [
                                      fireCol.withValues(alpha: 0.24),
                                      fireCol.withValues(alpha: 0.10),
                                    ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: fireCol,
                              width: isGunsFiring ? 2.2 : 1.2,
                            ),
                            boxShadow: isGunsFiring
                                ? [
                                    BoxShadow(
                                      color: fireCol.withValues(alpha: 0.5),
                                      blurRadius: 14,
                                    ),
                                  ]
                                : null,
                          ),
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.gps_fixed,
                                  color: isGunsFiring
                                      ? s.contrastTextFor(fireCol)
                                      : fireCol,
                                  size: 22,
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'FIRE / GUNS',
                                  style: TextStyle(
                                    color: isGunsFiring
                                        ? s.contrastTextFor(fireCol)
                                        : fireCol,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 1.1,
                                  ),
                                ),
                                Text(
                                  'TOP / MAKİNELİ (${_shortFlightKeyLabel(s.m9FireKey)})',
                                  style: const TextStyle(
                                    color: Colors.white60,
                                    fontSize: 8,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 5),

                    // ── 2. İKİNCİL SİLAHLAR: FÜZE / ROKET + BOMBARDIMAN ──
                    Expanded(
                      flex: 2,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(
                            child: _buildHoldWeaponButton(
                              s: s,
                              keyId: s.m9MissileKey,
                              label: 'FÜZE / ROKET',
                              subLabel: _shortFlightKeyLabel(s.m9MissileKey),
                              icon: Icons.rocket_launch,
                              activeColor: weaponCol,
                            ),
                          ),
                          const SizedBox(width: 5),
                          Expanded(
                            child: _buildHoldWeaponButton(
                              s: s,
                              keyId: s.m9BombKey,
                              label: 'BOMBA',
                              subLabel: _shortFlightKeyLabel(s.m9BombKey),
                              icon: Icons.vertical_align_bottom,
                              activeColor: weaponCol,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 5),

                    // ── 3. TAKTİK 2x2 IZGARASI: HEDEF KİLİT, FLARE, AĞIR SİLAH, HARİTA ──
                    Expanded(
                      flex: 3,
                      child: Column(
                        children: [
                          Expanded(
                            child: Row(
                              children: [
                                // HEDEF KİLİT
                                Expanded(
                                  child: _buildAvionicsButton(
                                    label: flightTargetLocked ? 'LOCKED' : 'LOCK',
                                    subLabel: _shortFlightKeyLabel(s.m9LockKey),
                                    icon: Icons.center_focus_strong,
                                    isActive: flightTargetLocked,
                                    activeColor: avionicsCol,
                                    onTap: () {
                                      setState(() {
                                        flightTargetLocked = !flightTargetLocked;
                                      });
                                      if (s.m9LockKey > 0) fireKey(s.m9LockKey);
                                      HapticManager().triggerMedium(s);
                                    },
                                  ),
                                ),
                                const SizedBox(width: 5),
                                // FLARE / CHAFF
                                Expanded(
                                  child: _buildAvionicsButton(
                                    label: 'FLARE',
                                    subLabel: _shortFlightKeyLabel(s.m9FlareKey),
                                    icon: Icons.auto_awesome,
                                    isActive: pressedKeys.contains(s.m9FlareKey),
                                    activeColor: avionicsCol,
                                    onTap: () {
                                      if (s.m9FlareKey > 0) fireKey(s.m9FlareKey);
                                      HapticManager().triggerLight(s);
                                    },
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 5),
                          Expanded(
                            child: Row(
                              children: [
                                // AĞIR SİLAH / TOP (Secondary Guns — basılı tut)
                                Expanded(
                                  child: _buildHoldWeaponButton(
                                    s: s,
                                    keyId: s.m9HeavyGunKey,
                                    label: 'AĞIR SİLAH',
                                    subLabel: _shortFlightKeyLabel(s.m9HeavyGunKey),
                                    icon: Icons.whatshot,
                                    activeColor: weaponCol,
                                  ),
                                ),
                                const SizedBox(width: 5),
                                // TAKTİK HARİTA / SKOR
                                Expanded(
                                  child: _buildAvionicsButton(
                                    label: 'MAP',
                                    subLabel: _shortFlightKeyLabel(s.m9MapKey),
                                    icon: Icons.radar,
                                    isActive: pressedKeys.contains(s.m9MapKey),
                                    activeColor: avionicsCol,
                                    onTap: () {
                                      if (s.m9MapKey > 0) fireKey(s.m9MapKey);
                                      HapticManager().triggerLight(s);
                                    },
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 5),

                    // ── 4. SERBEST BAKIŞ HAT-SWITCH (FREE LOOK — SAĞ ANALOG RX/RY) ──
                    Expanded(
                      flex: 3,
                      child: LayoutBuilder(
                        builder: (ctx, constraints) {
                          final padW = constraints.maxWidth;
                          final padH = constraints.maxHeight;
                          final maxR = math.min(padW, padH) * 0.38;

                          void updateFreeLook(Offset pos) {
                            final cx = padW / 2;
                            final cy = padH / 2;
                            final dx = ((pos.dx - cx) / maxR).clamp(-1.0, 1.0);
                            final dy = ((pos.dy - cy) / maxR).clamp(-1.0, 1.0);
                            setState(() {
                              flightFreeLookTouchActive = true;
                              joy1x = dx;
                              joy1y = dy;
                            });
                          }

                          return Listener(
                            onPointerDown: (e) => updateFreeLook(e.localPosition),
                            onPointerMove: (e) => updateFreeLook(e.localPosition),
                            onPointerUp: (_) {
                              setState(() {
                                flightFreeLookTouchActive = false;
                                joy1x = 0.0;
                                joy1y = 0.0;
                              });
                            },
                            onPointerCancel: (_) {
                              setState(() {
                                flightFreeLookTouchActive = false;
                                joy1x = 0.0;
                                joy1y = 0.0;
                              });
                            },
                            child: Container(
                              decoration: BoxDecoration(
                                color: const Color(0xFF0A0F1D).withValues(alpha: 0.88),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: flightFreeLookTouchActive
                                      ? hatCol
                                      : hatCol.withValues(alpha: 0.35),
                                  width: flightFreeLookTouchActive ? 1.6 : 1.0,
                                ),
                              ),
                              child: Stack(
                                alignment: Alignment.center,
                                children: [
                                  Positioned(
                                    top: 4,
                                    child: Text(
                                      'FREE LOOK (SAĞ ANALOG)',
                                      style: TextStyle(
                                        color: hatCol.withValues(alpha: 0.85),
                                        fontSize: 7.5,
                                        fontWeight: FontWeight.w700,
                                        letterSpacing: 0.6,
                                      ),
                                    ),
                                  ),
                                  // Hat Switch Dairesi
                                  Container(
                                    width: maxR * 1.4,
                                    height: maxR * 1.4,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: hatCol.withValues(alpha: 0.3),
                                        width: 1,
                                      ),
                                    ),
                                  ),
                                  // Hareketli Hat Thumb
                                  Transform.translate(
                                    offset: Offset(
                                      (flightFreeLookTouchActive ? joy1x : 0.0) *
                                          (maxR * 0.55),
                                      (flightFreeLookTouchActive ? joy1y : 0.0) *
                                          (maxR * 0.55),
                                    ),
                                    child: Container(
                                      width: 22,
                                      height: 22,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: flightFreeLookTouchActive
                                            ? hatCol
                                            : hatCol.withValues(alpha: 0.45),
                                        boxShadow: flightFreeLookTouchActive
                                            ? [
                                                BoxShadow(
                                                  color: hatCol.withValues(alpha: 0.5),
                                                  blurRadius: 8,
                                                ),
                                              ]
                                            : null,
                                      ),
                                      child: Icon(
                                        Icons.open_with,
                                        size: 13,
                                        color: s.contrastTextFor(hatCol),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAvionicsButton({
    required String label,
    required String subLabel,
    required IconData icon,
    required bool isActive,
    required Color activeColor,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: _buildAvionicsCardContent(
        label: label,
        subLabel: subLabel,
        icon: icon,
        isActive: isActive,
        activeColor: activeColor,
      ),
    );
  }

  /// Basılı tutulduğu sürece tuşu aktif tutan silah butonu
  /// (Ağır Silah / Top, Füze-Roket, Bomba — War Thunder'da seri atış için).
  Widget _buildHoldWeaponButton({
    required AppSettings s,
    required int keyId,
    required String label,
    required String subLabel,
    required IconData icon,
    required Color activeColor,
  }) {
    final bool isActive = keyId > 0 && pressedKeys.contains(keyId);
    return Listener(
      onPointerDown: (_) {
        if (keyId > 0) setState(() => pressedKeys.add(keyId));
        HapticManager().triggerHeavy(s);
      },
      onPointerUp: (_) {
        if (keyId > 0) setState(() => pressedKeys.remove(keyId));
      },
      onPointerCancel: (_) {
        if (keyId > 0) setState(() => pressedKeys.remove(keyId));
      },
      child: _buildAvionicsCardContent(
        label: label,
        subLabel: subLabel,
        icon: icon,
        isActive: isActive,
        activeColor: activeColor,
      ),
    );
  }

  Widget _buildAvionicsCardContent({
    required String label,
    required String subLabel,
    required IconData icon,
    required bool isActive,
    required Color activeColor,
  }) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 140),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
      decoration: BoxDecoration(
        color: isActive
            ? activeColor.withValues(alpha: 0.22)
            : const Color(0xFF0B1020).withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isActive ? activeColor : activeColor.withValues(alpha: 0.32),
          width: isActive ? 1.6 : 1.0,
        ),
      ),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: isActive ? activeColor : activeColor.withValues(alpha: 0.72),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: isActive ? activeColor : Colors.white.withValues(alpha: 0.85),
                fontSize: 8.5,
                fontWeight: FontWeight.w800,
              ),
            ),
            Text(
              subLabel,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white54,
                fontSize: 7,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRudderPedalButton({
    required String label,
    required bool isActive,
    required Color color,
    required VoidCallback onDown,
    required VoidCallback onUp,
  }) {
    return Listener(
      onPointerDown: (_) => onDown(),
      onPointerUp: (_) => onUp(),
      onPointerCancel: (_) => onUp(),
      child: Container(
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isActive
              ? color.withValues(alpha: 0.28)
              : const Color(0xFF0B1020).withValues(alpha: 0.88),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isActive ? color : color.withValues(alpha: 0.38),
            width: isActive ? 1.5 : 1.0,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isActive ? color : color.withValues(alpha: 0.8),
            fontSize: 8.5,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }

  Widget _buildHudReadout(String label, String value, Color accent) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0xFF0D1324),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: accent.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$label: ',
            style: const TextStyle(
              color: Colors.white54,
              fontSize: 8.5,
              fontWeight: FontWeight.w600,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: accent,
              fontSize: 10,
              fontWeight: FontWeight.w800,
              fontFamily: 'monospace',
            ),
          ),
        ],
      ),
    );
  }

  String _shortFlightKeyLabel(int keyId) {
    switch (keyId) {
      case 0:
        return 'YOK';
      case 1:
        return 'LB';
      case 2:
        return 'RB';
      case 3:
        return 'GUIDE';
      case 5:
        return 'A';
      case 6:
        return 'B';
      case 7:
        return 'X';
      case 8:
        return 'Y';
      case 9:
        return 'DPAD ▲';
      case 10:
        return 'DPAD ▼';
      case 11:
        return 'DPAD ◄';
      case 12:
        return 'DPAD ►';
      case 13:
        return 'START';
      case 14:
        return 'BACK';
      case 17:
        return 'L3';
      case 18:
        return 'R3';
      case 2001:
        return 'SOL TIK';
      case 2002:
        return 'ORTA TIK';
      case 2003:
        return 'SAĞ TIK';
      default:
        for (final entry in KeyboardKeys.appKeyMap.entries) {
          if (entry.value == keyId) {
            return entry.key.toUpperCase();
          }
        }
        return 'TUŞ $keyId';
    }
  }
}
