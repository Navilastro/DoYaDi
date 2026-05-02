import 'package:flutter/material.dart';

/// Swipe yönleri (8 yön + merkez/yok)
enum SwipeDir { none, up, down, left, right, upLeft, upRight, downLeft, downRight }

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
  Color yetsoreColor;  // %70+ geri bildirim rengi
  Color pedalBgColor;  // Pedal arka plan rengi

  // ── İvmeölçer kalibrasyonu ─────────────────────────────────────────────────
  /// 0: Auto, 1: Ekran üstte, 2: Ekran vücuda bakıyor
  int zeroOrientation;
  double calibPitchOffset;
  double calibRollOffset;

  // ── Direksiyon / Hareket ayarları ───────────────────────────────────────────
  bool useGyroscope;
  double steeringAngle;      // 75° – 1080°
  double swipeSensitivity;   // Pedal %100 için gereken mm mesafesi
  double clickMaxDistance;   // Dokunma sayılmak için maks. mm kayma
  double clickMaxDuration;   // Dokunma sayılmak için maks. süre (saniye)
  int defaultDrivingMode;    // 0–5

  // ── Mod 5 özel layout ───────────────────────────────────────────────────────
  String? customLayout5Json;

  // ── Donanım tuş ataması (1-16, 0 = devre dışı) ─────────────────────────────
  int volumeUpAction;
  int volumeDownAction;

  // ── Mod 0 tuş atamaları ─────────────────────────────────────────────────────
  // Ekranın sol yarısına tıklama / sağ yarısına tıklama
  int m0TapLeft;   // varsayılan 4
  int m0TapRight;  // varsayılan 3

  // ── Mod 1 tuş atamaları ─────────────────────────────────────────────────────
  // Sol pedal tıklama / Sağ pedal tıklama
  int m1TapLeft;   // varsayılan 4
  int m1TapRight;  // varsayılan 3

  // ── Mod 2 tuş atamaları ─────────────────────────────────────────────────────
  // 2×2 grid + pedal tıklama (mod2 = mod3 base)
  int m2Key1;      // üst-sol  → varsayılan 3
  int m2Key2;      // üst-sağ  → varsayılan 4
  int m2Key3;      // alt-sol  → varsayılan 5
  int m2Key4;      // alt-sağ  → varsayılan 6
  int m2TapLeft;   // fren pedal tıklama → varsayılan 4
  int m2TapRight;  // gaz pedal tıklama  → varsayılan 3

  // ── Mod 3 tuş atamaları ─────────────────────────────────────────────────────
  // Mod 2'nin aynısı + orta alt tuş
  int m3Key1;
  int m3Key2;
  int m3Key3;
  int m3Key4;
  int m3Key5;      // orta alt tuş → varsayılan 7
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

  AppSettings({
    this.backgroundColor        = const Color(0xFF050510),
    this.detailColor            = const Color(0xFF40E0D0),
    this.steeringIndicatorColor = const Color(0xFF40E0D0),
    this.steeringBgColor        = const Color(0xFF0A0A20),
    this.gasColor               = const Color(0xFF00C853),
    this.brakeColor             = const Color(0xFFD50000),
    this.yetsoreColor           = const Color(0xFFFFD600),
    this.pedalBgColor           = const Color(0xFF050525),
    this.zeroOrientation        = 0,
    this.calibPitchOffset       = 0.0,
    this.calibRollOffset        = 0.0,
    this.useGyroscope           = false,
    this.steeringAngle          = 180.0,
    this.swipeSensitivity       = 50.0,
    this.clickMaxDistance       = 2.0,
    this.clickMaxDuration       = 0.30,
    this.defaultDrivingMode     = 0,
    this.customLayout5Json,
    // Donanım tuşları
    this.volumeUpAction   = 2,
    this.volumeDownAction = 1,
    // Mod 0
    this.m0TapLeft  = 4,
    this.m0TapRight = 3,
    // Mod 1
    this.m1TapLeft  = 4,
    this.m1TapRight = 3,
    // Mod 2
    this.m2Key1     = 5,
    this.m2Key2     = 6,
    this.m2Key3     = 7,
    this.m2Key4     = 8,
    this.m2TapLeft  = 4,
    this.m2TapRight = 3,
    // Mod 3
    this.m3Key1     = 5,
    this.m3Key2     = 6,
    this.m3Key3     = 7,
    this.m3Key4     = 8,
    this.m3Key5     = 9,
    this.m3TapLeft  = 4,
    this.m3TapRight = 3,
    // Mod 4
    this.m4Key1      = 5,
    this.m4Key2      = 6,
    this.m4Key3      = 7,
    this.m4Key4      = 8,
    this.m4KeyBottom = 9,
    this.m4TapLeft   = 4,
    this.m4TapRight  = 3,
    // Gaz swipe atamaları (0 = devre dışı, -1 = bar doldur)
    this.gasSwipeUp        = -1,
    this.gasSwipeDown      = 0,
    this.gasSwipeLeft      = 10,
    this.gasSwipeRight     = 11,
    this.gasSwipeUpLeft    = 0,
    this.gasSwipeUpRight   = 0,
    this.gasSwipeDownLeft  = 0,
    this.gasSwipeDownRight = 0,
    // Fren swipe atamaları
    this.brakeSwipeUp      = -1,
    this.brakeSwipeDown      = 0,
    this.brakeSwipeLeft      = 12,
    this.brakeSwipeRight     = 13,
    this.brakeSwipeUpLeft    = 0,
    this.brakeSwipeUpRight   = 0,
    this.brakeSwipeDownLeft  = 0,
    this.brakeSwipeDownRight = 0,
  });
}
