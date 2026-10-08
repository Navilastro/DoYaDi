import 'package:flutter/material.dart';

/// Swipe yönleri (8 yön + merkez/yok)
enum SwipeDir {
  none,
  up,
  down,
  left,
  right,
  upLeft,
  upRight,
  downLeft,
  downRight,
}

class AppSettings {
  // ── Arka plan ve genel renkler ──────────────────────────────────────────────
  Color backgroundColor;
  Color detailColor;

  // ── Direksiyon göstergesi renkleri ─────────────────────────────────────────
  Color steeringIndicatorColor;
  Color steeringBgColor;

  // ── Pedal renkleri ──────────────────────────────────────────────────────────
  Color gasColor;
  Color brakeColor;
  Color yetsoreColor; // %70+ geri bildirim rengi
  Color pedalBgColor; // Pedal arka plan rengi

  // ── Mod 6 Özel Renkler ────────────────────────────────────────────────────
  Color clutchColor;
  Color clutchYetsoreColor;
  Color handbrakeColor;
  Color handbrakeYetsoreColor;
  Color gasIconColor;
  Color brakeIconColor;
  Color clutchIconColor;
  Color clutchButtonColor;
  Color handbrakeIconColor;
  Color handbrakeButtonColor;
  Color steeringWheelColor;

  // ── İvmeölçer kalibrasyonu ─────────────────────────────────────────────────
  /// 0: Auto, 1: Ekran üstte, 2: Ekran vücuda bakıyor
  int zeroOrientation;
  double calibPitchOffset;
  double calibRollOffset;

  // ── Direksiyon / Hareket ayarları ───────────────────────────────────────────
  bool useGyroscope;
  double steeringAngle; // 75° – 1080°
  double swipeSensitivity; // Pedal %100 için gereken mm mesafesi
  double clickMaxDistance; // Dokunma sayılmak için maks. mm kayma
  double clickMaxDuration; // Dokunma sayılmak için maks. süre (saniye)
  int defaultDrivingMode; // 0–6

  // ── Kümülatif Direksiyon ────────────────────────────────────────────────────
  /// true ise 180° eşiğinde gyroscope kümülatif toplama devreye girer.
  bool isCumulativeSteering;

  // ── Pedal İkonu İvmelenme Hızı ──────────────────────────────────────────────
  /// 0 → %100 arası geçiş süresi (saniye). Aralık: 0.2 – 3.0
  double pedalIconAccelerationRate;

  // ── Mod 6 Pedal Stili & Direksiyon Stili ─────────────────────────────────
  /// 0 = Bar, 1 = Pedal İkonu
  int mod6PedalStyle;

  // ── Debriyaj & El Freni & Dinamik Direksiyon Ayarları ────────────────────
  /// Debriyaj İkonu 0 -> %100 ivmelenme süresi (saniye). Varsayılan 0.6
  double clutchIconAccelerationRate;
  /// Debriyaj çalışma türü: 0 = Buton, 1 = Bar (Slider), 2 = İkon (İvmelenmeli)
  int clutchType;
  /// Dijital Debriyaj tuş ataması (1-25)
  int clutchKey;
  /// El Freni çalışma türü: 0 = Buton, 1 = Bar (Slider) (Sağ Analog Yatay Eksen)
  int handbrakeType;
  /// Dijital El Freni tuş ataması (1-25)
  int handbrakeKey;
  /// DLC Eklenti Paneli Anahtar Durumu
  bool isAddonMasterSwitchActive;
  /// Aktif seçili DLC eklenti paket ID'leri
  List<String> activeAddonIds;
  /// Mod 6 Debriyaj aktif mi
  bool mod6EnableClutch;
  /// Mod 6 El Freni aktif mi
  bool mod6EnableHandbrake;
  /// Mod 6 Direksiyon stili: 0 = Dönen Direksiyon, 1 = Dinamik Sabit Direksiyon
  int mod6SteeringStyle;
  /// Dinamik Sabit Direksiyon - Sağa dönüş dolgu rengi
  Color steeringTurnRightColor;
  /// Dinamik Sabit Direksiyon - Sola dönüş dolgu rengi
  Color steeringTurnLeftColor;

  /// Mod 6 Korna tuş ataması (Varsayılan 8 = Y Tuşu)
  int mod6HornKey;

  /// Mod 6 Konum Atamaları (1=Fren, 2=Gaz, 3=Debriyaj, 4=El Freni, 0=Yok)
  int mod6SlotLeft;
  int mod6SlotLeftInner;
  int mod6SlotRightInner;
  int mod6SlotRight;

  // ── Simüle Edilmiş Haptik ──────────────────────────────────────────────────
  /// true ise bar/ikona dokunulduğunda HapticFeedback tetiklenir.
  /// DLC haptic eklentisi aktifse otomatik devre dışı kalır.
  bool simulatedHapticEnabled;
  int globalHapticType; // 0: Hafif, 1: Orta, 2: Ağır, 3: Seçim, 4: Titreşim
  int globalHapticTrigger; // 0: Basılınca, 1: Bırakılınca, 2: Basıldığı Süre, 3: Aktif Süre
  Map<int, int> customButtonHapticTypes; // Key -> Type (0-4)
  Map<int, int> customButtonHapticTriggers; // Key -> Trigger (0-3)
  Map<int, bool> customButtonHapticEnabled; // Key -> Haptic Enabled override

  // ── Mod 5 özel layout & Profiller ──────────────────────────────────────────
  String? customLayout5Json;
  Map<String, String> layout5Profiles;
  String? activeLayout5Profile;

  // ── Mod 5 Joystick Hassasiyet Eğrisi ───────────────────────────────────────
  /// Üstel hassasiyet katsayısı. 1.0 = lineer, <1 = daha hassas, >1 = daha agresif.
  /// Aralık: 0.5 – 3.0
  double joystickSensitivity;

  // ── Sensör Merkez Noktası Ayarları ─────────────────────────────────────────
  /// 0: Otomatik (Belirli süre hareketsizlikte), 1: Yalnızca Butonla (Ayarlar/Düzenleyici)
  int gyroCenterMode;
  /// Otomatik merkezleme için hareketsiz kalınması gereken süre (saniye)
  double gyroAutoCenterDuration;
  /// Sağ analog / imleçte (Pitch ekseni) ölü alanın (deadzone) geçerli olup olmayacağı
  bool includePitchInDeadzone;

  // ── Sensörle Bakış (Gyro Look) — Global Ayar ───────────────────────────────
  /// Ana açma/kapama anahtarı
  bool gyroLookEnabled;
  /// 0: Sıfır Noktası Modu (direksiyon merkezde iken aktif), 1: TrackPoint Modu (mini joystick)
  int gyroLookStyle;
  /// 1: Normal (Mutlak), 2: FPS (Açısal Hız), 3: Sürücü (Yumuşatılmış)
  int gyroLookMode;
  /// Hassasiyet (0.2 - 3.0)
  double gyroLookSensitivity;
  /// Ölü alan (derece)
  double gyroLookDeadzone;

  // ── Joystick Çalışma Modu ──────────────────────────────────────────────────
  /// 0: Sabit (Fixed), 1: Sürüklenen (Floating Base), 2: Belirme (Spawn)
  /// Global ayar — sol ve sağ joystick aynı modu paylaşır.
  int joystickMode;

  // ── Buton Basış Süre Kontrolleri ───────────────────────────────────────────
  int globalButtonPressMode; // 0: Anlık, 1: Süreli, 2: Toggle, 3: Hızlı (Eski)
  int globalButtonPressDurationMs;
  Map<int, int> customButtonPressModes; // Key -> Mode map
  Map<int, int> customButtonPressDurationsMs; // Key -> Duration ms
  Map<int, List<int>> customMacros; // MacroID (>= 2000) -> List of keys

  // ── Donanım tuş ataması (1-16, 0 = devre dışı) ─────────────────────────────
  int volumeUpAction;
  int volumeDownAction;

  // ── Mod 0 tuş atamaları ─────────────────────────────────────────────────────
  // Ekranın sol yarısına tıklama / sağ yarısına tıklama
  int m0TapLeft; // varsayılan 4
  int m0TapRight; // varsayılan 3

  // ── Mod 1 tuş atamaları ─────────────────────────────────────────────────────
  // Sol pedal tıklama / Sağ pedal tıklama
  int m1TapLeft; // varsayılan 4
  int m1TapRight; // varsayılan 3

  // ── Mod 2 tuş atamaları ─────────────────────────────────────────────────────
  // 2×2 grid + pedal tıklama (mod2 = mod3 base)
  int m2Key1; // üst-sol  → varsayılan 3
  int m2Key2; // üst-sağ  → varsayılan 4
  int m2Key3; // alt-sol  → varsayılan 5
  int m2Key4; // alt-sağ  → varsayılan 6
  int m2TapLeft; // fren pedal tıklama → varsayılan 4
  int m2TapRight; // gaz pedal tıklama  → varsayılan 3

  // ── Mod 3 tuş atamaları ─────────────────────────────────────────────────────
  // Mod 2'nin aynısı + orta alt tuş
  int m3Key1;
  int m3Key2;
  int m3Key3;
  int m3Key4;
  int m3Key5; // orta alt tuş → varsayılan 7
  int m3TapLeft;
  int m3TapRight;

  // ── Mod 4 tuş atamaları ─────────────────────────────────────────────────────
  // Mod 2 grid + tam genişlik alt tuş
  int m4Key1;
  int m4Key2;
  int m4Key3;
  int m4Key4;
  int m4KeyBottom; // alt tam genişlik → varsayılan 7
  int m4TapLeft;
  int m4TapRight;

  // ── Gaz bölgesi 8-yön kaydırma atamaları ────────────────────────────────────
  int gasSwipeUp;
  int gasSwipeDown;
  int gasSwipeLeft;
  int gasSwipeRight;
  int gasSwipeUpLeft;
  int gasSwipeUpRight;
  int gasSwipeDownLeft;
  int gasSwipeDownRight;

  // ── Fren bölgesi 8-yön kaydırma atamaları ───────────────────────────────────
  int brakeSwipeUp;
  int brakeSwipeDown;
  int brakeSwipeLeft;
  int brakeSwipeRight;
  int brakeSwipeUpLeft;
  int brakeSwipeUpRight;
  int brakeSwipeDownLeft;
  int brakeSwipeDownRight;

  // ── Genel Pedal Tıklama Atamaları ───────────────────────────────────────────
  int gasTap;
  int brakeTap;

  AppSettings({
    this.backgroundColor = const Color(0xFF050510),
    this.detailColor = const Color(0xFF40E0D0),
    this.steeringIndicatorColor = const Color(0xFF40E0D0),
    this.steeringBgColor = const Color(0xFF0A0A20),
    this.gasColor = const Color(0xFF00C853),
    this.brakeColor = const Color(0xFFD50000),
    this.yetsoreColor = const Color(0xFFFFD600),
    this.pedalBgColor = const Color(0xFF050525),
    this.clutchColor = const Color(0xFF448AFF),
    this.clutchYetsoreColor = const Color(0xFFFFD600),
    this.handbrakeColor = const Color(0xFFFF5252),
    this.handbrakeYetsoreColor = const Color(0xFFFFD600),
    this.gasIconColor = const Color(0xFF69F0AE),
    this.brakeIconColor = const Color(0xFFFF5252),
    this.clutchIconColor = const Color(0xFF448AFF),
    this.clutchButtonColor = const Color(0xFF1E1E38),
    this.handbrakeIconColor = const Color(0xFFFF5252),
    this.handbrakeButtonColor = const Color(0xFF381E1E),
    this.steeringWheelColor = const Color(0xFF222234),
    this.zeroOrientation = 0,
    this.calibPitchOffset = 0.0,
    this.calibRollOffset = 0.0,
    this.useGyroscope = false,
    this.steeringAngle = 180.0,
    this.swipeSensitivity = 50.0,
    this.clickMaxDistance = 2.0,
    this.clickMaxDuration = 0.30,
    this.defaultDrivingMode = 0,
    this.isCumulativeSteering = false,
    this.pedalIconAccelerationRate = 1.0,
    this.mod6PedalStyle = 0,
    this.clutchIconAccelerationRate = 0.6,
    this.clutchType = 1,
    this.clutchKey = 18, // Varsayılan: R3 Tuşu
    this.handbrakeType = 0,
    this.handbrakeKey = 7, // Varsayılan: X Tuşu
    this.isAddonMasterSwitchActive = false,
    this.activeAddonIds = const [],
    this.mod6EnableClutch = true,
    this.mod6EnableHandbrake = true,
    this.mod6SteeringStyle = 1, // Varsayılan: Dinamik Sabit Direksiyon
    this.steeringTurnRightColor = const Color(0xFF00E5FF), // Cyan
    this.steeringTurnLeftColor = const Color(0xFFFF2A6D), // Neon Red
    this.mod6HornKey = 8, // Varsayılan: Y Tuşu
    this.mod6SlotLeft = 1, // Sol: Fren
    this.mod6SlotLeftInner = 3, // Sol-İç: Debriyaj
    this.mod6SlotRightInner = 4, // Sağ-İç: El Freni
    this.mod6SlotRight = 2, // Sağ: Gaz
    this.simulatedHapticEnabled = false,
    this.globalHapticType = 1,
    this.globalHapticTrigger = 0,
    this.customButtonHapticTypes = const {},
    this.customButtonHapticTriggers = const {},
    this.customButtonHapticEnabled = const {},
    this.customLayout5Json,
    this.layout5Profiles = const {},
    this.activeLayout5Profile,
    this.joystickSensitivity = 1.0,
    this.gyroCenterMode = 0,
    this.gyroAutoCenterDuration = 10.0,
    this.includePitchInDeadzone = true,
    this.gyroLookEnabled = false,
    this.gyroLookStyle = 0,
    this.gyroLookMode = 1,
    this.gyroLookSensitivity = 1.0,
    this.gyroLookDeadzone = 7.0,
    this.joystickMode = 0,
    this.globalButtonPressMode = 0,
    this.globalButtonPressDurationMs = 2000,
    this.customButtonPressModes = const {},
    this.customButtonPressDurationsMs = const {},
    this.customMacros = const {},
    // Donanım tuşları
    this.volumeUpAction = 2,
    this.volumeDownAction = 1,
    // Mod 0
    this.m0TapLeft = 17,
    this.m0TapRight = 18,
    // Mod 1
    this.m1TapLeft = 17,
    this.m1TapRight = 18,
    // Mod 2
    this.m2Key1 = 5,
    this.m2Key2 = 6,
    this.m2Key3 = 7,
    this.m2Key4 = 8,
    this.m2TapLeft = 17,
    this.m2TapRight = 18,
    // Mod 3
    this.m3Key1 = 5,
    this.m3Key2 = 6,
    this.m3Key3 = 14,
    this.m3Key4 = 8,
    this.m3Key5 = 7,
    this.m3TapLeft = 17,
    this.m3TapRight = 18,
    // Mod 4
    this.m4Key1 = 5,
    this.m4Key2 = 6,
    this.m4Key3 = 14,
    this.m4Key4 = 8,
    this.m4KeyBottom = 7,
    this.m4TapLeft = 17,
    this.m4TapRight = 18,
    // Gaz swipe atamaları (0 = devre dışı, -1 = Gaz, -2 = Fren)
    this.gasSwipeUp = -1,
    this.gasSwipeDown = -1,
    this.gasSwipeLeft = 9,
    this.gasSwipeRight = 12,
    this.gasSwipeUpLeft = 0,
    this.gasSwipeUpRight = 0,
    this.gasSwipeDownLeft = 0,
    this.gasSwipeDownRight = 0,
    // Fren swipe atamaları
    this.brakeSwipeUp = -2,
    this.brakeSwipeDown = -2,
    this.brakeSwipeLeft = 11,
    this.brakeSwipeRight = 10,
    this.brakeSwipeUpLeft = 0,
    this.brakeSwipeUpRight = 0,
    this.brakeSwipeDownLeft = 0,
    this.brakeSwipeDownRight = 0,
    this.gasTap = 18,
    this.brakeTap = 17,
  });
}
