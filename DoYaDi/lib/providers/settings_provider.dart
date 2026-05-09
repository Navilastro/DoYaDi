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
    _settings.customLayout5Json = prefs.getString('customLayout5Json');
    _settings.activeLayout5Profile = prefs.getString('activeLayout5Profile');
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
      };
      prefs.setBool('templatesInitialized', true);
    }
    _settings.globalButtonPressMode =
        prefs.getInt('globalButtonPressMode') ?? 0;
    _settings.globalButtonPressDurationMs =
        prefs.getInt('globalButtonPressDurationMs') ?? 2000;

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
    if (_settings.customLayout5Json != null) {
      await prefs.setString('customLayout5Json', _settings.customLayout5Json!);
    }
    if (_settings.activeLayout5Profile != null) {
      await prefs.setString(
        'activeLayout5Profile',
        _settings.activeLayout5Profile!,
      );
    }
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
