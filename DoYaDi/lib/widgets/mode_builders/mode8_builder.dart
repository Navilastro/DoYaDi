part of '../../widgets/driving_mode_builders.dart';

/// Mod 8 — Rahat Sürüş Modu (Chill Drive)
///
/// Sensör tabanlı sürüş: Telefon eğimi ile direksiyon, pitch ile gaz/fren.
/// Minimal arayüz, kalibrasyon butonu ve sensör göstergeleri.
///
/// NOT: Foreground Service ve Overlay Window paketleri pubspec'e
/// eklendiğinde arka plan servisi ve kapsül baloncuk entegre edilecektir.
extension _Mode8BuilderExt<T extends StatefulWidget> on DrivingModeBuildMixin<T> {

  Widget buildMode8(AppSettings s, Size size) {
    return _ChillDriveContent(
      settings: s,
      parentSize: size,
      onCalibrate: () {
        SensorManager().recenterGyro();
      },
      steeringAngle: steeringAngle,
      gasPercentage: gasPercentage,
      brakePercentage: brakePercentage,
    );
  }
}

class _ChillDriveContent extends StatefulWidget {
  final AppSettings settings;
  final Size parentSize;
  final VoidCallback onCalibrate;
  final double steeringAngle;
  final double gasPercentage;
  final double brakePercentage;

  const _ChillDriveContent({
    required this.settings,
    required this.parentSize,
    required this.onCalibrate,
    required this.steeringAngle,
    required this.gasPercentage,
    required this.brakePercentage,
  });

  @override
  State<_ChillDriveContent> createState() => _ChillDriveContentState();
}

class _ChillDriveContentState extends State<_ChillDriveContent> {
  bool _calibrated = false;

  @override
  Widget build(BuildContext context) {
    final s = widget.settings;
    final sensor = SensorManager();

    return Container(
      color: s.backgroundColor,
      child: SafeArea(
        child: Stack(
          children: [
            // ── Arka Plan Gradyan ──
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: Alignment.center,
                    radius: 1.2,
                    colors: [
                      s.detailColor.withValues(alpha: 0.03),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),

            // ── Ana İçerik ──
            Column(
              children: [
                const SizedBox(height: 16),

                // Mod Başlığı
                Text(
                  'RAHAT SÜRÜŞ',
                  style: TextStyle(
                    color: s.detailColor.withValues(alpha: 0.6),
                    fontSize: 12,
                    letterSpacing: 4,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),

                // ── Direksiyon Göstergesi (Yatay çubuk) ──
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: _buildSteeringBar(widget.steeringAngle, s),
                ),

                const SizedBox(height: 16),

                // ── Gaz / Fren Dikey Çubuklar ──
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 40),
                    child: Row(
                      children: [
                        // Fren
                        _buildVerticalPedal(
                          'FREN',
                          widget.brakePercentage,
                          s.brakeColor,
                          s,
                        ),
                        const Spacer(),

                        // Merkez Kalibrasyon Butonu
                        Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            GestureDetector(
                              onTap: () {
                                widget.onCalibrate();
                                setState(() => _calibrated = true);
                                Future.delayed(
                                  const Duration(seconds: 2),
                                  () {
                                    if (mounted) setState(() => _calibrated = false);
                                  },
                                );
                              },
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 300),
                                width: 80,
                                height: 80,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: _calibrated
                                      ? s.detailColor.withValues(alpha: 0.2)
                                      : const Color(0xFF1A1A2E),
                                  border: Border.all(
                                    color: _calibrated
                                        ? s.detailColor
                                        : s.detailColor.withValues(alpha: 0.3),
                                    width: 2,
                                  ),
                                  boxShadow: _calibrated
                                      ? [
                                          BoxShadow(
                                            color: s.detailColor.withValues(alpha: 0.3),
                                            blurRadius: 20,
                                          ),
                                        ]
                                      : null,
                                ),
                                child: Icon(
                                  _calibrated ? Icons.check : Icons.my_location,
                                  color: s.detailColor,
                                  size: 32,
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _calibrated ? 'KALİBRE EDİLDİ' : 'KALİBRE',
                              style: TextStyle(
                                color: s.detailColor.withValues(alpha: 0.5),
                                fontSize: 10,
                                letterSpacing: 2,
                              ),
                            ),
                          ],
                        ),

                        const Spacer(),

                        // Gaz
                        _buildVerticalPedal(
                          'GAZ',
                          widget.gasPercentage,
                          s.gasColor,
                          s,
                        ),
                      ],
                    ),
                  ),
                ),

                // ── Sensör Bilgi Satırı ──
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildInfoChip(
                        'Pitch',
                        '${sensor.pitchDeg.toStringAsFixed(1)}°',
                        s,
                      ),
                      _buildInfoChip(
                        'Roll',
                        '${(widget.steeringAngle * s.steeringAngle).toStringAsFixed(1)}°',
                        s,
                      ),
                      _buildInfoChip(
                        'Eksen',
                        s.chillSteeringAxis == 0 ? 'Roll' : 'Yaw',
                        s,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSteeringBar(double angle, AppSettings s) {
    // angle: -1.0 (sol) ... 0.0 (merkez) ... 1.0 (sağ)
    return SizedBox(
      height: 16,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final w = constraints.maxWidth;
          final center = w / 2;
          final indicatorX = center + (angle * center);

          return Stack(
            children: [
              // Arka plan çubuğu
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF1A1A2E),
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              // Dolgu (merkezden tarafa)
              Positioned(
                left: angle >= 0 ? center : indicatorX,
                width: (angle.abs() * center).clamp(0, center),
                top: 0,
                bottom: 0,
                child: Container(
                  decoration: BoxDecoration(
                    color: s.detailColor.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
              // Gösterge noktası
              Positioned(
                left: indicatorX - 4,
                top: 0,
                bottom: 0,
                child: Container(
                  width: 8,
                  decoration: BoxDecoration(
                    color: s.detailColor,
                    borderRadius: BorderRadius.circular(4),
                    boxShadow: [
                      BoxShadow(
                        color: s.detailColor.withValues(alpha: 0.5),
                        blurRadius: 8,
                      ),
                    ],
                  ),
                ),
              ),
              // Merkez çizgisi
              Positioned(
                left: center - 1,
                top: 0,
                bottom: 0,
                child: Container(
                  width: 2,
                  color: s.detailColor.withValues(alpha: 0.2),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildVerticalPedal(String label, double value, Color color, AppSettings s) {
    return SizedBox(
      width: 40,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Text(
            '${(value * 100).toStringAsFixed(0)}%',
            style: TextStyle(
              color: color.withValues(alpha: 0.7),
              fontSize: 11,
              fontFamily: 'monospace',
            ),
          ),
          const SizedBox(height: 4),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final h = constraints.maxHeight;
                return Stack(
                  alignment: Alignment.bottomCenter,
                  children: [
                    Container(
                      width: 24,
                      decoration: BoxDecoration(
                        color: const Color(0xFF1A1A2E),
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    Container(
                      width: 24,
                      height: h * value,
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: color.withValues(alpha: 0.3),
                            blurRadius: 8,
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFF666688),
              fontSize: 9,
              letterSpacing: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoChip(String label, String value, AppSettings s) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF0D0D1A),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF1E1E3A)),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFF666688),
              fontSize: 9,
              letterSpacing: 1,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: s.detailColor,
              fontSize: 13,
              fontWeight: FontWeight.w600,
              fontFamily: 'monospace',
            ),
          ),
        ],
      ),
    );
  }
}
