import 'dart:math' as math;
import 'package:flutter/services.dart';
import 'package:vibration/vibration.dart';
import '../models/app_settings.dart';
import 'network/addon_network_service.dart';

/// Haptik geri bildirim yönetimi.
///
/// İki kaynak:
/// 1. Simüle edilmiş haptic — ekrana dokunulduğunda (bar/ikon değişimi)
/// 2. DLC telemetri haptic — sunucudan gelen RPM/Vites verisiyle tetiklenen
///
/// DLC haptic eklentisi aktifse simüle edilmiş haptic otomatik devre dışı kalır.
class HapticManager {
  static final HapticManager _instance = HapticManager._internal();
  factory HapticManager() => _instance;
  HapticManager._internal();

  /// DLC tarafından yönetilen haptic eklentisi aktif mi
  bool _dlcHapticActive = false;

  /// Son işlenen telemetri zamanı (flood engeli)
  DateTime _lastTelemetryTrigger = DateTime(2000);

  bool? _hasVibrator;

  Future<bool> _checkVibrator() async {
    _hasVibrator ??= await Vibration.hasVibrator();
    return _hasVibrator ?? false;
  }

  /// Mobil cihazlarda haptik/titreşim özelliğini sına ve aktifleştir
  Future<bool> checkAndRequestHapticPermission() async {
    try {
      final hasVib = await _checkVibrator();
      if (hasVib) {
        Vibration.vibrate(duration: 40);
      } else {
        await HapticFeedback.selectionClick();
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Güvenli fiziki motor titreşimi (Android Dokunma Titreşimi ayarı kapalı olsa dahi çalışır)
  void _vibrateCustom({
    required int duration,
    int amplitude = -1,
    required VoidCallback fallbackHaptic,
  }) async {
    try {
      final hasVib = await _checkVibrator();
      if (hasVib) {
        if (amplitude > 0) {
          Vibration.vibrate(duration: duration, amplitude: amplitude);
        } else {
          Vibration.vibrate(duration: duration);
        }
      } else {
        fallbackHaptic();
      }
    } catch (_) {
      fallbackHaptic();
    }
  }

  // ── DLC Haptic Durum Yönetimi ──────────────────────────────────────────────

  /// DLC haptic eklentisinin durumunu güncelle
  void setDlcHapticActive(bool active) {
    _dlcHapticActive = active;
  }

  /// DLC haptic eklentisi aktif mi (dışarıdan sorgulama)
  bool get isDlcHapticActive => _dlcHapticActive;

  // ── Simüle Edilmiş Haptic ──────────────────────────────────────────────────

  /// Simüle edilmiş haptic tetiklenebilir mi kontrolü
  bool _canTrigger(AppSettings settings) {
    if (_dlcHapticActive) return false;
    if (!settings.simulatedHapticEnabled) return false;
    return true;
  }

  /// Hafif titreşim (bar/ikon değer değişimi sırasında)
  void triggerLight(AppSettings settings) {
    if (!_canTrigger(settings)) return;
    _vibrateCustom(
      duration: 20,
      amplitude: 60,
      fallbackHaptic: HapticFeedback.lightImpact,
    );
  }

  /// Orta titreşim (buton basımı vb.)
  void triggerMedium(AppSettings settings) {
    if (!_canTrigger(settings)) return;
    _vibrateCustom(
      duration: 45,
      amplitude: 140,
      fallbackHaptic: HapticFeedback.mediumImpact,
    );
  }

  /// Ağır titreşim (%100 pedalda vb.)
  void triggerHeavy(AppSettings settings) {
    if (!_canTrigger(settings)) return;
    _vibrateCustom(
      duration: 90,
      amplitude: 255,
      fallbackHaptic: HapticFeedback.heavyImpact,
    );
  }

  /// Seçim titreşimi (switch toggle vb.)
  void triggerSelection(AppSettings settings) {
    if (!_canTrigger(settings)) return;
    _vibrateCustom(
      duration: 15,
      amplitude: 80,
      fallbackHaptic: HapticFeedback.selectionClick,
    );
  }

  /// Belirtilen türe göre titreşim tetikler (0: Light, 1: Medium, 2: Heavy, 3: Selection, 4: Vibrate)
  void triggerHapticType(
    AppSettings settings,
    int typeIndex, {
    bool force = false,
  }) {
    if (_dlcHapticActive) return;
    if (!force && !settings.simulatedHapticEnabled) return;
    switch (typeIndex) {
      case 0:
        triggerLight(settings);
        break;
      case 1:
        triggerMedium(settings);
        break;
      case 2:
        triggerHeavy(settings);
        break;
      case 3:
        triggerSelection(settings);
        break;
      case 4:
        _vibrateCustom(
          duration: 180,
          amplitude: 220,
          fallbackHaptic: HapticFeedback.vibrate,
        );
        break;
      default:
        triggerMedium(settings);
        break;
    }
  }

  /// Öğe bazlı haptic kontrolü (Layout5Item ile)
  void triggerForItem(
    AppSettings settings,
    bool itemHapticEnabled, {
    int? customType,
    int? customTrigger,
  }) {
    if (!itemHapticEnabled) return;
    final type = customType ?? settings.globalHapticType;
    triggerHapticType(settings, type);
  }

  DateTime _lastSlipTrigger = DateTime(2000);

  // ── DLC Telemetri Bazlı Haptic ─────────────────────────────────────────────

  /// Telemetri verisini işleyerek bildirim odaklı haptik/titreşim tetikler.
  /// - Motor RPM titreşimi KAPALI (motor titreşimi verilmez)
  /// - Vites geçiş darbeleri (Gear Impact)
  /// - Tekerlek kayması, kilitlenmesi ve sert fren (Wheel Slip)
  void processTelemetry(TelemetryData data) {
    if (!_dlcHapticActive) return;

    final now = DateTime.now();

    // 0. Çarpışma / Kaza Titreşimi (Kritik Olay — G-Kuvveti Sıçraması & Hasar)
    if (data.reserved1 > 0) {
      if (now.difference(_lastTelemetryTrigger).inMilliseconds < 150) return;
      _lastTelemetryTrigger = now;

      if (data.reserved1 >= 200) {
        // Şiddetli Kaza
        _vibrateCustom(
          duration: 200,
          amplitude: 255,
          fallbackHaptic: HapticFeedback.heavyImpact,
        );
      } else {
        // Orta Darbe
        _vibrateCustom(
          duration: 110,
          amplitude: 200,
          fallbackHaptic: HapticFeedback.heavyImpact,
        );
      }
      return;
    }

    // 1. Vites Darbesi (Anlık Vites Değişimi Olayı)
    if (data.gearImpact > 0) {
      if (now.difference(_lastTelemetryTrigger).inMilliseconds < 100) return;
      _lastTelemetryTrigger = now;
      _vibrateCustom(
        duration: 50,
        amplitude: 200,
        fallbackHaptic: HapticFeedback.mediumImpact,
      );
      return;
    }

    // 2. Çevresel Etkenler & Sert Fren: Tekerlek Kayması (Wheel Slip)
    // LeftSlip / RightSlip 0-255 arası gelir. 90 üzeri kayma / fren kilitlenmesidir.
    final maxSlip = math.max(data.leftSlip, data.rightSlip);

    if (maxSlip >= 90) {
      if (now.difference(_lastSlipTrigger).inMilliseconds < 120) return;
      _lastSlipTrigger = now;

      if (maxSlip >= 180) {
        // Aşırı sert fren / ağır kayma (kilitlenme)
        _vibrateCustom(
          duration: 70,
          amplitude: 255,
          fallbackHaptic: HapticFeedback.heavyImpact,
        );
      } else if (maxSlip >= 130) {
        // Orta derece kayma / sert fren
        _vibrateCustom(
          duration: 45,
          amplitude: 160,
          fallbackHaptic: HapticFeedback.mediumImpact,
        );
      } else {
        // Hafif kayma
        _vibrateCustom(
          duration: 25,
          amplitude: 90,
          fallbackHaptic: HapticFeedback.lightImpact,
        );
      }
    }
  }
}
