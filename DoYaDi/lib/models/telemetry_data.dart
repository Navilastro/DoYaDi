import 'dart:typed_data';

/// Genişletilmiş telemetri veri modeli.
///
/// C++ sunucusu / shared memory / hook DLL üzerinden gelen verileri karşılar.
/// Mevcut 8-byte TelemetryData'yı (addon_network_service.dart) kapsar ve
/// F1 HUD, uçuş MFD ve ETS2 telemetri alanlarını ekler.
///
/// Paket Formatı (32 byte):
/// ```
/// [0]    = 0xFE (imza — mevcut 0xFF ile çakışmaz)
/// [1]    = rpmPct (0-255, %100 RPM oranı)
/// [2]    = speedRaw (0-255, haritalanmış hız)
/// [3]    = gear (0=N, 1-8, 255=R)
/// [4]    = throttlePct (0-255)
/// [5]    = brakePct (0-255)
/// [6]    = drsStatus (0=kapalı, 1=müsait, 2=aktif)
/// [7]    = ersDeployPct (0-255)
/// [8-11] = tyreTempRaw [FL, FR, RL, RR] (0-255 haritalanmış)
/// [12-15]= tyreWearPct [FL, FR, RL, RR] (0-100)
/// [16]   = leftSlip (0-255)
/// [17]   = rightSlip (0-255)
/// [18]   = gearImpact (0-255 anlık darbe)
/// [19-20]= altitudeFt (uint16 big-endian, 0-65535)
///          — flags bit3 set ise: engineRpm (gerçek motor devri, RPM)
/// [21-22]= airspeedKnots (uint16 big-endian, 0-65535)
/// [23]   = pitchDeg (signed int8, -128..127)
/// [24]   = rollDeg (signed int8, -128..127)
/// [25]   = n1Pct (0-255)
/// [26]   = n2Pct (0-255)
/// [27]   = egtRaw (0-255 haritalanmış)
/// [28-29]= deltaTimeMs (int16 big-endian, -32768..32767 ms)
/// [30]   = flags (bitfield: bit0=stallWarning, bit1=absActive, bit2=tcActive,
///          bit3=araç paketi — [19-20] motor devri taşır)
/// [31]   = reserved
/// ```
class ExtendedTelemetryData {
  // ── Motor & Sürüş ──────────────────────────────────────────────────────────
  /// Motor devir oranı (0-255 → %0-%100 RPM aralığı)
  final int rpmPct;

  /// Araç hızı (0-255, C++ tarafında 0-400 km/h aralığına haritalanır)
  final int speedRaw;

  /// Aktif vites: 0=Nötr, 1-8=İleri, 255=Geri
  final int gear;

  /// Gaz pedalı pozisyonu (0-255 → %0-%100)
  final int throttlePct;

  /// Fren pedalı pozisyonu (0-255 → %0-%100)
  final int brakePct;

  /// Gerçek motor devri (RPM). Yalnızca araç paketlerinde (flags bit3) dolu,
  /// aksi halde 0.
  final int engineRpm;

  // ── F1 Spesifik ────────────────────────────────────────────────────────────
  /// DRS durumu: 0=kapalı, 1=müsait, 2=aktif
  final int drsStatus;

  /// ERS enerji dağıtım yüzdesi (0-255)
  final int ersDeployPct;

  /// Lastik sıcaklıkları [FL, FR, RL, RR] (0-255 → haritalanmış °C)
  final List<int> tyreTemps;

  /// Lastik aşınma yüzdeleri [FL, FR, RL, RR] (0-100)
  final List<int> tyreWears;

  // ── Tekerlek Kayması ───────────────────────────────────────────────────────
  final int leftSlip;
  final int rightSlip;

  /// Vites geçiş darbesi (anlık olay, 0 = yok)
  final int gearImpact;

  // ── Uçuş Spesifik ─────────────────────────────────────────────────────────
  /// Barometrik irtifa (feet)
  final int altitudeFt;

  /// Gösterilmiş hava hızı (knots)
  final int airspeedKnots;

  /// Pitch açısı (derece, -128..127)
  final int pitchDeg;

  /// Roll açısı (derece, -128..127)
  final int rollDeg;

  /// Motor N1 türbin RPM yüzdesi (0-255)
  final int n1Pct;

  /// Motor N2 türbin RPM yüzdesi (0-255)
  final int n2Pct;

  /// Egzoz gaz sıcaklığı (0-255 haritalanmış)
  final int egtRaw;

  /// Pusula baş açısı (0..359 derece, uçuş paketinde)
  final int headingDeg;

  /// Mach x 100 (örn: 125 -> Mach 1.25)
  final int machX100;

  /// Kalan yakıt yüzdesi (0..100)
  final int fuelPct;

  /// İniş takımı açılma yüzdesi (0..100)
  final int gearDeployPct;

  /// Flap açılma yüzdesi (0..100)
  final int flapsDeployPct;

  /// Hava freni açılma yüzdesi (0..100)
  final int airbrakeDeployPct;

  /// G-Kuvveti x 10 (-127..127, örn: 45 -> 4.5G)
  final int gForceX10;

  /// Hücum açısı (AoA derece, -127..127)
  final int aoaDeg;

  /// Dikey hız (ft/min)
  final int verticalSpeedFpm;

  /// PC uçuş telemetrisi aktif bir sim/oyuna bağlı mı ([31] != 0)
  final bool isFlightLive;

  // ── Genel ──────────────────────────────────────────────────────────────────
  /// Tur delta zamanı (milisaniye, negatif = önde)
  final int deltaTimeMs;

  /// Durum bayrakları (bitfield)
  /// bit 0: stallWarning (perdövites uyarısı)
  /// bit 1: absActive
  /// bit 2: tcActive (çekiş kontrolü)
  final int flags;

  const ExtendedTelemetryData({
    this.rpmPct = 0,
    this.speedRaw = 0,
    this.gear = 0,
    this.throttlePct = 0,
    this.brakePct = 0,
    this.engineRpm = 0,
    this.drsStatus = 0,
    this.ersDeployPct = 0,
    this.tyreTemps = const [0, 0, 0, 0],
    this.tyreWears = const [0, 0, 0, 0],
    this.leftSlip = 0,
    this.rightSlip = 0,
    this.gearImpact = 0,
    this.altitudeFt = 0,
    this.airspeedKnots = 0,
    this.pitchDeg = 0,
    this.rollDeg = 0,
    this.n1Pct = 0,
    this.n2Pct = 0,
    this.egtRaw = 0,
    this.headingDeg = 0,
    this.machX100 = 0,
    this.fuelPct = 0,
    this.gearDeployPct = 0,
    this.flapsDeployPct = 0,
    this.airbrakeDeployPct = 0,
    this.gForceX10 = 10,
    this.aoaDeg = 0,
    this.verticalSpeedFpm = 0,
    this.isFlightLive = false,
    this.deltaTimeMs = 0,
    this.flags = 0,
  });

  // ── Yardımcı getter'lar ────────────────────────────────────────────────────

  /// RPM yüzdesi (0.0 - 1.0)
  double get rpmFraction => rpmPct / 255.0;

  /// Hız (km/h olarak, 0-400 aralığına haritalanmış)
  double get speedKmh => speedRaw * 400.0 / 255.0;

  /// Hız (mph olarak)
  double get speedMph => speedKmh * 0.621371;

  /// Hız (knots olarak)
  double get speedKnots => speedKmh * 0.539957;

  /// Vites gösterim string'i
  String get gearDisplay {
    if (gear == 0) return 'N';
    if (gear == 255) return 'R';
    if (gear >= 1 && gear <= 8) return gear.toString();
    return '?';
  }

  /// Gaz pedalı yüzdesi (0.0 - 1.0)
  double get throttleFraction => throttlePct / 255.0;

  /// Fren pedalı yüzdesi (0.0 - 1.0)
  double get brakeFraction => brakePct / 255.0;

  /// ERS yüzdesi (0.0 - 1.0)
  double get ersFraction => ersDeployPct / 255.0;

  /// Delta zamanı (saniye)
  double get deltaTimeSec => deltaTimeMs / 1000.0;

  /// Stall (perdövites) uyarısı aktif mi
  bool get isStallWarning => (flags & 0x01) != 0;

  /// ABS aktif mi
  bool get isAbsActive => (flags & 0x02) != 0;

  /// Çekiş kontrolü aktif mi
  bool get isTractionControlActive => (flags & 0x04) != 0;

  /// Paket gerçek motor devri taşıyor mu (araç paketi, flags bit3)
  bool get hasEngineRpm => (flags & 0x08) != 0;

  /// Genişletilmiş uçuş telemetri paketi mi (flags bit7)
  bool get isFlightPacket => (flags & 0x80) != 0 && !hasEngineRpm;

  /// Aşırı hız (overspeed) uyarısı (flags bit4)
  bool get isOverspeedWarning => (flags & 0x10) != 0;

  /// WEP / Afterburner telemetrisi aktif mi (flags bit5)
  bool get isWepTelemetry => (flags & 0x20) != 0;

  /// İniş takımı aşağıda mı (flags bit6 veya %50+)
  bool get isGearDownTelemetry => (flags & 0x40) != 0 || gearDeployPct >= 50;

  /// Hava freni açık mı
  bool get isAirbrakeTelemetry => airbrakeDeployPct >= 15;

  /// Mach sayısı
  double get machNumber => machX100 / 100.0;

  /// G yükü
  double get gForce => gForceX10 / 10.0;

  /// Rev limiter bölgesinde mi (RPM > %94)
  bool get isRevLimiter => rpmPct > 240;

  /// Lastik kayması var mı (herhangi bir tarafta)
  bool get hasWheelSlip => leftSlip > 90 || rightSlip > 90;

  // ── Fabrika: 32-byte ham veriden parse ──────────────────────────────────────

  /// 32 byte'lık ham UDP paketinden parse eder.
  /// İlk byte 0xFE imzası olmalıdır.
  factory ExtendedTelemetryData.fromBytes(List<int> bytes) {
    if (bytes.length < 32 || bytes[0] != 0xFE) {
      return const ExtendedTelemetryData();
    }

    final bd = ByteData.sublistView(Uint8List.fromList(bytes));
    final int flags = bytes[30];
    // Araç paketlerinde [19-20] irtifa yerine gerçek motor devrini taşır
    final bool isCarPacket = (flags & 0x08) != 0;
    final bool flightPacket = (flags & 0x80) != 0 && !isCarPacket;
    final int field19 = bd.getUint16(19, Endian.big);

    return ExtendedTelemetryData(
      rpmPct: bytes[1],
      speedRaw: bytes[2],
      gear: bytes[3],
      throttlePct: bytes[4],
      brakePct: bytes[5],
      engineRpm: isCarPacket ? field19 : 0,
      drsStatus: bytes[6],
      ersDeployPct: bytes[7],
      tyreTemps: flightPacket
          ? const [0, 0, 0, 0]
          : [bytes[8], bytes[9], bytes[10], bytes[11]],
      tyreWears: flightPacket
          ? const [0, 0, 0, 0]
          : [bytes[12], bytes[13], bytes[14], bytes[15]],
      leftSlip: flightPacket ? 0 : bytes[16],
      rightSlip: flightPacket ? 0 : bytes[17],
      gearImpact: flightPacket ? 0 : bytes[18],
      altitudeFt: isCarPacket ? 0 : field19,
      airspeedKnots: bd.getUint16(21, Endian.big),
      pitchDeg: bd.getInt8(23),
      rollDeg: bd.getInt8(24),
      n1Pct: bytes[25],
      n2Pct: bytes[26],
      egtRaw: bytes[27],
      headingDeg: flightPacket ? (bd.getUint16(8, Endian.big) % 360) : 0,
      machX100: flightPacket ? bytes[10] : 0,
      fuelPct: flightPacket ? bytes[11].clamp(0, 100) : 0,
      gearDeployPct: flightPacket ? bytes[12].clamp(0, 100) : 0,
      flapsDeployPct: flightPacket ? bytes[13].clamp(0, 100) : 0,
      airbrakeDeployPct: flightPacket ? bytes[14].clamp(0, 100) : 0,
      gForceX10: flightPacket ? bd.getInt8(15) : 10,
      aoaDeg: flightPacket ? bd.getInt8(16) : 0,
      verticalSpeedFpm: flightPacket ? bd.getInt16(17, Endian.big) * 10 : 0,
      isFlightLive: flightPacket && bytes[31] != 0,
      deltaTimeMs: bd.getInt16(28, Endian.big),
      flags: flags,
    );
  }

  @override
  String toString() =>
      'ExtTelemetry(RPM:$rpmPct%, Speed:${speedKmh.toStringAsFixed(0)}km/h, '
      'Gear:$gearDisplay, Alt:${altitudeFt}ft)';
}
