part of '../driving_mode_builders.dart';

/// Mod 10 — Profesyonel Hava Aracı Yönetim & Aviyonik MFD Kokpiti
///
/// Özellikler:
/// - Üst Master Warning / Caution Uyarı Barı (STALL, OVSPD, HIGH-G, FUEL, GEAR)
///   + AFCS Otopilot Butonları (AP LVL, ALT HLD, A/THR, TRIM RST)
/// - Sol Yönetim Konsolu: İtki Kolu (Thrust Lever + WEP/IDLE), Motor N1/N2/EGT/Fuel
///   özeti, Dümen (Rudder L1/R1) & Tekerlek Freni (L2)
/// - Merkez Çok İşlevli Ekran (MFD — 3 Sekme):
///   * PFD / ADI: Hız Bandı + İnteraktif Yapay Ufuk (Sensör + Dokunmatik Yoke) + İrtifa Bandı
///   * ENG / SYS: Türbin & Yakıt Göstergeleri + Canlı Uçuş Kontrol Yüzeyleri Şeması
///   * NAV / HSI: 360° Pusula Gülü (HSI) + Serbest Bakış (Free Look) Gimbal Pedi
/// - Sağ Yönetim Konsolu: 3 Yeşil Işıklı İniş Takımı Kolu (GEAR UP/DN), 3 Kademeli
///   Flap Seçici (UP/CMB/LND), Hava Freni (AIRBRK) ve Aviyonik/Silah Tuş Matrisi
extension _Mode10BuilderExt<T extends StatefulWidget> on DrivingModeBuildMixin<T> {
  Widget buildMode10(AppSettings s, Size size) {
    final double leftColW = (size.width * 0.215).clamp(136.0, 184.0);
    final double rightColW = (size.width * 0.225).clamp(142.0, 192.0);
    final throttleCol = s.mod9ThrottleColor;
    final wepCol = s.mod9WepColor;
    final avionicsCol = s.mod9AvionicsColor;
    final rudderCol = s.mod9RudderColor;
    final hudCol = s.mod9HudColor;
    final fireCol = s.mod9FireBtnColor;
    final weaponCol = s.mod9WeaponBtnColor;
    final hatCol = s.mod9HatSwitchColor;
    final bool hasBgMedia = AppMediaHelper.hasMedia(s.modeBackgroundMedia(10));

    return _FlightTelemetryLifecycleHost(
      filterAlpha: s.mfdGyroFilterAlpha,
      child: ValueListenableBuilder<ExtendedTelemetryData>(
        valueListenable: TelemetryListenerService().telemetryNotifier,
        builder: (context, data, _) {
          final sm = SensorManager();
          final bool telLive = data.isFlightLive;

          // Tutum verisi (önce dokunmatik yoke veya canlı telemetri, yoksa lokal sensör)
          final double activeRollNorm = flightTouchStickActive
              ? flightTouchRoll.clamp(-1.0, 1.0)
              : sm.flightRoll.clamp(-1.0, 1.0);
          final double activePitchNorm = flightTouchStickActive
              ? flightTouchPitch.clamp(-1.0, 1.0)
              : sm.flightPitch.clamp(-1.0, 1.0);
          final double activeYawNorm = flightRudderTouch.abs() > 0.01
              ? flightRudderTouch.clamp(-1.0, 1.0)
              : sm.flightYaw.clamp(-1.0, 1.0);

          final double displayPitchDeg = telLive && !flightTouchStickActive
              ? data.pitchDeg.toDouble()
              : (flightTouchStickActive ? activePitchNorm * 45.0 : sm.flightPitchDeg);
          final double displayRollDeg = telLive && !flightTouchStickActive
              ? data.rollDeg.toDouble()
              : (flightTouchStickActive ? activeRollNorm * 45.0 : sm.flightRollDeg);

          final double n1Frac = telLive
              ? (data.n1Pct / 255.0).clamp(0.0, 1.0)
              : gasPercentage.clamp(0.0, 1.0);
          final double n2Frac = telLive
              ? (data.n2Pct / 255.0).clamp(0.0, 1.0)
              : (gasPercentage * 0.96).clamp(0.0, 1.0);
          final int egtCelsius = telLive
              ? (data.egtRaw * 700 ~/ 255) + 200
              : (220 + (gasPercentage * 620)).round();
          final int fuelPct = telLive ? data.fuelPct : 100;
          final bool effectiveGearDown = telLive ? data.isGearDownTelemetry : flightGearDown;
          final bool effectiveAirbrake = telLive
              ? data.isAirbrakeTelemetry
              : (flightAirbrakeActive || brakePercentage > 0.15);
          final bool isWep = gasPercentage >= 0.95 || (telLive && data.isWepTelemetry);

          return Container(
            color: hasBgMedia ? Colors.transparent : s.modeBackgroundColor(10),
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(6, 4, 6, 6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // ── ÜST AVİYONİK & OTOPİLOT (AFCS) BARI ──
                    _buildM10TopBar(
                      s: s,
                      data: data,
                      telLive: telLive,
                      effectiveGearDown: effectiveGearDown,
                      fuelPct: fuelPct,
                      hudCol: hudCol,
                      avionicsCol: avionicsCol,
                      wepCol: wepCol,
                    ),
                    const SizedBox(height: 5),

                    // ── ANA KOKPİT GÖVDESİ (SOL / MERKEZ MFD / SAĞ) ──
                    Expanded(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // 1. SOL YÖNETİM KONSOLU
                          SizedBox(
                            width: leftColW,
                            child: _buildM10LeftConsole(
                              s: s,
                              telLive: telLive,
                              n1Frac: n1Frac,
                              n2Frac: n2Frac,
                              egtCelsius: egtCelsius,
                              fuelPct: fuelPct,
                              isWep: isWep,
                              throttleCol: throttleCol,
                              wepCol: wepCol,
                              rudderCol: rudderCol,
                              avionicsCol: avionicsCol,
                            ),
                          ),
                          const SizedBox(width: 6),

                          // 2. MERKEZ MFD (3 SEKMELİ PROFESYONEL EKRAN)
                          Expanded(
                            child: _buildM10CenterMfd(
                              s: s,
                              data: data,
                              telLive: telLive,
                              displayPitchDeg: displayPitchDeg,
                              displayRollDeg: displayRollDeg,
                              activeRollNorm: activeRollNorm,
                              activePitchNorm: activePitchNorm,
                              activeYawNorm: activeYawNorm,
                              n1Frac: n1Frac,
                              n2Frac: n2Frac,
                              egtCelsius: egtCelsius,
                              fuelPct: fuelPct,
                              effectiveGearDown: effectiveGearDown,
                              effectiveAirbrake: effectiveAirbrake,
                              hudCol: hudCol,
                              hatCol: hatCol,
                              throttleCol: throttleCol,
                            ),
                          ),
                          const SizedBox(width: 6),

                          // 3. SAĞ YÖNETİM KONSOLU
                          SizedBox(
                            width: rightColW,
                            child: _buildM10RightConsole(
                              s: s,
                              data: data,
                              telLive: telLive,
                              effectiveGearDown: effectiveGearDown,
                              effectiveAirbrake: effectiveAirbrake,
                              avionicsCol: avionicsCol,
                              fireCol: fireCol,
                              weaponCol: weaponCol,
                              hudCol: hudCol,
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
        },
      ),
    );
  }

  // ── Üst Uyarı & Otopilot Barı ─────────────────────────────────────────────
  Widget _buildM10TopBar({
    required AppSettings s,
    required ExtendedTelemetryData data,
    required bool telLive,
    required bool effectiveGearDown,
    required int fuelPct,
    required Color hudCol,
    required Color avionicsCol,
    required Color wepCol,
  }) {
    final bool highG = telLive && data.gForce.abs() >= 6.0;
    final bool lowFuel = telLive && fuelPct <= 15;

    return Container(
      height: 32,
      padding: const EdgeInsets.symmetric(horizontal: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF0A0F1E).withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: hudCol.withValues(alpha: 0.32)),
      ),
      child: Row(
        children: [
          // Telemetri Durum Rozeti
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: (telLive ? const Color(0xFF00E676) : hudCol)
                  .withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(5),
              border: Border.all(
                color: (telLive ? const Color(0xFF00E676) : hudCol)
                    .withValues(alpha: 0.5),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  telLive ? Icons.sensors : Icons.flight,
                  size: 11,
                  color: telLive ? const Color(0xFF00E676) : hudCol,
                ),
                const SizedBox(width: 4),
                Text(
                  telLive ? 'SIM TELEMETRİ' : 'MOD 10 MFD',
                  style: TextStyle(
                    color: telLive ? const Color(0xFF00E676) : hudCol,
                    fontSize: 8.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.6,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),

          // Master Caution / Warning Şeridi
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _m10Annunciator('STALL', data.isStallWarning, const Color(0xFFFF1744)),
                  const SizedBox(width: 4),
                  _m10Annunciator('OVSPD', data.isOverspeedWarning, const Color(0xFFFF1744)),
                  const SizedBox(width: 4),
                  _m10Annunciator('HIGH-G', highG, wepCol),
                  const SizedBox(width: 4),
                  _m10Annunciator('FUEL', lowFuel, wepCol),
                  const SizedBox(width: 4),
                  _m10Annunciator('GEAR', effectiveGearDown, const Color(0xFF00E676)),
                ],
              ),
            ),
          ),
          const SizedBox(width: 6),

          // AFCS Otopilot & Trim Tuşları
          Flexible(
            flex: 0,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _m10AfcsChip(
                    label: 'AP LVL',
                    active: flightApWingLevel,
                    color: avionicsCol,
                    onTap: () {
                      setState(() => flightApWingLevel = !flightApWingLevel);
                      HapticManager().triggerSelection(s);
                    },
                  ),
                  const SizedBox(width: 4),
                  _m10AfcsChip(
                    label: 'ALT HLD',
                    active: flightApAltHold,
                    color: avionicsCol,
                    onTap: () {
                      setState(() => flightApAltHold = !flightApAltHold);
                      HapticManager().triggerSelection(s);
                    },
                  ),
                  const SizedBox(width: 4),
                  _m10AfcsChip(
                    label: 'A/THR',
                    active: flightAutoThrottleLock,
                    color: wepCol,
                    onTap: () {
                      setState(() {
                        flightAutoThrottleLock = !flightAutoThrottleLock;
                      });
                      HapticManager().triggerSelection(s);
                    },
                  ),
                  const SizedBox(width: 4),
                  _m10AfcsChip(
                    label: 'TRIM',
                    active: false,
                    color: hudCol,
                    onTap: () {
                      SensorManager().calibrateFlightStick();
                      HapticManager().triggerMedium(s);
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _m10Annunciator(String text, bool active, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(
        color: active ? color.withValues(alpha: 0.24) : const Color(0xFF101628),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: active ? color : Colors.white10,
          width: active ? 1.2 : 0.7,
        ),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: active ? color : Colors.white24,
          fontSize: 8,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _m10AfcsChip({
    required String label,
    required bool active,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
        decoration: BoxDecoration(
          color: active ? color.withValues(alpha: 0.25) : const Color(0xFF121A2F),
          borderRadius: BorderRadius.circular(5),
          border: Border.all(
            color: active ? color : color.withValues(alpha: 0.4),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: active ? color : Colors.white70,
            fontSize: 8,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }

  // ── Sol Yönetim Konsolu ───────────────────────────────────────────────────
  Widget _buildM10LeftConsole({
    required AppSettings s,
    required bool telLive,
    required double n1Frac,
    required double n2Frac,
    required int egtCelsius,
    required int fuelPct,
    required bool isWep,
    required Color throttleCol,
    required Color wepCol,
    required Color rudderCol,
    required Color avionicsCol,
  }) {
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: const Color(0xFF0A0F1D).withValues(alpha: 0.90),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isWep ? wepCol.withValues(alpha: 0.65) : throttleCol.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        children: [
          // Üst: WEP %100 ve IDLE %0
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    setState(() {
                      gasPercentage = 1.0;
                      flightWepActive = true;
                    });
                    HapticManager().triggerMedium(s);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    decoration: BoxDecoration(
                      color: isWep ? wepCol.withValues(alpha: 0.28) : wepCol.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: isWep ? wepCol : wepCol.withValues(alpha: 0.45)),
                    ),
                    child: Text(
                      'WEP',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: wepCol,
                        fontSize: 8.5,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    setState(() {
                      gasPercentage = 0.0;
                      flightWepActive = false;
                    });
                    HapticManager().triggerLight(s);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF141C30),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: Colors.white24),
                    ),
                    child: const Text(
                      'IDLE',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 8.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),

          // Orta: İtki Kolu + Motor Durum Barları
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // İtki Sürgüsü
                Expanded(
                  flex: 5,
                  child: Column(
                    children: [
                      Expanded(
                        child: AbsorbPointer(
                          absorbing: flightAutoThrottleLock,
                          child: Opacity(
                            opacity: flightAutoThrottleLock ? 0.65 : 1.0,
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
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '${(gasPercentage * 100).round()}%',
                        style: TextStyle(
                          color: isWep ? wepCol : throttleCol,
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 5),

                // Motor & Yakıt Mini Monitör
                Expanded(
                  flex: 6,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _m10BarStat('N1', '${(n1Frac * 100).round()}%', n1Frac, _m10LoadColor(n1Frac)),
                      _m10BarStat('N2', '${(n2Frac * 100).round()}%', n2Frac, _m10LoadColor(n2Frac)),
                      _m10BarStat(
                        'EGT',
                        '$egtCelsius°',
                        ((egtCelsius - 200) / 700.0).clamp(0.0, 1.0),
                        egtCelsius >= 780
                            ? const Color(0xFFFF1744)
                            : (egtCelsius >= 620 ? const Color(0xFFFFC107) : const Color(0xFF00E676)),
                      ),
                      _m10BarStat(
                        'FUEL',
                        telLive ? '$fuelPct%' : '---',
                        (fuelPct / 100.0).clamp(0.0, 1.0),
                        fuelPct <= 15 ? const Color(0xFFFF1744) : avionicsCol,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 5),

          // Alt: Dümen (L1 / R1) & Tekerlek Freni (L2)
          SizedBox(
            height: 30,
            child: Row(
              children: [
                Expanded(
                  child: _m10HoldButton(
                    label: '◄ ${KeyboardKeys.getKeyLabel(s.m9RudderLeftKey)}',
                    active: flightRudderTouch < -0.1 || pressedKeys.contains(s.m9RudderLeftKey),
                    color: rudderCol,
                    onDown: () {
                      setState(() {
                        flightRudderTouch = -1.0;
                        if (s.m9RudderLeftKey > 0) pressedKeys.add(s.m9RudderLeftKey);
                      });
                      HapticManager().triggerLight(s);
                    },
                    onUp: () {
                      setState(() {
                        if (flightRudderTouch < 0) flightRudderTouch = 0.0;
                        if (s.m9RudderLeftKey > 0) pressedKeys.remove(s.m9RudderLeftKey);
                      });
                    },
                  ),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: _m10HoldButton(
                    label: 'L2 FREN',
                    active: brakePercentage > 0.2,
                    color: const Color(0xFFFF5252),
                    onDown: () {
                      setState(() => brakePercentage = 1.0);
                      HapticManager().triggerMedium(s);
                    },
                    onUp: () {
                      setState(() => brakePercentage = flightAirbrakeActive ? 1.0 : 0.0);
                    },
                  ),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: _m10HoldButton(
                    label: '${KeyboardKeys.getKeyLabel(s.m9RudderRightKey)} ►',
                    active: flightRudderTouch > 0.1 || pressedKeys.contains(s.m9RudderRightKey),
                    color: rudderCol,
                    onDown: () {
                      setState(() {
                        flightRudderTouch = 1.0;
                        if (s.m9RudderRightKey > 0) pressedKeys.add(s.m9RudderRightKey);
                      });
                      HapticManager().triggerLight(s);
                    },
                    onUp: () {
                      setState(() {
                        if (flightRudderTouch > 0) flightRudderTouch = 0.0;
                        if (s.m9RudderRightKey > 0) pressedKeys.remove(s.m9RudderRightKey);
                      });
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _m10BarStat(String label, String val, double frac, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0xFF0E1528),
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: const TextStyle(color: Colors.white54, fontSize: 7.5, fontWeight: FontWeight.w700),
              ),
              Text(
                val,
                style: TextStyle(
                  color: color,
                  fontSize: 8.5,
                  fontWeight: FontWeight.w800,
                  fontFamily: 'monospace',
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(
              value: frac.clamp(0.0, 1.0),
              minHeight: 3.5,
              backgroundColor: Colors.white10,
              valueColor: AlwaysStoppedAnimation(color),
            ),
          ),
        ],
      ),
    );
  }

  Color _m10LoadColor(double f) {
    if (f < 0.72) return const Color(0xFF00E676);
    if (f < 0.92) return const Color(0xFFFFC107);
    return const Color(0xFFFF1744);
  }

  Widget _m10HoldButton({
    required String label,
    required bool active,
    required Color color,
    required VoidCallback onDown,
    required VoidCallback onUp,
  }) {
    return Listener(
      behavior: HitTestBehavior.opaque,
      onPointerDown: (_) => onDown(),
      onPointerUp: (_) => onUp(),
      onPointerCancel: (_) => onUp(),
      child: Container(
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 2),
        decoration: BoxDecoration(
          color: active ? color.withValues(alpha: 0.28) : const Color(0xFF10182C),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: active ? color : color.withValues(alpha: 0.4)),
        ),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            label,
            style: TextStyle(
              color: active ? Colors.white : color,
              fontSize: 8,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ),
    );
  }

  // ── Merkez Çok İşlevli Ekran (3 Sekmeli MFD) ────────────────────────────────
  Widget _buildM10CenterMfd({
    required AppSettings s,
    required ExtendedTelemetryData data,
    required bool telLive,
    required double displayPitchDeg,
    required double displayRollDeg,
    required double activeRollNorm,
    required double activePitchNorm,
    required double activeYawNorm,
    required double n1Frac,
    required double n2Frac,
    required int egtCelsius,
    required int fuelPct,
    required bool effectiveGearDown,
    required bool effectiveAirbrake,
    required Color hudCol,
    required Color hatCol,
    required Color throttleCol,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF070B14).withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: hudCol.withValues(alpha: 0.35)),
      ),
      child: Column(
        children: [
          // MFD Sayfa Sekmeleri & Anlık Dijital Telemetri Özeti
          Padding(
            padding: const EdgeInsets.fromLTRB(6, 5, 6, 4),
            child: Row(
              children: [
                _m10TabBtn(0, 'PFD / ADI', hudCol),
                const SizedBox(width: 4),
                _m10TabBtn(1, 'ENG / SYS', throttleCol),
                const SizedBox(width: 4),
                _m10TabBtn(2, 'NAV / HSI', hatCol),
                const Spacer(),
                Flexible(
                  flex: 2,
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _m10MiniBadge('HDG', telLive ? '${data.headingDeg.toString().padLeft(3, '0')}°' : '---', hudCol),
                        const SizedBox(width: 4),
                        _m10MiniBadge('M', telLive ? data.machNumber.toStringAsFixed(2) : '0.00', hudCol),
                        const SizedBox(width: 4),
                        _m10MiniBadge(
                          'G',
                          telLive ? '${data.gForce.toStringAsFixed(1)}G' : '1.0G',
                          data.gForce.abs() >= 6.0 ? const Color(0xFFFF1744) : const Color(0xFF00E676),
                        ),
                        const SizedBox(width: 4),
                        _m10MiniBadge('AoA', telLive ? '${data.aoaDeg}°' : '0°', Colors.amber),
                        const SizedBox(width: 4),
                        _m10MiniBadge(
                          'VSI',
                          telLive ? '${data.verticalSpeedFpm >= 0 ? '+' : ''}${data.verticalSpeedFpm}' : '0',
                          Colors.white70,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Aktif MFD Sayfa İçeriği
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(6, 0, 6, 6),
              child: mod10MfdTab == 0
                  ? _buildM10PfdPage(s, data, displayPitchDeg, displayRollDeg, hudCol)
                  : (mod10MfdTab == 1
                      ? _buildM10EngineSysPage(
                          s: s,
                          data: data,
                          telLive: telLive,
                          n1Frac: n1Frac,
                          n2Frac: n2Frac,
                          egtCelsius: egtCelsius,
                          fuelPct: fuelPct,
                          activeRollNorm: activeRollNorm,
                          activePitchNorm: activePitchNorm,
                          activeYawNorm: activeYawNorm,
                          effectiveGearDown: effectiveGearDown,
                          effectiveAirbrake: effectiveAirbrake,
                          hudCol: hudCol,
                        )
                      : _buildM10NavHsiPage(s, data, telLive, hudCol, hatCol)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _m10TabBtn(int index, String label, Color color) {
    final bool selected = mod10MfdTab == index;
    return GestureDetector(
      onTap: () => setState(() => mod10MfdTab = index),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: selected ? color.withValues(alpha: 0.24) : const Color(0xFF0F1629),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: selected ? color : Colors.white12),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? color : Colors.white60,
            fontSize: 8.5,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }

  Widget _m10MiniBadge(String k, String v, Color c) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(
        color: const Color(0xFF0D1324),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: c.withValues(alpha: 0.25)),
      ),
      child: Text(
        '$k:$v',
        style: TextStyle(
          color: c,
          fontSize: 8.5,
          fontWeight: FontWeight.w800,
          fontFamily: 'monospace',
        ),
      ),
    );
  }

  // Sayfa 0: Primary Flight Display (Speed Tape + İnteraktif ADI + Altitude Tape)
  Widget _buildM10PfdPage(
    AppSettings s,
    ExtendedTelemetryData data,
    double displayPitchDeg,
    double displayRollDeg,
    Color hudCol,
  ) {
    return Row(
      children: [
        if (s.mfdShowSpeedTape)
          SizedBox(
            width: 56,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: RepaintBoundary(
                child: CustomPaint(
                  painter: SpeedTapePainter(speedKnots: data.airspeedKnots.toDouble()),
                  child: const SizedBox.expand(),
                ),
              ),
            ),
          ),
        const SizedBox(width: 4),
        Expanded(
          child: s.mfdShowArtificialHorizon
              ? LayoutBuilder(
                  builder: (ctx, c) {
                    final cx = c.maxWidth / 2;
                    final cy = c.maxHeight / 2;
                    final maxR = math.max(20.0, math.min(c.maxWidth, c.maxHeight) * 0.42);
                    void updateYoke(Offset pos) {
                      final dx = ((pos.dx - cx) / maxR).clamp(-1.0, 1.0);
                      final dy = ((pos.dy - cy) / maxR).clamp(-1.0, 1.0);
                      setState(() {
                        flightTouchStickActive = true;
                        flightTouchRoll = dx;
                        flightTouchPitch = SensorManager().flightInvertPitch ? dy : -dy;
                      });
                    }

                    return Listener(
                      behavior: HitTestBehavior.opaque,
                      onPointerDown: (e) => updateYoke(e.localPosition),
                      onPointerMove: (e) => updateYoke(e.localPosition),
                      onPointerUp: (_) => setState(() {
                        flightTouchStickActive = false;
                        flightTouchRoll = 0.0;
                        flightTouchPitch = 0.0;
                      }),
                      onPointerCancel: (_) => setState(() {
                        flightTouchStickActive = false;
                        flightTouchRoll = 0.0;
                        flightTouchPitch = 0.0;
                      }),
                      child: Stack(
                        children: [
                          Positioned.fill(
                            child: RepaintBoundary(
                              child: CustomPaint(
                                painter: ArtificialHorizonPainter(
                                  pitchDeg: displayPitchDeg,
                                  rollDeg: displayRollDeg,
                                ),
                                child: const SizedBox.expand(),
                              ),
                            ),
                          ),
                          Positioned(
                            top: 4,
                            left: 6,
                            child: _m10MiniBadge(
                              'PITCH',
                              '${displayPitchDeg >= 0 ? '+' : ''}${displayPitchDeg.toStringAsFixed(0)}°',
                              hudCol,
                            ),
                          ),
                          Positioned(
                            top: 4,
                            right: 6,
                            child: _m10MiniBadge(
                              'ROLL',
                              '${displayRollDeg >= 0 ? '+' : ''}${displayRollDeg.toStringAsFixed(0)}°',
                              hudCol,
                            ),
                          ),
                          Positioned(
                            bottom: 4,
                            left: 0,
                            right: 0,
                            child: Center(
                              child: Text(
                                flightTouchStickActive ? 'YOKE AKTİF' : 'EĞİM VEYA DOKUNMATİK YOKE',
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.45),
                                  fontSize: 8,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                )
              : Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF0A0A18),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  alignment: Alignment.center,
                  child: const Text(
                    'ADI KAPALI',
                    style: TextStyle(color: Colors.white38, fontSize: 12),
                  ),
                ),
        ),
        const SizedBox(width: 4),
        if (s.mfdShowAltitudeTape)
          SizedBox(
            width: 58,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: RepaintBoundary(
                child: CustomPaint(
                  painter: AltitudeTapePainter(altitudeFt: data.altitudeFt.toDouble()),
                  child: const SizedBox.expand(),
                ),
              ),
            ),
          ),
      ],
    );
  }

  // Sayfa 1: Engine & Aircraft Control Surfaces Monitor
  Widget _buildM10EngineSysPage({
    required AppSettings s,
    required ExtendedTelemetryData data,
    required bool telLive,
    required double n1Frac,
    required double n2Frac,
    required int egtCelsius,
    required int fuelPct,
    required double activeRollNorm,
    required double activePitchNorm,
    required double activeYawNorm,
    required bool effectiveGearDown,
    required bool effectiveAirbrake,
    required Color hudCol,
  }) {
    final int flapsDisplayPct = telLive
        ? data.flapsDeployPct
        : (flightFlapStage == 2 ? 100 : (flightFlapStage == 1 ? 45 : 0));

    return Row(
      children: [
        // Sol yarı: Motor & Yakıt Göstergeleri
        if (s.mfdShowEngineGauges)
          Expanded(
            flex: 5,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF0B1120),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.white10),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _m10CircularDial('N1', n1Frac, '${(n1Frac * 100).round()}%'),
                      _m10CircularDial('N2', n2Frac, '${(n2Frac * 100).round()}%'),
                    ],
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _m10CircularDial(
                        'EGT',
                        ((egtCelsius - 200) / 700.0).clamp(0.0, 1.0),
                        '$egtCelsius°',
                      ),
                      _m10CircularDial(
                        'FUEL',
                        (fuelPct / 100.0).clamp(0.0, 1.0),
                        telLive ? '$fuelPct%' : '100%',
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        if (s.mfdShowEngineGauges) const SizedBox(width: 6),

        // Sağ yarı: Kontrol Yüzeyleri Şeması
        Expanded(
          flex: 6,
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF0B1120),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.white10),
            ),
            child: Column(
              children: [
                Text(
                  'KONTROL YÜZEYLERİ & SİSTEMLER',
                  style: TextStyle(
                    color: hudCol,
                    fontSize: 8.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.7,
                  ),
                ),
                const SizedBox(height: 4),
                Expanded(
                  child: RepaintBoundary(
                    child: CustomPaint(
                      painter: _ControlSurfacesPainter(
                        aileron: activeRollNorm,
                        elevator: activePitchNorm,
                        rudder: activeYawNorm,
                        gearDown: effectiveGearDown,
                        flapsPct: flapsDisplayPct / 100.0,
                        airbrakeActive: effectiveAirbrake,
                        accentColor: hudCol,
                      ),
                      child: const SizedBox.expand(),
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _m10MiniBadge('AIL', '${(activeRollNorm * 100).round()}%', hudCol),
                      const SizedBox(width: 4),
                      _m10MiniBadge('ELV', '${(activePitchNorm * 100).round()}%', hudCol),
                      const SizedBox(width: 4),
                      _m10MiniBadge('FLP', '$flapsDisplayPct%', Colors.amber),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _m10CircularDial(String label, double frac, String text) {
    final c = _m10LoadColor(label == 'FUEL' ? (1.0 - frac).clamp(0.0, 1.0) : frac);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: const TextStyle(color: Colors.white54, fontSize: 8, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 3),
        SizedBox(
          width: 46,
          height: 46,
          child: Stack(
            alignment: Alignment.center,
            children: [
              CircularProgressIndicator(
                value: frac.clamp(0.0, 1.0),
                strokeWidth: 4,
                backgroundColor: Colors.white12,
                valueColor: AlwaysStoppedAnimation(c),
              ),
              Text(
                text,
                style: TextStyle(
                  color: c,
                  fontSize: 9.5,
                  fontWeight: FontWeight.w800,
                  fontFamily: 'monospace',
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // Sayfa 2: NAV / HSI Pusula & Serbest Bakış (Free Look Gimbal)
  Widget _buildM10NavHsiPage(
    AppSettings s,
    ExtendedTelemetryData data,
    bool telLive,
    Color hudCol,
    Color hatCol,
  ) {
    return Row(
      children: [
        Expanded(
          flex: 6,
          child: Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: const Color(0xFF0B1120),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.white10),
            ),
            child: Column(
              children: [
                Text(
                  'YATAY DURUM GÖSTERGESİ (HSI)',
                  style: TextStyle(
                    color: hudCol,
                    fontSize: 8.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.7,
                  ),
                ),
                Expanded(
                  child: RepaintBoundary(
                    child: CustomPaint(
                      painter: _HsiCompassPainter(
                        headingDeg: data.headingDeg.toDouble(),
                        accentColor: hudCol,
                        isLive: telLive,
                      ),
                      child: const SizedBox.expand(),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          flex: 5,
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF0B1120),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: hatCol.withValues(alpha: 0.35)),
            ),
            child: Column(
              children: [
                Text(
                  'SERBEST BAKIŞ (FREE LOOK)',
                  style: TextStyle(
                    color: hatCol,
                    fontSize: 8.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Expanded(
                  child: LayoutBuilder(
                    builder: (ctx, c) {
                      final cx = c.maxWidth / 2;
                      final cy = c.maxHeight / 2;
                      final r = math.max(20.0, math.min(cx, cy) - 4);
                      void updateLook(Offset pos) {
                        final dx = ((pos.dx - cx) / r).clamp(-1.0, 1.0);
                        final dy = ((pos.dy - cy) / r).clamp(-1.0, 1.0);
                        setState(() {
                          flightFreeLookTouchActive = true;
                          joy1x = dx;
                          joy1y = dy;
                        });
                      }

                      return Listener(
                        behavior: HitTestBehavior.opaque,
                        onPointerDown: (e) => updateLook(e.localPosition),
                        onPointerMove: (e) => updateLook(e.localPosition),
                        onPointerUp: (_) => setState(() {
                          flightFreeLookTouchActive = false;
                          joy1x = 0.0;
                          joy1y = 0.0;
                        }),
                        onPointerCancel: (_) => setState(() {
                          flightFreeLookTouchActive = false;
                          joy1x = 0.0;
                          joy1y = 0.0;
                        }),
                        child: Center(
                          child: Container(
                            width: r * 2,
                            height: r * 2,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: hatCol.withValues(alpha: 0.08),
                              border: Border.all(
                                color: flightFreeLookTouchActive
                                    ? hatCol
                                    : hatCol.withValues(alpha: 0.45),
                              ),
                            ),
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                Icon(Icons.visibility, color: hatCol.withValues(alpha: 0.45), size: 22),
                                Transform.translate(
                                  offset: Offset(joy1x * (r * 0.65), joy1y * (r * 0.65)),
                                  child: Container(
                                    width: 18,
                                    height: 18,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: hatCol.withValues(alpha: 0.85),
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
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ── Sağ Yönetim Konsolu (İniş Takımı, Flap, Airbrake & Aviyonik) ─────────
  Widget _buildM10RightConsole({
    required AppSettings s,
    required ExtendedTelemetryData data,
    required bool telLive,
    required bool effectiveGearDown,
    required bool effectiveAirbrake,
    required Color avionicsCol,
    required Color fireCol,
    required Color weaponCol,
    required Color hudCol,
  }) {
    final int gearPct = telLive ? data.gearDeployPct : (effectiveGearDown ? 100 : 0);
    final int flapsPct = telLive
        ? data.flapsDeployPct
        : (flightFlapStage == 2 ? 100 : (flightFlapStage == 1 ? 45 : 0));

    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: const Color(0xFF0A0F1D).withValues(alpha: 0.90),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: avionicsCol.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. İniş Takımı Paneli (3 Yeşil Işık + GEAR Kolu)
          GestureDetector(
            onTap: () {
              setState(() => flightGearDown = !flightGearDown);
              if (s.m9GearKey > 0) fireKey(s.m9GearKey);
              HapticManager().triggerMedium(s);
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
              decoration: BoxDecoration(
                color: effectiveGearDown
                    ? const Color(0xFF00E676).withValues(alpha: 0.14)
                    : const Color(0xFF121829),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: effectiveGearDown ? const Color(0xFF00E676) : Colors.white24,
                ),
              ),
              child: Row(
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _m10GearBulb(effectiveGearDown, gearPct),
                      const SizedBox(width: 2),
                      _m10GearBulb(effectiveGearDown, gearPct),
                      const SizedBox(width: 2),
                      _m10GearBulb(effectiveGearDown, gearPct),
                    ],
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      effectiveGearDown ? 'GEAR DN' : 'GEAR UP',
                      style: TextStyle(
                        color: effectiveGearDown ? const Color(0xFF00E676) : Colors.white70,
                        fontSize: 9.5,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  Text(
                    '$gearPct%',
                    style: const TextStyle(color: Colors.white54, fontSize: 8.5, fontFamily: 'monospace'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 5),

          // 2. 3 Kademeli Flap Seçici + Hava Freni
          Row(
            children: [
              Expanded(
                flex: 6,
                child: Container(
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    color: const Color(0xFF101628),
                    borderRadius: BorderRadius.circular(7),
                    border: Border.all(color: Colors.white12),
                  ),
                  child: Row(
                    children: [
                      _m10FlapOption(0, 'UP', avionicsCol, s),
                      _m10FlapOption(1, 'CMB', avionicsCol, s),
                      _m10FlapOption(2, 'LND', avionicsCol, s),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 4),
              Expanded(
                flex: 4,
                child: GestureDetector(
                  onTap: () {
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
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    decoration: BoxDecoration(
                      color: effectiveAirbrake
                          ? Colors.amber.withValues(alpha: 0.25)
                          : const Color(0xFF121829),
                      borderRadius: BorderRadius.circular(7),
                      border: Border.all(
                        color: effectiveAirbrake ? Colors.amber : Colors.white24,
                      ),
                    ),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Text(
                          effectiveAirbrake ? 'BRK ON' : 'AIRBRK',
                          style: TextStyle(
                            color: effectiveAirbrake ? Colors.amber : Colors.white70,
                            fontSize: 8.5,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          if (telLive)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                'FLAPS: $flapsPct%',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white38, fontSize: 7.5, fontFamily: 'monospace'),
              ),
            ),
          const SizedBox(height: 5),

          // 3. Taktik & Silah Kontrol Matrisi (2x3)
          Expanded(
            child: Column(
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Expanded(
                        child: _m10ActionKey(
                          label: 'GUNS',
                          keyId: s.m9FireKey,
                          color: fireCol,
                          s: s,
                          hold: true,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: _m10ActionKey(
                          label: 'MSL',
                          keyId: s.m9MissileKey,
                          color: weaponCol,
                          s: s,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 4),
                Expanded(
                  child: Row(
                    children: [
                      Expanded(
                        child: _m10ActionKey(
                          label: 'HVY GUN',
                          keyId: s.m9HeavyGunKey,
                          color: fireCol,
                          s: s,
                          hold: true,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: _m10ActionKey(
                          label: 'BOMB',
                          keyId: s.m9BombKey,
                          color: weaponCol,
                          s: s,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 4),
                Expanded(
                  child: Row(
                    children: [
                      Expanded(
                        child: _m10ActionKey(
                          label: 'LOCK',
                          keyId: s.m9LockKey,
                          color: hudCol,
                          s: s,
                          onTapExtra: () {
                            setState(() => flightTargetLocked = !flightTargetLocked);
                          },
                        ),
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: _m10ActionKey(
                          label: 'FLARE',
                          keyId: s.m9FlareKey,
                          color: Colors.amber,
                          s: s,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 4),
                SizedBox(
                  height: 28,
                  child: _m10ActionKey(
                    label: 'RADAR / MAP (${KeyboardKeys.getKeyLabel(s.m9MapKey)})',
                    keyId: s.m9MapKey,
                    color: avionicsCol,
                    s: s,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _m10GearBulb(bool gearDown, int pct) {
    final bool moving = pct > 5 && pct < 95;
    final Color col = moving
        ? const Color(0xFFFFC107)
        : (gearDown ? const Color(0xFF00E676) : const Color(0xFFFF1744));
    return Container(
      width: 7,
      height: 7,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: col,
        boxShadow: [BoxShadow(color: col.withValues(alpha: 0.6), blurRadius: 4)],
      ),
    );
  }

  Widget _m10FlapOption(int stage, String label, Color color, AppSettings s) {
    final bool selected = flightFlapStage == stage;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          final int prev = flightFlapStage;
          setState(() => flightFlapStage = stage);
          if (stage > prev && s.m9FlapDownKey > 0) {
            fireKey(s.m9FlapDownKey);
          } else if (stage < prev && s.m9FlapUpKey > 0) {
            fireKey(s.m9FlapUpKey);
          }
          HapticManager().triggerLight(s);
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 4),
          decoration: BoxDecoration(
            color: selected ? color.withValues(alpha: 0.25) : Colors.transparent,
            borderRadius: BorderRadius.circular(5),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              color: selected ? color : Colors.white54,
              fontSize: 8,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ),
    );
  }

  Widget _m10ActionKey({
    required String label,
    required int keyId,
    required Color color,
    required AppSettings s,
    bool hold = false,
    VoidCallback? onTapExtra,
  }) {
    final bool isActive = pressedKeys.contains(keyId);
    final Widget body = Container(
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      decoration: BoxDecoration(
        color: isActive ? color.withValues(alpha: 0.30) : const Color(0xFF101729),
        borderRadius: BorderRadius.circular(7),
        border: Border.all(
          color: isActive ? color : color.withValues(alpha: 0.4),
          width: isActive ? 1.5 : 1.0,
        ),
      ),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(
          label,
          style: TextStyle(
            color: isActive ? Colors.white : color,
            fontSize: 9,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );

    if (hold) {
      return Listener(
        behavior: HitTestBehavior.opaque,
        onPointerDown: (_) {
          if (keyId > 0) handleButtonDown(keyId);
          HapticManager().triggerMedium(s);
        },
        onPointerUp: (_) {
          if (keyId > 0) handleButtonUp(keyId);
        },
        onPointerCancel: (_) {
          if (keyId > 0) handleButtonUp(keyId);
        },
        child: body,
      );
    }

    return GestureDetector(
      onTap: () {
        if (keyId > 0) fireKey(keyId);
        onTapExtra?.call();
        HapticManager().triggerLight(s);
      },
      child: body,
    );
  }
}

class _FlightTelemetryLifecycleHost extends StatefulWidget {
  final double filterAlpha;
  final Widget child;
  const _FlightTelemetryLifecycleHost({
    required this.filterAlpha,
    required this.child,
  });

  @override
  State<_FlightTelemetryLifecycleHost> createState() =>
      _FlightTelemetryLifecycleHostState();
}

class _FlightTelemetryLifecycleHostState
    extends State<_FlightTelemetryLifecycleHost> {
  @override
  void initState() {
    super.initState();
    TelemetryListenerService().filterAlpha = widget.filterAlpha;
    TelemetryListenerService().start();
  }

  @override
  void dispose() {
    TelemetryListenerService().stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

class _HsiCompassPainter extends CustomPainter {
  final double headingDeg;
  final Color accentColor;
  final bool isLive;

  const _HsiCompassPainter({
    required this.headingDeg,
    required this.accentColor,
    required this.isLive,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2 + 6;
    final radius = math.max(24.0, math.min(cx, cy) - 10);

    canvas.drawCircle(
      Offset(cx, cy),
      radius,
      Paint()
        ..color = const Color(0xFF090F1E)
        ..style = PaintingStyle.fill,
    );
    canvas.drawCircle(
      Offset(cx, cy),
      radius,
      Paint()
        ..color = accentColor.withValues(alpha: 0.45)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );

    canvas.save();
    canvas.translate(cx, cy);
    canvas.rotate(-headingDeg * math.pi / 180.0);

    for (int deg = 0; deg < 360; deg += 10) {
      final rad = (deg - 90) * math.pi / 180.0;
      final isMajor = deg % 30 == 0;
      final inner = radius * (isMajor ? 0.78 : 0.87);
      final outer = radius * 0.96;
      canvas.drawLine(
        Offset(math.cos(rad) * inner, math.sin(rad) * inner),
        Offset(math.cos(rad) * outer, math.sin(rad) * outer),
        Paint()
          ..color = isMajor ? Colors.white70 : Colors.white30
          ..strokeWidth = isMajor ? 1.5 : 0.8,
      );

      if (isMajor) {
        final String label = switch (deg) {
          0 => 'N',
          90 => 'E',
          180 => 'S',
          270 => 'W',
          _ => '${deg ~/ 10}',
        };
        final tp = TextPainter(
          text: TextSpan(
            text: label,
            style: TextStyle(
              color: deg == 0 ? const Color(0xFFFF5252) : Colors.white70,
              fontSize: 9.5,
              fontWeight: FontWeight.bold,
              fontFamily: 'monospace',
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        final textR = radius * 0.64;
        final pos = Offset(
          math.cos(rad) * textR - tp.width / 2,
          math.sin(rad) * textR - tp.height / 2,
        );
        tp.paint(canvas, pos);
      }
    }
    canvas.restore();

    // Sabit Uçak Simgesi ve Üst Lubber Üçgeni
    final tri = Path()
      ..moveTo(cx, cy - radius - 2)
      ..lineTo(cx - 5, cy - radius - 9)
      ..lineTo(cx + 5, cy - radius - 9)
      ..close();
    canvas.drawPath(tri, Paint()..color = accentColor);

    final acPaint = Paint()
      ..color = accentColor
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(cx, cy - 10), Offset(cx, cy + 10), acPaint);
    canvas.drawLine(Offset(cx - 10, cy - 1), Offset(cx + 10, cy - 1), acPaint);
    canvas.drawLine(Offset(cx - 4, cy + 8), Offset(cx + 4, cy + 8), acPaint);

    final hdgText = TextPainter(
      text: TextSpan(
        text: isLive ? 'HDG ${headingDeg.round().toString().padLeft(3, '0')}°' : 'HDG ---',
        style: TextStyle(
          color: accentColor,
          fontSize: 9.5,
          fontWeight: FontWeight.w800,
          fontFamily: 'monospace',
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    hdgText.paint(canvas, Offset(cx - hdgText.width / 2, cy + radius - 14));
  }

  @override
  bool shouldRepaint(covariant _HsiCompassPainter oldDelegate) =>
      oldDelegate.headingDeg != headingDeg ||
      oldDelegate.accentColor != accentColor ||
      oldDelegate.isLive != isLive;
}

class _ControlSurfacesPainter extends CustomPainter {
  final double aileron;
  final double elevator;
  final double rudder;
  final bool gearDown;
  final double flapsPct;
  final bool airbrakeActive;
  final Color accentColor;

  const _ControlSurfacesPainter({
    required this.aileron,
    required this.elevator,
    required this.rudder,
    required this.gearDown,
    required this.flapsPct,
    required this.airbrakeActive,
    required this.accentColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final s = math.min(size.width, size.height) * 0.42;

    final bodyPaint = Paint()
      ..color = Colors.white24
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    // Gövde & Kanat silueti
    final craft = Path()
      ..moveTo(cx, cy - s)
      ..lineTo(cx + s * 0.16, cy - s * 0.35)
      ..lineTo(cx + s * 0.98, cy + s * 0.12)
      ..lineTo(cx + s * 0.98, cy + s * 0.30)
      ..lineTo(cx + s * 0.18, cy + s * 0.25)
      ..lineTo(cx + s * 0.16, cy + s * 0.62)
      ..lineTo(cx + s * 0.52, cy + s * 0.85)
      ..lineTo(cx + s * 0.52, cy + s * 0.98)
      ..lineTo(cx, cy + s * 0.82)
      ..lineTo(cx - s * 0.52, cy + s * 0.98)
      ..lineTo(cx - s * 0.52, cy + s * 0.85)
      ..lineTo(cx - s * 0.16, cy + s * 0.62)
      ..lineTo(cx - s * 0.18, cy + s * 0.25)
      ..lineTo(cx - s * 0.98, cy + s * 0.30)
      ..lineTo(cx - s * 0.98, cy + s * 0.12)
      ..lineTo(cx - s * 0.16, cy - s * 0.35)
      ..close();
    canvas.drawPath(craft, bodyPaint);

    // Kanatçık (Aileron) sapması (sol & sağ)
    final Color ailCol = aileron.abs() > 0.05 ? accentColor : Colors.white30;
    canvas.drawLine(
      Offset(cx - s * 0.88, cy + s * 0.30 - aileron * 8),
      Offset(cx - s * 0.52, cy + s * 0.27 - aileron * 8),
      Paint()
        ..color = ailCol
        ..strokeWidth = 3,
    );
    canvas.drawLine(
      Offset(cx + s * 0.52, cy + s * 0.27 + aileron * 8),
      Offset(cx + s * 0.88, cy + s * 0.30 + aileron * 8),
      Paint()
        ..color = ailCol
        ..strokeWidth = 3,
    );

    // Flap göstergesi
    if (flapsPct > 0.05) {
      final flapPaint = Paint()
        ..color = Colors.amber
        ..strokeWidth = 3;
      canvas.drawLine(
        Offset(cx - s * 0.48, cy + s * 0.28 + flapsPct * 6),
        Offset(cx - s * 0.22, cy + s * 0.28 + flapsPct * 6),
        flapPaint,
      );
      canvas.drawLine(
        Offset(cx + s * 0.22, cy + s * 0.28 + flapsPct * 6),
        Offset(cx + s * 0.48, cy + s * 0.28 + flapsPct * 6),
        flapPaint,
      );
    }

    // İrtifa Dümeni (Elevator)
    canvas.drawLine(
      Offset(cx - s * 0.45, cy + s * 0.94 + elevator * 7),
      Offset(cx + s * 0.45, cy + s * 0.94 + elevator * 7),
      Paint()
        ..color = elevator.abs() > 0.05 ? accentColor : Colors.white30
        ..strokeWidth = 2.5,
    );

    // İstikamet Dümeni (Rudder)
    canvas.drawLine(
      Offset(cx, cy + s * 0.58),
      Offset(cx + rudder * 12, cy + s * 0.92),
      Paint()
        ..color = rudder.abs() > 0.05 ? const Color(0xFF00E676) : Colors.white38
        ..strokeWidth = 3,
    );

    // Hava freni & İniş takımı göstergeleri
    if (airbrakeActive) {
      canvas.drawRect(
        Rect.fromCenter(center: Offset(cx, cy + s * 0.15), width: 12, height: 10),
        Paint()..color = Colors.amber.withValues(alpha: 0.75),
      );
    }
    if (gearDown) {
      final gp = Paint()..color = const Color(0xFF00E676);
      canvas.drawCircle(Offset(cx, cy - s * 0.55), 3.5, gp);
      canvas.drawCircle(Offset(cx - s * 0.35, cy + s * 0.15), 3.5, gp);
      canvas.drawCircle(Offset(cx + s * 0.35, cy + s * 0.15), 3.5, gp);
    }
  }

  @override
  bool shouldRepaint(covariant _ControlSurfacesPainter old) =>
      old.aileron != aileron ||
      old.elevator != elevator ||
      old.rudder != rudder ||
      old.gearDown != gearDown ||
      old.flapsPct != flapsPct ||
      old.airbrakeActive != airbrakeActive ||
      old.accentColor != accentColor;
}
