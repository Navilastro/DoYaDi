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
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      AppTranslations.getText('chill_bg_title'),
                      style: TextStyle(
                        color: ac,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
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
    final ac = s.detailColor;

    return Container(
      color: s.backgroundColor,
      child: SafeArea(
        child: Stack(
          children: [
            // ── Arka Plan Atmosferik Işıma ──
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: const Alignment(0, -0.1),
                    radius: 1.1,
                    colors: [
                      ac.withValues(alpha: 0.06),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),

            // ── Ana Dikey (Portrait) Tek-El Kokpit Düzeni ──
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Column(
                children: [
                  // 1. ÜST BAR: Başlık + Kapsül Baloncuk & Eksen Hızlı Geçişleri
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            AppTranslations.getText('chill_mode_title'),
                            style: TextStyle(
                              color: ac,
                              fontSize: 13,
                              letterSpacing: 3,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            AppTranslations.getText('chill_mode_subtitle'),
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.45),
                              fontSize: 9,
                              letterSpacing: 1.2,
                            ),
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          // Eksen Seçici (Roll / Yaw)
                          GestureDetector(
                            onTap: () => _toggleSteeringAxis(context, s),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: const Color(0xFF121226),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: ac.withValues(alpha: 0.4)),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    s.chillSteeringAxis == 0
                                        ? Icons.screen_rotation
                                        : Icons.rotate_90_degrees_ccw,
                                    color: ac,
                                    size: 13,
                                  ),
                                  const SizedBox(width: 5),
                                  Text(
                                    s.chillSteeringAxis == 0 ? 'ROLL' : 'YAW',
                                    style: TextStyle(
                                      color: ac,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 1,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          // Kapsül Baloncuk (Overlay) 3 Durumlu Buton: Kapalı -> Kapsül -> Baloncuk
                          GestureDetector(
                            onTap: () => _cycleOverlayMode(context, s),
                            onLongPress: () => _showOverlayPicker(context, s),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: s.chillOverlayEnabled
                                    ? ac.withValues(alpha: 0.2)
                                    : const Color(0xFF121226),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: s.chillOverlayEnabled ? ac : Colors.white24,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    !s.chillOverlayEnabled
                                        ? Icons.layers_clear
                                        : (s.chillOverlayStyle == 0
                                            ? Icons.web_asset
                                            : Icons.bubble_chart),
                                    color: s.chillOverlayEnabled ? ac : Colors.white54,
                                    size: 14,
                                  ),
                                  const SizedBox(width: 5),
                                  Text(
                                    !s.chillOverlayEnabled
                                        ? AppTranslations.getText('chill_bg_off')
                                        : (s.chillOverlayStyle == 0
                                            ? AppTranslations.getText('chill_bg_capsule')
                                            : AppTranslations.getText('chill_bg_bubble')),
                                    style: TextStyle(
                                      color: s.chillOverlayEnabled ? ac : Colors.white70,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
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

                  const SizedBox(height: 14),

                  // 2. DİREKSİYON BAR GÖSTERGESİ
                  _buildSteeringSection(widget.steeringAngle, s),

                  const SizedBox(height: 14),

                  // 3. ORTA BÖLÜM: Sol Fren Barı + Merkez 2D Eğim/Kalibrasyon Küresi + Sağ Gaz Barı
                  Expanded(
                    child: Row(
                      children: [
                        // SOL SÜTUN: FREN (Hem Sensör Göstergesi Hem Dokunmatik)
                        _buildInteractivePedalBar(
                          label: 'FREN',
                          subLabel: 'GERİ EĞ / DOKUN',
                          value: widget.brakePercentage,
                          color: s.brakeColor,
                          isGas: false,
                        ),

                        // MERKEZ: 2 Eksenli Eğim Radarı + Kalibre + Hız Sabitleyici + Yardımcı Tuşlar
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [
                                // 2D Eğim Küresi ve Kalibrasyon Butonu
                                _buildTiltSphereAndCalibrate(s),

                                // Hız Sabitleyici (Cruise Control) Kapsülü
                                _buildCruiseControlButton(s),

                                // El Freni & Korna Hızlı Erişim Satırı
                                Row(
                                  children: [
                                    Expanded(
                                      child: _buildHoldActionButton(
                                        label: AppTranslations.getText('chill_handbrake_key'),
                                        icon: Icons.warning_amber_rounded,
                                        activeColor: const Color(0xFFFF2A6D),
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
                                        activeColor: Colors.amberAccent,
                                        isActive: widget.isHornActive,
                                        onDown: () => widget.onButtonDown(s.mod6HornKey),
                                        onUp: () => widget.onButtonUp(s.mod6HornKey),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),

                        // SAĞ SÜTUN: GAZ (Hem Sensör Göstergesi Hem Dokunmatik)
                        _buildInteractivePedalBar(
                          label: 'GAZ',
                          subLabel: 'ÖNE EĞ / DOKUN',
                          value: widget.gasPercentage,
                          color: s.gasColor,
                          isGas: true,
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 12),

                  // 4. BAŞPARMAK VİTES PANELİ (GEAR - / GEAR +)
                  if (s.chillOverlayGearButtons) ...[
                    Row(
                      children: [
                        Expanded(
                          child: _buildGearShiftButton(
                            label: AppTranslations.getText('chill_gear_down'),
                            badge: 'LB / -',
                            icon: Icons.keyboard_double_arrow_down_rounded,
                            color: const Color(0xFFFF2A6D),
                            isActive: widget.isGearDownActive,
                            onDown: () => widget.onButtonDown(1), // LB
                            onUp: () => widget.onButtonUp(1),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildGearShiftButton(
                            label: AppTranslations.getText('chill_gear_up'),
                            badge: 'RB / +',
                            icon: Icons.keyboard_double_arrow_up_rounded,
                            color: ac,
                            isActive: widget.isGearUpActive,
                            onDown: () => widget.onButtonDown(2), // RB
                            onUp: () => widget.onButtonUp(2),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                  ],

                  // 5. ALT SENSÖR TELEMETRİ ÇİPLERİ
                  Row(
                    children: [
                      Expanded(
                        child: _buildInfoChip(
                          'EĞİM (GAZ/FREN)',
                          '${widget.pitchDeltaDeg >= 0 ? '+' : ''}${widget.pitchDeltaDeg.toStringAsFixed(1)}°',
                          s,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildInfoChip(
                          'DİREKSİYON AÇISI',
                          '${(widget.steeringAngle * s.steeringAngle).toStringAsFixed(0)}°',
                          s,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildInfoChip(
                          'HASSASİYET',
                          '${s.chillSteeringSensitivity.toStringAsFixed(1)}x / ${s.chillGasBrakeSensitivity.toStringAsFixed(1)}x',
                          s,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSteeringSection(double angle, AppSettings s) {
    final ac = s.detailColor;
    final int pct = (angle * 100).round();
    final String dirText = pct == 0
        ? AppTranslations.getText('chill_center_zero')
        : pct < 0
            ? 'SOL ${pct.abs()}%'
            : 'SAĞ $pct%';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF0D0D1C),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                '◄ SOL',
                style: TextStyle(color: Colors.white38, fontSize: 9, letterSpacing: 1.5),
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
              const Text(
                'SAĞ ►',
                style: TextStyle(color: Colors.white38, fontSize: 9, letterSpacing: 1.5),
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

  Widget _buildTiltSphereAndCalibrate(AppSettings s) {
    final ac = s.detailColor;
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
            width: 148,
            height: 148,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _calibratedFlash
                  ? ac.withValues(alpha: 0.18)
                  : const Color(0xFF0E0E20),
              border: Border.all(
                color: _calibratedFlash ? ac : ac.withValues(alpha: 0.35),
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: ac.withValues(alpha: _calibratedFlash ? 0.35 : 0.08),
                  blurRadius: 22,
                ),
              ],
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                // İç halka (Ölü alan sınırı)
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white12, width: 1),
                  ),
                ),
                // Yatay ve dikey eksen çizgileri
                Container(width: 120, height: 1, color: Colors.white10),
                Container(width: 1, height: 120, color: Colors.white10),

                // Canlı Eğim Noktası (Pitch + Roll)
                Transform.translate(
                  offset: Offset(normX * 52.0, normY * 52.0),
                  child: Container(
                    width: 22,
                    height: 22,
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
                      size: 13,
                      color: Colors.black,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          _calibratedFlash
              ? AppTranslations.getText('chill_calibrated')
              : AppTranslations.getText('chill_calibrate_touch'),
          style: TextStyle(
            color: _calibratedFlash ? ac : Colors.white54,
            fontSize: 9,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.3,
          ),
        ),
      ],
    );
  }

  Widget _buildCruiseControlButton(AppSettings s) {
    final bool locked = widget.cruiseLocked;
    final Color activeColor = const Color(0xFF00E676);

    return GestureDetector(
      onTap: widget.onToggleCruise,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: locked
              ? activeColor.withValues(alpha: 0.18)
              : const Color(0xFF121226),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: locked ? activeColor : Colors.white12,
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
                    ? 'HIZ SABİT (${(widget.cruiseGasValue * 100).round()}%)'
                    : 'HIZ SABİTLEYİCİ (CRUISE)',
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
        padding: const EdgeInsets.symmetric(vertical: 12),
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
  }) {
    return Listener(
      behavior: HitTestBehavior.opaque,
      onPointerDown: (_) => onDown(),
      onPointerUp: (_) => onUp(),
      onPointerCancel: (_) => onUp(),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 100),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
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
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1,
                  ),
                ),
                Text(
                  badge,
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
    );
  }

  Widget _buildInteractivePedalBar({
    required String label,
    required String subLabel,
    required double value,
    required Color color,
    required bool isGas,
  }) {
    return SizedBox(
      width: 64,
      child: Column(
        children: [
          Text(
            '${(value * 100).round()}%',
            style: TextStyle(
              color: color,
              fontSize: 13,
              fontWeight: FontWeight.bold,
              fontFamily: 'monospace',
            ),
          ),
          const SizedBox(height: 6),
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
                        width: 48,
                        decoration: BoxDecoration(
                          color: const Color(0xFF101022),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: color.withValues(alpha: 0.25),
                            width: 1.5,
                          ),
                        ),
                      ),
                      // Seviye çizgileri (%25, %50, %75)
                      for (final frac in [0.25, 0.5, 0.75])
                        Positioned(
                          bottom: h * frac,
                          child: Container(
                            width: 30,
                            height: 1,
                            color: Colors.white10,
                          ),
                        ),
                      // Dolgu barı
                      Container(
                        width: 48,
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
          const SizedBox(height: 6),
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
            style: const TextStyle(
              color: Colors.white38,
              fontSize: 7,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoChip(String label, String value, AppSettings s) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
      decoration: BoxDecoration(
        color: const Color(0xFF0D0D1A),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF1E1E3A)),
      ),
      child: Column(
        children: [
          Text(
            label,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Color(0xFF666688),
              fontSize: 8,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
              color: s.detailColor,
              fontSize: 12,
              fontWeight: FontWeight.w700,
              fontFamily: 'monospace',
            ),
          ),
        ],
      ),
    );
  }
}
