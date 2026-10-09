part of '../../widgets/driving_mode_builders.dart';

/// Mod 9 — Dikey Jet Kontrolcüsü (Flight Stick / HOTAS)
///
/// Sensör tabanlı uçuş kontrolü:
///   İleri/geri eğim  → Pitch (sol analog Y)
///   Sağa/sola eğim   → Roll  (sol analog X)
///   Dikey eksende döndürme → Yaw (sağ analog X)
///
/// Kokpit arayüzü: İtki çubuğu, taktik anahtarlar, merkez retikül.
extension _Mode9BuilderExt<T extends StatefulWidget> on DrivingModeBuildMixin<T> {

  Widget buildMode9(AppSettings s, Size size) {
    return _FlightStickContent(
      settings: s,
      parentSize: size,
      steeringAngle: steeringAngle,
      pitchDeg: pitchDeg,
    );
  }
}

class _FlightStickContent extends StatefulWidget {
  final AppSettings settings;
  final Size parentSize;
  final double steeringAngle;
  final double pitchDeg;

  const _FlightStickContent({
    required this.settings,
    required this.parentSize,
    required this.steeringAngle,
    required this.pitchDeg,
  });

  @override
  State<_FlightStickContent> createState() => _FlightStickContentState();
}

class _FlightStickContentState extends State<_FlightStickContent> {
  double _thrustValue = 0.0;
  bool _masterArm = false;
  bool _gearDown = true;
  bool _airbrake = false;
  int _flapLevel = 0; // 0=up, 1=half, 2=full

  @override
  Widget build(BuildContext context) {
    final s = widget.settings;

    // Sensör verilerinden pitch/roll hesapla
    final rollNorm = widget.steeringAngle.clamp(-1.0, 1.0);
    // Pitch: pitchDeg'den normalize (±45° aralığı)
    final pitchNorm = (widget.pitchDeg / 45.0).clamp(-1.0, 1.0);

    return Container(
      color: s.backgroundColor,
      child: SafeArea(
        child: Row(
          children: [
            // ── Sol: İtki Çubuğu ──
            SizedBox(
              width: 100,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Column(
                  children: [
                    Text(
                      'İTKİ',
                      style: TextStyle(
                        color: s.detailColor.withValues(alpha: 0.5),
                        fontSize: 10,
                        letterSpacing: 2,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Expanded(
                      child: ThrustLeverWidget(
                        value: _thrustValue,
                        onChanged: (v) => setState(() => _thrustValue = v),
                        detents: s.flightThrustDetents,
                        color: s.detailColor,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ── Orta: Crosshair ──
            Expanded(
              child: Column(
                children: [
                  const SizedBox(height: 8),
                  Text(
                    'UÇUŞ KONTROLÜ',
                    style: TextStyle(
                      color: s.detailColor.withValues(alpha: 0.5),
                      fontSize: 10,
                      letterSpacing: 4,
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Crosshair retikülü
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: RepaintBoundary(
                        child: CustomPaint(
                          painter: CrosshairPainter(
                            color: s.detailColor,
                            offsetX: rollNorm,
                            offsetY: pitchNorm,
                          ),
                          child: const SizedBox.expand(),
                        ),
                      ),
                    ),
                  ),

                  // ── Sensör Bilgi ──
                  Padding(
                    padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _buildFlightInfo('PITCH', '${(pitchNorm * 45).toStringAsFixed(1)}°', s),
                        _buildFlightInfo('ROLL', '${(rollNorm * s.steeringAngle).toStringAsFixed(1)}°', s),
                        _buildFlightInfo('THR', '${(_thrustValue * 100).toStringAsFixed(0)}%', s),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // ── Sağ: Taktik Anahtarlar ──
            SizedBox(
              width: 80,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    TacticalSwitchWidget(
                      label: 'ARM',
                      isActive: _masterArm,
                      onTap: () => setState(() => _masterArm = !_masterArm),
                      icon: Icons.gps_fixed,
                      activeColor: const Color(0xFFFF1744),
                      hasSafetyGuard: true,
                      compact: true,
                    ),
                    TacticalSwitchWidget(
                      label: 'GEAR',
                      isActive: _gearDown,
                      onTap: () => setState(() => _gearDown = !_gearDown),
                      icon: Icons.flight_land,
                      activeColor: const Color(0xFF00E676),
                      compact: true,
                    ),
                    TacticalSwitchWidget(
                      label: 'BRK',
                      isActive: _airbrake,
                      onTap: () => setState(() => _airbrake = !_airbrake),
                      icon: Icons.speed,
                      activeColor: const Color(0xFFFFEB3B),
                      compact: true,
                    ),
                    TacticalSwitchWidget(
                      label: 'FLAP ${_flapLevel == 0 ? 'UP' : _flapLevel == 1 ? '½' : 'FULL'}',
                      isActive: _flapLevel > 0,
                      onTap: () => setState(() {
                        _flapLevel = (_flapLevel + 1) % 3;
                      }),
                      icon: Icons.layers,
                      activeColor: const Color(0xFF40E0D0),
                      compact: true,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFlightInfo(String label, String value, AppSettings s) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF0D0D1A),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0xFF1E1E3A)),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFF666688),
              fontSize: 8,
              letterSpacing: 1,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: s.detailColor,
              fontSize: 12,
              fontWeight: FontWeight.w600,
              fontFamily: 'monospace',
            ),
          ),
        ],
      ),
    );
  }
}
