part of '../../widgets/driving_mode_builders.dart';

/// Mod 7 — F1 Telemetri HUD
///
/// RPM LED barı, 7-segment vites göstergesi, hız, lastik sıcaklıkları,
/// DRS/ERS durumu ve tur delta zamanı gibi F1 telemetri verilerini
/// gerçek zamanlı olarak gösterir.
///
/// Tüm yüksek frekanslı göstergeler CustomPainter + RepaintBoundary ile
/// izole edilmiştir. Telemetri ValueNotifier ile güncellendiğinden
/// setState ile tüm ekran yeniden çizilmez.
extension _Mode7BuilderExt<T extends StatefulWidget> on DrivingModeBuildMixin<T> {

  Widget buildMode7(AppSettings s, Size size) {
    return _withTrackPoint(s, size, Stack(
      children: [
        // 1. Arka plan ve HUD (telemetry + lokal input)
        Positioned.fill(
          child: _F1HudContent(
            settings: s,
            parentSize: size,
            gasPercentage: gasPercentage,
            brakePercentage: brakePercentage,
            isGasLeft: false, // Mod 1 gibi her zaman Sol Fren
          ),
        ),
        
        // 2. Etkileşim katmanı (Görünmez pedal yüzeyleri)
        Positioned.fill(
          child: Row(
            children: [
              // Sol - Fren
              Expanded(
                child: Listener(
                  behavior: HitTestBehavior.opaque, // Opaque so it catches touches
                  onPointerDown: (e) => onPedalDown(e, false, tapKey: s.brakeTap),
                  onPointerMove: (e) => onPedalMove(e, s),
                  onPointerUp: onPedalUp,
                  onPointerCancel: onPedalUp,
                  child: const SizedBox.expand(),
                ),
              ),
              // Sağ - Gaz
              Expanded(
                child: Listener(
                  behavior: HitTestBehavior.opaque,
                  onPointerDown: (e) => onPedalDown(e, true, tapKey: s.gasTap),
                  onPointerMove: (e) => onPedalMove(e, s),
                  onPointerUp: onPedalUp,
                  onPointerCancel: onPedalUp,
                  child: const SizedBox.expand(),
                ),
              ),
            ],
          ),
        ),
        
        // 3. Merkezdeki 4 stilistik yuvarlak buton
        _buildMode7Buttons(s, size),
      ],
    ));
  }

  Widget _buildMode7Buttons(AppSettings s, Size size) {
    // 4 buton, ekranın alt ortasına (direksiyon göstergesine yakın) yerleştiriliyor
    // HUD barlarının üzerine gelecek ama yazıları sıkıştırmayacak şekilde.
    final double centerX = size.width / 2;
    // Y ekseninde lastik derecelerinin ortası gibi bir yere
    final double bottomY = size.height - 130; 

    return Stack(
      children: [
        // Sol Buton
        Positioned(
          left: centerX - 80,
          top: bottomY,
          child: _buildM7StylizedButton(s, s.m7Key1, 'X'),
        ),
        // Üst Buton
        Positioned(
          left: centerX - 25,
          top: bottomY - 55,
          child: _buildM7StylizedButton(s, s.m7Key2, 'Y'),
        ),
        // Sağ Buton
        Positioned(
          left: centerX + 30,
          top: bottomY,
          child: _buildM7StylizedButton(s, s.m7Key3, 'B'),
        ),
        // Alt Buton
        Positioned(
          left: centerX - 25,
          top: bottomY + 55,
          child: _buildM7StylizedButton(s, s.m7Key4, 'A'),
        ),
      ],
    );
  }

  Widget _buildM7StylizedButton(AppSettings s, int key, String defaultLabel) {
    return Listener(
      behavior: HitTestBehavior.opaque,
      onPointerDown: (_) => handleButtonDown(key),
      onPointerUp: (_) => handleButtonUp(key),
      onPointerCancel: (_) => handleButtonUp(key),
      child: Container(
        width: 50,
        height: 50,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: const Color(0xFF101018),
          border: Border.all(color: s.detailColor.withValues(alpha: 0.6), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: s.detailColor.withValues(alpha: 0.2),
              blurRadius: 8,
              spreadRadius: 1,
            )
          ]
        ),
        alignment: Alignment.center,
        child: Text(
          defaultLabel,
          style: TextStyle(
            color: s.detailColor,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
      ),
    );
  }
}

class _F1HudContent extends StatefulWidget {
  final AppSettings settings;
  final Size parentSize;
  final double gasPercentage;
  final double brakePercentage;
  final bool isGasLeft;

  const _F1HudContent({
    required this.settings, 
    required this.parentSize,
    required this.gasPercentage,
    required this.brakePercentage,
    required this.isGasLeft,
  });

  @override
  State<_F1HudContent> createState() => _F1HudContentState();
}

class _F1HudContentState extends State<_F1HudContent>
    with SingleTickerProviderStateMixin {
  late final AnimationController _blinkController;

  @override
  void initState() {
    super.initState();
    // Rev limiter yanıp sönme animasyonu
    _blinkController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    )..repeat(reverse: true);

    // Telemetri servisini başlat
    TelemetryListenerService().filterAlpha = widget.settings.f1LowPassAlpha;
    TelemetryListenerService().start();
  }

  @override
  void dispose() {
    _blinkController.dispose();
    TelemetryListenerService().stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.settings;
    final telemetryService = TelemetryListenerService();

    return ValueListenableBuilder<ExtendedTelemetryData>(
      valueListenable: telemetryService.telemetryNotifier,
      builder: (context, data, _) {
        return Container(
          color: s.backgroundColor,
          child: SafeArea(
            child: Column(
              children: [
                // ── RPM LED Barı ──
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                  child: RepaintBoundary(
                    child: SizedBox(
                      width: double.infinity,
                      height: 24,
                      child: AnimatedBuilder(
                        animation: _blinkController,
                        builder: (context, _) {
                          return CustomPaint(
                            painter: RpmLedBarPainter(
                              rpmFraction: data.rpmFraction,
                              blinkPhase: data.isRevLimiter
                                  ? _blinkController.value
                                  : 1.0,
                            ),
                            child: const SizedBox.expand(),
                          );
                        },
                      ),
                    ),
                  ),
                ),

                // ── Vites + Hız Satırı ──
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // DRS Göstergesi
                      _buildDrsIndicator(data.drsStatus, s),
                      const SizedBox(width: 12),

                      // Hız
                      Column(
                        children: [
                          Text(
                            s.f1UseImperial
                                ? data.speedMph.toStringAsFixed(0)
                                : data.speedKmh.toStringAsFixed(0),
                            style: TextStyle(
                              color: s.detailColor,
                              fontSize: 42,
                              fontWeight: FontWeight.w300,
                              fontFamily: 'monospace',
                            ),
                          ),
                          Text(
                            s.f1UseImperial ? 'MPH' : 'KM/H',
                            style: const TextStyle(
                              color: Color(0xFF666688),
                              fontSize: 10,
                              letterSpacing: 2,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(width: 16),

                      // 7-Segment Vites
                      RepaintBoundary(
                        child: SizedBox(
                          width: 48,
                          height: 72,
                          child: CustomPaint(
                            painter: SevenSegmentPainter(
                              gear: data.gear,
                              activeColor: _gearColor(data.gear),
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(width: 12),

                      // ERS Göstergesi
                      _buildErsBar(data.ersFraction, s),
                    ],
                  ),
                ),

                // ── Gaz / Fren Çubukları (Lokal Etkileşim) ──
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: Row(
                    children: [
                      Expanded(
                        child: _buildPedalBar(
                          widget.isGasLeft ? 'GAZ' : 'FREN',
                          widget.isGasLeft ? widget.gasPercentage : widget.brakePercentage,
                          widget.isGasLeft ? s.gasColor : s.brakeColor,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildPedalBar(
                          widget.isGasLeft ? 'FREN' : 'GAZ',
                          widget.isGasLeft ? widget.brakePercentage : widget.gasPercentage,
                          widget.isGasLeft ? s.brakeColor : s.gasColor,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 4),

                // ── Lastik Sıcaklıkları ──
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        // Lastikler
                        Expanded(
                          child: TyreTempWidget(
                            tyreTemps: data.tyreTemps,
                            tyreWears: data.tyreWears,
                          ),
                        ),

                        // Delta + Durum
                        Expanded(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              // Delta Zamanı
                              _buildDeltaTime(data.deltaTimeSec),
                              const SizedBox(height: 8),

                              // Durum Bayrakları
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  if (data.isAbsActive)
                                    _buildStatusChip('ABS', const Color(0xFFFF9800)),
                                  if (data.isTractionControlActive)
                                    _buildStatusChip('TC', const Color(0xFFFFEB3B)),
                                ],
                              ),

                              const SizedBox(height: 8),

                              // Tekerlek Kayma Göstergesi
                              if (data.hasWheelSlip)
                                Text(
                                  '⚠ SLIP',
                                  style: TextStyle(
                                    color: const Color(0xFFFF1744).withValues(alpha: 0.9),
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ── Yardımcı Widget'lar ─────────────────────────────────────────────────

  Widget _buildDrsIndicator(int status, AppSettings s) {
    Color color;
    String label;
    switch (status) {
      case 1:
        color = const Color(0xFF66BB6A);
        label = 'DRS';
        break;
      case 2:
        color = const Color(0xFF00E676);
        label = 'DRS';
        break;
      default:
        color = const Color(0xFF333344);
        label = 'DRS';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: status == 2 ? color.withValues(alpha: 0.2) : Colors.transparent,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color, width: status == 2 ? 2 : 1),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildErsBar(double fraction, AppSettings s) {
    return SizedBox(
      width: 12,
      height: 60,
      child: RotatedBox(
        quarterTurns: 2,
        child: LinearProgressIndicator(
          value: fraction,
          backgroundColor: const Color(0xFF1A1A2E),
          valueColor: const AlwaysStoppedAnimation(Color(0xFFFFEB3B)),
          borderRadius: BorderRadius.circular(6),
        ),
      ),
    );
  }

  Widget _buildPedalBar(String label, double fraction, Color color) {
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Color(0xFF666688),
            fontSize: 9,
            letterSpacing: 1.5,
          ),
        ),
        const SizedBox(height: 2),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: fraction,
            minHeight: 10,
            backgroundColor: const Color(0xFF1A1A2E),
            valueColor: AlwaysStoppedAnimation(color),
          ),
        ),
        Text(
          '${(fraction * 100).toStringAsFixed(0)}%',
          style: TextStyle(
            color: color.withValues(alpha: 0.7),
            fontSize: 10,
            fontFamily: 'monospace',
          ),
        ),
      ],
    );
  }

  Widget _buildDeltaTime(double deltaSec) {
    final isAhead = deltaSec < 0;
    final color = isAhead ? const Color(0xFF00E676) : const Color(0xFFFF1744);
    final sign = isAhead ? '' : '+';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        '$sign${deltaSec.toStringAsFixed(3)}',
        style: TextStyle(
          color: color,
          fontSize: 24,
          fontWeight: FontWeight.bold,
          fontFamily: 'monospace',
        ),
      ),
    );
  }

  Widget _buildStatusChip(String label, Color color) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color, width: 1),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Color _gearColor(int gear) {
    if (gear == 0) return const Color(0xFF40E0D0);
    if (gear == 255) return const Color(0xFFFF9800);
    return const Color(0xFFFF1744);
  }
}
