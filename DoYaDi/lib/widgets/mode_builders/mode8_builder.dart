part of '../driving_mode_builders.dart';

/// Mod 8 — Rahat Sürüş Modu (Chill Drive - Dikey Tek El Modu)
///
/// Sensör tabanlı tek el sürüş:
/// - Telefonu sağa/sola eğme (Roll) veya döndürme (Yaw) → Direksiyon
/// - Telefonu öne eğme (Pitch +) → Gaz, kendine çekme (Pitch -) → Fren
/// - Dikey Gaz ve Fren barlarına dokunarak/kaydırarak manuel pedal müdahalesi (Touch Override)
/// - Başparmak altında Vites Küçült / Vites Büyüt (LB/RB), El Freni, Korna ve Hız Sabitleyici (Cruise Control)
/// - Kapsül Baloncuk (Arka Plan Overlay) hızlı geçiş ve merkezleme (Kalibre) küresi
extension _Mode8BuilderExt<T extends StatefulWidget> on DrivingModeBuildMixin<T> {
  Widget buildMode8(AppSettings s, Size size) {
    final sensor = SensorManager();
    return _withTrackPoint(
      s,
      size,
      _ChillDriveContent(
        settings: s,
        parentSize: size,
        steeringAngle: steeringAngle,
        gasPercentage: gasPercentage,
        brakePercentage: brakePercentage,
        pitchDeltaDeg: sensor.chillPitchDeg,
        rollDeltaDeg: sensor.chillRollDeg,
        cruiseLocked: chillCruiseControlLocked,
        cruiseGasValue: chillCruiseControlGasValue,
        isHandbrakeActive: pressedKeys.contains(s.handbrakeKey),
        isHornActive: pressedKeys.contains(s.mod6HornKey),
        isGearDownActive: pressedKeys.contains(1), // LB
        isGearUpActive: pressedKeys.contains(2), // RB
        onCalibrate: () {
          SensorManager().calibrateChillDrive();
          HapticManager().triggerLight(s);
        },
        onToggleCruise: () {
          setState(() {
            if (chillCruiseControlLocked) {
              chillCruiseControlLocked = false;
              chillCruiseControlGasValue = 0.0;
            } else {
              final targetGas = gasPercentage > 0.08 ? gasPercentage : 0.45;
              chillCruiseControlLocked = true;
              chillCruiseControlGasValue = targetGas;
              gasPercentage = targetGas;
              brakePercentage = 0.0;
            }
          });
          HapticManager().triggerLight(s);
        },
        onTouchPedalChanged: (bool isGas, double? val) {
          setState(() {
            if (isGas) {
              if (val == null) {
                chillTouchGasActive = false;
              } else {
                chillTouchGasActive = true;
                gasPercentage = val.clamp(0.0, 1.0);
              }
            } else {
              if (val == null) {
                chillTouchBrakeActive = false;
              } else {
                chillTouchBrakeActive = true;
                chillCruiseControlLocked = false;
                brakePercentage = val.clamp(0.0, 1.0);
                if (val > 0.05) gasPercentage = 0.0;
              }
            }
          });
        },
        onButtonDown: (int key) {
          if (! isGasOrBrakeSpecialKey(key)) {
            handleButtonDown(key);
          }
        },
        onButtonUp: (int key) {
          if (!isGasOrBrakeSpecialKey(key)) {
            handleButtonUp(key);
          }
        },
      ),
      mode: 8,
    );
  }

  bool isGasOrBrakeSpecialKey(int key) => key <= 0;
}

class _ChillDriveContent extends StatefulWidget {
  final AppSettings settings;
  final Size parentSize;
  final double steeringAngle;
  final double gasPercentage;
  final double brakePercentage;
  final double pitchDeltaDeg;
  final double rollDeltaDeg;
  final bool cruiseLocked;
  final double cruiseGasValue;
  final bool isHandbrakeActive;
  final bool isHornActive;
  final bool isGearDownActive;
  final bool isGearUpActive;
  final VoidCallback onCalibrate;
  final VoidCallback onToggleCruise;
  final void Function(bool isGas, double? value) onTouchPedalChanged;
  final void Function(int key) onButtonDown;
  final void Function(int key) onButtonUp;

  const _ChillDriveContent({
    required this.settings,
    required this.parentSize,
    required this.steeringAngle,
    required this.gasPercentage,
    required this.brakePercentage,
    required this.pitchDeltaDeg,
    required this.rollDeltaDeg,
    required this.cruiseLocked,
    required this.cruiseGasValue,
    required this.isHandbrakeActive,
    required this.isHornActive,
    required this.isGearDownActive,
    required this.isGearUpActive,
    required this.onCalibrate,
    required this.onToggleCruise,
    required this.onTouchPedalChanged,
    required this.onButtonDown,
    required this.onButtonUp,
  });

  @override
  State<_ChillDriveContent> createState() => _ChillDriveContentState();
}

class _ChillDriveContentState extends State<_ChillDriveContent> {
  bool _calibratedFlash = false;

  static const _mod8BgChannel = MethodChannel('Navilastro.DoYaDi/volume_keys');

  Future<void> _setOverlayMode(
    BuildContext context,
    AppSettings s, {
    required bool enabled,
    int? style,
  }) async {
    final prov = Provider.of<SettingsProvider>(context, listen: false);
    String ip = '';
    try {
      final conn = Provider.of<ConnectionProvider>(context, listen: false);
      ip = conn.wifiIp;
    } catch (_) {}
    if (ip.isEmpty) {
      ip = NetworkManager().serverIp;
    }

    s.chillOverlayEnabled = enabled;
    if (style != null) {
      s.chillOverlayStyle = style;
    }

    if (enabled) {
      bool overlayGranted = true;
      try {
        overlayGranted =
            (await _mod8BgChannel.invokeMethod<bool>('check_overlay_permission')) ?? true;
        if (!overlayGranted) {
          await _mod8BgChannel.invokeMethod('request_overlay_permission');
          overlayGranted =
              (await _mod8BgChannel.invokeMethod<bool>('check_overlay_permission')) ?? false;
        }
      } catch (_) {}

      try {
        if (await Permission.notification.isDenied) {
          await Permission.notification.request();
        }
      } catch (_) {}

      prov.updateSettings(s);
      final sm = SensorManager();
      _mod8BgChannel.invokeMethod('start_mod8_bg', {
        'ip': ip,
        'steerSens': s.chillSteeringSensitivity,
        'gasBrakeSens': s.chillGasBrakeSensitivity,
        'steeringAngle': s.steeringAngle,
        'steeringAxis': s.chillSteeringAxis,
        'showGearButtons': s.chillOverlayGearButtons,
        'overlayStyle': s.chillOverlayStyle,
        'basePitch': sm.chillBasePitch,
        'baseRoll': sm.chillBaseRoll,
        'cruiseLocked': widget.cruiseLocked,
        'cruiseGasValue': widget.cruiseGasValue,
        'overlayBgColor': s.mod8OverlayBgColor.toARGB32(),
        'overlayBorderColor': s.mod8OverlayBorderColor.toARGB32(),
        'overlaySteerColor': s.mod8OverlaySteerColor.toARGB32(),
        'overlayGasColor': s.mod8OverlayGasColor.toARGB32(),
        'overlayBrakeColor': s.mod8OverlayBrakeColor.toARGB32(),
        'overlayGearBtnColor': s.mod8OverlayGearBtnColor.toARGB32(),
        'lang': AppTranslations.currentLanguage,
      }).catchError((_) {});

      if (context.mounted) {
        final styleName = s.chillOverlayStyle == 0
            ? AppTranslations.getText('chill_bg_capsule')
            : AppTranslations.getText('chill_bg_bubble');
        final styleDesc = s.chillOverlayStyle == 0
            ? AppTranslations.getText('chill_bg_capsule_desc')
            : AppTranslations.getText('chill_bg_bubble_desc');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '$styleName: $styleDesc',
              style: const TextStyle(color: Colors.white, fontSize: 12),
            ),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } else {
      prov.updateSettings(s);
      _mod8BgChannel.invokeMethod('stop_mod8_bg').catchError((_) {});
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${AppTranslations.getText('chill_bg_title')}: ${AppTranslations.getText('chill_bg_off')}',
              style: const TextStyle(color: Colors.white, fontSize: 12),
            ),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
    if (mounted) setState(() {});
  }

  Future<void> _cycleOverlayMode(BuildContext context, AppSettings s) async {
    if (!s.chillOverlayEnabled) {
      // Kapalı -> Kapsül
      await _setOverlayMode(context, s, enabled: true, style: 0);
    } else if (s.chillOverlayStyle == 0) {
      // Kapsül -> Baloncuk (3 Yuvarlak)
      await _setOverlayMode(context, s, enabled: true, style: 1);
    } else {
      // Baloncuk -> Kapalı
      await _setOverlayMode(context, s, enabled: false);
    }
  }

  void _showOverlayPicker(BuildContext context, AppSettings s) {
    final ac = s.detailColor;
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF16162A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        AppTranslations.getText('chill_bg_title'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: ac,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white70),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                _buildOverlayOptionTile(
                  title: AppTranslations.getText('chill_bg_off'),
                  desc: AppTranslations.getText('chill_bg_off_desc'),
                  icon: Icons.layers_clear,
                  isSelected: !s.chillOverlayEnabled,
                  ac: ac,
                  onTap: () {
                    Navigator.pop(ctx);
                    _setOverlayMode(context, s, enabled: false);
                  },
                ),
                const SizedBox(height: 8),
                _buildOverlayOptionTile(
                  title: AppTranslations.getText('chill_bg_capsule'),
                  desc: AppTranslations.getText('chill_bg_capsule_desc'),
                  icon: Icons.web_asset,
                  isSelected: s.chillOverlayEnabled && s.chillOverlayStyle == 0,
                  ac: ac,
                  onTap: () {
                    Navigator.pop(ctx);
                    _setOverlayMode(context, s, enabled: true, style: 0);
                  },
                ),
                const SizedBox(height: 8),
                _buildOverlayOptionTile(
                  title: AppTranslations.getText('chill_bg_bubble'),
                  desc: AppTranslations.getText('chill_bg_bubble_desc'),
                  icon: Icons.bubble_chart,
                  isSelected: s.chillOverlayEnabled && s.chillOverlayStyle == 1,
                  ac: ac,
                  onTap: () {
                    Navigator.pop(ctx);
                    _setOverlayMode(context, s, enabled: true, style: 1);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildOverlayOptionTile({
    required String title,
    required String desc,
    required IconData icon,
    required bool isSelected,
    required Color ac,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? ac.withValues(alpha: 0.15) : const Color(0xFF0F0F1E),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? ac : Colors.white12,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(icon, color: isSelected ? ac : Colors.white54, size: 24),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: isSelected ? ac : Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    desc,
                    style: const TextStyle(color: Colors.white54, fontSize: 11),
                  ),
                ],
              ),
            ),
            if (isSelected)
              Icon(Icons.check_circle_rounded, color: ac, size: 20),
          ],
        ),
      ),
    );
  }

  Future<void> _toggleSteeringAxis(BuildContext context, AppSettings s) async {
    final prov = Provider.of<SettingsProvider>(context, listen: false);
    s.chillSteeringAxis = s.chillSteeringAxis == 0 ? 1 : 0;
    SensorManager().calibrateChillDrive();
    prov.updateSettings(s);
    if (mounted) setState(() {});
  }

  void _handlePedalPointer(PointerEvent e, double maxHeight, bool isGas) {
    final double localY = e.localPosition.dy.clamp(0.0, maxHeight);
    final double ratio = (1.0 - (localY / math.max(1.0, maxHeight))).clamp(0.0, 1.0);
    widget.onTouchPedalChanged(isGas, ratio);
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.settings;
    final steerAccent = s.mod8SteerColor;
    final hasBgMedia = AppMediaHelper.hasMedia(s.modeBackgroundMedia(8));
    final pageBg = s.modeBackgroundColor(8);
    final txt = hasBgMedia ? Colors.white : s.contrastTextFor(pageBg);
    final sub = hasBgMedia
        ? Colors.white70
        : txt.withValues(alpha: 0.55);

    return Container(
      color: Colors.transparent,
      child: SafeArea(
        child: Stack(
          children: [
            // ── Arka Plan Atmosferik Işıma ──
            if (!hasBgMedia)
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      center: const Alignment(0, -0.1),
                      radius: 1.1,
                      colors: [
                        steerAccent.withValues(alpha: 0.06),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),

            // ── Ana Dikey (Portrait) Tek-El Kokpit Düzeni ──
            LayoutBuilder(
              builder: (context, rootConstraints) {
                final bool isTightH = rootConstraints.maxHeight < 460;
                final double vGap = isTightH ? 6 : 14;
                final double hPad = rootConstraints.maxWidth < 360 ? 10 : 14;

                return Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: hPad,
                    vertical: isTightH ? 6 : 10,
                  ),
                  child: Column(
                    children: [
                      // 1. ÜST BAR: Başlık + Kapsül Baloncuk & Eksen Hızlı Geçişleri
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Flexible(
                            child: BlurredTextChip(
                              enabled: hasBgMedia,
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    AppTranslations.getText('chill_mode_title'),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: steerAccent,
                                      fontSize: 13,
                                      letterSpacing: 3,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    AppTranslations.getText('chill_mode_subtitle'),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: sub,
                                      fontSize: 9,
                                      letterSpacing: 1.2,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // Eksen Seçici (Roll / Yaw)
                              GestureDetector(
                                onTap: () => _toggleSteeringAxis(context, s),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF121226).withValues(alpha: 0.85),
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(color: steerAccent.withValues(alpha: 0.45)),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        s.chillSteeringAxis == 0
                                            ? Icons.screen_rotation
                                            : Icons.rotate_90_degrees_ccw,
                                        color: steerAccent,
                                        size: 13,
                                      ),
                                      const SizedBox(width: 5),
                                      Text(
                                        s.chillSteeringAxis == 0 ? 'ROLL' : 'YAW',
                                        style: TextStyle(
                                          color: steerAccent,
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                          letterSpacing: 1,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              // Kapsül Baloncuk (Overlay) 3 Durumlu Buton: Kapalı -> Kapsül -> Baloncuk
                              GestureDetector(
                                onTap: () => _cycleOverlayMode(context, s),
                                onLongPress: () => _showOverlayPicker(context, s),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: s.chillOverlayEnabled
                                        ? steerAccent.withValues(alpha: 0.25)
                                        : const Color(0xFF121226).withValues(alpha: 0.85),
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(
                                      color: s.chillOverlayEnabled ? steerAccent : Colors.white24,
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        !s.chillOverlayEnabled
                                            ? Icons.layers_clear
                                            : (s.chillOverlayStyle == 0
                                                ? Icons.web_asset
                                                : Icons.bubble_chart),
                                        color: s.chillOverlayEnabled ? steerAccent : Colors.white70,
                                        size: 14,
                                      ),
                                      const SizedBox(width: 5),
                                      ConstrainedBox(
                                        constraints: const BoxConstraints(maxWidth: 74),
                                        child: Text(
                                          !s.chillOverlayEnabled
                                              ? AppTranslations.getText('chill_bg_off')
                                              : (s.chillOverlayStyle == 0
                                                  ? AppTranslations.getText('chill_bg_capsule')
                                                  : AppTranslations.getText('chill_bg_bubble')),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            color: s.chillOverlayEnabled ? steerAccent : Colors.white70,
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),

                      SizedBox(height: vGap),

                      // 2. DİREKSİYON BAR GÖSTERGESİ
                      _buildSteeringSection(widget.steeringAngle, s),

                      SizedBox(height: vGap),

                      // 3. ORTA BÖLÜM: Sol Fren Barı + Merkez 2D Eğim/Kalibrasyon Küresi + Sağ Gaz Barı
                      Expanded(
                        child: Row(
                          children: [
                            // SOL SÜTUN: FREN (Hem Sensör Göstergesi Hem Dokunmatik)
                            _buildInteractivePedalBar(
                              label: AppTranslations.getText('chill_brake_label'),
                              subLabel: AppTranslations.getText('chill_brake_sub'),
                              value: widget.brakePercentage,
                              color: s.mod8BrakeColor,
                              subColor: sub,
                              isGas: false,
                            ),

                            // MERKEZ: 2 Eksenli Eğim Radarı + Kalibre + Hız Sabitleyici + Yardımcı Tuşlar
                            Expanded(
                              child: Padding(
                                padding: EdgeInsets.symmetric(
                                  horizontal: rootConstraints.maxWidth < 360 ? 6 : 10,
                                ),
                                child: LayoutBuilder(
                                  builder: (ctx, centerConstraints) {
                                    final double maxH = centerConstraints.maxHeight;
                                    final double maxW = centerConstraints.maxWidth;
                                    final double sphereSize = math.min(
                                      (maxH * 0.45).clamp(56.0, 148.0),
                                      (maxW * 0.88).clamp(56.0, 148.0),
                                    );

                                    final holdButtonsRow = Row(
                                      children: [
                                        Expanded(
                                          child: _buildHoldActionButton(
                                            label: AppTranslations.getText('chill_handbrake_key'),
                                            icon: Icons.warning_amber_rounded,
                                            activeColor: s.mod8HoldButtonsColor,
                                            isActive: widget.isHandbrakeActive,
                                            onDown: () => widget.onButtonDown(s.handbrakeKey),
                                            onUp: () => widget.onButtonUp(s.handbrakeKey),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: _buildHoldActionButton(
                                            label: AppTranslations.getText('chill_horn_key'),
                                            icon: Icons.volume_up_rounded,
                                            activeColor: s.mod8HoldButtonsColor,
                                            isActive: widget.isHornActive,
                                            onDown: () => widget.onButtonDown(s.mod6HornKey),
                                            onUp: () => widget.onButtonUp(s.mod6HornKey),
                                          ),
                                        ),
                                      ],
                                    );

                                    if (maxH < 215) {
                                      return FittedBox(
                                        fit: BoxFit.scaleDown,
                                        alignment: Alignment.center,
                                        child: SizedBox(
                                          width: maxW,
                                          child: Column(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              _buildTiltSphereAndCalibrate(
                                                s,
                                                sub,
                                                sphereSize: sphereSize,
                                              ),
                                              const SizedBox(height: 6),
                                              _buildCruiseControlButton(s),
                                              const SizedBox(height: 6),
                                              holdButtonsRow,
                                            ],
                                          ),
                                        ),
                                      );
                                    }

                                    return Column(
                                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                      children: [
                                        _buildTiltSphereAndCalibrate(
                                          s,
                                          sub,
                                          sphereSize: sphereSize,
                                        ),
                                        _buildCruiseControlButton(s),
                                        holdButtonsRow,
                                      ],
                                    );
                                  },
                                ),
                              ),
                            ),

                            // SAĞ SÜTUN: GAZ (Hem Sensör Göstergesi Hem Dokunmatik)
                            _buildInteractivePedalBar(
                              label: AppTranslations.getText('chill_gas_label'),
                              subLabel: AppTranslations.getText('chill_gas_sub'),
                              value: widget.gasPercentage,
                              color: s.mod8GasColor,
                              subColor: sub,
                              isGas: true,
                            ),
                          ],
                        ),
                      ),

                      SizedBox(height: isTightH ? 6 : 12),

                      // 4. BAŞPARMAK VİTES PANELİ (GEAR - / GEAR +)
                      if (s.chillOverlayGearButtons) ...[
                        Row(
                          children: [
                            Expanded(
                              child: _buildGearShiftButton(
                                label: AppTranslations.getText('chill_gear_down'),
                                badge: 'L1 / -',
                                icon: Icons.keyboard_double_arrow_down_rounded,
                                color: s.mod8GearBtnColor,
                                isActive: widget.isGearDownActive,
                                compact: isTightH,
                                onDown: () => widget.onButtonDown(1), // L1
                                onUp: () => widget.onButtonUp(1),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _buildGearShiftButton(
                                label: AppTranslations.getText('chill_gear_up'),
                                badge: 'R1 / +',
                                icon: Icons.keyboard_double_arrow_up_rounded,
                                color: s.mod8GearBtnColor,
                                isActive: widget.isGearUpActive,
                                compact: isTightH,
                                onDown: () => widget.onButtonDown(2), // R1
                                onUp: () => widget.onButtonUp(2),
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: isTightH ? 6 : 10),
                      ],

                      // 5. ALT SENSÖR TELEMETRİ ÇİPLERİ
                      Row(
                        children: [
                          Expanded(
                            child: _buildInfoChip(
                              AppTranslations.getText('chill_chip_tilt'),
                              '${widget.pitchDeltaDeg >= 0 ? '+' : ''}${widget.pitchDeltaDeg.toStringAsFixed(1)}°',
                              s,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _buildInfoChip(
                              AppTranslations.getText('chill_chip_steer_angle'),
                              '${(widget.steeringAngle * s.steeringAngle).toStringAsFixed(0)}°',
                              s,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _buildInfoChip(
                              AppTranslations.getText('chill_chip_sensitivity'),
                              '${s.chillSteeringSensitivity.toStringAsFixed(1)}x / ${s.chillGasBrakeSensitivity.toStringAsFixed(1)}x',
                              s,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSteeringSection(double angle, AppSettings s) {
    final ac = s.mod8SteerColor;
    final int pct = (angle * 100).round();
    final String leftTxt = AppTranslations.getText('chill_left_short');
    final String rightTxt = AppTranslations.getText('chill_right_short');
    final String dirText = pct == 0
        ? AppTranslations.getText('chill_center_zero')
        : pct < 0
            ? '$leftTxt ${pct.abs()}%'
            : '$rightTxt $pct%';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF0D0D1C).withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: ac.withValues(alpha: 0.25)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '◄ $leftTxt',
                style: const TextStyle(color: Colors.white38, fontSize: 9, letterSpacing: 1.5),
              ),
              Text(
                dirText,
                style: TextStyle(
                  color: ac,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'monospace',
                ),
              ),
              Text(
                '$rightTxt ►',
                style: const TextStyle(color: Colors.white38, fontSize: 9, letterSpacing: 1.5),
              ),
            ],
          ),
          const SizedBox(height: 6),
          SizedBox(
            height: 14,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final w = constraints.maxWidth;
                final center = w / 2;
                final indicatorX = (center + (angle * center)).clamp(4.0, w - 4.0);

                return Stack(
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFF1A1A2E),
                        borderRadius: BorderRadius.circular(7),
                      ),
                    ),
                    Positioned(
                      left: angle >= 0 ? center : indicatorX,
                      width: (angle.abs() * center).clamp(0.0, center),
                      top: 0,
                      bottom: 0,
                      child: Container(
                        decoration: BoxDecoration(
                          color: ac.withValues(alpha: 0.4),
                          borderRadius: BorderRadius.circular(7),
                        ),
                      ),
                    ),
                    Positioned(
                      left: center - 1,
                      top: 0,
                      bottom: 0,
                      child: Container(
                        width: 2,
                        color: Colors.white24,
                      ),
                    ),
                    Positioned(
                      left: indicatorX - 5,
                      top: 0,
                      bottom: 0,
                      child: Container(
                        width: 10,
                        decoration: BoxDecoration(
                          color: ac,
                          borderRadius: BorderRadius.circular(5),
                          boxShadow: [
                            BoxShadow(
                              color: ac.withValues(alpha: 0.6),
                              blurRadius: 8,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTiltSphereAndCalibrate(
    AppSettings s,
    Color sub, {
    double sphereSize = 148.0,
  }) {
    final ac = s.mod8RadarColor;
    final double scale = sphereSize / 148.0;
    final double deadzoneSize = 52.0 * scale;
    final double axisLength = 120.0 * scale;
    final double dotSize = (22.0 * scale).clamp(14.0, 22.0);
    final double travelRadius = 52.0 * scale;

    // Normalize dot offset inside radar (-1.0 .. 1.0)
    final double normX = widget.steeringAngle.clamp(-1.0, 1.0);
    final double normY = (-widget.pitchDeltaDeg / 28.0).clamp(-1.0, 1.0);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: () {
            widget.onCalibrate();
            setState(() => _calibratedFlash = true);
            Future.delayed(const Duration(milliseconds: 1200), () {
              if (mounted) setState(() => _calibratedFlash = false);
            });
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            width: sphereSize,
            height: sphereSize,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _calibratedFlash
                  ? ac.withValues(alpha: 0.22)
                  : const Color(0xFF0E0E20).withValues(alpha: 0.88),
              border: Border.all(
                color: _calibratedFlash ? ac : ac.withValues(alpha: 0.45),
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: ac.withValues(alpha: _calibratedFlash ? 0.35 : 0.12),
                  blurRadius: 22,
                ),
              ],
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                // İç halka (Ölü alan sınırı)
                Container(
                  width: deadzoneSize,
                  height: deadzoneSize,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white12, width: 1),
                  ),
                ),
                // Yatay ve dikey eksen çizgileri
                Container(width: axisLength, height: 1, color: Colors.white10),
                Container(width: 1, height: axisLength, color: Colors.white10),

                // Canlı Eğim Noktası (Pitch + Roll)
                Transform.translate(
                  offset: Offset(normX * travelRadius, normY * travelRadius),
                  child: Container(
                    width: dotSize,
                    height: dotSize,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: ac,
                      boxShadow: [
                        BoxShadow(
                          color: ac.withValues(alpha: 0.7),
                          blurRadius: 12,
                        ),
                      ],
                    ),
                    child: Icon(
                      _calibratedFlash ? Icons.check : Icons.my_location,
                      size: (13.0 * scale).clamp(9.0, 13.0),
                      color: s.contrastTextFor(ac),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        SizedBox(height: sphereSize < 100 ? 4 : 8),
        BlurredTextChip(
          enabled: AppMediaHelper.hasMedia(s.modeBackgroundMedia(8)),
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              _calibratedFlash
                  ? AppTranslations.getText('chill_calibrated')
                  : AppTranslations.getText('chill_calibrate_touch'),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: _calibratedFlash ? ac : sub,
                fontSize: 9,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.3,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCruiseControlButton(AppSettings s) {
    final bool locked = widget.cruiseLocked;
    final Color activeColor = s.mod8CruiseColor;

    return GestureDetector(
      onTap: widget.onToggleCruise,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: locked
              ? activeColor.withValues(alpha: 0.22)
              : const Color(0xFF121226).withValues(alpha: 0.88),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: locked ? activeColor : activeColor.withValues(alpha: 0.25),
            width: 1.5,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              locked ? Icons.lock_rounded : Icons.speed_rounded,
              color: locked ? activeColor : Colors.white60,
              size: 16,
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                locked
                    ? '${AppTranslations.getText('chill_cruise_locked')} (${(widget.cruiseGasValue * 100).round()}%)'
                    : AppTranslations.getText('chill_cruise_button'),
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: locked ? activeColor : Colors.white70,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.8,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHoldActionButton({
    required String label,
    required IconData icon,
    required Color activeColor,
    required bool isActive,
    required VoidCallback onDown,
    required VoidCallback onUp,
  }) {
    return Listener(
      behavior: HitTestBehavior.opaque,
      onPointerDown: (_) => onDown(),
      onPointerUp: (_) => onUp(),
      onPointerCancel: (_) => onUp(),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 12),
        decoration: BoxDecoration(
          color: isActive
              ? activeColor.withValues(alpha: 0.25)
              : const Color(0xFF121226),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isActive ? activeColor : Colors.white12,
            width: 1.5,
          ),
        ),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                color: isActive ? activeColor : Colors.white70,
                size: 18,
              ),
              const SizedBox(height: 4),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: isActive ? activeColor : Colors.white70,
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGearShiftButton({
    required String label,
    required String badge,
    required IconData icon,
    required Color color,
    required bool isActive,
    required VoidCallback onDown,
    required VoidCallback onUp,
    bool compact = false,
  }) {
    return Listener(
      behavior: HitTestBehavior.opaque,
      onPointerDown: (_) => onDown(),
      onPointerUp: (_) => onUp(),
      onPointerCancel: (_) => onUp(),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 100),
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 10 : 14,
          vertical: compact ? 8 : 14,
        ),
        decoration: BoxDecoration(
          color: isActive ? color.withValues(alpha: 0.28) : const Color(0xFF111124),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isActive ? color : color.withValues(alpha: 0.35),
            width: 1.6,
          ),
          boxShadow: isActive
              ? [
                  BoxShadow(
                    color: color.withValues(alpha: 0.3),
                    blurRadius: 12,
                  ),
                ]
              : null,
        ),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: color, size: 22),
              const SizedBox(width: 8),
              Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1,
                    ),
                  ),
                  Text(
                    badge,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: color.withValues(alpha: 0.8),
                      fontSize: 9,
                      fontFamily: 'monospace',
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInteractivePedalBar({
    required String label,
    required String subLabel,
    required double value,
    required Color color,
    required Color subColor,
    required bool isGas,
  }) {
    final double barColWidth = math.min(
      64.0,
      (widget.parentSize.width * 0.17).clamp(52.0, 64.0),
    );
    final double barInnerWidth = (barColWidth - 16.0).clamp(36.0, 48.0);

    return SizedBox(
      width: barColWidth,
      child: LayoutBuilder(
        builder: (context, colConstraints) {
          final bool compact = colConstraints.maxHeight < 130;

          final content = Column(
            children: [
              BlurredTextChip(
                enabled: AppMediaHelper.hasMedia(widget.settings.modeBackgroundMedia(8)),
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    '${(value * 100).round()}%',
                    style: TextStyle(
                      color: color,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'monospace',
                    ),
                  ),
                ),
              ),
              SizedBox(height: compact ? 2 : 6),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final h = constraints.maxHeight;
                    return Listener(
                      behavior: HitTestBehavior.opaque,
                      onPointerDown: (e) => _handlePedalPointer(e, h, isGas),
                      onPointerMove: (e) => _handlePedalPointer(e, h, isGas),
                      onPointerUp: (_) => widget.onTouchPedalChanged(isGas, null),
                      onPointerCancel: (_) => widget.onTouchPedalChanged(isGas, null),
                      child: Stack(
                        alignment: Alignment.bottomCenter,
                        children: [
                          // Arka plan kanal
                          Container(
                            width: barInnerWidth,
                            decoration: BoxDecoration(
                              color: const Color(0xFF101022).withValues(alpha: 0.88),
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(
                                color: color.withValues(alpha: 0.3),
                                width: 1.5,
                              ),
                            ),
                          ),
                          // Seviye çizgileri (%25, %50, %75)
                          for (final frac in [0.25, 0.5, 0.75])
                            Positioned(
                              bottom: h * frac,
                              child: Container(
                                width: (barInnerWidth - 18).clamp(16.0, 30.0),
                                height: 1,
                                color: Colors.white10,
                              ),
                            ),
                          // Dolgu barı
                          Container(
                            width: barInnerWidth,
                            height: (h * value).clamp(0.0, h),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.bottomCenter,
                                end: Alignment.topCenter,
                                colors: [
                                  color.withValues(alpha: 0.45),
                                  color.withValues(alpha: 0.85),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(18),
                              boxShadow: value > 0.05
                                  ? [
                                      BoxShadow(
                                        color: color.withValues(alpha: 0.35),
                                        blurRadius: 12,
                                      ),
                                    ]
                                  : null,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              SizedBox(height: compact ? 2 : 6),
              BlurredTextChip(
                enabled: AppMediaHelper.hasMedia(widget.settings.modeBackgroundMedia(8)),
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        label,
                        style: TextStyle(
                          color: color,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.5,
                        ),
                      ),
                      Text(
                        subLabel,
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: subColor,
                          fontSize: 7,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );

          if (colConstraints.maxHeight < 105) {
            return FittedBox(
              fit: BoxFit.scaleDown,
              child: SizedBox(
                width: barColWidth,
                height: 115,
                child: content,
              ),
            );
          }

          return content;
        },
      ),
    );
  }

  Widget _buildInfoChip(String label, String value, AppSettings s) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
      decoration: BoxDecoration(
        color: const Color(0xFF0D0D1A).withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF1E1E3A)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Color(0xFF8888AA),
              fontSize: 8,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              maxLines: 1,
              style: TextStyle(
                color: s.mod8SteerColor,
                fontSize: 12,
                fontWeight: FontWeight.w700,
                fontFamily: 'monospace',
              ),
            ),
          ),
        ],
      ),
    );
  }
}
