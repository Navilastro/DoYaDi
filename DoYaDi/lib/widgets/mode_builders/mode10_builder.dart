part of '../../widgets/driving_mode_builders.dart';

/// Mod 10 — Uçuş Telemetri MFD (Multi-Function Display)
///
/// Yapay ufuk (ADI), hız bandı (speed tape), irtifa bandı (altitude tape)
/// ve motor telemetrisi (N1/N2, EGT) gösteren tam uçuş enstrüman paneli.
///
/// Tüm yüksek frekanslı göstergeler CustomPainter + RepaintBoundary ile izole.
/// Telemetri ValueNotifier ile güncellenir — setState ile ekran yeniden çizilmez.
extension _Mode10BuilderExt<T extends StatefulWidget> on DrivingModeBuildMixin<T> {

  Widget buildMode10(AppSettings s, Size size) {
    return _FlightMfdContent(settings: s, parentSize: size);
  }
}

class _FlightMfdContent extends StatefulWidget {
  final AppSettings settings;
  final Size parentSize;

  const _FlightMfdContent({required this.settings, required this.parentSize});

  @override
  State<_FlightMfdContent> createState() => _FlightMfdContentState();
}

class _FlightMfdContentState extends State<_FlightMfdContent> {
  @override
  void initState() {
    super.initState();
    // Telemetri servisini başlat
    TelemetryListenerService().filterAlpha = widget.settings.mfdGyroFilterAlpha;
    TelemetryListenerService().start();
  }

  @override
  void dispose() {
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
                // ── Başlık ──
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    'UÇUŞ MFD',
                    style: TextStyle(
                      color: s.detailColor.withValues(alpha: 0.5),
                      fontSize: 10,
                      letterSpacing: 4,
                    ),
                  ),
                ),

                // ── Ana Panel ──
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: Row(
                      children: [
                        // ── Sol: Hız Bandı ──
                        if (s.mfdShowSpeedTape)
                          SizedBox(
                            width: 64,
                            child: RepaintBoundary(
                              child: CustomPaint(
                                painter: SpeedTapePainter(
                                  speedKnots: data.airspeedKnots.toDouble(),
                                ),
                                child: const SizedBox.expand(),
                              ),
                            ),
                          ),

                        const SizedBox(width: 4),

                        // ── Orta: Yapay Ufuk ──
                        Expanded(
                          child: s.mfdShowArtificialHorizon
                              ? RepaintBoundary(
                                  child: CustomPaint(
                                    painter: ArtificialHorizonPainter(
                                      pitchDeg: data.pitchDeg.toDouble(),
                                      rollDeg: data.rollDeg.toDouble(),
                                    ),
                                    child: const SizedBox.expand(),
                                  ),
                                )
                              : Container(
                                  color: const Color(0xFF0A0A18),
                                  child: const Center(
                                    child: Text(
                                      'ADI KAPALI',
                                      style: TextStyle(
                                        color: Color(0xFF333344),
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                ),
                        ),

                        const SizedBox(width: 4),

                        // ── Sağ: İrtifa Bandı ──
                        if (s.mfdShowAltitudeTape)
                          SizedBox(
                            width: 64,
                            child: RepaintBoundary(
                              child: CustomPaint(
                                painter: AltitudeTapePainter(
                                  altitudeFt: data.altitudeFt.toDouble(),
                                ),
                                child: const SizedBox.expand(),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),

                // ── Alt Panel: Motor Telemetrisi ──
                Container(
                  height: 64,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  decoration: const BoxDecoration(
                    color: Color(0xFF0A0A18),
                    border: Border(
                      top: BorderSide(color: Color(0xFF1E1E3A)),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildEngineGauge('N1', data.n1Pct / 255.0, s),
                      _buildEngineGauge('N2', data.n2Pct / 255.0, s),
                      _buildEgtGauge(data.egtRaw, s),
                      _buildInfoBox('ALT', '${data.altitudeFt} ft', s),
                      _buildInfoBox('SPD', '${data.airspeedKnots} kts', s),
                      _buildInfoBox(
                        'HDG',
                        '${data.rollDeg.abs()}°${data.rollDeg >= 0 ? 'R' : 'L'}',
                        s,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildEngineGauge(String label, double fraction, AppSettings s) {
    // N1/N2 rengi: yeşil → sarı → kırmızı
    Color gaugeColor;
    if (fraction < 0.7) {
      gaugeColor = const Color(0xFF00E676);
    } else if (fraction < 0.9) {
      gaugeColor = const Color(0xFFFFC107);
    } else {
      gaugeColor = const Color(0xFFFF1744);
    }

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Color(0xFF666688),
            fontSize: 9,
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: 2),
        SizedBox(
          width: 32,
          height: 32,
          child: Stack(
            alignment: Alignment.center,
            children: [
              CircularProgressIndicator(
                value: fraction,
                strokeWidth: 3,
                backgroundColor: const Color(0xFF1A1A2E),
                valueColor: AlwaysStoppedAnimation(gaugeColor),
              ),
              Text(
                (fraction * 100).toStringAsFixed(0),
                style: TextStyle(
                  color: gaugeColor,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'monospace',
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildEgtGauge(int egtRaw, AppSettings s) {
    // EGT (Exhaust Gas Temperature): 0-255 → 200-900°C haritalanmış
    final egtCelsius = (egtRaw * 700 ~/ 255) + 200;
    Color egtColor;
    if (egtCelsius < 600) {
      egtColor = const Color(0xFF00E676);
    } else if (egtCelsius < 780) {
      egtColor = const Color(0xFFFFC107);
    } else {
      egtColor = const Color(0xFFFF1744);
    }

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text(
          'EGT',
          style: TextStyle(
            color: Color(0xFF666688),
            fontSize: 9,
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          '$egtCelsius°',
          style: TextStyle(
            color: egtColor,
            fontSize: 14,
            fontWeight: FontWeight.bold,
            fontFamily: 'monospace',
          ),
        ),
      ],
    );
  }

  Widget _buildInfoBox(String label, String value, AppSettings s) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF0D0D1A),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: const Color(0xFF1E1E3A)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
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
              fontSize: 11,
              fontWeight: FontWeight.w600,
              fontFamily: 'monospace',
            ),
          ),
        ],
      ),
    );
  }
}
