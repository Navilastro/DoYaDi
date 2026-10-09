import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/app_settings.dart';
import '../core/utils/template_profiles.dart';
import '../core/utils/app_translations.dart';

class SettingsProvider with ChangeNotifier {
  AppSettings _settings = AppSettings();
  AppSettings get settings => _settings;

  Color get backgroundColor => _settings.backgroundColor;
  Color get primaryColor => _settings.detailColor;

  String _currentLanguage = 'tr';
  String get currentLanguage => _currentLanguage;

  Future<void> updateLanguage(String langCode) async {
    await AppTranslations.setLanguage(langCode);
    _currentLanguage = langCode;
    notifyListeners(); // Tüm uygulamaya 'dil değişti, kendini yenile' mesajı gönderir.
  }

  Future<void> loadSettings() async {
    final prefs = await SharedPreferences.getInstance();

    // Dili yükle ve AppTranslations'u başlat
    final savedLang = prefs.getString('languageCode') ?? 'tr';
    _currentLanguage = savedLang;
    await AppTranslations.setLanguage(savedLang);

    _settings.useGyroscope = prefs.getBool('useGyroscope') ?? false;
    _settings.zeroOrientation = prefs.getInt('zeroOrientation') ?? 0;
    _settings.calibPitchOffset = prefs.getDouble('calibPitchOffset') ?? 0.0;
    _settings.calibRollOffset = prefs.getDouble('calibRollOffset') ?? 0.0;
    _settings.steeringAngle = prefs.getDouble('steeringAngle') ?? 180.0;
    _settings.swipeSensitivity = prefs.getDouble('swipeSensitivity') ?? 50.0;
    _settings.clickMaxDistance = prefs.getDouble('clickMaxDistance') ?? 2.0;
    _settings.clickMaxDuration = prefs.getDouble('clickMaxDuration') ?? 0.30;
    _settings.defaultDrivingMode = prefs.getInt('defaultDrivingMode') ?? 0;
    _settings.isCumulativeSteering =
        prefs.getBool('isCumulativeSteering') ?? false;
    _settings.pedalIconAccelerationRate =
        (prefs.getDouble('pedalIconAccelerationRate') ?? 1.0).clamp(0.2, 3.0);
    _settings.mod6PedalStyle = prefs.getInt('mod6PedalStyle') ?? 0;
    _settings.mod6HornKey = prefs.getInt('mod6HornKey') ?? 8;
    _settings.handbrakeType = prefs.getInt('handbrakeType') ?? 0;
    _settings.simulatedHapticEnabled =
        prefs.getBool('simulatedHapticEnabled') ?? false;
    // Uygulama her açıldığında eklenti paneli varsayılan olarak kapalı konuma getirilir
    _settings.isAddonMasterSwitchActive = false;
    _settings.activeAddonIds = [];
    prefs.setBool('isAddonMasterSwitchActive', false);
    prefs.setStringList('activeAddonIds', []);
    _settings.customLayout5Json = prefs.getString('customLayout5Json');
    _settings.activeLayout5Profile = prefs.getString('activeLayout5Profile');
    _settings.joystickSensitivity =
        (prefs.getDouble('joystickSensitivity') ?? 1.0).clamp(0.5, 3.0);
    _settings.gyroCenterMode = prefs.getInt('gyroCenterMode') ?? 0;
    _settings.gyroAutoCenterDuration =
        (prefs.getDouble('gyroAutoCenterDuration') ?? 10.0).clamp(5.0, 30.0);
    _settings.includePitchInDeadzone = prefs.getBool('includePitchInDeadzone') ?? true;
    _settings.gyroLookEnabled = prefs.getBool('gyroLookEnabled') ?? false;
    _settings.gyroLookStyle = prefs.getInt('gyroLookStyle') ?? 0;
    _settings.gyroLookMode = (prefs.getInt('gyroLookMode') ?? 1).clamp(1, 3);
    _settings.gyroLookSensitivity =
        (prefs.getDouble('gyroLookSensitivity') ?? 1.0).clamp(0.2, 3.0);
    _settings.gyroLookDeadzone =
        (prefs.getDouble('gyroLookDeadzone') ?? 7.0).clamp(1.0, 30.0);
    _settings.joystickMode =
        (prefs.getInt('joystickMode') ?? 0).clamp(0, 3);
    final profilesStr = prefs.getString('layout5Profiles');
    if (profilesStr != null && profilesStr.isNotEmpty) {
      try {
        final Map<String, dynamic> decoded = jsonDecode(profilesStr);
        _settings.layout5Profiles = decoded.map(
          (key, value) => MapEntry(key, value.toString()),
        );
      } catch (_) {}
    }
    if (_settings.layout5Profiles.isEmpty &&
        !(prefs.getBool('templatesInitialized') ?? false)) {
      _settings.layout5Profiles = {
        'Oyun şablonu 1': getGameTemplate1(),
        'Oyuncu şablonu 2': getControllerTemplate2(),
        'Klavye fare dizilimi': getKeyboardMouseTemplate(),
        'Tam Gamepad': getFullControllerTemplate(),
        'Oyuncu Klavyesi': getGamerKeyboardTemplate(),
      };
      prefs.setBool('templatesInitialized', true);
    } else {
      // Mevcut profillere yeni şablonlar eksikse ekle (güncelleme uyumluluğu)
      // Ayrıca built-in şablonları her zaman en güncel halleriyle güncelle
      bool changed = false;
      final builtins = {
        'Oyun Şablonu 1': getGameTemplate1(),
        'Oyuncu şablonu 2': getControllerTemplate2(),
        'Klavye fare dizilimi': getKeyboardMouseTemplate(),
        'Tam Gamepad': getFullControllerTemplate(),
        'Oyuncu Klavyesi': getGamerKeyboardTemplate(),
      };
      for (final entry in builtins.entries) {
        if (!_settings.layout5Profiles.containsKey(entry.key)) {
          _settings.layout5Profiles[entry.key] = entry.value;
          changed = true;
        }
      }
      if (changed) {
        await prefs.setString(
          'layout5Profiles',
          jsonEncode(_settings.layout5Profiles),
        );
      }
    }
    _settings.globalButtonPressMode =
        prefs.getInt('globalButtonPressMode') ?? 0;
    _settings.globalButtonPressDurationMs =
        prefs.getInt('globalButtonPressDurationMs') ?? 2000;

    _settings.globalHapticType = prefs.getInt('globalHapticType') ?? 1;
    _settings.globalHapticTrigger = prefs.getInt('globalHapticTrigger') ?? 0;

    final customHapticTypesStr = prefs.getString('customButtonHapticTypes');
    if (customHapticTypesStr != null && customHapticTypesStr.isNotEmpty) {
      try {
        final Map<String, dynamic> decoded = jsonDecode(customHapticTypesStr);
        _settings.customButtonHapticTypes = decoded.map(
          (key, value) => MapEntry(int.parse(key), value as int),
        );
      } catch (_) {}
    }

    final customHapticTriggersStr = prefs.getString('customButtonHapticTriggers');
    if (customHapticTriggersStr != null && customHapticTriggersStr.isNotEmpty) {
      try {
        final Map<String, dynamic> decoded = jsonDecode(customHapticTriggersStr);
        _settings.customButtonHapticTriggers = decoded.map(
          (key, value) => MapEntry(int.parse(key), value as int),
        );
      } catch (_) {}
    }

    final customModesStr = prefs.getString('customButtonPressModes');
    if (customModesStr != null && customModesStr.isNotEmpty) {
      try {
        final Map<String, dynamic> decoded = jsonDecode(customModesStr);
        _settings.customButtonPressModes = decoded.map(
          (key, value) => MapEntry(int.parse(key), value as int),
        );
      } catch (_) {}
    }

    final customDurationsStr = prefs.getString('customButtonPressDurationsMs');
    if (customDurationsStr != null && customDurationsStr.isNotEmpty) {
      try {
        final Map<String, dynamic> decoded = jsonDecode(customDurationsStr);
        _settings.customButtonPressDurationsMs = decoded.map(
          (key, value) => MapEntry(int.parse(key), value as int),
        );
      } catch (_) {}
    }

    final customMacrosStr = prefs.getString('customMacros');
    if (customMacrosStr != null && customMacrosStr.isNotEmpty) {
      try {
        final Map<String, dynamic> decoded = jsonDecode(customMacrosStr);
        _settings.customMacros = decoded.map(
          (key, value) => MapEntry(int.parse(key), (value as List).cast<int>()),
        );
      } catch (_) {}
    }

    // Donanım tuş atamaları
    _settings.volumeUpAction = prefs.getInt('volumeUpAction') ?? 1;
    _settings.volumeDownAction = prefs.getInt('volumeDownAction') ?? 2;

    // Mod 0
    _settings.m0TapLeft = prefs.getInt('m0TapLeft') ?? 4;
    _settings.m0TapRight = prefs.getInt('m0TapRight') ?? 3;

    // Mod 1
    _settings.m1TapLeft = prefs.getInt('m1TapLeft') ?? 4;
    _settings.m1TapRight = prefs.getInt('m1TapRight') ?? 3;

    // Mod 2
    _settings.m2Key1 = prefs.getInt('m2Key1') ?? 5;
    _settings.m2Key2 = prefs.getInt('m2Key2') ?? 6;
    _settings.m2Key3 = prefs.getInt('m2Key3') ?? 7;
    _settings.m2Key4 = prefs.getInt('m2Key4') ?? 8;
    _settings.m2TapLeft = prefs.getInt('m2TapLeft') ?? 4;
    _settings.m2TapRight = prefs.getInt('m2TapRight') ?? 3;

    // Mod 3
    _settings.m3Key1 = prefs.getInt('m3Key1') ?? 5;
    _settings.m3Key2 = prefs.getInt('m3Key2') ?? 6;
    _settings.m3Key3 = prefs.getInt('m3Key3') ?? 14;
    _settings.m3Key4 = prefs.getInt('m3Key4') ?? 8;
    _settings.m3Key5 = prefs.getInt('m3Key5') ?? 7;
    _settings.m3TapLeft = prefs.getInt('m3TapLeft') ?? 4;
    _settings.m3TapRight = prefs.getInt('m3TapRight') ?? 3;

    // Mod 4
    _settings.m4Key1 = prefs.getInt('m4Key1') ?? 5;
    _settings.m4Key2 = prefs.getInt('m4Key2') ?? 6;
    _settings.m4Key3 = prefs.getInt('m4Key3') ?? 14;
    _settings.m4Key4 = prefs.getInt('m4Key4') ?? 8;
    _settings.m4KeyBottom = prefs.getInt('m4KeyBottom') ?? 7;
    _settings.m4TapLeft = prefs.getInt('m4TapLeft') ?? 4;
    _settings.m4TapRight = prefs.getInt('m4TapRight') ?? 3;

    // Gaz swipe atamaları
    _settings.gasSwipeUp = prefs.getInt('gasSwipeUp') ?? -1;
    _settings.gasSwipeDown = prefs.getInt('gasSwipeDown') ?? -1;
    _settings.gasSwipeLeft = prefs.getInt('gasSwipeLeft') ?? 5;
    _settings.gasSwipeRight = prefs.getInt('gasSwipeRight') ?? 16;
    _settings.gasSwipeUpLeft = prefs.getInt('gasSwipeUpLeft') ?? 0;
    _settings.gasSwipeUpRight = prefs.getInt('gasSwipeUpRight') ?? 0;
    _settings.gasSwipeDownLeft = prefs.getInt('gasSwipeDownLeft') ?? 0;
    _settings.gasSwipeDownRight = prefs.getInt('gasSwipeDownRight') ?? 0;

    // Fren swipe atamaları
    _settings.brakeSwipeUp = prefs.getInt('brakeSwipeUp') ?? -1;
    _settings.brakeSwipeDown = prefs.getInt('brakeSwipeDown') ?? -2;
    _settings.brakeSwipeLeft = prefs.getInt('brakeSwipeLeft') ?? 15;
    _settings.brakeSwipeRight = prefs.getInt('brakeSwipeRight') ?? 4;
    _settings.brakeSwipeUpLeft = prefs.getInt('brakeSwipeUpLeft') ?? 0;
    _settings.brakeSwipeUpRight = prefs.getInt('brakeSwipeUpRight') ?? 0;
    _settings.brakeSwipeDownLeft = prefs.getInt('brakeSwipeDownLeft') ?? 0;
    _settings.brakeSwipeDownRight = prefs.getInt('brakeSwipeDownRight') ?? 0;

    // Renk alanları
    _settings.backgroundColor = Color(
      prefs.getInt('backgroundColor') ?? const Color(0xFF050510).toARGB32(),
    );
    _settings.detailColor = Color(
      prefs.getInt('detailColor') ?? const Color(0xFF40E0D0).toARGB32(),
    );
    _settings.steeringIndicatorColor = Color(
      prefs.getInt('steeringIndicatorColor') ??
          const Color(0xFF40E0D0).toARGB32(),
    );
    _settings.steeringBgColor = Color(
      prefs.getInt('steeringBgColor') ?? const Color(0xFF0A0A20).toARGB32(),
    );
    _settings.gasColor = Color(
      prefs.getInt('gasColor') ?? const Color(0xFF00C853).toARGB32(),
    );
    _settings.brakeColor = Color(
      prefs.getInt('brakeColor') ?? const Color(0xFFD50000).toARGB32(),
    );
    _settings.yetsoreColor = Color(
      prefs.getInt('yetsoreColor') ?? const Color(0xFFFFD600).toARGB32(),
    );
    _settings.pedalBgColor = Color(
      prefs.getInt('pedalBgColor') ?? const Color(0xFF050525).toARGB32(),
    );

    _settings.clutchColor = Color(
      prefs.getInt('clutchColor') ?? const Color(0xFF448AFF).toARGB32(),
    );
    _settings.clutchYetsoreColor = Color(
      prefs.getInt('clutchYetsoreColor') ?? const Color(0xFFFFD600).toARGB32(),
    );
    _settings.handbrakeColor = Color(
      prefs.getInt('handbrakeColor') ?? const Color(0xFFFF5252).toARGB32(),
    );
    _settings.handbrakeYetsoreColor = Color(
      prefs.getInt('handbrakeYetsoreColor') ?? const Color(0xFFFFD600).toARGB32(),
    );
    _settings.gasIconColor = Color(
      prefs.getInt('gasIconColor') ?? const Color(0xFF69F0AE).toARGB32(),
    );
    _settings.brakeIconColor = Color(
      prefs.getInt('brakeIconColor') ?? const Color(0xFFFF5252).toARGB32(),
    );
    _settings.clutchIconColor = Color(
      prefs.getInt('clutchIconColor') ?? const Color(0xFF448AFF).toARGB32(),
    );
    _settings.clutchButtonColor = Color(
      prefs.getInt('clutchButtonColor') ?? const Color(0xFF1E1E38).toARGB32(),
    );
    _settings.handbrakeIconColor = Color(
      prefs.getInt('handbrakeIconColor') ?? const Color(0xFFFF5252).toARGB32(),
    );
    _settings.handbrakeButtonColor = Color(
      prefs.getInt('handbrakeButtonColor') ?? const Color(0xFF381E1E).toARGB32(),
    );
    _settings.steeringWheelColor = Color(
      prefs.getInt('steeringWheelColor') ?? const Color(0xFF222234).toARGB32(),
    );
    _settings.steeringTurnRightColor = Color(
      prefs.getInt('steeringTurnRightColor') ?? const Color(0xFF00E5FF).toARGB32(),
    );
    _settings.steeringTurnLeftColor = Color(
      prefs.getInt('steeringTurnLeftColor') ?? const Color(0xFFFF2A6D).toARGB32(),
    );

    // ── Mod 7 (F1 HUD) Ayarları ──
    _settings.f1UseImperial = prefs.getBool('f1UseImperial') ?? false;
    _settings.f1LowPassAlpha =
        (prefs.getDouble('f1LowPassAlpha') ?? 0.3).clamp(0.05, 1.0);
    _settings.f1HapticRevLimiter = prefs.getBool('f1HapticRevLimiter') ?? true;
    _settings.f1HapticWheelSlip = prefs.getBool('f1HapticWheelSlip') ?? true;
    _settings.m7Key1 = prefs.getInt('m7Key1') ?? 7;
    _settings.m7Key2 = prefs.getInt('m7Key2') ?? 8;
    _settings.m7Key3 = prefs.getInt('m7Key3') ?? 6;
    _settings.m7Key4 = prefs.getInt('m7Key4') ?? 5;

    // ── Mod 8 (Chill Drive) Ayarları ──
    _settings.chillOverlayEnabled = prefs.getBool('chillOverlayEnabled') ?? false;
    _settings.chillOverlayGearButtons = prefs.getBool('chillOverlayGearButtons') ?? true;
    _settings.chillSteeringAxis = prefs.getInt('chillSteeringAxis') ?? 0;
    _settings.chillSteeringSensitivity =
        (prefs.getDouble('chillSteeringSensitivity') ?? 1.0).clamp(0.2, 3.0);
    _settings.chillGasBrakeSensitivity =
        (prefs.getDouble('chillGasBrakeSensitivity') ?? 1.0).clamp(0.2, 3.0);

    // ── Mod 9 (Flight Stick) Ayarları ──
    _settings.flightPitchSensitivity =
        (prefs.getDouble('flightPitchSensitivity') ?? 1.0).clamp(0.2, 3.0);
    _settings.flightRollSensitivity =
        (prefs.getDouble('flightRollSensitivity') ?? 1.0).clamp(0.2, 3.0);
    _settings.flightYawSensitivity =
        (prefs.getDouble('flightYawSensitivity') ?? 1.0).clamp(0.2, 3.0);
    _settings.flightThrustDetents =
        (prefs.getInt('flightThrustDetents') ?? 4).clamp(2, 8);

    // ── Mod 10 (Flight MFD) Ayarları ──
    _settings.mfdShowArtificialHorizon = prefs.getBool('mfdShowArtificialHorizon') ?? true;
    _settings.mfdShowSpeedTape = prefs.getBool('mfdShowSpeedTape') ?? true;
    _settings.mfdShowAltitudeTape = prefs.getBool('mfdShowAltitudeTape') ?? true;
    _settings.mfdGyroFilterAlpha =
        (prefs.getDouble('mfdGyroFilterAlpha') ?? 0.15).clamp(0.05, 1.0);

    notifyListeners();
  }

  Future<void> saveSettings() async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setBool('useGyroscope', _settings.useGyroscope);
    await prefs.setInt('zeroOrientation', _settings.zeroOrientation);
    await prefs.setDouble('calibPitchOffset', _settings.calibPitchOffset);
    await prefs.setDouble('calibRollOffset', _settings.calibRollOffset);
    await prefs.setDouble('steeringAngle', _settings.steeringAngle);
    await prefs.setDouble('swipeSensitivity', _settings.swipeSensitivity);
    await prefs.setDouble('clickMaxDistance', _settings.clickMaxDistance);
    await prefs.setDouble('clickMaxDuration', _settings.clickMaxDuration);
    await prefs.setInt('defaultDrivingMode', _settings.defaultDrivingMode);
    await prefs.setBool(
      'isCumulativeSteering',
      _settings.isCumulativeSteering,
    );
    await prefs.setDouble(
      'pedalIconAccelerationRate',
      _settings.pedalIconAccelerationRate.clamp(0.2, 3.0),
    );
    await prefs.setInt('mod6PedalStyle', _settings.mod6PedalStyle);
    await prefs.setInt('mod6HornKey', _settings.mod6HornKey);
    await prefs.setInt('handbrakeType', _settings.handbrakeType);
    await prefs.setBool(
      'simulatedHapticEnabled',
      _settings.simulatedHapticEnabled,
    );
    await prefs.setBool('isAddonMasterSwitchActive', _settings.isAddonMasterSwitchActive);
    await prefs.setStringList('activeAddonIds', _settings.activeAddonIds);
    await prefs.setInt('globalHapticType', _settings.globalHapticType);
    await prefs.setInt('globalHapticTrigger', _settings.globalHapticTrigger);

    final hapticTypesMapStr = _settings.customButtonHapticTypes.map(
      (key, value) => MapEntry(key.toString(), value),
    );
    await prefs.setString('customButtonHapticTypes', jsonEncode(hapticTypesMapStr));

    final hapticTriggersMapStr = _settings.customButtonHapticTriggers.map(
      (key, value) => MapEntry(key.toString(), value),
    );
    await prefs.setString('customButtonHapticTriggers', jsonEncode(hapticTriggersMapStr));
    if (_settings.customLayout5Json != null) {
      await prefs.setString('customLayout5Json', _settings.customLayout5Json!);
    }
    if (_settings.activeLayout5Profile != null) {
      await prefs.setString(
        'activeLayout5Profile',

        _settings.activeLayout5Profile!,
      );
    }
    await prefs.setDouble(
      'joystickSensitivity',
      _settings.joystickSensitivity.clamp(0.5, 3.0),
    );
    await prefs.setInt('gyroCenterMode', _settings.gyroCenterMode);
    await prefs.setDouble(
      'gyroAutoCenterDuration',
      _settings.gyroAutoCenterDuration.clamp(5.0, 30.0),
    );
    await prefs.setBool('includePitchInDeadzone', _settings.includePitchInDeadzone);
    await prefs.setBool('gyroLookEnabled', _settings.gyroLookEnabled);
    await prefs.setInt('gyroLookStyle', _settings.gyroLookStyle);
    await prefs.setInt('gyroLookMode', _settings.gyroLookMode.clamp(1, 3));
    await prefs.setDouble(
      'gyroLookSensitivity',
      _settings.gyroLookSensitivity.clamp(0.2, 3.0),
    );
    await prefs.setDouble(
      'gyroLookDeadzone',
      _settings.gyroLookDeadzone.clamp(1.0, 30.0),
    );
    await prefs.setInt(
      'joystickMode',
      _settings.joystickMode.clamp(0, 3),
    );
    await prefs.setString(
      'layout5Profiles',
      jsonEncode(_settings.layout5Profiles),
    );
    await prefs.setInt(
      'globalButtonPressMode',
      _settings.globalButtonPressMode,
    );
    await prefs.setInt(
      'globalButtonPressDurationMs',
      _settings.globalButtonPressDurationMs,
    );

    final mapStr = _settings.customButtonPressModes.map(
      (key, value) => MapEntry(key.toString(), value),
    );
    await prefs.setString('customButtonPressModes', jsonEncode(mapStr));

    final durationsMapStr = _settings.customButtonPressDurationsMs.map(
      (key, value) => MapEntry(key.toString(), value),
    );
    await prefs.setString(
      'customButtonPressDurationsMs',
      jsonEncode(durationsMapStr),
    );

    final macrosMapStr = _settings.customMacros.map(
      (key, value) => MapEntry(key.toString(), value),
    );
    await prefs.setString('customMacros', jsonEncode(macrosMapStr));

    // Donanım tuş atamaları
    await prefs.setInt('volumeUpAction', _settings.volumeUpAction);
    await prefs.setInt('volumeDownAction', _settings.volumeDownAction);

    // Mod 0-4 tuş atamaları
    await prefs.setInt('m0TapLeft', _settings.m0TapLeft);
    await prefs.setInt('m0TapRight', _settings.m0TapRight);
    await prefs.setInt('m1TapLeft', _settings.m1TapLeft);
    await prefs.setInt('m1TapRight', _settings.m1TapRight);
    await prefs.setInt('m2Key1', _settings.m2Key1);
    await prefs.setInt('m2Key2', _settings.m2Key2);
    await prefs.setInt('m2Key3', _settings.m2Key3);
    await prefs.setInt('m2Key4', _settings.m2Key4);
    await prefs.setInt('m2TapLeft', _settings.m2TapLeft);
    await prefs.setInt('m2TapRight', _settings.m2TapRight);
    await prefs.setInt('m3Key1', _settings.m3Key1);
    await prefs.setInt('m3Key2', _settings.m3Key2);
    await prefs.setInt('m3Key3', _settings.m3Key3);
    await prefs.setInt('m3Key4', _settings.m3Key4);
    await prefs.setInt('m3Key5', _settings.m3Key5);
    await prefs.setInt('m3TapLeft', _settings.m3TapLeft);
    await prefs.setInt('m3TapRight', _settings.m3TapRight);
    await prefs.setInt('m4Key1', _settings.m4Key1);
    await prefs.setInt('m4Key2', _settings.m4Key2);
    await prefs.setInt('m4Key3', _settings.m4Key3);
    await prefs.setInt('m4Key4', _settings.m4Key4);
    await prefs.setInt('m4KeyBottom', _settings.m4KeyBottom);
    await prefs.setInt('m4TapLeft', _settings.m4TapLeft);
    await prefs.setInt('m4TapRight', _settings.m4TapRight);

    // Gaz swipe atamaları
    await prefs.setInt('gasSwipeUp', _settings.gasSwipeUp);
    await prefs.setInt('gasSwipeDown', _settings.gasSwipeDown);
    await prefs.setInt('gasSwipeLeft', _settings.gasSwipeLeft);
    await prefs.setInt('gasSwipeRight', _settings.gasSwipeRight);
    await prefs.setInt('gasSwipeUpLeft', _settings.gasSwipeUpLeft);
    await prefs.setInt('gasSwipeUpRight', _settings.gasSwipeUpRight);
    await prefs.setInt('gasSwipeDownLeft', _settings.gasSwipeDownLeft);
    await prefs.setInt('gasSwipeDownRight', _settings.gasSwipeDownRight);

    // Fren swipe atamaları
    await prefs.setInt('brakeSwipeUp', _settings.brakeSwipeUp);
    await prefs.setInt('brakeSwipeDown', _settings.brakeSwipeDown);
    await prefs.setInt('brakeSwipeLeft', _settings.brakeSwipeLeft);
    await prefs.setInt('brakeSwipeRight', _settings.brakeSwipeRight);
    await prefs.setInt('brakeSwipeUpLeft', _settings.brakeSwipeUpLeft);
    await prefs.setInt('brakeSwipeUpRight', _settings.brakeSwipeUpRight);
    await prefs.setInt('brakeSwipeDownLeft', _settings.brakeSwipeDownLeft);
    await prefs.setInt('brakeSwipeDownRight', _settings.brakeSwipeDownRight);

    // Renk alanları
    await prefs.setInt('backgroundColor', _settings.backgroundColor.toARGB32());

    // ── Mod 7 (F1 HUD) Ayarları ──
    await prefs.setBool('f1UseImperial', _settings.f1UseImperial);
    await prefs.setDouble('f1LowPassAlpha', _settings.f1LowPassAlpha.clamp(0.05, 1.0));
    await prefs.setBool('f1HapticRevLimiter', _settings.f1HapticRevLimiter);
    await prefs.setBool('f1HapticWheelSlip', _settings.f1HapticWheelSlip);
    await prefs.setInt('m7Key1', _settings.m7Key1);
    await prefs.setInt('m7Key2', _settings.m7Key2);
    await prefs.setInt('m7Key3', _settings.m7Key3);
    await prefs.setInt('m7Key4', _settings.m7Key4);

    // ── Mod 8 (Chill Drive) Ayarları ──
    await prefs.setBool('chillOverlayEnabled', _settings.chillOverlayEnabled);
    await prefs.setBool('chillOverlayGearButtons', _settings.chillOverlayGearButtons);
    await prefs.setInt('chillSteeringAxis', _settings.chillSteeringAxis);
    await prefs.setDouble('chillSteeringSensitivity', _settings.chillSteeringSensitivity.clamp(0.2, 3.0));
    await prefs.setDouble('chillGasBrakeSensitivity', _settings.chillGasBrakeSensitivity.clamp(0.2, 3.0));

    // ── Mod 9 (Flight Stick) Ayarları ──
    await prefs.setDouble('flightPitchSensitivity', _settings.flightPitchSensitivity.clamp(0.2, 3.0));
    await prefs.setDouble('flightRollSensitivity', _settings.flightRollSensitivity.clamp(0.2, 3.0));
    await prefs.setDouble('flightYawSensitivity', _settings.flightYawSensitivity.clamp(0.2, 3.0));
    await prefs.setInt('flightThrustDetents', _settings.flightThrustDetents.clamp(2, 8));

    // ── Mod 10 (Flight MFD) Ayarları ──
    await prefs.setBool('mfdShowArtificialHorizon', _settings.mfdShowArtificialHorizon);
    await prefs.setBool('mfdShowSpeedTape', _settings.mfdShowSpeedTape);
    await prefs.setBool('mfdShowAltitudeTape', _settings.mfdShowAltitudeTape);
    await prefs.setDouble('mfdGyroFilterAlpha', _settings.mfdGyroFilterAlpha.clamp(0.05, 1.0));
    await prefs.setInt('detailColor', _settings.detailColor.toARGB32());
    await prefs.setInt(
      'steeringIndicatorColor',
      _settings.steeringIndicatorColor.toARGB32(),
    );
    await prefs.setInt('steeringBgColor', _settings.steeringBgColor.toARGB32());
    await prefs.setInt('gasColor', _settings.gasColor.toARGB32());
    await prefs.setInt('brakeColor', _settings.brakeColor.toARGB32());
    await prefs.setInt('yetsoreColor', _settings.yetsoreColor.toARGB32());
    await prefs.setInt('pedalBgColor', _settings.pedalBgColor.toARGB32());
    await prefs.setInt('clutchColor', _settings.clutchColor.toARGB32());
    await prefs.setInt('clutchYetsoreColor', _settings.clutchYetsoreColor.toARGB32());
    await prefs.setInt('handbrakeColor', _settings.handbrakeColor.toARGB32());
    await prefs.setInt('handbrakeYetsoreColor', _settings.handbrakeYetsoreColor.toARGB32());
    await prefs.setInt('gasIconColor', _settings.gasIconColor.toARGB32());
    await prefs.setInt('brakeIconColor', _settings.brakeIconColor.toARGB32());
    await prefs.setInt('clutchIconColor', _settings.clutchIconColor.toARGB32());
    await prefs.setInt('clutchButtonColor', _settings.clutchButtonColor.toARGB32());
    await prefs.setInt('handbrakeIconColor', _settings.handbrakeIconColor.toARGB32());
    await prefs.setInt('handbrakeButtonColor', _settings.handbrakeButtonColor.toARGB32());
    await prefs.setInt('steeringWheelColor', _settings.steeringWheelColor.toARGB32());
    await prefs.setInt('steeringTurnRightColor', _settings.steeringTurnRightColor.toARGB32());
    await prefs.setInt('steeringTurnLeftColor', _settings.steeringTurnLeftColor.toARGB32());

    notifyListeners();
  }

  void updateSettings(AppSettings newSettings) {
    _settings = newSettings;
    saveSettings();
  }

  void saveCustomLayout5(String json) {
    _settings.customLayout5Json = json;
    saveSettings();
  }
}
