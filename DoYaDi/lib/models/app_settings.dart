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

extension AppSettingsThemeExt on AppSettings {
  /// Arka plan parlaklığına göre dinamik zıt yazı rengi (Siyah veya Beyaz)
  Color get textColor =>
      backgroundColor.computeLuminance() > 0.5 ? const Color(0xFF111111) : Colors.white;

  /// İkincil zıt yazı rengi (Gri tonları)
  Color get textSecondaryColor =>
      backgroundColor.computeLuminance() > 0.5 ? const Color(0xFF555555) : Colors.white70;

  /// Açıklama ve pasif yazı rengi
  Color get textDisabledColor =>
      backgroundColor.computeLuminance() > 0.5 ? const Color(0xFF777777) : Colors.white38;

  /// Ayırıcı çizgi rengi
  Color get dividerColor =>
      backgroundColor.computeLuminance() > 0.5 ? Colors.black12 : Colors.white12;

  /// Belirli bir arka plan rengi için dinamik zıt yazı rengi
  Color contrastTextFor(Color bg) =>
      bg.computeLuminance() > 0.5 ? const Color(0xFF111111) : Colors.white;

  /// Mod bazlı aktif sayfa arka plan rengi
  Color modeBackgroundColor(int mode) {
    if (mode == 0 || mode == 1) return mod01BgColor;
    if (mode >= 2 && mode <= 4) return mod234BgColor;
    if (mode == 5) return mod5BgColor;
    if (mode == 6) return mod6BgColor;
    if (mode == 7) return mod7BgColor;
    if (mode == 8) return mod8BgColor;
    if (mode == 9) return mod9BgColor;
    return backgroundColor;
  }

  /// Mod bazlı aktif sayfa arka plan medyası
  String? modeBackgroundMedia(int mode) {
    if (mode == 0 || mode == 1) return mod01BgMediaPath ?? bgMediaPath;
    if (mode >= 2 && mode <= 4) return mod234BgMediaPath ?? bgMediaPath;
    if (mode == 5) return mod5BgMediaPath ?? bgMediaPath;
    if (mode == 6) return mod6BgMediaPath ?? bgMediaPath;
    if (mode == 7) return mod7BgMediaPath ?? bgMediaPath;
    if (mode == 8) return mod8BgMediaPath ?? bgMediaPath;
    if (mode == 9) return mod9BgMediaPath ?? bgMediaPath;
    return bgMediaPath;
  }
}

extension ColorContrastExt on Color {
  /// Herhangi bir renge zıt yazı rengi döndürür (Siyah veya Beyaz)
  Color get contrastingTextColor =>
      computeLuminance() > 0.5 ? const Color(0xFF111111) : Colors.white;
}

class AppSettings {
  // ── Giriş ekranı karşılama metni ("Hoşgeldin / Welcome" sonrası yazı) ───────
  String customDriverName;

  // ── Arka plan ve genel renkler ──────────────────────────────────────────────
  Color backgroundColor;
  Color detailColor;

  // ── Tema Renkleri & Font ──────────────────────────────────────────────────
  String appFontFamily;
  Color secondaryColor;
  Color tertiaryColor;
  Color warningColor;
  Color surfaceColor;
  bool preventIncompatibleColors;
  Color homeStartBtnColor;

  // ── Medya Arka Planları (Görsel / GIF / Döngülü Video) ────────────────────
  String? bgMediaPath;
  String? homeStartBtnMediaPath;
  String? generalButtonMediaPath;
  String? gasBarMediaPath;
  String? brakeBarMediaPath;
  String? pedalBarBgMediaPath;
  bool separatePedalBg;
  Color leftPedalBgColor;
  Color rightPedalBgColor;
  String? leftPedalBgMediaPath;
  String? rightPedalBgMediaPath;
  String? yetsoreMediaPath;
  String? steeringBarMediaPath;
  Color mode234ButtonColor;
  String? mode234ButtonMediaPath;
  Color mod01BgColor;
  String? mod01BgMediaPath;
  Color mod234BgColor;
  String? mod234BgMediaPath;
  Color mod5BgColor;
  String? mod5BgMediaPath;
  String? mod5JoystickMediaPath;
  String? mod5JoystickBaseMediaPath;
  String? mod5ButtonMediaPath;

  // ── Direksiyon göstergesi renkleri ─────────────────────────────────────────
  Color steeringIndicatorColor;
  Color steeringBgColor;

  // ── Pedal renkleri ──────────────────────────────────────────────────────────
  Color gasColor;
  Color brakeColor;
  Color yetsoreColor; // %70+ geri bildirim rengi
  Color pedalBgColor; // Pedal arka plan rengi

  // ── Mod 6 Özel Renkler & Görseller ─────────────────────────────────────────
  Color mod6BgColor;
  String? mod6BgMediaPath;
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
  Color mod6HornColor;
  String? mod6HornMediaPath;
  String? mod6ButtonsMediaPath;
  String? mod6AccelIconsMediaPath;
  String? clutchBarMediaPath;
  String? handbrakeBarMediaPath;

  // ── Mod 7 (F1 HUD) Renkler, Geçişler (Gradient) & Medya ────────────────────
  Color mod7BgColor;
  String? mod7BgMediaPath;
  Color mod7TyreColdColor;
  Color mod7TyreOptColor;
  Color mod7TyreHotColor;
  Color mod7TyreCritColor;
  Color mod7RpmLowColor;
  Color mod7RpmMidColor;
  Color mod7RpmHighColor;
  Color mod7RpmLimColor;
  Color mod7GearColor;
  Color mod7SpeedColor;
  Color mod7DrsActiveColor;
  Color mod7ErsColor;
  Color mod7RpmBoxColor;
  Color mod7ButtonsColor;

  // ── Mod 8 (Rahat Sürüş) Sayfa İçi & Sayfa Dışı (Overlay) Renkler ──────────
  Color mod8BgColor;
  String? mod8BgMediaPath;
  Color mod8SteerColor;
  Color mod8GasColor;
  Color mod8BrakeColor;
  Color mod8RadarColor;
  Color mod8CruiseColor;
  Color mod8HoldButtonsColor;
  Color mod8GearBtnColor;
  Color mod8OverlayBgColor;
  Color mod8OverlayBorderColor;
  Color mod8OverlaySteerColor;
  Color mod8OverlayGasColor;
  Color mod8OverlayBrakeColor;
  Color mod8OverlayGearBtnColor;

  // ── Mod 9 (Uçuş HOTAS) Renkler & Medya ────────────────────────────────────
  Color mod9BgColor;
  String? mod9BgMediaPath;
  Color mod9ThrottleColor;
  Color mod9WepColor;
  Color mod9AvionicsColor;
  Color mod9RudderColor;
  Color mod9HudColor;
  Color mod9FireBtnColor;
  Color mod9WeaponBtnColor;
  Color mod9HatSwitchColor;

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
  int defaultDrivingMode; // 0–10

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

  // ── DLC Haptic Telemetri İçerikleri ───────────────────────────────────────
  /// Motor RPM / Redline titreşimi (Varsayılan: KAPALI)
  bool dlcHapticRpm;
  /// Lastik kayması ve fren kilitlenmesi titreşimi (Varsayılan: AÇIK)
  bool dlcHapticSlip;
  /// Vites geçiş darbesi titreşimi (Varsayılan: AÇIK)
  bool dlcHapticGear;
  /// Çarpışma ve G-kuvveti darbesi titreşimi (Varsayılan: AÇIK)
  bool dlcHapticCollision;
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
  /// 0: Otomatik (Hareketsizlik), 1: Ayarlar Sayfasından, 2: Düzenleme Ekranından, 3: Ekranda Mini Buton
  int gyroCenterMode;
  /// Otomatik merkezleme için hareketsiz kalınması gereken süre (saniye)
  double gyroAutoCenterDuration;
  /// Sağ analog / imleçte (Pitch ekseni) ölü alanın (deadzone) geçerli olup olmayacağı
  bool includePitchInDeadzone;

  // ── Sensörle Bakış (Gyro Look) — Global Ayar ───────────────────────────────
  /// Ana açma/kapama anahtarı
  bool gyroLookEnabled;
  /// 0: Yarışçı Modu (Sadece Yaw), 1: TrackPoint Modu (mini joystick), 2: Sıfır Noktası Modu (Pitch & Yaw - direksiyon merkezde iken)
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

  // ── Mod 7 (F1 HUD) Ayarları ───────────────────────────────────────────────
  /// Birim sistemi: true = mph, false = km/h
  bool f1UseImperial;
  /// Telemetri düşük geçiş filtresi alfa (0.05-1.0)
  double f1LowPassAlpha;
  /// Rev limiter titreşim geri bildirimi
  bool f1HapticRevLimiter;
  /// Lastik kayması titreşim geri bildirimi
  bool f1HapticWheelSlip;
  /// Mod 7 merkez butonları
  int m7Key1; // Sol (Varsayılan X: 7)
  int m7Key2; // Üst (Varsayılan Y: 8)
  int m7Key3; // Sağ (Varsayılan B: 6)
  int m7Key4; // Alt (Varsayılan A: 5)
  // ── Mod 7 Gösterge İçerikleri ──
  /// RPM LED barı göster
  bool hudShowRpm;
  /// Hız göstergesi göster
  bool hudShowSpeed;
  /// 7-segment vites göstergesi göster
  bool hudShowGear;
  /// DRS ve ERS göstergeleri göster
  bool hudShowDrsErs;
  /// Gaz ve fren çubukları göster
  bool hudShowPedalBars;
  /// Lastik sıcaklıkları ve aşınma widget'ı göster
  bool hudShowTyres;
  /// Kırmızı telemetri RPM kutusu göster
  bool hudShowRpmBox;
  /// ABS / TC / SLIP durum rozetleri göster
  bool hudShowStatusFlags;

  // ── Mod 8 (Chill Drive) Ayarları ──────────────────────────────────────────
  /// Kapsül baloncuk overlay aktif
  bool chillOverlayEnabled;
  /// Overlay'de vites butonları göster
  bool chillOverlayGearButtons;
  /// Baloncuk stili: 0=Geniş Kapsül Kart, 1=Dikey Üçlü Yuvarlak (Vites+, Kalibre, Vites-)
  int chillOverlayStyle;
  /// Direksiyon ekseni: 0=Roll, 1=Yaw
  int chillSteeringAxis;
  /// Direksiyon hassasiyeti (0.2-3.0)
  double chillSteeringSensitivity;
  /// Gaz/Fren hassasiyeti (0.2-3.0)
  double chillGasBrakeSensitivity;

  // ── Mod 9 (Flight Stick) Ayarları ─────────────────────────────────────────
  /// Pitch hassasiyeti (0.2-3.0)
  double flightPitchSensitivity;
  /// Roll hassasiyeti (0.2-3.0)
  double flightRollSensitivity;
  /// Yaw hassasiyeti (0.2-3.0)
  double flightYawSensitivity;
  /// Pitch ölü bölgesi (derece, 0.0-10.0, varsayılan 0.0)
  double flightPitchDeadzone;
  /// Roll ölü bölgesi (derece, 0.0-10.0, varsayılan 0.0)
  double flightRollDeadzone;
  /// Yaw ölü bölgesi (derece, 0.0-10.0, varsayılan 0.0)
  double flightYawDeadzone;
  /// Uçuş Pitch ekseni tersinirliği
  bool flightInvertPitch;
  /// Uçuş Roll ekseni tersinirliği
  bool flightInvertRoll;
  /// Uçuş Yaw ekseni tersinirliği
  bool flightInvertYaw;
  /// Kademeli itki bölüm sayısı (2-8)
  int flightThrustDetents;
  /// Mod 9 Buton Atamaları
  int m9FireKey; // Top / Makineli Ateş (Varsayılan A: 5)
  int m9MissileKey; // Füze / Roket (Varsayılan B: 6)
  int m9LockKey; // Hedef Kilitleme (Varsayılan X: 7)
  int m9FlareKey; // Karşı Tedbir Flare/Chaff (Varsayılan Y: 8)
  int m9HeavyGunKey; // Ağır Silah / Top (Secondary Guns — Varsayılan Back: 14)
  int m9BombKey; // Bombardıman / Bomba Bırak (Varsayılan D-Pad Sağ: 12)
  int m9MapKey; // Taktik Harita / Radar (Varsayılan Start: 13)
  int m9FlapDownKey; // Flap Aç / İndir (Varsayılan D-Pad Aşağı: 10)
  int m9FlapUpKey; // Flap Topla (Varsayılan D-Pad Yukarı: 9)
  int m9GearKey; // İniş Takımı Aç/Kapat (Varsayılan L3: 17)
  int m9AirbrakeKey; // Hava Freni Ek Tuşu (Varsayılan D-Pad Sol: 11)
  int m9RudderLeftKey; // Sol Dümen Pedalı (Varsayılan LB: 1)
  int m9RudderRightKey; // Sağ Dümen Pedalı (Varsayılan RB: 2)

  // ── Mod 10 (Flight MFD) Ayarları ──────────────────────────────────────────
  /// Yapay ufuk göster
  bool mfdShowArtificialHorizon;
  /// Hız bandı göster
  bool mfdShowSpeedTape;
  /// İrtifa bandı göster
  bool mfdShowAltitudeTape;
  /// Alt panel motor göstergeleri (N1 / N2 / EGT)
  bool mfdShowEngineGauges;
  /// Gyro filtre alfa (0.05-1.0)
  double mfdGyroFilterAlpha;

  AppSettings({
    this.customDriverName = '',
    this.appFontFamily = 'Roboto',
    this.backgroundColor = const Color(0xFF050510),
    this.detailColor = const Color(0xFF40E0D0),
    this.secondaryColor = const Color(0xFF7C4DFF),
    this.tertiaryColor = const Color(0xFFFF6D00),
    this.warningColor = const Color(0xFFFF5252),
    this.surfaceColor = const Color(0xFF0A0A20),
    this.preventIncompatibleColors = false,
    this.homeStartBtnColor = const Color(0xFF40E0D0),
    this.bgMediaPath,
    this.homeStartBtnMediaPath,
    this.generalButtonMediaPath,
    this.gasBarMediaPath,
    this.brakeBarMediaPath,
    this.pedalBarBgMediaPath,
    this.separatePedalBg = false,
    this.leftPedalBgColor = const Color(0xFF050525),
    this.rightPedalBgColor = const Color(0xFF050525),
    this.leftPedalBgMediaPath,
    this.rightPedalBgMediaPath,
    this.yetsoreMediaPath,
    this.steeringBarMediaPath,
    this.mode234ButtonColor = const Color(0xFF40E0D0),
    this.mode234ButtonMediaPath,
    this.mod01BgColor = const Color(0xFF050510),
    this.mod01BgMediaPath,
    this.mod234BgColor = const Color(0xFF050510),
    this.mod234BgMediaPath,
    this.mod5BgColor = const Color(0xFF08080F),
    this.mod5BgMediaPath,
    this.mod5JoystickMediaPath,
    this.mod5JoystickBaseMediaPath,
    this.mod5ButtonMediaPath,
    this.steeringIndicatorColor = const Color(0xFF40E0D0),
    this.steeringBgColor = const Color(0xFF0A0A20),
    this.gasColor = const Color(0xFF00C853),
    this.brakeColor = const Color(0xFFD50000),
    this.yetsoreColor = const Color(0xFFFFD600),
    this.pedalBgColor = const Color(0xFF050525),
    this.mod6BgColor = const Color(0xFF0A0A12),
    this.mod6BgMediaPath,
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
    this.mod6HornColor = const Color(0xFF40E0D0),
    this.mod6HornMediaPath,
    this.mod6ButtonsMediaPath,
    this.mod6AccelIconsMediaPath,
    this.clutchBarMediaPath,
    this.handbrakeBarMediaPath,
    this.mod7BgColor = const Color(0xFF050508),
    this.mod7BgMediaPath,
    this.mod7TyreColdColor = const Color(0xFF1565C0),
    this.mod7TyreOptColor = const Color(0xFF2E7D32),
    this.mod7TyreHotColor = const Color(0xFFE65100),
    this.mod7TyreCritColor = const Color(0xFFC62828),
    this.mod7RpmLowColor = const Color(0xFF00E676),
    this.mod7RpmMidColor = const Color(0xFFFFEA00),
    this.mod7RpmHighColor = const Color(0xFFFF1744),
    this.mod7RpmLimColor = const Color(0xFFD500F9),
    this.mod7GearColor = const Color(0xFFFFFFFF),
    this.mod7SpeedColor = const Color(0xFFFFFFFF),
    this.mod7DrsActiveColor = const Color(0xFF00E676),
    this.mod7ErsColor = const Color(0xFFFFD600),
    this.mod7RpmBoxColor = const Color(0xFFFF1744),
    this.mod7ButtonsColor = const Color(0xFF40E0D0),
    this.mod8BgColor = const Color(0xFF0A0E14),
    this.mod8BgMediaPath,
    this.mod8SteerColor = const Color(0xFF00E5FF),
    this.mod8GasColor = const Color(0xFF4CAF50),
    this.mod8BrakeColor = const Color(0xFFEF5350),
    this.mod8RadarColor = const Color(0xFF00E5FF),
    this.mod8CruiseColor = const Color(0xFF00E676),
    this.mod8HoldButtonsColor = const Color(0xFFFFB300),
    this.mod8GearBtnColor = const Color(0xFF00E5FF),
    this.mod8OverlayBgColor = const Color(0xE610141E),
    this.mod8OverlayBorderColor = const Color(0x6600E5FF),
    this.mod8OverlaySteerColor = const Color(0xFF00E5FF),
    this.mod8OverlayGasColor = const Color(0xFF81C784),
    this.mod8OverlayBrakeColor = const Color(0xFFE57373),
    this.mod8OverlayGearBtnColor = const Color(0xFF00E5FF),
    this.mod9BgColor = const Color(0xFF080C0A),
    this.mod9BgMediaPath,
    this.mod9ThrottleColor = const Color(0xFF00E676),
    this.mod9WepColor = const Color(0xFFFF1744),
    this.mod9AvionicsColor = const Color(0xFF00E676),
    this.mod9RudderColor = const Color(0xFF00E676),
    this.mod9HudColor = const Color(0xFF00E676),
    this.mod9FireBtnColor = const Color(0xFFD50000),
    this.mod9WeaponBtnColor = const Color(0xFFFF5252),
    this.mod9HatSwitchColor = const Color(0xFF00E676),
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
    this.dlcHapticRpm = false,
    this.dlcHapticSlip = true,
    this.dlcHapticGear = true,
    this.dlcHapticCollision = true,
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
    // Mod 7 (F1 HUD)
    this.f1UseImperial = false,
    this.f1LowPassAlpha = 0.3,
    this.f1HapticRevLimiter = true,
    this.f1HapticWheelSlip = true,
    this.m7Key1 = 7, // X
    this.m7Key2 = 8, // Y
    this.m7Key3 = 6, // B
    this.m7Key4 = 5, // A
    this.hudShowRpm = true,
    this.hudShowSpeed = true,
    this.hudShowGear = true,
    this.hudShowDrsErs = true,
    this.hudShowPedalBars = true,
    this.hudShowTyres = true,
    this.hudShowRpmBox = true,
    this.hudShowStatusFlags = true,
    // Mod 8 (Chill Drive)
    this.chillOverlayEnabled = true,
    this.chillOverlayGearButtons = true,
    this.chillOverlayStyle = 0,
    this.chillSteeringAxis = 0,
    this.chillSteeringSensitivity = 1.0,
    this.chillGasBrakeSensitivity = 1.0,
    // Mod 9 (Flight Stick)
    this.flightPitchSensitivity = 1.0,
    this.flightRollSensitivity = 1.0,
    this.flightYawSensitivity = 1.0,
    this.flightPitchDeadzone = 0.0,
    this.flightRollDeadzone = 0.0,
    this.flightYawDeadzone = 0.0,
    this.flightInvertPitch = false,
    this.flightInvertRoll = false,
    this.flightInvertYaw = false,
    this.flightThrustDetents = 4,
    this.m9FireKey = 5,
    this.m9MissileKey = 6,
    this.m9LockKey = 7,
    this.m9FlareKey = 8,
    this.m9HeavyGunKey = 14,
    this.m9BombKey = 12,
    this.m9MapKey = 13,
    this.m9FlapDownKey = 10,
    this.m9FlapUpKey = 9,
    this.m9GearKey = 17,
    this.m9AirbrakeKey = 11,
    this.m9RudderLeftKey = 1,
    this.m9RudderRightKey = 2,
    // Mod 10 (Flight MFD)
    this.mfdShowArtificialHorizon = true,
    this.mfdShowSpeedTape = true,
    this.mfdShowAltitudeTape = true,
    this.mfdShowEngineGauges = true,
    this.mfdGyroFilterAlpha = 0.15,
  });

  /// Tüm özelleştirme (renk, medya, font) ayarlarını varsayılan değerlere döndürür.
  void resetCustomizationToDefaults() {
    appFontFamily = 'Roboto';
    backgroundColor = const Color(0xFF050510);
    detailColor = const Color(0xFF40E0D0);
    secondaryColor = const Color(0xFF7C4DFF);
    tertiaryColor = const Color(0xFFFF6D00);
    warningColor = const Color(0xFFFF5252);
    surfaceColor = const Color(0xFF0A0A20);
    preventIncompatibleColors = false;
    homeStartBtnColor = const Color(0xFF40E0D0);

    bgMediaPath = null;
    homeStartBtnMediaPath = null;
    generalButtonMediaPath = null;
    gasBarMediaPath = null;
    brakeBarMediaPath = null;
    pedalBarBgMediaPath = null;
    separatePedalBg = false;
    leftPedalBgColor = const Color(0xFF050525);
    rightPedalBgColor = const Color(0xFF050525);
    leftPedalBgMediaPath = null;
    rightPedalBgMediaPath = null;
    yetsoreMediaPath = null;
    steeringBarMediaPath = null;
    mode234ButtonColor = const Color(0xFF40E0D0);
    mode234ButtonMediaPath = null;
    mod01BgColor = const Color(0xFF050510);
    mod01BgMediaPath = null;
    mod234BgColor = const Color(0xFF050510);
    mod234BgMediaPath = null;
    mod5BgColor = const Color(0xFF08080F);
    mod5BgMediaPath = null;
    mod5JoystickMediaPath = null;
    mod5JoystickBaseMediaPath = null;
    mod5ButtonMediaPath = null;

    steeringIndicatorColor = const Color(0xFF40E0D0);
    steeringBgColor = const Color(0xFF0A0A20);
    gasColor = const Color(0xFF00C853);
    brakeColor = const Color(0xFFD50000);
    yetsoreColor = const Color(0xFFFFD600);
    pedalBgColor = const Color(0xFF050525);

    mod6BgColor = const Color(0xFF0A0A12);
    mod6BgMediaPath = null;
    clutchColor = const Color(0xFF448AFF);
    clutchYetsoreColor = const Color(0xFFFFD600);
    handbrakeColor = const Color(0xFFFF5252);
    handbrakeYetsoreColor = const Color(0xFFFFD600);
    gasIconColor = const Color(0xFF69F0AE);
    brakeIconColor = const Color(0xFFFF5252);
    clutchIconColor = const Color(0xFF448AFF);
    clutchButtonColor = const Color(0xFF1E1E38);
    handbrakeIconColor = const Color(0xFFFF5252);
    handbrakeButtonColor = const Color(0xFF381E1E);
    steeringWheelColor = const Color(0xFF222234);
    steeringTurnRightColor = const Color(0xFF00E5FF);
    steeringTurnLeftColor = const Color(0xFFFF2A6D);
    mod6HornColor = const Color(0xFF40E0D0);
    mod6HornMediaPath = null;
    mod6ButtonsMediaPath = null;
    mod6AccelIconsMediaPath = null;
    clutchBarMediaPath = null;
    handbrakeBarMediaPath = null;

    mod7BgColor = const Color(0xFF050508);
    mod7BgMediaPath = null;
    mod7TyreColdColor = const Color(0xFF1565C0);
    mod7TyreOptColor = const Color(0xFF2E7D32);
    mod7TyreHotColor = const Color(0xFFE65100);
    mod7TyreCritColor = const Color(0xFFC62828);
    mod7RpmLowColor = const Color(0xFF00E676);
    mod7RpmMidColor = const Color(0xFFFFEA00);
    mod7RpmHighColor = const Color(0xFFFF1744);
    mod7RpmLimColor = const Color(0xFFD500F9);
    mod7GearColor = const Color(0xFFFFFFFF);
    mod7SpeedColor = const Color(0xFFFFFFFF);
    mod7DrsActiveColor = const Color(0xFF00E676);
    mod7ErsColor = const Color(0xFFFFD600);
    mod7RpmBoxColor = const Color(0xFFFF1744);
    mod7ButtonsColor = const Color(0xFF40E0D0);

    mod8BgColor = const Color(0xFF0A0E14);
    mod8BgMediaPath = null;
    mod8SteerColor = const Color(0xFF00E5FF);
    mod8GasColor = const Color(0xFF4CAF50);
    mod8BrakeColor = const Color(0xFFEF5350);
    mod8RadarColor = const Color(0xFF00E5FF);
    mod8CruiseColor = const Color(0xFF00E676);
    mod8HoldButtonsColor = const Color(0xFFFFB300);
    mod8GearBtnColor = const Color(0xFF00E5FF);
    mod8OverlayBgColor = const Color(0xE610141E);
    mod8OverlayBorderColor = const Color(0x6600E5FF);
    mod8OverlaySteerColor = const Color(0xFF00E5FF);
    mod8OverlayGasColor = const Color(0xFF81C784);
    mod8OverlayBrakeColor = const Color(0xFFE57373);
    mod8OverlayGearBtnColor = const Color(0xFF00E5FF);

    mod9BgColor = const Color(0xFF080C0A);
    mod9BgMediaPath = null;
    mod9ThrottleColor = const Color(0xFF00E676);
    mod9WepColor = const Color(0xFFFF1744);
    mod9AvionicsColor = const Color(0xFF00E676);
    mod9RudderColor = const Color(0xFF00E676);
    mod9HudColor = const Color(0xFF00E676);
    mod9FireBtnColor = const Color(0xFFD50000);
    mod9WeaponBtnColor = const Color(0xFFFF5252);
    mod9HatSwitchColor = const Color(0xFF00E676);
  }

  /// Tüm uygulama ayarlarını tek bir JSON haritasına dönüştürür (Snapshot için).
  Map<String, dynamic> toJson() {
    return {
      'customDriverName': customDriverName,
      'appFontFamily': appFontFamily,
      'backgroundColor': backgroundColor.toARGB32(),
      'detailColor': detailColor.toARGB32(),
      'secondaryColor': secondaryColor.toARGB32(),
      'tertiaryColor': tertiaryColor.toARGB32(),
      'warningColor': warningColor.toARGB32(),
      'surfaceColor': surfaceColor.toARGB32(),
      'preventIncompatibleColors': preventIncompatibleColors,
      'homeStartBtnColor': homeStartBtnColor.toARGB32(),
      'bgMediaPath': bgMediaPath,
      'homeStartBtnMediaPath': homeStartBtnMediaPath,
      'generalButtonMediaPath': generalButtonMediaPath,
      'gasBarMediaPath': gasBarMediaPath,
      'brakeBarMediaPath': brakeBarMediaPath,
      'pedalBarBgMediaPath': pedalBarBgMediaPath,
      'separatePedalBg': separatePedalBg,
      'leftPedalBgColor': leftPedalBgColor.toARGB32(),
      'rightPedalBgColor': rightPedalBgColor.toARGB32(),
      'leftPedalBgMediaPath': leftPedalBgMediaPath,
      'rightPedalBgMediaPath': rightPedalBgMediaPath,
      'yetsoreMediaPath': yetsoreMediaPath,
      'steeringBarMediaPath': steeringBarMediaPath,
      'mode234ButtonColor': mode234ButtonColor.toARGB32(),
      'mode234ButtonMediaPath': mode234ButtonMediaPath,
      'mod01BgColor': mod01BgColor.toARGB32(),
      'mod01BgMediaPath': mod01BgMediaPath,
      'mod234BgColor': mod234BgColor.toARGB32(),
      'mod234BgMediaPath': mod234BgMediaPath,
      'mod5BgColor': mod5BgColor.toARGB32(),
      'mod5BgMediaPath': mod5BgMediaPath,
      'mod5JoystickMediaPath': mod5JoystickMediaPath,
      'mod5JoystickBaseMediaPath': mod5JoystickBaseMediaPath,
      'mod5ButtonMediaPath': mod5ButtonMediaPath,
      'steeringIndicatorColor': steeringIndicatorColor.toARGB32(),
      'steeringBgColor': steeringBgColor.toARGB32(),
      'gasColor': gasColor.toARGB32(),
      'brakeColor': brakeColor.toARGB32(),
      'yetsoreColor': yetsoreColor.toARGB32(),
      'pedalBgColor': pedalBgColor.toARGB32(),
      'mod6BgColor': mod6BgColor.toARGB32(),
      'mod6BgMediaPath': mod6BgMediaPath,
      'clutchColor': clutchColor.toARGB32(),
      'clutchYetsoreColor': clutchYetsoreColor.toARGB32(),
      'handbrakeColor': handbrakeColor.toARGB32(),
      'handbrakeYetsoreColor': handbrakeYetsoreColor.toARGB32(),
      'gasIconColor': gasIconColor.toARGB32(),
      'brakeIconColor': brakeIconColor.toARGB32(),
      'clutchIconColor': clutchIconColor.toARGB32(),
      'clutchButtonColor': clutchButtonColor.toARGB32(),
      'handbrakeIconColor': handbrakeIconColor.toARGB32(),
      'handbrakeButtonColor': handbrakeButtonColor.toARGB32(),
      'steeringWheelColor': steeringWheelColor.toARGB32(),
      'mod6HornColor': mod6HornColor.toARGB32(),
      'mod6HornMediaPath': mod6HornMediaPath,
      'mod6ButtonsMediaPath': mod6ButtonsMediaPath,
      'mod6AccelIconsMediaPath': mod6AccelIconsMediaPath,
      'clutchBarMediaPath': clutchBarMediaPath,
      'handbrakeBarMediaPath': handbrakeBarMediaPath,
      'mod7BgColor': mod7BgColor.toARGB32(),
      'mod7BgMediaPath': mod7BgMediaPath,
      'mod7TyreColdColor': mod7TyreColdColor.toARGB32(),
      'mod7TyreOptColor': mod7TyreOptColor.toARGB32(),
      'mod7TyreHotColor': mod7TyreHotColor.toARGB32(),
      'mod7TyreCritColor': mod7TyreCritColor.toARGB32(),
      'mod7RpmLowColor': mod7RpmLowColor.toARGB32(),
      'mod7RpmMidColor': mod7RpmMidColor.toARGB32(),
      'mod7RpmHighColor': mod7RpmHighColor.toARGB32(),
      'mod7RpmLimColor': mod7RpmLimColor.toARGB32(),
      'mod7GearColor': mod7GearColor.toARGB32(),
      'mod7SpeedColor': mod7SpeedColor.toARGB32(),
      'mod7DrsActiveColor': mod7DrsActiveColor.toARGB32(),
      'mod7ErsColor': mod7ErsColor.toARGB32(),
      'mod7RpmBoxColor': mod7RpmBoxColor.toARGB32(),
      'mod7ButtonsColor': mod7ButtonsColor.toARGB32(),
      'mod8BgColor': mod8BgColor.toARGB32(),
      'mod8BgMediaPath': mod8BgMediaPath,
      'mod8SteerColor': mod8SteerColor.toARGB32(),
      'mod8GasColor': mod8GasColor.toARGB32(),
      'mod8BrakeColor': mod8BrakeColor.toARGB32(),
      'mod8RadarColor': mod8RadarColor.toARGB32(),
      'mod8CruiseColor': mod8CruiseColor.toARGB32(),
      'mod8HoldButtonsColor': mod8HoldButtonsColor.toARGB32(),
      'mod8GearBtnColor': mod8GearBtnColor.toARGB32(),
      'mod8OverlayBgColor': mod8OverlayBgColor.toARGB32(),
      'mod8OverlayBorderColor': mod8OverlayBorderColor.toARGB32(),
      'mod8OverlaySteerColor': mod8OverlaySteerColor.toARGB32(),
      'mod8OverlayGasColor': mod8OverlayGasColor.toARGB32(),
      'mod8OverlayBrakeColor': mod8OverlayBrakeColor.toARGB32(),
      'mod8OverlayGearBtnColor': mod8OverlayGearBtnColor.toARGB32(),
      'mod9BgColor': mod9BgColor.toARGB32(),
      'mod9BgMediaPath': mod9BgMediaPath,
      'mod9ThrottleColor': mod9ThrottleColor.toARGB32(),
      'mod9WepColor': mod9WepColor.toARGB32(),
      'mod9AvionicsColor': mod9AvionicsColor.toARGB32(),
      'mod9RudderColor': mod9RudderColor.toARGB32(),
      'mod9HudColor': mod9HudColor.toARGB32(),
      'mod9FireBtnColor': mod9FireBtnColor.toARGB32(),
      'mod9WeaponBtnColor': mod9WeaponBtnColor.toARGB32(),
      'mod9HatSwitchColor': mod9HatSwitchColor.toARGB32(),
      'zeroOrientation': zeroOrientation,
      'calibPitchOffset': calibPitchOffset,
      'calibRollOffset': calibRollOffset,
      'useGyroscope': useGyroscope,
      'steeringAngle': steeringAngle,
      'swipeSensitivity': swipeSensitivity,
      'clickMaxDistance': clickMaxDistance,
      'clickMaxDuration': clickMaxDuration,
      'defaultDrivingMode': defaultDrivingMode,
      'isCumulativeSteering': isCumulativeSteering,
      'pedalIconAccelerationRate': pedalIconAccelerationRate,
      'mod6PedalStyle': mod6PedalStyle,
      'clutchIconAccelerationRate': clutchIconAccelerationRate,
      'clutchType': clutchType,
      'clutchKey': clutchKey,
      'handbrakeType': handbrakeType,
      'handbrakeKey': handbrakeKey,
      'isAddonMasterSwitchActive': isAddonMasterSwitchActive,
      'activeAddonIds': List<String>.from(activeAddonIds),
      'dlcHapticRpm': dlcHapticRpm,
      'dlcHapticSlip': dlcHapticSlip,
      'dlcHapticGear': dlcHapticGear,
      'dlcHapticCollision': dlcHapticCollision,
      'mod6EnableClutch': mod6EnableClutch,
      'mod6EnableHandbrake': mod6EnableHandbrake,
      'mod6SteeringStyle': mod6SteeringStyle,
      'steeringTurnRightColor': steeringTurnRightColor.toARGB32(),
      'steeringTurnLeftColor': steeringTurnLeftColor.toARGB32(),
      'mod6HornKey': mod6HornKey,
      'mod6SlotLeft': mod6SlotLeft,
      'mod6SlotLeftInner': mod6SlotLeftInner,
      'mod6SlotRightInner': mod6SlotRightInner,
      'mod6SlotRight': mod6SlotRight,
      'simulatedHapticEnabled': simulatedHapticEnabled,
      'globalHapticType': globalHapticType,
      'globalHapticTrigger': globalHapticTrigger,
      'customButtonHapticTypes': customButtonHapticTypes.map(
        (k, v) => MapEntry(k.toString(), v),
      ),
      'customButtonHapticTriggers': customButtonHapticTriggers.map(
        (k, v) => MapEntry(k.toString(), v),
      ),
      'customButtonHapticEnabled': customButtonHapticEnabled.map(
        (k, v) => MapEntry(k.toString(), v),
      ),
      'customLayout5Json': customLayout5Json,
      'layout5Profiles': Map<String, String>.from(layout5Profiles),
      'activeLayout5Profile': activeLayout5Profile,
      'joystickSensitivity': joystickSensitivity,
      'gyroCenterMode': gyroCenterMode,
      'gyroAutoCenterDuration': gyroAutoCenterDuration,
      'includePitchInDeadzone': includePitchInDeadzone,
      'gyroLookEnabled': gyroLookEnabled,
      'gyroLookStyle': gyroLookStyle,
      'gyroLookMode': gyroLookMode,
      'gyroLookSensitivity': gyroLookSensitivity,
      'gyroLookDeadzone': gyroLookDeadzone,
      'joystickMode': joystickMode,
      'globalButtonPressMode': globalButtonPressMode,
      'globalButtonPressDurationMs': globalButtonPressDurationMs,
      'customButtonPressModes': customButtonPressModes.map(
        (k, v) => MapEntry(k.toString(), v),
      ),
      'customButtonPressDurationsMs': customButtonPressDurationsMs.map(
        (k, v) => MapEntry(k.toString(), v),
      ),
      'customMacros': customMacros.map(
        (k, v) => MapEntry(k.toString(), List<int>.from(v)),
      ),
      'volumeUpAction': volumeUpAction,
      'volumeDownAction': volumeDownAction,
      'm0TapLeft': m0TapLeft,
      'm0TapRight': m0TapRight,
      'm1TapLeft': m1TapLeft,
      'm1TapRight': m1TapRight,
      'm2Key1': m2Key1,
      'm2Key2': m2Key2,
      'm2Key3': m2Key3,
      'm2Key4': m2Key4,
      'm2TapLeft': m2TapLeft,
      'm2TapRight': m2TapRight,
      'm3Key1': m3Key1,
      'm3Key2': m3Key2,
      'm3Key3': m3Key3,
      'm3Key4': m3Key4,
      'm3Key5': m3Key5,
      'm3TapLeft': m3TapLeft,
      'm3TapRight': m3TapRight,
      'm4Key1': m4Key1,
      'm4Key2': m4Key2,
      'm4Key3': m4Key3,
      'm4Key4': m4Key4,
      'm4KeyBottom': m4KeyBottom,
      'm4TapLeft': m4TapLeft,
      'm4TapRight': m4TapRight,
      'gasSwipeUp': gasSwipeUp,
      'gasSwipeDown': gasSwipeDown,
      'gasSwipeLeft': gasSwipeLeft,
      'gasSwipeRight': gasSwipeRight,
      'gasSwipeUpLeft': gasSwipeUpLeft,
      'gasSwipeUpRight': gasSwipeUpRight,
      'gasSwipeDownLeft': gasSwipeDownLeft,
      'gasSwipeDownRight': gasSwipeDownRight,
      'brakeSwipeUp': brakeSwipeUp,
      'brakeSwipeDown': brakeSwipeDown,
      'brakeSwipeLeft': brakeSwipeLeft,
      'brakeSwipeRight': brakeSwipeRight,
      'brakeSwipeUpLeft': brakeSwipeUpLeft,
      'brakeSwipeUpRight': brakeSwipeUpRight,
      'brakeSwipeDownLeft': brakeSwipeDownLeft,
      'brakeSwipeDownRight': brakeSwipeDownRight,
      'gasTap': gasTap,
      'brakeTap': brakeTap,
      'f1UseImperial': f1UseImperial,
      'f1LowPassAlpha': f1LowPassAlpha,
      'f1HapticRevLimiter': f1HapticRevLimiter,
      'f1HapticWheelSlip': f1HapticWheelSlip,
      'm7Key1': m7Key1,
      'm7Key2': m7Key2,
      'm7Key3': m7Key3,
      'm7Key4': m7Key4,
      'hudShowRpm': hudShowRpm,
      'hudShowSpeed': hudShowSpeed,
      'hudShowGear': hudShowGear,
      'hudShowDrsErs': hudShowDrsErs,
      'hudShowPedalBars': hudShowPedalBars,
      'hudShowTyres': hudShowTyres,
      'hudShowRpmBox': hudShowRpmBox,
      'hudShowStatusFlags': hudShowStatusFlags,
      'chillOverlayEnabled': chillOverlayEnabled,
      'chillOverlayGearButtons': chillOverlayGearButtons,
      'chillOverlayStyle': chillOverlayStyle,
      'chillSteeringAxis': chillSteeringAxis,
      'chillSteeringSensitivity': chillSteeringSensitivity,
      'chillGasBrakeSensitivity': chillGasBrakeSensitivity,
      'flightPitchSensitivity': flightPitchSensitivity,
      'flightRollSensitivity': flightRollSensitivity,
      'flightYawSensitivity': flightYawSensitivity,
      'flightPitchDeadzone': flightPitchDeadzone,
      'flightRollDeadzone': flightRollDeadzone,
      'flightYawDeadzone': flightYawDeadzone,
      'flightInvertPitch': flightInvertPitch,
      'flightInvertRoll': flightInvertRoll,
      'flightInvertYaw': flightInvertYaw,
      'flightThrustDetents': flightThrustDetents,
      'm9FireKey': m9FireKey,
      'm9MissileKey': m9MissileKey,
      'm9LockKey': m9LockKey,
      'm9FlareKey': m9FlareKey,
      'm9HeavyGunKey': m9HeavyGunKey,
      'm9BombKey': m9BombKey,
      'm9MapKey': m9MapKey,
      'm9FlapDownKey': m9FlapDownKey,
      'm9FlapUpKey': m9FlapUpKey,
      'm9GearKey': m9GearKey,
      'm9AirbrakeKey': m9AirbrakeKey,
      'm9RudderLeftKey': m9RudderLeftKey,
      'm9RudderRightKey': m9RudderRightKey,
      'mfdShowArtificialHorizon': mfdShowArtificialHorizon,
      'mfdShowSpeedTape': mfdShowSpeedTape,
      'mfdShowAltitudeTape': mfdShowAltitudeTape,
      'mfdShowEngineGauges': mfdShowEngineGauges,
      'mfdGyroFilterAlpha': mfdGyroFilterAlpha,
    };
  }

  static Color _colorFromJson(dynamic raw, Color fallback) {
    if (raw is int) return Color(raw);
    if (raw is num) return Color(raw.toInt());
    return fallback;
  }

  static double _doubleFromJson(dynamic raw, double fallback) {
    if (raw is num) return raw.toDouble();
    return fallback;
  }

  static int _intFromJson(dynamic raw, int fallback) {
    if (raw is num) return raw.toInt();
    return fallback;
  }

  static bool _boolFromJson(dynamic raw, bool fallback) {
    if (raw is bool) return raw;
    return fallback;
  }

  static Map<int, int> _intIntMapFromJson(dynamic raw) {
    if (raw is! Map) return const {};
    final out = <int, int>{};
    raw.forEach((k, v) {
      final ki = int.tryParse(k.toString());
      if (ki != null && v is num) out[ki] = v.toInt();
    });
    return out;
  }

  static Map<int, bool> _intBoolMapFromJson(dynamic raw) {
    if (raw is! Map) return const {};
    final out = <int, bool>{};
    raw.forEach((k, v) {
      final ki = int.tryParse(k.toString());
      if (ki != null && v is bool) out[ki] = v;
    });
    return out;
  }

  static Map<int, List<int>> _macrosMapFromJson(dynamic raw) {
    if (raw is! Map) return const {};
    final out = <int, List<int>>{};
    raw.forEach((k, v) {
      final ki = int.tryParse(k.toString());
      if (ki != null && v is List) {
        out[ki] = v.whereType<num>().map((e) => e.toInt()).toList();
      }
    });
    return out;
  }

  factory AppSettings.fromJson(Map<String, dynamic> m) {
    final defaults = AppSettings();
    return AppSettings(
      customDriverName: m['customDriverName']?.toString() ?? defaults.customDriverName,
      appFontFamily: m['appFontFamily']?.toString() ?? defaults.appFontFamily,
      backgroundColor: _colorFromJson(m['backgroundColor'], defaults.backgroundColor),
      detailColor: _colorFromJson(m['detailColor'], defaults.detailColor),
      secondaryColor: _colorFromJson(m['secondaryColor'], defaults.secondaryColor),
      tertiaryColor: _colorFromJson(m['tertiaryColor'], defaults.tertiaryColor),
      warningColor: _colorFromJson(m['warningColor'], defaults.warningColor),
      surfaceColor: _colorFromJson(m['surfaceColor'], defaults.surfaceColor),
      preventIncompatibleColors: _boolFromJson(
        m['preventIncompatibleColors'],
        defaults.preventIncompatibleColors,
      ),
      homeStartBtnColor: _colorFromJson(m['homeStartBtnColor'], defaults.homeStartBtnColor),
      bgMediaPath: m['bgMediaPath'] as String?,
      homeStartBtnMediaPath: m['homeStartBtnMediaPath'] as String?,
      generalButtonMediaPath: m['generalButtonMediaPath'] as String?,
      gasBarMediaPath: m['gasBarMediaPath'] as String?,
      brakeBarMediaPath: m['brakeBarMediaPath'] as String?,
      pedalBarBgMediaPath: m['pedalBarBgMediaPath'] as String?,
      separatePedalBg: _boolFromJson(m['separatePedalBg'], defaults.separatePedalBg),
      leftPedalBgColor: _colorFromJson(m['leftPedalBgColor'], defaults.leftPedalBgColor),
      rightPedalBgColor: _colorFromJson(m['rightPedalBgColor'], defaults.rightPedalBgColor),
      leftPedalBgMediaPath: m['leftPedalBgMediaPath'] as String?,
      rightPedalBgMediaPath: m['rightPedalBgMediaPath'] as String?,
      yetsoreMediaPath: m['yetsoreMediaPath'] as String?,
      steeringBarMediaPath: m['steeringBarMediaPath'] as String?,
      mode234ButtonColor: _colorFromJson(m['mode234ButtonColor'], defaults.mode234ButtonColor),
      mode234ButtonMediaPath: m['mode234ButtonMediaPath'] as String?,
      mod01BgColor: _colorFromJson(m['mod01BgColor'], defaults.mod01BgColor),
      mod01BgMediaPath: m['mod01BgMediaPath'] as String?,
      mod234BgColor: _colorFromJson(m['mod234BgColor'], defaults.mod234BgColor),
      mod234BgMediaPath: m['mod234BgMediaPath'] as String?,
      mod5BgColor: _colorFromJson(m['mod5BgColor'], defaults.mod5BgColor),
      mod5BgMediaPath: m['mod5BgMediaPath'] as String?,
      mod5JoystickMediaPath: m['mod5JoystickMediaPath'] as String?,
      mod5JoystickBaseMediaPath: m['mod5JoystickBaseMediaPath'] as String?,
      mod5ButtonMediaPath: m['mod5ButtonMediaPath'] as String?,
      steeringIndicatorColor: _colorFromJson(
        m['steeringIndicatorColor'],
        defaults.steeringIndicatorColor,
      ),
      steeringBgColor: _colorFromJson(m['steeringBgColor'], defaults.steeringBgColor),
      gasColor: _colorFromJson(m['gasColor'], defaults.gasColor),
      brakeColor: _colorFromJson(m['brakeColor'], defaults.brakeColor),
      yetsoreColor: _colorFromJson(m['yetsoreColor'], defaults.yetsoreColor),
      pedalBgColor: _colorFromJson(m['pedalBgColor'], defaults.pedalBgColor),
      mod6BgColor: _colorFromJson(m['mod6BgColor'], defaults.mod6BgColor),
      mod6BgMediaPath: m['mod6BgMediaPath'] as String?,
      clutchColor: _colorFromJson(m['clutchColor'], defaults.clutchColor),
      clutchYetsoreColor: _colorFromJson(m['clutchYetsoreColor'], defaults.clutchYetsoreColor),
      handbrakeColor: _colorFromJson(m['handbrakeColor'], defaults.handbrakeColor),
      handbrakeYetsoreColor: _colorFromJson(
        m['handbrakeYetsoreColor'],
        defaults.handbrakeYetsoreColor,
      ),
      gasIconColor: _colorFromJson(m['gasIconColor'], defaults.gasIconColor),
      brakeIconColor: _colorFromJson(m['brakeIconColor'], defaults.brakeIconColor),
      clutchIconColor: _colorFromJson(m['clutchIconColor'], defaults.clutchIconColor),
      clutchButtonColor: _colorFromJson(m['clutchButtonColor'], defaults.clutchButtonColor),
      handbrakeIconColor: _colorFromJson(m['handbrakeIconColor'], defaults.handbrakeIconColor),
      handbrakeButtonColor: _colorFromJson(
        m['handbrakeButtonColor'],
        defaults.handbrakeButtonColor,
      ),
      steeringWheelColor: _colorFromJson(m['steeringWheelColor'], defaults.steeringWheelColor),
      mod6HornColor: _colorFromJson(m['mod6HornColor'], defaults.mod6HornColor),
      mod6HornMediaPath: m['mod6HornMediaPath'] as String?,
      mod6ButtonsMediaPath: m['mod6ButtonsMediaPath'] as String?,
      mod6AccelIconsMediaPath: m['mod6AccelIconsMediaPath'] as String?,
      clutchBarMediaPath: m['clutchBarMediaPath'] as String?,
      handbrakeBarMediaPath: m['handbrakeBarMediaPath'] as String?,
      mod7BgColor: _colorFromJson(m['mod7BgColor'], defaults.mod7BgColor),
      mod7BgMediaPath: m['mod7BgMediaPath'] as String?,
      mod7TyreColdColor: _colorFromJson(m['mod7TyreColdColor'], defaults.mod7TyreColdColor),
      mod7TyreOptColor: _colorFromJson(m['mod7TyreOptColor'], defaults.mod7TyreOptColor),
      mod7TyreHotColor: _colorFromJson(m['mod7TyreHotColor'], defaults.mod7TyreHotColor),
      mod7TyreCritColor: _colorFromJson(m['mod7TyreCritColor'], defaults.mod7TyreCritColor),
      mod7RpmLowColor: _colorFromJson(m['mod7RpmLowColor'], defaults.mod7RpmLowColor),
      mod7RpmMidColor: _colorFromJson(m['mod7RpmMidColor'], defaults.mod7RpmMidColor),
      mod7RpmHighColor: _colorFromJson(m['mod7RpmHighColor'], defaults.mod7RpmHighColor),
      mod7RpmLimColor: _colorFromJson(m['mod7RpmLimColor'], defaults.mod7RpmLimColor),
      mod7GearColor: _colorFromJson(m['mod7GearColor'], defaults.mod7GearColor),
      mod7SpeedColor: _colorFromJson(m['mod7SpeedColor'], defaults.mod7SpeedColor),
      mod7DrsActiveColor: _colorFromJson(m['mod7DrsActiveColor'], defaults.mod7DrsActiveColor),
      mod7ErsColor: _colorFromJson(m['mod7ErsColor'], defaults.mod7ErsColor),
      mod7RpmBoxColor: _colorFromJson(m['mod7RpmBoxColor'], defaults.mod7RpmBoxColor),
      mod7ButtonsColor: _colorFromJson(m['mod7ButtonsColor'], defaults.mod7ButtonsColor),
      mod8BgColor: _colorFromJson(m['mod8BgColor'], defaults.mod8BgColor),
      mod8BgMediaPath: m['mod8BgMediaPath'] as String?,
      mod8SteerColor: _colorFromJson(m['mod8SteerColor'], defaults.mod8SteerColor),
      mod8GasColor: _colorFromJson(m['mod8GasColor'], defaults.mod8GasColor),
      mod8BrakeColor: _colorFromJson(m['mod8BrakeColor'], defaults.mod8BrakeColor),
      mod8RadarColor: _colorFromJson(m['mod8RadarColor'], defaults.mod8RadarColor),
      mod8CruiseColor: _colorFromJson(m['mod8CruiseColor'], defaults.mod8CruiseColor),
      mod8HoldButtonsColor: _colorFromJson(
        m['mod8HoldButtonsColor'],
        defaults.mod8HoldButtonsColor,
      ),
      mod8GearBtnColor: _colorFromJson(m['mod8GearBtnColor'], defaults.mod8GearBtnColor),
      mod8OverlayBgColor: _colorFromJson(m['mod8OverlayBgColor'], defaults.mod8OverlayBgColor),
      mod8OverlayBorderColor: _colorFromJson(
        m['mod8OverlayBorderColor'],
        defaults.mod8OverlayBorderColor,
      ),
      mod8OverlaySteerColor: _colorFromJson(
        m['mod8OverlaySteerColor'],
        defaults.mod8OverlaySteerColor,
      ),
      mod8OverlayGasColor: _colorFromJson(m['mod8OverlayGasColor'], defaults.mod8OverlayGasColor),
      mod8OverlayBrakeColor: _colorFromJson(
        m['mod8OverlayBrakeColor'],
        defaults.mod8OverlayBrakeColor,
      ),
      mod8OverlayGearBtnColor: _colorFromJson(
        m['mod8OverlayGearBtnColor'],
        defaults.mod8OverlayGearBtnColor,
      ),
      mod9BgColor: _colorFromJson(m['mod9BgColor'], defaults.mod9BgColor),
      mod9BgMediaPath: m['mod9BgMediaPath'] as String?,
      mod9ThrottleColor: _colorFromJson(m['mod9ThrottleColor'], defaults.mod9ThrottleColor),
      mod9WepColor: _colorFromJson(m['mod9WepColor'], defaults.mod9WepColor),
      mod9AvionicsColor: _colorFromJson(m['mod9AvionicsColor'], defaults.mod9AvionicsColor),
      mod9RudderColor: _colorFromJson(m['mod9RudderColor'], defaults.mod9RudderColor),
      mod9HudColor: _colorFromJson(m['mod9HudColor'], defaults.mod9HudColor),
      mod9FireBtnColor: _colorFromJson(m['mod9FireBtnColor'], defaults.mod9FireBtnColor),
      mod9WeaponBtnColor: _colorFromJson(m['mod9WeaponBtnColor'], defaults.mod9WeaponBtnColor),
      mod9HatSwitchColor: _colorFromJson(m['mod9HatSwitchColor'], defaults.mod9HatSwitchColor),
      zeroOrientation: _intFromJson(m['zeroOrientation'], defaults.zeroOrientation),
      calibPitchOffset: _doubleFromJson(m['calibPitchOffset'], defaults.calibPitchOffset),
      calibRollOffset: _doubleFromJson(m['calibRollOffset'], defaults.calibRollOffset),
      useGyroscope: _boolFromJson(m['useGyroscope'], defaults.useGyroscope),
      steeringAngle: _doubleFromJson(m['steeringAngle'], defaults.steeringAngle),
      swipeSensitivity: _doubleFromJson(m['swipeSensitivity'], defaults.swipeSensitivity),
      clickMaxDistance: _doubleFromJson(m['clickMaxDistance'], defaults.clickMaxDistance),
      clickMaxDuration: _doubleFromJson(m['clickMaxDuration'], defaults.clickMaxDuration),
      defaultDrivingMode: _intFromJson(m['defaultDrivingMode'], defaults.defaultDrivingMode),
      isCumulativeSteering: _boolFromJson(
        m['isCumulativeSteering'],
        defaults.isCumulativeSteering,
      ),
      pedalIconAccelerationRate: _doubleFromJson(
        m['pedalIconAccelerationRate'],
        defaults.pedalIconAccelerationRate,
      ),
      mod6PedalStyle: _intFromJson(m['mod6PedalStyle'], defaults.mod6PedalStyle),
      clutchIconAccelerationRate: _doubleFromJson(
        m['clutchIconAccelerationRate'],
        defaults.clutchIconAccelerationRate,
      ),
      clutchType: _intFromJson(m['clutchType'], defaults.clutchType),
      clutchKey: _intFromJson(m['clutchKey'], defaults.clutchKey),
      handbrakeType: _intFromJson(m['handbrakeType'], defaults.handbrakeType),
      handbrakeKey: _intFromJson(m['handbrakeKey'], defaults.handbrakeKey),
      isAddonMasterSwitchActive: _boolFromJson(
        m['isAddonMasterSwitchActive'],
        defaults.isAddonMasterSwitchActive,
      ),
      activeAddonIds: (m['activeAddonIds'] is List)
          ? (m['activeAddonIds'] as List).map((e) => e.toString()).toList()
          : defaults.activeAddonIds,
      dlcHapticRpm: _boolFromJson(m['dlcHapticRpm'], defaults.dlcHapticRpm),
      dlcHapticSlip: _boolFromJson(m['dlcHapticSlip'], defaults.dlcHapticSlip),
      dlcHapticGear: _boolFromJson(m['dlcHapticGear'], defaults.dlcHapticGear),
      dlcHapticCollision: _boolFromJson(m['dlcHapticCollision'], defaults.dlcHapticCollision),
      mod6EnableClutch: _boolFromJson(m['mod6EnableClutch'], defaults.mod6EnableClutch),
      mod6EnableHandbrake: _boolFromJson(m['mod6EnableHandbrake'], defaults.mod6EnableHandbrake),
      mod6SteeringStyle: _intFromJson(m['mod6SteeringStyle'], defaults.mod6SteeringStyle),
      steeringTurnRightColor: _colorFromJson(
        m['steeringTurnRightColor'],
        defaults.steeringTurnRightColor,
      ),
      steeringTurnLeftColor: _colorFromJson(
        m['steeringTurnLeftColor'],
        defaults.steeringTurnLeftColor,
      ),
      mod6HornKey: _intFromJson(m['mod6HornKey'], defaults.mod6HornKey),
      mod6SlotLeft: _intFromJson(m['mod6SlotLeft'], defaults.mod6SlotLeft),
      mod6SlotLeftInner: _intFromJson(m['mod6SlotLeftInner'], defaults.mod6SlotLeftInner),
      mod6SlotRightInner: _intFromJson(m['mod6SlotRightInner'], defaults.mod6SlotRightInner),
      mod6SlotRight: _intFromJson(m['mod6SlotRight'], defaults.mod6SlotRight),
      simulatedHapticEnabled: _boolFromJson(
        m['simulatedHapticEnabled'],
        defaults.simulatedHapticEnabled,
      ),
      globalHapticType: _intFromJson(m['globalHapticType'], defaults.globalHapticType),
      globalHapticTrigger: _intFromJson(m['globalHapticTrigger'], defaults.globalHapticTrigger),
      customButtonHapticTypes: _intIntMapFromJson(m['customButtonHapticTypes']),
      customButtonHapticTriggers: _intIntMapFromJson(m['customButtonHapticTriggers']),
      customButtonHapticEnabled: _intBoolMapFromJson(m['customButtonHapticEnabled']),
      customLayout5Json: m['customLayout5Json'] as String?,
      layout5Profiles: (m['layout5Profiles'] is Map)
          ? (m['layout5Profiles'] as Map).map(
              (k, v) => MapEntry(k.toString(), v.toString()),
            )
          : defaults.layout5Profiles,
      activeLayout5Profile: m['activeLayout5Profile'] as String?,
      joystickSensitivity: _doubleFromJson(
        m['joystickSensitivity'],
        defaults.joystickSensitivity,
      ),
      gyroCenterMode: _intFromJson(m['gyroCenterMode'], defaults.gyroCenterMode),
      gyroAutoCenterDuration: _doubleFromJson(
        m['gyroAutoCenterDuration'],
        defaults.gyroAutoCenterDuration,
      ),
      includePitchInDeadzone: _boolFromJson(
        m['includePitchInDeadzone'],
        defaults.includePitchInDeadzone,
      ),
      gyroLookEnabled: _boolFromJson(m['gyroLookEnabled'], defaults.gyroLookEnabled),
      gyroLookStyle: _intFromJson(m['gyroLookStyle'], defaults.gyroLookStyle),
      gyroLookMode: _intFromJson(m['gyroLookMode'], defaults.gyroLookMode),
      gyroLookSensitivity: _doubleFromJson(
        m['gyroLookSensitivity'],
        defaults.gyroLookSensitivity,
      ),
      gyroLookDeadzone: _doubleFromJson(m['gyroLookDeadzone'], defaults.gyroLookDeadzone),
      joystickMode: _intFromJson(m['joystickMode'], defaults.joystickMode),
      globalButtonPressMode: _intFromJson(
        m['globalButtonPressMode'],
        defaults.globalButtonPressMode,
      ),
      globalButtonPressDurationMs: _intFromJson(
        m['globalButtonPressDurationMs'],
        defaults.globalButtonPressDurationMs,
      ),
      customButtonPressModes: _intIntMapFromJson(m['customButtonPressModes']),
      customButtonPressDurationsMs: _intIntMapFromJson(m['customButtonPressDurationsMs']),
      customMacros: _macrosMapFromJson(m['customMacros']),
      volumeUpAction: _intFromJson(m['volumeUpAction'], defaults.volumeUpAction),
      volumeDownAction: _intFromJson(m['volumeDownAction'], defaults.volumeDownAction),
      m0TapLeft: _intFromJson(m['m0TapLeft'], defaults.m0TapLeft),
      m0TapRight: _intFromJson(m['m0TapRight'], defaults.m0TapRight),
      m1TapLeft: _intFromJson(m['m1TapLeft'], defaults.m1TapLeft),
      m1TapRight: _intFromJson(m['m1TapRight'], defaults.m1TapRight),
      m2Key1: _intFromJson(m['m2Key1'], defaults.m2Key1),
      m2Key2: _intFromJson(m['m2Key2'], defaults.m2Key2),
      m2Key3: _intFromJson(m['m2Key3'], defaults.m2Key3),
      m2Key4: _intFromJson(m['m2Key4'], defaults.m2Key4),
      m2TapLeft: _intFromJson(m['m2TapLeft'], defaults.m2TapLeft),
      m2TapRight: _intFromJson(m['m2TapRight'], defaults.m2TapRight),
      m3Key1: _intFromJson(m['m3Key1'], defaults.m3Key1),
      m3Key2: _intFromJson(m['m3Key2'], defaults.m3Key2),
      m3Key3: _intFromJson(m['m3Key3'], defaults.m3Key3),
      m3Key4: _intFromJson(m['m3Key4'], defaults.m3Key4),
      m3Key5: _intFromJson(m['m3Key5'], defaults.m3Key5),
      m3TapLeft: _intFromJson(m['m3TapLeft'], defaults.m3TapLeft),
      m3TapRight: _intFromJson(m['m3TapRight'], defaults.m3TapRight),
      m4Key1: _intFromJson(m['m4Key1'], defaults.m4Key1),
      m4Key2: _intFromJson(m['m4Key2'], defaults.m4Key2),
      m4Key3: _intFromJson(m['m4Key3'], defaults.m4Key3),
      m4Key4: _intFromJson(m['m4Key4'], defaults.m4Key4),
      m4KeyBottom: _intFromJson(m['m4KeyBottom'], defaults.m4KeyBottom),
      m4TapLeft: _intFromJson(m['m4TapLeft'], defaults.m4TapLeft),
      m4TapRight: _intFromJson(m['m4TapRight'], defaults.m4TapRight),
      gasSwipeUp: _intFromJson(m['gasSwipeUp'], defaults.gasSwipeUp),
      gasSwipeDown: _intFromJson(m['gasSwipeDown'], defaults.gasSwipeDown),
      gasSwipeLeft: _intFromJson(m['gasSwipeLeft'], defaults.gasSwipeLeft),
      gasSwipeRight: _intFromJson(m['gasSwipeRight'], defaults.gasSwipeRight),
      gasSwipeUpLeft: _intFromJson(m['gasSwipeUpLeft'], defaults.gasSwipeUpLeft),
      gasSwipeUpRight: _intFromJson(m['gasSwipeUpRight'], defaults.gasSwipeUpRight),
      gasSwipeDownLeft: _intFromJson(m['gasSwipeDownLeft'], defaults.gasSwipeDownLeft),
      gasSwipeDownRight: _intFromJson(m['gasSwipeDownRight'], defaults.gasSwipeDownRight),
      brakeSwipeUp: _intFromJson(m['brakeSwipeUp'], defaults.brakeSwipeUp),
      brakeSwipeDown: _intFromJson(m['brakeSwipeDown'], defaults.brakeSwipeDown),
      brakeSwipeLeft: _intFromJson(m['brakeSwipeLeft'], defaults.brakeSwipeLeft),
      brakeSwipeRight: _intFromJson(m['brakeSwipeRight'], defaults.brakeSwipeRight),
      brakeSwipeUpLeft: _intFromJson(m['brakeSwipeUpLeft'], defaults.brakeSwipeUpLeft),
      brakeSwipeUpRight: _intFromJson(m['brakeSwipeUpRight'], defaults.brakeSwipeUpRight),
      brakeSwipeDownLeft: _intFromJson(m['brakeSwipeDownLeft'], defaults.brakeSwipeDownLeft),
      brakeSwipeDownRight: _intFromJson(m['brakeSwipeDownRight'], defaults.brakeSwipeDownRight),
      gasTap: _intFromJson(m['gasTap'], defaults.gasTap),
      brakeTap: _intFromJson(m['brakeTap'], defaults.brakeTap),
      f1UseImperial: _boolFromJson(m['f1UseImperial'], defaults.f1UseImperial),
      f1LowPassAlpha: _doubleFromJson(m['f1LowPassAlpha'], defaults.f1LowPassAlpha),
      f1HapticRevLimiter: _boolFromJson(m['f1HapticRevLimiter'], defaults.f1HapticRevLimiter),
      f1HapticWheelSlip: _boolFromJson(m['f1HapticWheelSlip'], defaults.f1HapticWheelSlip),
      m7Key1: _intFromJson(m['m7Key1'], defaults.m7Key1),
      m7Key2: _intFromJson(m['m7Key2'], defaults.m7Key2),
      m7Key3: _intFromJson(m['m7Key3'], defaults.m7Key3),
      m7Key4: _intFromJson(m['m7Key4'], defaults.m7Key4),
      hudShowRpm: _boolFromJson(m['hudShowRpm'], defaults.hudShowRpm),
      hudShowSpeed: _boolFromJson(m['hudShowSpeed'], defaults.hudShowSpeed),
      hudShowGear: _boolFromJson(m['hudShowGear'], defaults.hudShowGear),
      hudShowDrsErs: _boolFromJson(m['hudShowDrsErs'], defaults.hudShowDrsErs),
      hudShowPedalBars: _boolFromJson(m['hudShowPedalBars'], defaults.hudShowPedalBars),
      hudShowTyres: _boolFromJson(m['hudShowTyres'], defaults.hudShowTyres),
      hudShowRpmBox: _boolFromJson(m['hudShowRpmBox'], defaults.hudShowRpmBox),
      hudShowStatusFlags: _boolFromJson(m['hudShowStatusFlags'], defaults.hudShowStatusFlags),
      chillOverlayEnabled: _boolFromJson(m['chillOverlayEnabled'], defaults.chillOverlayEnabled),
      chillOverlayGearButtons: _boolFromJson(
        m['chillOverlayGearButtons'],
        defaults.chillOverlayGearButtons,
      ),
      chillOverlayStyle: _intFromJson(m['chillOverlayStyle'], defaults.chillOverlayStyle),
      chillSteeringAxis: _intFromJson(m['chillSteeringAxis'], defaults.chillSteeringAxis),
      chillSteeringSensitivity: _doubleFromJson(
        m['chillSteeringSensitivity'],
        defaults.chillSteeringSensitivity,
      ),
      chillGasBrakeSensitivity: _doubleFromJson(
        m['chillGasBrakeSensitivity'],
        defaults.chillGasBrakeSensitivity,
      ),
      flightPitchSensitivity: _doubleFromJson(
        m['flightPitchSensitivity'],
        defaults.flightPitchSensitivity,
      ),
      flightRollSensitivity: _doubleFromJson(
        m['flightRollSensitivity'],
        defaults.flightRollSensitivity,
      ),
      flightYawSensitivity: _doubleFromJson(
        m['flightYawSensitivity'],
        defaults.flightYawSensitivity,
      ),
      flightPitchDeadzone: _doubleFromJson(
        m['flightPitchDeadzone'],
        defaults.flightPitchDeadzone,
      ),
      flightRollDeadzone: _doubleFromJson(m['flightRollDeadzone'], defaults.flightRollDeadzone),
      flightYawDeadzone: _doubleFromJson(m['flightYawDeadzone'], defaults.flightYawDeadzone),
      flightInvertPitch: _boolFromJson(m['flightInvertPitch'], defaults.flightInvertPitch),
      flightInvertRoll: _boolFromJson(m['flightInvertRoll'], defaults.flightInvertRoll),
      flightInvertYaw: _boolFromJson(m['flightInvertYaw'], defaults.flightInvertYaw),
      flightThrustDetents: _intFromJson(m['flightThrustDetents'], defaults.flightThrustDetents),
      m9FireKey: _intFromJson(m['m9FireKey'], defaults.m9FireKey),
      m9MissileKey: _intFromJson(m['m9MissileKey'], defaults.m9MissileKey),
      m9LockKey: _intFromJson(m['m9LockKey'], defaults.m9LockKey),
      m9FlareKey: _intFromJson(m['m9FlareKey'], defaults.m9FlareKey),
      m9HeavyGunKey: _intFromJson(m['m9HeavyGunKey'], defaults.m9HeavyGunKey),
      m9BombKey: _intFromJson(m['m9BombKey'], defaults.m9BombKey),
      m9MapKey: _intFromJson(m['m9MapKey'], defaults.m9MapKey),
      m9FlapDownKey: _intFromJson(m['m9FlapDownKey'], defaults.m9FlapDownKey),
      m9FlapUpKey: _intFromJson(m['m9FlapUpKey'], defaults.m9FlapUpKey),
      m9GearKey: _intFromJson(m['m9GearKey'], defaults.m9GearKey),
      m9AirbrakeKey: _intFromJson(m['m9AirbrakeKey'], defaults.m9AirbrakeKey),
      m9RudderLeftKey: _intFromJson(m['m9RudderLeftKey'], defaults.m9RudderLeftKey),
      m9RudderRightKey: _intFromJson(m['m9RudderRightKey'], defaults.m9RudderRightKey),
      mfdShowArtificialHorizon: _boolFromJson(
        m['mfdShowArtificialHorizon'],
        defaults.mfdShowArtificialHorizon,
      ),
      mfdShowSpeedTape: _boolFromJson(m['mfdShowSpeedTape'], defaults.mfdShowSpeedTape),
      mfdShowAltitudeTape: _boolFromJson(
        m['mfdShowAltitudeTape'],
        defaults.mfdShowAltitudeTape,
      ),
      mfdShowEngineGauges: _boolFromJson(
        m['mfdShowEngineGauges'],
        defaults.mfdShowEngineGauges,
      ),
      mfdGyroFilterAlpha: _doubleFromJson(m['mfdGyroFilterAlpha'], defaults.mfdGyroFilterAlpha),
    );
  }
}
