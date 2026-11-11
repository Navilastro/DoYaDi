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
    final ac = s.detailColor;

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
      color: s.backgroundColor,
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
                          color: const Color(0xFF0A0F1D),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: isWep
                                ? const Color(0xFFFF5252).withValues(alpha: 0.7)
                                : ac.withValues(alpha: 0.22),
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
                                      ? const Color(0xFFFF1744).withValues(alpha: 0.28)
                                      : Colors.white.withValues(alpha: 0.04),
                                  borderRadius: BorderRadius.circular(7),
                                  border: Border.all(
                                    color: isWep
                                        ? const Color(0xFFFF1744)
                                        : Colors.white24,
                                  ),
                                ),
                                child: Text(
                                  isWep ? '🔥 WEP' : 'WEP %100',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: isWep
                                        ? const Color(0xFFFF5252)
                                        : Colors.white70,
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
                                color: isWep ? const Color(0xFFFF5252) : ac,
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
                              activeColor: flightFlapStage == 1
                                  ? const Color(0xFF00E5FF)
                                  : const Color(0xFFFFEA00),
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
                              activeColor: const Color(0xFF00E676),
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
                                activeColor: const Color(0xFFFF9100),
                              ),
                            ),
                          ),
                          const SizedBox(height: 5),

                          // SOL / SAĞ DÜMEN (RUDDER / YAW)
                          SizedBox(
                            height: 56,
                            child: Column(
                              children: [
                                const Text(
                                  'DÜMEN (YAW)',
                                  style: TextStyle(
                                    color: Colors.white54,
                                    fontSize: 8,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.8,
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
                                          color: ac,
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
                                          color: ac,
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
                    color: const Color(0xFF070B14),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isGunsFiring || isMissileFiring
                          ? const Color(0xFFFF1744).withValues(alpha: 0.75)
                          : ac.withValues(alpha: 0.28),
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
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 7,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: ac.withValues(alpha: 0.14),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: ac.withValues(alpha: 0.4)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    flightTouchStickActive
                                        ? Icons.touch_app
                                        : Icons.screen_rotation,
                                    size: 12,
                                    color: ac,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    flightTouchStickActive
                                        ? 'DOKUNMATİK YOKE'
                                        : 'SENSÖR HOTAS',
                                    style: TextStyle(
                                      color: ac,
                                      fontSize: 9,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 0.8,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const Spacer(),
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
                                        color: ac,
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
                                        color: Colors.white.withValues(alpha: 0.30),
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
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            _buildHudReadout(
                              'THR',
                              isWep
                                  ? 'WEP ${(gasPercentage * 100).toStringAsFixed(0)}%'
                                  : '${(gasPercentage * 100).toStringAsFixed(0)}%',
                              isWep ? const Color(0xFFFF5252) : ac,
                            ),
                            _buildHudReadout(
                              'PITCH',
                              '${displayPitchDeg >= 0 ? '+' : ''}${displayPitchDeg.toStringAsFixed(1)}°',
                              ac,
                            ),
                            _buildHudReadout(
                              'ROLL',
                              '${displayRollDeg >= 0 ? '+' : ''}${displayRollDeg.toStringAsFixed(1)}°',
                              ac,
                            ),
                            _buildHudReadout(
                              'YAW',
                              '${displayYawDeg >= 0 ? '+' : ''}${displayYawDeg.toStringAsFixed(1)}°',
                              ac,
                            ),
                          ],
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
                                      const Color(0xFFFF1744),
                                      const Color(0xFFD50000),
                                    ]
                                  : [
                                      const Color(0xFF3B0D16),
                                      const Color(0xFF1F080E),
                                    ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: const Color(0xFFFF1744),
                              width: isGunsFiring ? 2.2 : 1.2,
                            ),
                            boxShadow: isGunsFiring
                                ? [
                                    BoxShadow(
                                      color: const Color(0xFFFF1744).withValues(alpha: 0.5),
                                      blurRadius: 14,
                                    ),
                                  ]
                                : null,
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.gps_fixed,
                                color: isGunsFiring
                                    ? Colors.white
                                    : const Color(0xFFFF5252),
                                size: 22,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'FIRE / GUNS',
                                style: TextStyle(
                                  color: isGunsFiring
                                      ? Colors.white
                                      : const Color(0xFFFF8A80),
                                  fontSize: 11,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 1.1,
                                ),
                              ),
                              Text(
                                'TOP / MAKİNELİ (${_shortFlightKeyLabel(s.m9FireKey)})',
                                style: const TextStyle(
                                  color: Colors.white54,
                                  fontSize: 8,
                                ),
                              ),
                            ],
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
                              activeColor: const Color(0xFFFF9100),
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
                              activeColor: const Color(0xFFFFD600),
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
                                    activeColor: const Color(0xFFFFEA00),
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
                                    activeColor: const Color(0xFFFF9100),
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
                                    activeColor: const Color(0xFFFF3D00),
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
                                    activeColor: ac,
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
                                color: const Color(0xFF0A0F1D),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: flightFreeLookTouchActive
                                      ? ac
                                      : ac.withValues(alpha: 0.25),
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
                                        color: ac.withValues(alpha: 0.7),
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
                                        color: Colors.white24,
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
                                            ? ac
                                            : ac.withValues(alpha: 0.35),
                                        boxShadow: flightFreeLookTouchActive
                                            ? [
                                                BoxShadow(
                                                  color: ac.withValues(alpha: 0.5),
                                                  blurRadius: 8,
                                                ),
                                              ]
                                            : null,
                                      ),
                                      child: const Icon(
                                        Icons.open_with,
                                        size: 13,
                                        color: Colors.black87,
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
            ? activeColor.withValues(alpha: 0.18)
            : const Color(0xFF0B1020),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isActive ? activeColor : const Color(0xFF252B42),
          width: isActive ? 1.6 : 1.0,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            size: 16,
            color: isActive ? activeColor : Colors.white54,
          ),
          const SizedBox(height: 2),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: isActive ? activeColor : Colors.white70,
              fontSize: 8.5,
              fontWeight: FontWeight.w800,
            ),
          ),
          Text(
            subLabel,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white38,
              fontSize: 7,
            ),
          ),
        ],
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
              ? color.withValues(alpha: 0.25)
              : const Color(0xFF0B1020),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isActive ? color : const Color(0xFF252B42),
            width: isActive ? 1.5 : 1.0,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isActive ? color : Colors.white70,
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
