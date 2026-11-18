import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/app_config.dart';
import '../models/app_settings.dart';
import '../models/settings_snapshot.dart';
import '../core/utils/template_profiles.dart';
import '../core/utils/app_translations.dart';
import '../core/haptic_manager.dart';
import 'monetization_provider.dart';

class SettingsProvider with ChangeNotifier {
  static const int maxFreeSnapshots = 3;
  static const String _snapshotsPrefKey = 'saved_settings_snapshots_v1';
  static const String _activeSnapshotPrefKey = 'active_settings_snapshot_id_v1';

  AppSettings _settings = AppSettings();
  AppSettings get settings => _settings;

  List<SettingsSnapshot> _snapshots = [];
  List<SettingsSnapshot> get snapshots => List.unmodifiable(_snapshots);

  String? _activeSnapshotId;
  String? get activeSnapshotId => _activeSnapshotId;

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

    _settings.customDriverName = prefs.getString('customDriverName') ?? '';
    _settings.useGyroscope = prefs.getBool('useGyroscope') ?? false;
    _settings.zeroOrientation = prefs.getInt('zeroOrientation') ?? 0;
    _settings.calibPitchOffset = prefs.getDouble('calibPitchOffset') ?? 0.0;
    _settings.calibRollOffset = prefs.getDouble('calibRollOffset') ?? 0.0;
    _settings.steeringAngle = prefs.getDouble('steeringAngle') ?? 180.0;
    _settings.swipeSensitivity = prefs.getDouble('swipeSensitivity') ?? 50.0;
    _settings.clickMaxDistance = prefs.getDouble('clickMaxDistance') ?? 2.0;
    _settings.clickMaxDuration = prefs.getDouble('clickMaxDuration') ?? 0.30;
    _settings.defaultDrivingMode = AppConfig.instance.sanitizeMode(
      prefs.getInt('defaultDrivingMode') ??
          AppConfig.instance.allowedModes.first,
    );
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
    _settings.dlcHapticRpm = prefs.getBool('dlcHapticRpm') ?? false;
    _settings.dlcHapticSlip = prefs.getBool('dlcHapticSlip') ?? true;
    _settings.dlcHapticGear = prefs.getBool('dlcHapticGear') ?? true;
    _settings.dlcHapticCollision = prefs.getBool('dlcHapticCollision') ?? true;
    _settings.customLayout5Json = prefs.getString('customLayout5Json');
    _settings.activeLayout5Profile = prefs.getString('activeLayout5Profile');
    _settings.joystickSensitivity =
        (prefs.getDouble('joystickSensitivity') ?? 1.0).clamp(0.5, 3.0);
    _settings.gyroCenterMode = prefs.getInt('gyroCenterMode') ?? 0;
    _settings.gyroAutoCenterDuration =
        (prefs.getDouble('gyroAutoCenterDuration') ?? 10.0).clamp(5.0, 30.0);
    _settings.includePitchInDeadzone =
        prefs.getBool('includePitchInDeadzone') ?? true;
    _settings.gyroLookEnabled = prefs.getBool('gyroLookEnabled') ?? false;
    _settings.gyroLookStyle = prefs.getInt('gyroLookStyle') ?? 0;
    _settings.gyroLookMode = (prefs.getInt('gyroLookMode') ?? 1).clamp(1, 3);
    _settings.gyroLookSensitivity =
        (prefs.getDouble('gyroLookSensitivity') ?? 1.0).clamp(0.2, 3.0);
    _settings.gyroLookDeadzone = (prefs.getDouble('gyroLookDeadzone') ?? 7.0)
        .clamp(1.0, 30.0);
    _settings.joystickMode = (prefs.getInt('joystickMode') ?? 0).clamp(0, 3);
    final profilesStr = prefs.getString('layout5Profiles');
    if (profilesStr != null && profilesStr.isNotEmpty) {
      try {
        final Map<String, dynamic> decoded = jsonDecode(profilesStr);
        _settings.layout5Profiles = decoded.map(
          (key, value) => MapEntry(key, value.toString()),
        );
      } catch (_) {}
    }
    // Varsayılan Mod 5 profilleri boş olmalı; eski sürümden otomatik eklenen şablon profillerini tek seferlik temizle.
    if (!(prefs.getBool('migrated_clear_default_layout5_profiles_v1') ??
        false)) {
      const autoSeededNames = <String>{
        'Oyun şablonu 1',
        'Oyun Şablonu 1',
        'Oyuncu şablonu 2',
        'Klavye fare dizilimi',
        'Tam Gamepad',
        'Oyuncu Klavyesi',
      };
      bool cleared = false;
      for (final name in autoSeededNames) {
        if (_settings.layout5Profiles.remove(name) != null) {
          cleared = true;
        }
      }
      if (_settings.activeLayout5Profile != null &&
          autoSeededNames.contains(_settings.activeLayout5Profile)) {
        _settings.activeLayout5Profile = null;
        await prefs.remove('activeLayout5Profile');
      }
      if (cleared) {
        await prefs.setString(
          'layout5Profiles',
          jsonEncode(_settings.layout5Profiles),
        );
      }
      await prefs.setBool('migrated_clear_default_layout5_profiles_v1', true);
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

    final customHapticTriggersStr = prefs.getString(
      'customButtonHapticTriggers',
    );
    if (customHapticTriggersStr != null && customHapticTriggersStr.isNotEmpty) {
      try {
        final Map<String, dynamic> decoded = jsonDecode(
          customHapticTriggersStr,
        );
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
    _settings.brakeSwipeUp = prefs.getInt('brakeSwipeUp') ?? -2;
    if (!(prefs.getBool('migrated_brake_swipe_up_v2') ?? false)) {
      if (_settings.brakeSwipeUp == -1) {
        _settings.brakeSwipeUp = -2;
        await prefs.setInt('brakeSwipeUp', -2);
      }
      await prefs.setBool('migrated_brake_swipe_up_v2', true);
    }
    _settings.brakeSwipeDown = prefs.getInt('brakeSwipeDown') ?? -2;
    _settings.brakeSwipeLeft = prefs.getInt('brakeSwipeLeft') ?? 15;
    _settings.brakeSwipeRight = prefs.getInt('brakeSwipeRight') ?? 4;
    _settings.brakeSwipeUpLeft = prefs.getInt('brakeSwipeUpLeft') ?? 0;
    _settings.brakeSwipeUpRight = prefs.getInt('brakeSwipeUpRight') ?? 0;
    _settings.brakeSwipeDownLeft = prefs.getInt('brakeSwipeDownLeft') ?? 0;
    _settings.brakeSwipeDownRight = prefs.getInt('brakeSwipeDownRight') ?? 0;

    // Renk alanları & Font
    _settings.appFontFamily = prefs.getString('appFontFamily') ?? 'Roboto';
    _settings.backgroundColor = Color(
      prefs.getInt('backgroundColor') ?? const Color(0xFF050510).toARGB32(),
    );
    _settings.detailColor = Color(
      prefs.getInt('detailColor') ?? const Color(0xFF40E0D0).toARGB32(),
    );
    _settings.secondaryColor = Color(
      prefs.getInt('secondaryColor') ?? const Color(0xFF7C4DFF).toARGB32(),
    );
    _settings.tertiaryColor = Color(
      prefs.getInt('tertiaryColor') ?? const Color(0xFFFF6D00).toARGB32(),
    );
    _settings.warningColor = Color(
      prefs.getInt('warningColor') ?? const Color(0xFFFF5252).toARGB32(),
    );
    _settings.surfaceColor = Color(
      prefs.getInt('surfaceColor') ?? const Color(0xFF0A0A20).toARGB32(),
    );
    _settings.preventIncompatibleColors =
        prefs.getBool('preventIncompatibleColors') ?? false;
    _settings.homeStartBtnColor = Color(
      prefs.getInt('homeStartBtnColor') ?? const Color(0xFF40E0D0).toARGB32(),
    );

    // Medya arka planları & Mod 0-4
    _settings.bgMediaPath = prefs.getString('bgMediaPath');
    _settings.homeStartBtnMediaPath = prefs.getString('homeStartBtnMediaPath');
    _settings.generalButtonMediaPath = prefs.getString(
      'generalButtonMediaPath',
    );
    _settings.gasBarMediaPath = prefs.getString('gasBarMediaPath');
    _settings.brakeBarMediaPath = prefs.getString('brakeBarMediaPath');
    _settings.pedalBarBgMediaPath = prefs.getString('pedalBarBgMediaPath');
    _settings.separatePedalBg = prefs.getBool('separatePedalBg') ?? false;
    _settings.leftPedalBgColor = Color(
      prefs.getInt('leftPedalBgColor') ?? const Color(0xFF050525).toARGB32(),
    );
    _settings.rightPedalBgColor = Color(
      prefs.getInt('rightPedalBgColor') ?? const Color(0xFF050525).toARGB32(),
    );
    _settings.leftPedalBgMediaPath = prefs.getString('leftPedalBgMediaPath');
    _settings.rightPedalBgMediaPath = prefs.getString('rightPedalBgMediaPath');
    _settings.yetsoreMediaPath = prefs.getString('yetsoreMediaPath');
    _settings.steeringBarMediaPath = prefs.getString('steeringBarMediaPath');
    _settings.mode234ButtonColor = Color(
      prefs.getInt('mode234ButtonColor') ?? const Color(0xFF40E0D0).toARGB32(),
    );
    _settings.mode234ButtonMediaPath = prefs.getString(
      'mode234ButtonMediaPath',
    );
    _settings.mod01BgColor = Color(
      prefs.getInt('mod01BgColor') ?? const Color(0xFF050510).toARGB32(),
    );
    _settings.mod01BgMediaPath = prefs.getString('mod01BgMediaPath');
    _settings.mod234BgColor = Color(
      prefs.getInt('mod234BgColor') ?? const Color(0xFF050510).toARGB32(),
    );
    _settings.mod234BgMediaPath = prefs.getString('mod234BgMediaPath');
    _settings.mod5BgColor = Color(
      prefs.getInt('mod5BgColor') ?? const Color(0xFF08080F).toARGB32(),
    );
    _settings.mod5BgMediaPath = prefs.getString('mod5BgMediaPath');
    _settings.mod5JoystickMediaPath = prefs.getString('mod5JoystickMediaPath');
    _settings.mod5JoystickBaseMediaPath = prefs.getString(
      'mod5JoystickBaseMediaPath',
    );
    _settings.mod5ButtonMediaPath = prefs.getString('mod5ButtonMediaPath');
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
      prefs.getInt('handbrakeYetsoreColor') ??
          const Color(0xFFFFD600).toARGB32(),
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
      prefs.getInt('handbrakeButtonColor') ??
          const Color(0xFF381E1E).toARGB32(),
    );
    _settings.steeringWheelColor = Color(
      prefs.getInt('steeringWheelColor') ?? const Color(0xFF222234).toARGB32(),
    );
    _settings.steeringTurnRightColor = Color(
      prefs.getInt('steeringTurnRightColor') ??
          const Color(0xFF00E5FF).toARGB32(),
    );
    _settings.steeringTurnLeftColor = Color(
      prefs.getInt('steeringTurnLeftColor') ??
          const Color(0xFFFF2A6D).toARGB32(),
    );
    _settings.mod6BgColor = Color(
      prefs.getInt('mod6BgColor') ?? const Color(0xFF0A0A12).toARGB32(),
    );
    _settings.mod6BgMediaPath = prefs.getString('mod6BgMediaPath');
    _settings.mod6HornColor = Color(
      prefs.getInt('mod6HornColor') ?? const Color(0xFF40E0D0).toARGB32(),
    );
    _settings.mod6HornMediaPath = prefs.getString('mod6HornMediaPath');
    _settings.mod6ButtonsMediaPath = prefs.getString('mod6ButtonsMediaPath');
    _settings.mod6AccelIconsMediaPath = prefs.getString(
      'mod6AccelIconsMediaPath',
    );
    _settings.clutchBarMediaPath = prefs.getString('clutchBarMediaPath');
    _settings.handbrakeBarMediaPath = prefs.getString('handbrakeBarMediaPath');

    // Mod 7 Özelleştirme
    _settings.mod7BgColor = Color(
      prefs.getInt('mod7BgColor') ?? const Color(0xFF050508).toARGB32(),
    );
    _settings.mod7BgMediaPath = prefs.getString('mod7BgMediaPath');
    _settings.mod7TyreColdColor = Color(
      prefs.getInt('mod7TyreColdColor') ?? const Color(0xFF1565C0).toARGB32(),
    );
    _settings.mod7TyreOptColor = Color(
      prefs.getInt('mod7TyreOptColor') ?? const Color(0xFF2E7D32).toARGB32(),
    );
    _settings.mod7TyreHotColor = Color(
      prefs.getInt('mod7TyreHotColor') ?? const Color(0xFFE65100).toARGB32(),
    );
    _settings.mod7TyreCritColor = Color(
      prefs.getInt('mod7TyreCritColor') ?? const Color(0xFFC62828).toARGB32(),
    );
    _settings.mod7RpmLowColor = Color(
      prefs.getInt('mod7RpmLowColor') ?? const Color(0xFF00E676).toARGB32(),
    );
    _settings.mod7RpmMidColor = Color(
      prefs.getInt('mod7RpmMidColor') ?? const Color(0xFFFFEA00).toARGB32(),
    );
    _settings.mod7RpmHighColor = Color(
      prefs.getInt('mod7RpmHighColor') ?? const Color(0xFFFF1744).toARGB32(),
    );
    int rpmLimColorInt =
        prefs.getInt('mod7RpmLimColor') ?? const Color(0xFFFF0000).toARGB32();
    if (!(prefs.getBool('migrated_mod7_rpm_lim_red_v1') ?? false)) {
      if (rpmLimColorInt == const Color(0xFFD500F9).toARGB32()) {
        rpmLimColorInt = const Color(0xFFFF0000).toARGB32();
        await prefs.setInt('mod7RpmLimColor', rpmLimColorInt);
      }
      await prefs.setBool('migrated_mod7_rpm_lim_red_v1', true);
    }
    _settings.mod7RpmLimColor = Color(rpmLimColorInt);
    _settings.mod7GearColor = Color(
      prefs.getInt('mod7GearColor') ?? const Color(0xFFFFFFFF).toARGB32(),
    );
    _settings.mod7SpeedColor = Color(
      prefs.getInt('mod7SpeedColor') ?? const Color(0xFFFFFFFF).toARGB32(),
    );
    _settings.mod7DrsActiveColor = Color(
      prefs.getInt('mod7DrsActiveColor') ?? const Color(0xFF00E676).toARGB32(),
    );
    _settings.mod7ErsColor = Color(
      prefs.getInt('mod7ErsColor') ?? const Color(0xFFFFD600).toARGB32(),
    );
    _settings.mod7RpmBoxColor = Color(
      prefs.getInt('mod7RpmBoxColor') ?? const Color(0xFFFF1744).toARGB32(),
    );
    _settings.mod7ButtonsColor = Color(
      prefs.getInt('mod7ButtonsColor') ?? const Color(0xFF40E0D0).toARGB32(),
    );

    // Mod 8 Özelleştirme (Sayfa İçi & Sayfa Dışı Ayrı Ayrı)
    _settings.mod8BgColor = Color(
      prefs.getInt('mod8BgColor') ?? const Color(0xFF0A0E14).toARGB32(),
    );
    _settings.mod8BgMediaPath = prefs.getString('mod8BgMediaPath');
    _settings.mod8SteerColor = Color(
      prefs.getInt('mod8SteerColor') ?? const Color(0xFF00E5FF).toARGB32(),
    );
    _settings.mod8GasColor = Color(
      prefs.getInt('mod8GasColor') ?? const Color(0xFF4CAF50).toARGB32(),
    );
    _settings.mod8BrakeColor = Color(
      prefs.getInt('mod8BrakeColor') ?? const Color(0xFFEF5350).toARGB32(),
    );
    _settings.mod8RadarColor = Color(
      prefs.getInt('mod8RadarColor') ?? const Color(0xFF00E5FF).toARGB32(),
    );
    _settings.mod8CruiseColor = Color(
      prefs.getInt('mod8CruiseColor') ?? const Color(0xFF00E676).toARGB32(),
    );
    _settings.mod8HoldButtonsColor = Color(
      prefs.getInt('mod8HoldButtonsColor') ??
          const Color(0xFFFFB300).toARGB32(),
    );
    _settings.mod8GearBtnColor = Color(
      prefs.getInt('mod8GearBtnColor') ?? const Color(0xFF00E5FF).toARGB32(),
    );
    _settings.mod8OverlayBgColor = Color(
      prefs.getInt('mod8OverlayBgColor') ?? const Color(0xE610141E).toARGB32(),
    );
    _settings.mod8OverlayBorderColor = Color(
      prefs.getInt('mod8OverlayBorderColor') ??
          const Color(0x6600E5FF).toARGB32(),
    );
    _settings.mod8OverlaySteerColor = Color(
      prefs.getInt('mod8OverlaySteerColor') ??
          const Color(0xFF00E5FF).toARGB32(),
    );
    _settings.mod8OverlayGasColor = Color(
      prefs.getInt('mod8OverlayGasColor') ?? const Color(0xFF81C784).toARGB32(),
    );
    _settings.mod8OverlayBrakeColor = Color(
      prefs.getInt('mod8OverlayBrakeColor') ??
          const Color(0xFFE57373).toARGB32(),
    );
    _settings.mod8OverlayGearBtnColor = Color(
      prefs.getInt('mod8OverlayGearBtnColor') ??
          const Color(0xFF00E5FF).toARGB32(),
    );

    // Mod 9 Özelleştirme
    _settings.mod9BgColor = Color(
      prefs.getInt('mod9BgColor') ?? const Color(0xFF080C0A).toARGB32(),
    );
    _settings.mod9BgMediaPath = prefs.getString('mod9BgMediaPath');
    _settings.mod9ThrottleColor = Color(
      prefs.getInt('mod9ThrottleColor') ?? const Color(0xFF00E676).toARGB32(),
    );
    _settings.mod9WepColor = Color(
      prefs.getInt('mod9WepColor') ?? const Color(0xFFFF1744).toARGB32(),
    );
    _settings.mod9AvionicsColor = Color(
      prefs.getInt('mod9AvionicsColor') ?? const Color(0xFF00E676).toARGB32(),
    );
    _settings.mod9RudderColor = Color(
      prefs.getInt('mod9RudderColor') ?? const Color(0xFF00E676).toARGB32(),
    );
    _settings.mod9HudColor = Color(
      prefs.getInt('mod9HudColor') ?? const Color(0xFF00E676).toARGB32(),
    );
    _settings.mod9FireBtnColor = Color(
      prefs.getInt('mod9FireBtnColor') ?? const Color(0xFFD50000).toARGB32(),
    );
    _settings.mod9WeaponBtnColor = Color(
      prefs.getInt('mod9WeaponBtnColor') ?? const Color(0xFFFF5252).toARGB32(),
    );
    _settings.mod9HatSwitchColor = Color(
      prefs.getInt('mod9HatSwitchColor') ?? const Color(0xFF00E676).toARGB32(),
    );

    // ── Mod 7 (F1 HUD) Ayarları ──
    _settings.f1UseImperial = prefs.getBool('f1UseImperial') ?? false;
    _settings.f1LowPassAlpha = (prefs.getDouble('f1LowPassAlpha') ?? 0.3).clamp(
      0.05,
      1.0,
    );
    _settings.f1HapticRevLimiter = prefs.getBool('f1HapticRevLimiter') ?? true;
    _settings.f1HapticWheelSlip = prefs.getBool('f1HapticWheelSlip') ?? true;
    _settings.m7Key1 = prefs.getInt('m7Key1') ?? 7;
    _settings.m7Key2 = prefs.getInt('m7Key2') ?? 8;
    _settings.m7Key3 = prefs.getInt('m7Key3') ?? 6;
    _settings.m7Key4 = prefs.getInt('m7Key4') ?? 5;
    _settings.hudShowRpm = prefs.getBool('hudShowRpm') ?? true;
    _settings.hudShowSpeed = prefs.getBool('hudShowSpeed') ?? true;
    _settings.hudShowGear = prefs.getBool('hudShowGear') ?? true;
    _settings.hudShowDrsErs = prefs.getBool('hudShowDrsErs') ?? true;
    _settings.hudShowPedalBars = prefs.getBool('hudShowPedalBars') ?? true;
    _settings.hudShowTyres = prefs.getBool('hudShowTyres') ?? true;
    _settings.hudShowRpmBox = prefs.getBool('hudShowRpmBox') ?? true;
    _settings.hudShowStatusFlags = prefs.getBool('hudShowStatusFlags') ?? true;

    // ── Mod 8 (Chill Drive) Ayarları ──
    _settings.chillOverlayEnabled =
        prefs.getBool('chillOverlayEnabled') ?? true;
    _settings.chillOverlayGearButtons =
        prefs.getBool('chillOverlayGearButtons') ?? true;
    _settings.chillOverlayStyle = prefs.getInt('chillOverlayStyle') ?? 0;
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
    _settings.flightPitchDeadzone =
        (prefs.getDouble('flightPitchDeadzone') ?? 0.0).clamp(0.0, 10.0);
    _settings.flightRollDeadzone =
        (prefs.getDouble('flightRollDeadzone') ?? 0.0).clamp(0.0, 10.0);
    _settings.flightYawDeadzone = (prefs.getDouble('flightYawDeadzone') ?? 0.0)
        .clamp(0.0, 10.0);
    _settings.flightInvertPitch = prefs.getBool('flightInvertPitch') ?? false;
    _settings.flightInvertRoll = prefs.getBool('flightInvertRoll') ?? false;
    _settings.flightInvertYaw = prefs.getBool('flightInvertYaw') ?? false;
    _settings.flightThrustDetents = (prefs.getInt('flightThrustDetents') ?? 4)
        .clamp(2, 8);
    _settings.m9FireKey = prefs.getInt('m9FireKey') ?? 5;
    _settings.m9MissileKey = prefs.getInt('m9MissileKey') ?? 6;
    _settings.m9LockKey = prefs.getInt('m9LockKey') ?? 7;
    _settings.m9FlareKey = prefs.getInt('m9FlareKey') ?? 8;
    _settings.m9HeavyGunKey =
        prefs.getInt('m9HeavyGunKey') ?? prefs.getInt('m9ViewKey') ?? 14;
    _settings.m9BombKey = prefs.getInt('m9BombKey') ?? 12;
    _settings.m9MapKey = prefs.getInt('m9MapKey') ?? 13;
    _settings.m9FlapDownKey = prefs.getInt('m9FlapDownKey') ?? 10;
    _settings.m9FlapUpKey = prefs.getInt('m9FlapUpKey') ?? 9;
    _settings.m9GearKey = prefs.getInt('m9GearKey') ?? 17;
    _settings.m9AirbrakeKey = prefs.getInt('m9AirbrakeKey') ?? 11;
    _settings.m9RudderLeftKey = prefs.getInt('m9RudderLeftKey') ?? 1;
    _settings.m9RudderRightKey = prefs.getInt('m9RudderRightKey') ?? 2;

    // ── Mod 10 (Flight MFD) Ayarları ──
    _settings.mfdShowArtificialHorizon =
        prefs.getBool('mfdShowArtificialHorizon') ?? true;
    _settings.mfdShowSpeedTape = prefs.getBool('mfdShowSpeedTape') ?? true;
    _settings.mfdShowAltitudeTape =
        prefs.getBool('mfdShowAltitudeTape') ?? true;
    _settings.mfdShowEngineGauges =
        prefs.getBool('mfdShowEngineGauges') ?? true;
    _settings.mfdGyroFilterAlpha =
        (prefs.getDouble('mfdGyroFilterAlpha') ?? 0.15).clamp(0.05, 1.0);

    _snapshots = SettingsSnapshot.decodeList(
      prefs.getString(_snapshotsPrefKey),
    );
    _activeSnapshotId = prefs.getString(_activeSnapshotPrefKey);

    HapticManager().updateSettings(_settings);
    notifyListeners();
  }

  Future<void> saveSettings() async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setString('customDriverName', _settings.customDriverName);
    await prefs.setBool('useGyroscope', _settings.useGyroscope);
    await prefs.setInt('zeroOrientation', _settings.zeroOrientation);
    await prefs.setDouble('calibPitchOffset', _settings.calibPitchOffset);
    await prefs.setDouble('calibRollOffset', _settings.calibRollOffset);
    await prefs.setDouble('steeringAngle', _settings.steeringAngle);
    await prefs.setDouble('swipeSensitivity', _settings.swipeSensitivity);
    await prefs.setDouble('clickMaxDistance', _settings.clickMaxDistance);
    await prefs.setDouble('clickMaxDuration', _settings.clickMaxDuration);
    await prefs.setInt('defaultDrivingMode', _settings.defaultDrivingMode);
    await prefs.setBool('isCumulativeSteering', _settings.isCumulativeSteering);
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
    await prefs.setBool(
      'isAddonMasterSwitchActive',
      _settings.isAddonMasterSwitchActive,
    );
    await prefs.setStringList('activeAddonIds', _settings.activeAddonIds);
    await prefs.setBool('dlcHapticRpm', _settings.dlcHapticRpm);
    await prefs.setBool('dlcHapticSlip', _settings.dlcHapticSlip);
    await prefs.setBool('dlcHapticGear', _settings.dlcHapticGear);
    await prefs.setBool('dlcHapticCollision', _settings.dlcHapticCollision);
    await prefs.setInt('globalHapticType', _settings.globalHapticType);
    await prefs.setInt('globalHapticTrigger', _settings.globalHapticTrigger);

    final hapticTypesMapStr = _settings.customButtonHapticTypes.map(
      (key, value) => MapEntry(key.toString(), value),
    );
    await prefs.setString(
      'customButtonHapticTypes',
      jsonEncode(hapticTypesMapStr),
    );

    final hapticTriggersMapStr = _settings.customButtonHapticTriggers.map(
      (key, value) => MapEntry(key.toString(), value),
    );
    await prefs.setString(
      'customButtonHapticTriggers',
      jsonEncode(hapticTriggersMapStr),
    );
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
    await prefs.setBool(
      'includePitchInDeadzone',
      _settings.includePitchInDeadzone,
    );
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
    await prefs.setInt('joystickMode', _settings.joystickMode.clamp(0, 3));
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

    // Renk & Font alanları
    await prefs.setString('appFontFamily', _settings.appFontFamily);
    await prefs.setInt('backgroundColor', _settings.backgroundColor.toARGB32());
    await prefs.setInt('secondaryColor', _settings.secondaryColor.toARGB32());
    await prefs.setInt('tertiaryColor', _settings.tertiaryColor.toARGB32());
    await prefs.setInt('warningColor', _settings.warningColor.toARGB32());
    await prefs.setInt('surfaceColor', _settings.surfaceColor.toARGB32());
    await prefs.setBool(
      'preventIncompatibleColors',
      _settings.preventIncompatibleColors,
    );
    await prefs.setInt(
      'homeStartBtnColor',
      _settings.homeStartBtnColor.toARGB32(),
    );
    await prefs.setBool('separatePedalBg', _settings.separatePedalBg);
    await prefs.setInt(
      'leftPedalBgColor',
      _settings.leftPedalBgColor.toARGB32(),
    );
    await prefs.setInt(
      'rightPedalBgColor',
      _settings.rightPedalBgColor.toARGB32(),
    );
    await prefs.setInt(
      'mode234ButtonColor',
      _settings.mode234ButtonColor.toARGB32(),
    );
    await prefs.setInt('mod01BgColor', _settings.mod01BgColor.toARGB32());
    await prefs.setInt('mod234BgColor', _settings.mod234BgColor.toARGB32());
    await prefs.setInt('mod5BgColor', _settings.mod5BgColor.toARGB32());

    // Medya yolları
    Future<void> saveOrRemove(String key, String? val) async {
      if (val != null && val.isNotEmpty) {
        await prefs.setString(key, val);
      } else {
        await prefs.remove(key);
      }
    }

    await saveOrRemove('bgMediaPath', _settings.bgMediaPath);
    await saveOrRemove(
      'homeStartBtnMediaPath',
      _settings.homeStartBtnMediaPath,
    );
    await saveOrRemove(
      'generalButtonMediaPath',
      _settings.generalButtonMediaPath,
    );
    await saveOrRemove('gasBarMediaPath', _settings.gasBarMediaPath);
    await saveOrRemove('brakeBarMediaPath', _settings.brakeBarMediaPath);
    await saveOrRemove('pedalBarBgMediaPath', _settings.pedalBarBgMediaPath);
    await saveOrRemove('leftPedalBgMediaPath', _settings.leftPedalBgMediaPath);
    await saveOrRemove(
      'rightPedalBgMediaPath',
      _settings.rightPedalBgMediaPath,
    );
    await saveOrRemove('yetsoreMediaPath', _settings.yetsoreMediaPath);
    await saveOrRemove('steeringBarMediaPath', _settings.steeringBarMediaPath);
    await saveOrRemove(
      'mode234ButtonMediaPath',
      _settings.mode234ButtonMediaPath,
    );
    await saveOrRemove('mod01BgMediaPath', _settings.mod01BgMediaPath);
    await saveOrRemove('mod234BgMediaPath', _settings.mod234BgMediaPath);
    await saveOrRemove('mod5BgMediaPath', _settings.mod5BgMediaPath);
    await saveOrRemove(
      'mod5JoystickMediaPath',
      _settings.mod5JoystickMediaPath,
    );
    await saveOrRemove(
      'mod5JoystickBaseMediaPath',
      _settings.mod5JoystickBaseMediaPath,
    );
    await saveOrRemove('mod5ButtonMediaPath', _settings.mod5ButtonMediaPath);
    await saveOrRemove('mod6BgMediaPath', _settings.mod6BgMediaPath);
    await saveOrRemove('mod6HornMediaPath', _settings.mod6HornMediaPath);
    await saveOrRemove('mod6ButtonsMediaPath', _settings.mod6ButtonsMediaPath);
    await saveOrRemove(
      'mod6AccelIconsMediaPath',
      _settings.mod6AccelIconsMediaPath,
    );
    await saveOrRemove('clutchBarMediaPath', _settings.clutchBarMediaPath);
    await saveOrRemove(
      'handbrakeBarMediaPath',
      _settings.handbrakeBarMediaPath,
    );
    await saveOrRemove('mod7BgMediaPath', _settings.mod7BgMediaPath);
    await saveOrRemove('mod8BgMediaPath', _settings.mod8BgMediaPath);
    await saveOrRemove('mod9BgMediaPath', _settings.mod9BgMediaPath);

    // ── Mod 7 (F1 HUD) Ayarları ──
    await prefs.setBool('f1UseImperial', _settings.f1UseImperial);
    await prefs.setDouble(
      'f1LowPassAlpha',
      _settings.f1LowPassAlpha.clamp(0.05, 1.0),
    );
    await prefs.setBool('f1HapticRevLimiter', _settings.f1HapticRevLimiter);
    await prefs.setBool('f1HapticWheelSlip', _settings.f1HapticWheelSlip);
    await prefs.setInt('m7Key1', _settings.m7Key1);
    await prefs.setInt('m7Key2', _settings.m7Key2);
    await prefs.setInt('m7Key3', _settings.m7Key3);
    await prefs.setInt('m7Key4', _settings.m7Key4);
    await prefs.setBool('hudShowRpm', _settings.hudShowRpm);
    await prefs.setBool('hudShowSpeed', _settings.hudShowSpeed);
    await prefs.setBool('hudShowGear', _settings.hudShowGear);
    await prefs.setBool('hudShowDrsErs', _settings.hudShowDrsErs);
    await prefs.setBool('hudShowPedalBars', _settings.hudShowPedalBars);
    await prefs.setBool('hudShowTyres', _settings.hudShowTyres);
    await prefs.setBool('hudShowRpmBox', _settings.hudShowRpmBox);
    await prefs.setBool('hudShowStatusFlags', _settings.hudShowStatusFlags);

    // ── Mod 8 (Chill Drive) Ayarları ──
    await prefs.setBool('chillOverlayEnabled', _settings.chillOverlayEnabled);
    await prefs.setBool(
      'chillOverlayGearButtons',
      _settings.chillOverlayGearButtons,
    );
    await prefs.setInt('chillOverlayStyle', _settings.chillOverlayStyle);
    await prefs.setInt('chillSteeringAxis', _settings.chillSteeringAxis);
    await prefs.setDouble(
      'chillSteeringSensitivity',
      _settings.chillSteeringSensitivity.clamp(0.2, 3.0),
    );
    await prefs.setDouble(
      'chillGasBrakeSensitivity',
      _settings.chillGasBrakeSensitivity.clamp(0.2, 3.0),
    );

    // ── Mod 9 (Flight Stick) Ayarları ──
    await prefs.setDouble(
      'flightPitchSensitivity',
      _settings.flightPitchSensitivity.clamp(0.2, 3.0),
    );
    await prefs.setDouble(
      'flightRollSensitivity',
      _settings.flightRollSensitivity.clamp(0.2, 3.0),
    );
    await prefs.setDouble(
      'flightYawSensitivity',
      _settings.flightYawSensitivity.clamp(0.2, 3.0),
    );
    await prefs.setDouble(
      'flightPitchDeadzone',
      _settings.flightPitchDeadzone.clamp(0.0, 10.0),
    );
    await prefs.setDouble(
      'flightRollDeadzone',
      _settings.flightRollDeadzone.clamp(0.0, 10.0),
    );
    await prefs.setDouble(
      'flightYawDeadzone',
      _settings.flightYawDeadzone.clamp(0.0, 10.0),
    );
    await prefs.setBool('flightInvertPitch', _settings.flightInvertPitch);
    await prefs.setBool('flightInvertRoll', _settings.flightInvertRoll);
    await prefs.setBool('flightInvertYaw', _settings.flightInvertYaw);
    await prefs.setInt(
      'flightThrustDetents',
      _settings.flightThrustDetents.clamp(2, 8),
    );
    await prefs.setInt('m9FireKey', _settings.m9FireKey);
    await prefs.setInt('m9MissileKey', _settings.m9MissileKey);
    await prefs.setInt('m9LockKey', _settings.m9LockKey);
    await prefs.setInt('m9FlareKey', _settings.m9FlareKey);
    await prefs.setInt('m9HeavyGunKey', _settings.m9HeavyGunKey);
    await prefs.setInt('m9BombKey', _settings.m9BombKey);
    await prefs.setInt('m9MapKey', _settings.m9MapKey);
    await prefs.setInt('m9FlapDownKey', _settings.m9FlapDownKey);
    await prefs.setInt('m9FlapUpKey', _settings.m9FlapUpKey);
    await prefs.setInt('m9GearKey', _settings.m9GearKey);
    await prefs.setInt('m9AirbrakeKey', _settings.m9AirbrakeKey);
    await prefs.setInt('m9RudderLeftKey', _settings.m9RudderLeftKey);
    await prefs.setInt('m9RudderRightKey', _settings.m9RudderRightKey);

    // ── Mod 10 (Flight MFD) Ayarları ──
    await prefs.setBool(
      'mfdShowArtificialHorizon',
      _settings.mfdShowArtificialHorizon,
    );
    await prefs.setBool('mfdShowSpeedTape', _settings.mfdShowSpeedTape);
    await prefs.setBool('mfdShowAltitudeTape', _settings.mfdShowAltitudeTape);
    await prefs.setBool('mfdShowEngineGauges', _settings.mfdShowEngineGauges);
    await prefs.setDouble(
      'mfdGyroFilterAlpha',
      _settings.mfdGyroFilterAlpha.clamp(0.05, 1.0),
    );
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
    await prefs.setInt(
      'clutchYetsoreColor',
      _settings.clutchYetsoreColor.toARGB32(),
    );
    await prefs.setInt('handbrakeColor', _settings.handbrakeColor.toARGB32());
    await prefs.setInt(
      'handbrakeYetsoreColor',
      _settings.handbrakeYetsoreColor.toARGB32(),
    );
    await prefs.setInt('gasIconColor', _settings.gasIconColor.toARGB32());
    await prefs.setInt('brakeIconColor', _settings.brakeIconColor.toARGB32());
    await prefs.setInt('clutchIconColor', _settings.clutchIconColor.toARGB32());
    await prefs.setInt(
      'clutchButtonColor',
      _settings.clutchButtonColor.toARGB32(),
    );
    await prefs.setInt(
      'handbrakeIconColor',
      _settings.handbrakeIconColor.toARGB32(),
    );
    await prefs.setInt(
      'handbrakeButtonColor',
      _settings.handbrakeButtonColor.toARGB32(),
    );
    await prefs.setInt(
      'steeringWheelColor',
      _settings.steeringWheelColor.toARGB32(),
    );
    await prefs.setInt(
      'steeringTurnRightColor',
      _settings.steeringTurnRightColor.toARGB32(),
    );
    await prefs.setInt(
      'steeringTurnLeftColor',
      _settings.steeringTurnLeftColor.toARGB32(),
    );
    await prefs.setInt('mod6BgColor', _settings.mod6BgColor.toARGB32());
    await prefs.setInt('mod6HornColor', _settings.mod6HornColor.toARGB32());

    // Mod 7 Özelleştirme
    await prefs.setInt('mod7BgColor', _settings.mod7BgColor.toARGB32());
    await prefs.setInt(
      'mod7TyreColdColor',
      _settings.mod7TyreColdColor.toARGB32(),
    );
    await prefs.setInt(
      'mod7TyreOptColor',
      _settings.mod7TyreOptColor.toARGB32(),
    );
    await prefs.setInt(
      'mod7TyreHotColor',
      _settings.mod7TyreHotColor.toARGB32(),
    );
    await prefs.setInt(
      'mod7TyreCritColor',
      _settings.mod7TyreCritColor.toARGB32(),
    );
    await prefs.setInt('mod7RpmLowColor', _settings.mod7RpmLowColor.toARGB32());
    await prefs.setInt('mod7RpmMidColor', _settings.mod7RpmMidColor.toARGB32());
    await prefs.setInt(
      'mod7RpmHighColor',
      _settings.mod7RpmHighColor.toARGB32(),
    );
    await prefs.setInt('mod7RpmLimColor', _settings.mod7RpmLimColor.toARGB32());
    await prefs.setInt('mod7GearColor', _settings.mod7GearColor.toARGB32());
    await prefs.setInt('mod7SpeedColor', _settings.mod7SpeedColor.toARGB32());
    await prefs.setInt(
      'mod7DrsActiveColor',
      _settings.mod7DrsActiveColor.toARGB32(),
    );
    await prefs.setInt('mod7ErsColor', _settings.mod7ErsColor.toARGB32());
    await prefs.setInt('mod7RpmBoxColor', _settings.mod7RpmBoxColor.toARGB32());
    await prefs.setInt(
      'mod7ButtonsColor',
      _settings.mod7ButtonsColor.toARGB32(),
    );

    // Mod 8 Özelleştirme
    await prefs.setInt('mod8BgColor', _settings.mod8BgColor.toARGB32());
    await prefs.setInt('mod8SteerColor', _settings.mod8SteerColor.toARGB32());
    await prefs.setInt('mod8GasColor', _settings.mod8GasColor.toARGB32());
    await prefs.setInt('mod8BrakeColor', _settings.mod8BrakeColor.toARGB32());
    await prefs.setInt('mod8RadarColor', _settings.mod8RadarColor.toARGB32());
    await prefs.setInt('mod8CruiseColor', _settings.mod8CruiseColor.toARGB32());
    await prefs.setInt(
      'mod8HoldButtonsColor',
      _settings.mod8HoldButtonsColor.toARGB32(),
    );
    await prefs.setInt(
      'mod8GearBtnColor',
      _settings.mod8GearBtnColor.toARGB32(),
    );
    await prefs.setInt(
      'mod8OverlayBgColor',
      _settings.mod8OverlayBgColor.toARGB32(),
    );
    await prefs.setInt(
      'mod8OverlayBorderColor',
      _settings.mod8OverlayBorderColor.toARGB32(),
    );
    await prefs.setInt(
      'mod8OverlaySteerColor',
      _settings.mod8OverlaySteerColor.toARGB32(),
    );
    await prefs.setInt(
      'mod8OverlayGasColor',
      _settings.mod8OverlayGasColor.toARGB32(),
    );
    await prefs.setInt(
      'mod8OverlayBrakeColor',
      _settings.mod8OverlayBrakeColor.toARGB32(),
    );
    await prefs.setInt(
      'mod8OverlayGearBtnColor',
      _settings.mod8OverlayGearBtnColor.toARGB32(),
    );

    // Mod 9 Özelleştirme
    await prefs.setInt('mod9BgColor', _settings.mod9BgColor.toARGB32());
    await prefs.setInt(
      'mod9ThrottleColor',
      _settings.mod9ThrottleColor.toARGB32(),
    );
    await prefs.setInt('mod9WepColor', _settings.mod9WepColor.toARGB32());
    await prefs.setInt(
      'mod9AvionicsColor',
      _settings.mod9AvionicsColor.toARGB32(),
    );
    await prefs.setInt('mod9RudderColor', _settings.mod9RudderColor.toARGB32());
    await prefs.setInt('mod9HudColor', _settings.mod9HudColor.toARGB32());
    await prefs.setInt(
      'mod9FireBtnColor',
      _settings.mod9FireBtnColor.toARGB32(),
    );
    await prefs.setInt(
      'mod9WeaponBtnColor',
      _settings.mod9WeaponBtnColor.toARGB32(),
    );
    await prefs.setInt(
      'mod9HatSwitchColor',
      _settings.mod9HatSwitchColor.toARGB32(),
    );

    notifyListeners();
  }

  void updateSettings(AppSettings newSettings) {
    newSettings.defaultDrivingMode = AppConfig.instance.sanitizeMode(
      newSettings.defaultDrivingMode,
    );
    _settings = newSettings;
    HapticManager().updateSettings(_settings);
    saveSettings();
  }

  void saveCustomLayout5(String json) {
    _settings.customLayout5Json = json;
    saveSettings();
  }

  Future<void> _persistSnapshots() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _snapshotsPrefKey,
      SettingsSnapshot.encodeList(_snapshots),
    );
    if (_activeSnapshotId != null) {
      await prefs.setString(_activeSnapshotPrefKey, _activeSnapshotId!);
    } else {
      await prefs.remove(_activeSnapshotPrefKey);
    }
  }

  /// Mevcut tüm ayarları yeni bir Snapshot olarak kaydeder.
  /// Ücretsiz kullanıcılar için maksimum 3 ile sınırlıdır; 4. denemede Paywall açılır.
  Future<bool> saveSnapshot({
    required BuildContext context,
    required String name,
    required MonetizationProvider monetizationProvider,
  }) async {
    if (!monetizationProvider.isPro && _snapshots.length >= maxFreeSnapshots) {
      await monetizationProvider.showPaywall(context);
      return false;
    }

    final trimmed = name.trim();
    final id = DateTime.now().microsecondsSinceEpoch.toString();
    final snapshot = SettingsSnapshot.fromAppSettings(
      id: id,
      name: trimmed.isEmpty ? 'Preset ${_snapshots.length + 1}' : trimmed,
      settings: _settings,
    );

    _snapshots = [..._snapshots, snapshot];
    _activeSnapshotId = snapshot.id;
    await _persistSnapshots();
    notifyListeners();
    return true;
  }

  /// Seçili Snapshot içindeki tüm ayarları uygulamaya yükler.
  Future<void> loadSnapshot(String snapshotId) async {
    SettingsSnapshot? target;
    for (final s in _snapshots) {
      if (s.id == snapshotId) {
        target = s;
        break;
      }
    }
    if (target == null) return;

    _settings = target.toAppSettings();
    _settings.defaultDrivingMode = AppConfig.instance.sanitizeMode(
      _settings.defaultDrivingMode,
    );
    _activeSnapshotId = target.id;
    await _persistSnapshots();
    HapticManager().updateSettings(_settings);
    await saveSettings();
  }

  /// Kayıtlı bir Snapshot'u siler.
  Future<void> deleteSnapshot(String snapshotId) async {
    _snapshots = _snapshots.where((s) => s.id != snapshotId).toList();
    if (_activeSnapshotId == snapshotId) {
      _activeSnapshotId = null;
    }
    await _persistSnapshots();
    notifyListeners();
  }
}
