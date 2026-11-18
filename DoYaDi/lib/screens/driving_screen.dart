import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../config/app_config.dart';
import '../core/network/network_manager.dart';
import '../core/utils/app_translations.dart';
import '../core/sensor_manager.dart';
import '../models/app_settings.dart';
import '../providers/connection_provider.dart';
import '../providers/settings_provider.dart';
import '../widgets/driving_painters.dart';
import '../widgets/driving_mode_builders.dart';
import '../widgets/looping_media_widget.dart';
import 'driving_screen_state.dart';

// Ana ekran
class DrivingScreen extends StatefulWidget {
  const DrivingScreen({super.key});

  @override
  State<DrivingScreen> createState() => _DrivingScreenState();
}

class _DrivingScreenState extends State<DrivingScreen>
    with
        SingleTickerProviderStateMixin,
        DrivingInputMixin<DrivingScreen>,
        DrivingModeBuildMixin<DrivingScreen>,
        WidgetsBindingObserver {
  late AnimationController _tickController;
  Timer? _mod8BgTimer;
  bool _isInBackground = false;
  bool _mod8NativeBgActive = false;
  bool _enteredPortrait = false;

  DateTime _lastUiRefresh = DateTime(2000);
  double _uiLastSteer = -999;
  double _uiLastGas = -999;
  double _uiLastBrake = -999;
  double _uiLastClutch = -999;
  double _uiLastHandbrake = -999;
  double _uiLastPitch = -999;
  double _uiLastJoy0x = -999;
  double _uiLastJoy0y = -999;
  double _uiLastJoy1x = -999;
  double _uiLastJoy1y = -999;
  int _uiLastKeysCount = -1;

  final SensorManager _sensorManager = SensorManager();

  static const _volumeChannel = MethodChannel('Navilastro.DoYaDi/volume_keys');

  Map<String, dynamic> _buildMod8BgArgs(AppSettings settings) {
    String ip = '';
    try {
      final conn = Provider.of<ConnectionProvider>(context, listen: false);
      ip = conn.wifiIp;
    } catch (_) {}
    if (ip.isEmpty) {
      ip = NetworkManager().serverIp;
    }
    return {
      'ip': ip,
      'steerSens': settings.chillSteeringSensitivity,
      'gasBrakeSens': settings.chillGasBrakeSensitivity,
      'steeringAngle': settings.steeringAngle,
      'steeringAxis': settings.chillSteeringAxis,
      'showGearButtons': settings.chillOverlayGearButtons,
      'overlayStyle': settings.chillOverlayStyle,
      'basePitch': _sensorManager.chillBasePitch,
      'baseRoll': _sensorManager.chillBaseRoll,
      'cruiseLocked': chillCruiseControlLocked,
      'cruiseGasValue': chillCruiseControlGasValue,
      'overlayBgColor': settings.mod8OverlayBgColor.toARGB32(),
      'overlayBorderColor': settings.mod8OverlayBorderColor.toARGB32(),
      'overlaySteerColor': settings.mod8OverlaySteerColor.toARGB32(),
      'overlayGasColor': settings.mod8OverlayGasColor.toARGB32(),
      'overlayBrakeColor': settings.mod8OverlayBrakeColor.toARGB32(),
      'overlayGearBtnColor': settings.mod8OverlayGearBtnColor.toARGB32(),
      'lang': AppTranslations.currentLanguage,
    };
  }

  String? _lastMod8BgArgsSignature;

  void _syncMod8BackgroundService(AppSettings settings) {
    final int activeMode = AppConfig.instance.sanitizeMode(
      settings.defaultDrivingMode,
    );
    final bool shouldRunBg =
        mounted && activeMode == 8 && settings.chillOverlayEnabled;
    if (shouldRunBg && !_mod8NativeBgActive) {
      _mod8NativeBgActive = true;
      final args = _buildMod8BgArgs(settings);
      _lastMod8BgArgsSignature = args.toString();
      _volumeChannel
          .invokeMethod('start_mod8_bg', args)
          .catchError((_) {});
    } else if (shouldRunBg && _mod8NativeBgActive) {
      // build() saniyede ~60 kez çağrılır: yalnızca ayarlar gerçekten değiştiyse native'e bildir
      final args = _buildMod8BgArgs(settings);
      final signature = args.toString();
      if (signature != _lastMod8BgArgsSignature) {
        _lastMod8BgArgsSignature = signature;
        _volumeChannel
            .invokeMethod('update_mod8_bg', args)
            .catchError((_) {});
      }
    } else if (!shouldRunBg && _mod8NativeBgActive) {
      _mod8NativeBgActive = false;
      _lastMod8BgArgsSignature = null;
      _volumeChannel.invokeMethod('stop_mod8_bg').catchError((_) {});
    }
  }

  void _stopMod8BackgroundService() {
    _mod8BgTimer?.cancel();
    _mod8BgTimer = null;
    if (_mod8NativeBgActive) {
      _mod8NativeBgActive = false;
    }
    _lastMod8BgArgsSignature = null;
    _volumeChannel.invokeMethod('stop_mod8_bg').catchError((_) {});
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WakelockPlus.enable();

    // Hardware ses tuşu ve Mod 8 arka plan servisi dinleyici
    _volumeChannel.setMethodCallHandler((call) async {
      if (call.method == 'key_event') {
        final settings = Provider.of<SettingsProvider>(
          context,
          listen: false,
        ).settings;
        final String event = call.arguments as String;
        if (event == 'volume_up' && settings.volumeUpAction > 0) {
          fireKey(settings.volumeUpAction);
        }
        if (event == 'volume_down' && settings.volumeDownAction > 0) {
          fireKey(settings.volumeDownAction);
        }
      } else if (call.method == 'mod8_bg_recalibrated') {
        final map = call.arguments as Map?;
        if (map != null) {
          final double bp = (map['basePitch'] as num?)?.toDouble() ?? 45.0;
          final double br = (map['baseRoll'] as num?)?.toDouble() ?? 0.0;
          _sensorManager.setChillCalibration(bp, br);
        }
      } else if (call.method == 'mod8_bg_packet') {
        // Bluetooth üzerinden bağlıyken native arka plan servisinin ürettiği paketi ilet
        if (_isInBackground &&
            NetworkManager().isBluetoothConnected &&
            call.arguments is List) {
          final List<int> pkt = (call.arguments as List).cast<int>();
          NetworkManager().sendPayloadData(pkt);
        }
      } else if (call.method == 'mod8_bg_closed') {
        final prov = Provider.of<SettingsProvider>(context, listen: false);
        final s = prov.settings;
        s.chillOverlayEnabled = false;
        prov.updateSettings(s);
        _mod8NativeBgActive = false;
        if (mounted) setState(() {});
      }
    });

    // 60 Hz tick
    _tickController =
        AnimationController(vsync: this, duration: const Duration(seconds: 1))
          ..addListener(_onTick)
          ..repeat();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initSensors();
      _ensureNetworkConnected();
      final settings = Provider.of<SettingsProvider>(context, listen: false).settings;
      final int activeMode = AppConfig.instance.sanitizeMode(
        settings.defaultDrivingMode,
      );
      _syncMod8BackgroundService(settings);
      if (activeMode == 8) {
        _enteredPortrait = true;
        SystemChrome.setPreferredOrientations([
          DeviceOrientation.portraitUp,
          DeviceOrientation.portraitDown,
        ]);
        _checkMod8OverlayPermissionOnEnter();
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final settings = Provider.of<SettingsProvider>(context, listen: false).settings;
    _syncMod8BackgroundService(settings);
  }

  Future<void> _checkMod8OverlayPermissionOnEnter() async {
    if (!mounted) return;
    try {
      final bool granted =
          (await _volumeChannel.invokeMethod<bool>('check_overlay_permission')) ?? true;
      if (!granted && mounted) {
        _showOverlayPermissionDialog();
      }
    } catch (_) {}
  }

  void _showOverlayPermissionDialog() {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: const Color(0xFF101026),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: const BorderSide(color: Color(0xFF40E0D0), width: 1.2),
          ),
          title: Row(
            children: [
              const Icon(Icons.picture_in_picture_alt, color: Color(0xFF40E0D0), size: 24),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  AppTranslations.getText('mod8_overlay_perm_title'),
                  style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          content: Text(
            AppTranslations.getText('mod8_overlay_perm_desc'),
            style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.45),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(
                AppTranslations.getText('later'),
                style: const TextStyle(color: Colors.white54),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF40E0D0),
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () {
                Navigator.pop(ctx);
                _volumeChannel.invokeMethod('request_overlay_permission').catchError((_) {});
              },
              child: Text(
                AppTranslations.getText('allow_permission'),
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _ensureNetworkConnected() async {
    if (!mounted) return;
    try {
      final conn = Provider.of<ConnectionProvider>(context, listen: false);
      await conn.ensureConnectedForDriving();
    } catch (_) {
      await NetworkManager().ensureUdpReady();
    }
  }

  void _initSensors() {
    final settings = Provider.of<SettingsProvider>(
      context,
      listen: false,
    ).settings;

    // Sensör yönetimini SensorManager'a devret
    _sensorManager.init(settings);
  }

  void _onTick() {
    if (!mounted) return;
    final settings = Provider.of<SettingsProvider>(
      context,
      listen: false,
    ).settings;
    final int currentMode = AppConfig.instance.sanitizeMode(
      settings.defaultDrivingMode,
    );
    final bool isMod5 = currentMode == 5;
    final bool isMod6 = currentMode == 6;
    final bool isMod8 = currentMode == 8;
    final bool isMod9 = currentMode == 9;
    final bool isMod10 = currentMode == 10;
    final bool isFlightMode = isMod9 || isMod10;

    // Arka planda çalışma özelliği SADECE Mod 8 için ve ilgili ayar açıkken geçerlidir.
    if (_isInBackground && (!isMod8 || !settings.chillOverlayEnabled)) {
      _mod8BgTimer?.cancel();
      _mod8BgTimer = null;
      return;
    }

    final int activeMod5GyroRaMode = isMod5 ? gyroToRightAnalogMode : 0;
    final int activeMod5GyroMouseMode = isMod5 ? gyroToMouseMode : 0;

    // SensorManager'dan güncel açı değerlerini al
    if (isMod8) {
      // Mod 8 (Rahat Sürüş - Dikey Tek El Modu): İzole sensör değerlerini kullan
      steeringAngle = _sensorManager.chillSteering;
      pitchDeg = _sensorManager.chillPitchDeg;
      if (!chillTouchGasActive && !chillTouchBrakeActive) {
        if (chillCruiseControlLocked) {
          if (_sensorManager.chillBrake > 0.18) {
            chillCruiseControlLocked = false;
            gasPercentage = 0.0;
            brakePercentage = _sensorManager.chillBrake;
          } else {
            gasPercentage = math.max(chillCruiseControlGasValue, _sensorManager.chillGas);
            brakePercentage = 0.0;
          }
        } else {
          gasPercentage = _sensorManager.chillGas;
          brakePercentage = _sensorManager.chillBrake;
        }
      }
    } else if (isFlightMode) {
      // Mod 9 & Mod 10 (Uçuş Kontrolü & MFD Kokpiti): Roll -> Sol Analog X, Pitch -> Sol Analog Y
      double rollCmd = flightTouchStickActive
          ? flightTouchRoll
          : _sensorManager.flightRoll;
      if (isMod10 && flightApWingLevel && !flightTouchStickActive) {
        final telemetry = TelemetryListenerService().telemetryNotifier.value;
        rollCmd = telemetry.isFlightLive
            ? (-telemetry.rollDeg / 35.0).clamp(-0.6, 0.6)
            : 0.0;
      }
      steeringAngle = rollCmd;
      pitchDeg = (isMod10 && flightApAltHold && !flightTouchStickActive)
          ? 0.0
          : _sensorManager.flightPitchDeg;
    } else {
      steeringAngle = _sensorManager.steeringAngle;
      pitchDeg = _sensorManager.pitchDeg;
    }

    if (isGyroLookActive && (settings.gyroLookStyle == 0 || settings.gyroLookStyle == 2)) {
      _sensorManager.ensureGyroscopeActive(settings);
      _sensorManager.rightAnalogMode = settings.gyroLookMode;
      _sensorManager.rightAnalogSensitivity = settings.gyroLookSensitivity;
      _sensorManager.rightAnalogDeadzone = settings.gyroLookDeadzone;
      _sensorManager.rightAnalogOnlyYaw = (settings.gyroLookStyle == 0);
    } else if (activeMod5GyroRaMode != 0) {
      _sensorManager.ensureGyroscopeActive(settings);
      _sensorManager.rightAnalogMode = activeMod5GyroRaMode;
      _sensorManager.rightAnalogSensitivity = gyroRightAnalogSensitivity;
      _sensorManager.rightAnalogDeadzone = gyroRightAnalogDeadzone;
      _sensorManager.rightAnalogOnlyYaw = false;
    } else {
      _sensorManager.rightAnalogMode = 0;
      _sensorManager.rightAnalogOnlyYaw = false;
    }

    if (activeMod5GyroMouseMode != 0) {
      _sensorManager.ensureGyroscopeActive(settings);
      _sensorManager.mouseMode = activeMod5GyroMouseMode;
      _sensorManager.mouseSensitivity = gyroMouseSensitivity;
      _sensorManager.mouseDeadzone = gyroMouseDeadzone;
    } else {
      _sensorManager.mouseMode = 0;
    }

    // ── Sensör Bypass (Pil/CPU Optimizasyonu) ──────────────────────────────
    // SADECE ekranda Sol Joystick (Left Joystick) eklenmişse direksiyon devre dışı bırakılır.
    // Sağ Analog veya Debriyaj eklense dahi telefon çevrilmesi (raw değer) DAİMA dinlenir.
    final bool bypassSteering = isMod5 && leftJoystickPresent;

    // Byte 0: Steering
    // bypass aktifse sabit 128 (merkez) gönder, sensör matematiğini çalıştırma.
    int steerByte;
    if (bypassSteering) {
      steerByte = 128;
    } else {
      steerByte = ((steeringAngle + 1.0) / 2.0 * 255).clamp(0, 255).toInt();
    }

    // R2 (19) veya L2 (20) tuş ataması herhangi bir butonda aktifse %0 -> %100 etki uygula
    final bool r2Pressed = pressedKeys.contains(19);
    if (r2Pressed) {
      r2TriggerButtonActive = true;
      gasPercentage = 1.0;
    } else if (r2TriggerButtonActive) {
      r2TriggerButtonActive = false;
      final bool hasActiveGasSource =
          gasPedalIconPressed ||
          chillTouchGasActive ||
          (isMod8 && chillCruiseControlLocked) ||
          activePedals.values.any((p) => p.isBarAction && p.isGas);
      if (!hasActiveGasSource) {
        gasPercentage = 0.0;
      }
    }

    final bool l2Pressed = pressedKeys.contains(20);
    if (l2Pressed) {
      l2TriggerButtonActive = true;
      brakePercentage = 1.0;
    } else if (l2TriggerButtonActive) {
      l2TriggerButtonActive = false;
      final bool hasActiveBrakeSource =
          brakePedalIconPressed ||
          chillTouchBrakeActive ||
          activePedals.values.any((p) => p.isBarAction && !p.isGas);
      if (!hasActiveBrakeSource) {
        brakePercentage = 0.0;
      }
    }

    // Byte 1: Gas (0.0 to 1.0) mapped to 0-255
    int gasByte = (gasPercentage * 255).clamp(0, 255).toInt();

    // Byte 2: Brake (0.0 to 1.0) mapped to 0-255
    int brakeByte = (brakePercentage * 255).clamp(0, 255).toInt();

    // ── XUSB_BUTTON Bitmask (Xbox 360 / XInput Standardı) ─────────────────
    // Yalnızca Xbox tuşları (1-18) dahil edilir.
    // Fare (2000s) ve Klavye (1000s) bu hesaba KESİNLİKLE girmez.
    //
    // XUSB_GAMEPAD_* sabitleri:
    //   DPAD_UP    0x0001  → keyIndex 9
    //   DPAD_DOWN  0x0002  → keyIndex 10
    //   DPAD_LEFT  0x0004  → keyIndex 11
    //   DPAD_RIGHT 0x0008  → keyIndex 12
    //   START      0x0010  → keyIndex 13
    //   BACK       0x0020  → keyIndex 14
    //   L3         0x0040  → keyIndex 17
    //   R3         0x0080  → keyIndex 18
    //   LB         0x0100  → keyIndex 1
    //   RB         0x0200  → keyIndex 2
    //   GUIDE      0x0400  → keyIndex 3
    //   A          0x1000  → keyIndex 5
    //   B          0x2000  → keyIndex 6
    //   X          0x4000  → keyIndex 7
    //   Y          0x8000  → keyIndex 8
    int buttons = 0;
    if (pressedKeys.contains(9)) buttons |= 0x0001; // DPAD_UP
    if (pressedKeys.contains(10)) buttons |= 0x0002; // DPAD_DOWN
    if (pressedKeys.contains(11)) buttons |= 0x0004; // DPAD_LEFT
    if (pressedKeys.contains(12)) buttons |= 0x0008; // DPAD_RIGHT
    if (pressedKeys.contains(13)) buttons |= 0x0010; // START
    if (pressedKeys.contains(14)) buttons |= 0x0020; // BACK / SELECT
    if (pressedKeys.contains(17)) buttons |= 0x0040; // L3 (Sol Analog Tık)
    if (pressedKeys.contains(18)) buttons |= 0x0080; // R3 (Sağ Analog Tık)
    if (pressedKeys.contains(1)) buttons |= 0x0100; // LB
    if (pressedKeys.contains(2)) buttons |= 0x0200; // RB
    if (pressedKeys.contains(3)) buttons |= 0x0400; // GUIDE / Steam
    if (pressedKeys.contains(5)) buttons |= 0x1000; // A
    if (pressedKeys.contains(6)) buttons |= 0x2000; // B
    if (pressedKeys.contains(7)) buttons |= 0x4000; // X
    if (pressedKeys.contains(8)) buttons |= 0x8000; // Y

    // Byte 3: High Byte, Byte 4: Low Byte
    final int buttonsHigh = (buttons >> 8) & 0xFF;
    final int buttonsLow = buttons & 0xFF;

    // ── SAĞ ANALOG EKSENİ (BYTE 8) NORMALIZE DEBRİYAJ MİMARİSİ ──────────────
    // Yalnızca Mod 6 (veya Mod 5'te debriyaj/el freni öğesi varsa) aktif olur.
    // Böylece Mod 0-4 gibi temel sürüş modlarıyla veya Sensörle Bakış ile karışmaz.
    if (isMod6 && settings.mod6EnableClutch) {
      if (settings.clutchType == 0) {
        // Buton Modu: Basıldığında 1.0, bırakıldığında 0.0
        if (pressedKeys.contains(settings.clutchKey)) {
          clutchPercentage = 1.0;
        } else {
          clutchPercentage = 0.0;
        }
      }
    }

    final bool isClutchActive =
        (isMod6 && settings.mod6EnableClutch) || (isMod5 && mod5ClutchPresent);
    final bool isHandbrakeBarActive =
        (isMod6 && settings.mod6EnableHandbrake && settings.handbrakeType == 1) ||
        (isMod5 && mod5HandbrakePresent);
    final bool isGlobalGyroLookEnabled = settings.gyroLookEnabled;

    final List<int> payload = [
      steerByte,
      gasByte,
      brakeByte,
      buttonsHigh, // Byte 3 — XUSB High Byte
      buttonsLow, // Byte 4 — XUSB Low Byte
    ];

    // Her modda 16+1 (17 bayt) genişletilmiş paketi gönder:
    // Böylece Mod 0-4, Mod 5 (Touchpad/Joystick/Makro), Mod 6-9 dahil tüm modlarda
    // Klavye tuşları (1000+), Fare tıklamaları (2000+), Touchpad ve Analog eksenler
    // hiçbir zaman kesintiye uğramaz; kullanılmayan analog eksenler 128 (nötr) kalır.
    const bool useExtended = true;

    if (useExtended) {
      // Bytes 5-8: Joystick axes (128 = neutral when no joystick present)
      // Deadzone filtresi
      final double activeFlightPitch = flightTouchStickActive
          ? flightTouchPitch
          : ((isMod10 && flightApAltHold) ? 0.0 : _sensorManager.flightPitch);
      final double j0x = isFlightMode
          ? steeringAngle
          : ((isMod5 && leftJoystickPresent && joy0x.abs() >= 0.05) ? joy0x : 0.0);
      final double j0y = isFlightMode
          ? activeFlightPitch
          : ((isMod5 && leftJoystickPresent && joy0y.abs() >= 0.05) ? joy0y : 0.0);
      final bool allowRightTouchJoy =
          (isMod5 && rightJoystickPresent) ||
          (isFlightMode && flightFreeLookTouchActive) ||
          (isGlobalGyroLookEnabled && settings.gyroLookStyle == 1);
      final double j1x = (allowRightTouchJoy && joy1x.abs() >= 0.05) ? joy1x : 0.0;
      final double j1y = (allowRightTouchJoy && joy1y.abs() >= 0.05) ? joy1y : 0.0;

      // Üstel hassasiyet eğrisi uygula (Exponential Sensitivity Curve)
      // Item bazlı hassasiyet (sol/sağ ayrı), yoksa global fallback
      final double leftSens = leftJoySensitivity ?? settings.joystickSensitivity;
      final double rightSens = rightJoySensitivity ?? settings.joystickSensitivity;
      final double curve0x = isFlightMode ? j0x : (j0x.sign * math.pow(j0x.abs(), leftSens));
      final double curve0y = isFlightMode ? j0y : (j0y.sign * math.pow(j0y.abs(), leftSens));
      double curve1x = j1x.sign * math.pow(j1x.abs(), rightSens);
      double curve1y = j1y.sign * math.pow(j1y.abs(), rightSens);
      
      // Gyro-to-Right Analog (Mod 5 kuralı) veya Global Gyro Look (Yarışçı veya Sıfır Noktası modu) aktifse sensör verisiyle ez
      final bool useSensorRightAnalog =
          activeMod5GyroRaMode != 0 || (isGyroLookActive && (settings.gyroLookStyle == 0 || settings.gyroLookStyle == 2));
      
      if (useSensorRightAnalog) {
        curve1x = _sensorManager.rightAnalogX;
        curve1y = (settings.gyroLookStyle == 0) ? 0.0 : _sensorManager.rightAnalogY;
      } else if (isFlightMode && !flightFreeLookTouchActive) {
        final double rudderVal =
            flightRudderTouch.abs() > 0.01 ? flightRudderTouch : _sensorManager.flightYaw;
        curve1x = rudderVal.clamp(-1.0, 1.0);
        curve1y = 0.0;
      }

      int leftStickXByte = 128;
      int leftStickYByte = 128;
      if (isFlightMode) {
        if (j0x != 0.0) {
          leftStickXByte = ((curve0x + 1.0) / 2.0 * 255).clamp(1, 255).round();
        }
        if (j0y != 0.0) {
          leftStickYByte = ((curve0y + 1.0) / 2.0 * 255).clamp(1, 255).round();
        }
      } else {
        if (j0x.abs() >= 0.05) {
          leftStickXByte = ((curve0x + 1.0) / 2.0 * 255).clamp(1, 255).round();
          if (leftStickXByte == 127) leftStickXByte = 128;
        }
        if (j0y.abs() >= 0.05) {
          leftStickYByte = ((curve0y + 1.0) / 2.0 * 255).clamp(1, 255).round();
          if (leftStickYByte == 127) leftStickYByte = 128;
        }
      }

      // Sağ Analog ekseni kamera/bakış için de kullanılıyor mu?
      final bool isRightStickSharedWithCamera =
          isGlobalGyroLookEnabled ||
          activeMod5GyroRaMode != 0 ||
          isFlightMode ||
          (isMod5 && rightJoystickPresent);

      int rightStickXByte = 128;
      if (isHandbrakeBarActive && !useSensorRightAnalog && j1x.abs() < 0.05) {
        if (!isRightStickSharedWithCamera) {
          // Orijinal Mod 6/5 davranışı: 0-255 tam eksen
          rightStickXByte = (handbrakePercentage * 255).clamp(0, 255).round();
        } else if (handbrakePercentage > 0.01) {
          // Kamera/Bakış açıkken boşta 0 gönderip sol-üste çekmemesi için 128..255
          rightStickXByte = (128 + handbrakePercentage * 127).clamp(128, 255).round();
        }
      } else if (useSensorRightAnalog || j1x.abs() >= 0.05 || (isFlightMode && curve1x != 0.0)) {
        rightStickXByte = ((curve1x + 1.0) / 2.0 * 255).clamp(0, 255).round();
        if (!isFlightMode && rightStickXByte == 127) rightStickXByte = 128;
      }

      int rStickYByte = 128;
      if (isClutchActive && !useSensorRightAnalog && j1y.abs() < 0.05) {
        if (!isRightStickSharedWithCamera) {
          // Orijinal Mod 6/5 davranışı: 0-255 tam eksen
          rStickYByte = (clutchPercentage * 255).clamp(0, 255).round();
        } else if (clutchPercentage > 0.01) {
          // Kamera/Bakış açıkken boşta 0 gönderip sol-üste çekmemesi için 128..255
          rStickYByte = (128 + clutchPercentage * 127).clamp(128, 255).round();
        }
      } else if (useSensorRightAnalog || j1y.abs() >= 0.05 || (isFlightMode && curve1y != 0.0)) {
        rStickYByte = ((curve1y + 1.0) / 2.0 * 255).clamp(0, 255).round();
        if (!isFlightMode && rStickYByte == 127) rStickYByte = 128;
      }

      payload.addAll([
        leftStickXByte,
        leftStickYByte,
        rightStickXByte,
        rStickYByte,
      ]);

      // Bytes 9-10: Touchpad mouse delta (128 = no movement)
      double totalMouseX = touchpadDeltaX;
      double totalMouseY = touchpadDeltaY;
      
      if (activeMod5GyroMouseMode != 0) {
        totalMouseX += _sensorManager.mouseDeltaX;
        totalMouseY += _sensorManager.mouseDeltaY;
        _sensorManager.mouseDeltaX = 0.0;
        _sensorManager.mouseDeltaY = 0.0;
      }
      
      final int mouseX = (128 + totalMouseX.clamp(-127, 127)).toInt();
      final int mouseY = (128 + totalMouseY.clamp(-127, 127)).toInt();
      payload.add(mouseX);
      payload.add(mouseY);

      // Byte 11: Mouse click (0=none, 1=left/2001, 2=right/2003, 3=middle/2002)
      int btnMouseClick = 0;
      if (pressedKeys.contains(2001)) {
        btnMouseClick = 1; // Sol Tık
      } else if (pressedKeys.contains(2002)) {
        btnMouseClick = 3; // Orta Tık (2002)
      } else if (pressedKeys.contains(2003)) {
        btnMouseClick = 2; // Sağ Tık (2003)
      }
      int finalMouseClick = tpClick != 0
          ? tpClick
          : btnMouseClick; // Touchpad'in önceliği var
      payload.add(finalMouseClick); // Byte 11 olarak ekle

      // Bytes 12-15: Keyboard keys (VK codes for keys with ID >= 100, up to 4 simultaneous)
      final List<int> kbKeys = pressedKeys
          .where((k) => k >= 1000 && k < 2000)
          .map((k) => k - 1000) // Gerçek VK koduna geri çevir (Örn 1013 -> 13)
          .take(4)
          .toList();
      while (kbKeys.length < 4) {
        kbKeys.add(0);
      }
      payload.addAll(kbKeys);

      // Reset touchpad deltas after sending (but NOT clicks, gestures handle their own release)
      touchpadDeltaX = 0.0;
      touchpadDeltaY = 0.0;
    }

    payload.add(221);
    NetworkManager().sendPayloadData(payload);
    if (mounted && !_isInBackground) {
      final now = DateTime.now();
      final elapsedMs = now.difference(_lastUiRefresh).inMilliseconds;
      final bool changed =
          (steeringAngle - _uiLastSteer).abs() > 0.005 ||
          (gasPercentage - _uiLastGas).abs() > 0.005 ||
          (brakePercentage - _uiLastBrake).abs() > 0.005 ||
          (clutchPercentage - _uiLastClutch).abs() > 0.005 ||
          (handbrakePercentage - _uiLastHandbrake).abs() > 0.005 ||
          (pitchDeg - _uiLastPitch).abs() > 0.4 ||
          (joy0x - _uiLastJoy0x).abs() > 0.005 ||
          (joy0y - _uiLastJoy0y).abs() > 0.005 ||
          (joy1x - _uiLastJoy1x).abs() > 0.005 ||
          (joy1y - _uiLastJoy1y).abs() > 0.005 ||
          pressedKeys.length != _uiLastKeysCount;
      if ((changed && elapsedMs >= 30) || elapsedMs >= 160) {
        _lastUiRefresh = now;
        _uiLastSteer = steeringAngle;
        _uiLastGas = gasPercentage;
        _uiLastBrake = brakePercentage;
        _uiLastClutch = clutchPercentage;
        _uiLastHandbrake = handbrakePercentage;
        _uiLastPitch = pitchDeg;
        _uiLastJoy0x = joy0x;
        _uiLastJoy0y = joy0y;
        _uiLastJoy1x = joy1x;
        _uiLastJoy1y = joy1y;
        _uiLastKeysCount = pressedKeys.length;
        setState(() {});
      }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (!mounted) return;
    final settings = Provider.of<SettingsProvider>(context, listen: false).settings;
    final int activeMode = AppConfig.instance.sanitizeMode(
      settings.defaultDrivingMode,
    );
    final bool allowMod8Background =
        activeMode == 8 && settings.chillOverlayEnabled;

    if (state == AppLifecycleState.inactive && allowMod8Background) {
      // Mod 8: 'inactive' (bildirim paneli, uygulama değiştirici geçişi) henüz arka plan
      // değildir; baloncuk yalnızca gerçekten arka plana geçince (paused/hidden) açılır.
      return;
    }

    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      // Her modda ekran vsync animasyon kontrolcüsünü durdur
      _tickController.stop();

      if (allowMod8Background) {
        // SADECE Mod 8'de ve arka planda çalışma aktifse kapsül baloncuğu aç ve native sensör-ağ döngüsünü sürdür
        _isInBackground = true;
        _mod8NativeBgActive = true;
        _volumeChannel
            .invokeMethod('enter_mod8_bg', _buildMod8BgArgs(settings))
            .catchError((_) {});
      } else {
        // Diğer tüm modlarda (0-7, 9, 10) veya Mod 8 arka plan kapalıyken arka planda çalışmayı durdur
        _isInBackground = false;
        _stopMod8BackgroundService();
        // Güvenlik için nötr paket gönder (gaz/fren basılı kalmasın)
        NetworkManager().sendPayloadData(
          const [128, 0, 0, 0, 0, 128, 128, 128, 128, 128, 128, 0, 0, 0, 0, 0, 221],
        );
      }
    } else if (state == AppLifecycleState.resumed) {
      _isInBackground = false;
      _mod8BgTimer?.cancel();
      _mod8BgTimer = null;
      _volumeChannel.invokeMethod('exit_mod8_bg').catchError((_) {});
      _syncMod8BackgroundService(settings);
      if (!_tickController.isAnimating) {
        _tickController.repeat();
      }
      _ensureNetworkConnected();
    } else if (state == AppLifecycleState.detached) {
      _isInBackground = false;
      _stopMod8BackgroundService();
    }
  }

  @override
  void dispose() {
    _stopMod8BackgroundService();
    WidgetsBinding.instance.removeObserver(this);
    WakelockPlus.disable();
    _tickController.dispose();
    _sensorManager.dispose();
    
    // Sadece Mod 8 için portre moda geçildiyse yatay moda geri döndür
    if (_enteredPortrait) {
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
    }
    
    super.dispose();
  }

  // UI
  DateTime? _lastBackPressTime;
  bool _isExiting = false;

  bool _canPop = false;

  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<SettingsProvider>(context).settings;
    final int activeMode = AppConfig.instance.sanitizeMode(
      settings.defaultDrivingMode,
    );
    final size = MediaQuery.of(context).size;

    return PopScope(
      canPop: _canPop,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        final now = DateTime.now();
        if (_lastBackPressTime == null ||
            now.difference(_lastBackPressTime!) > const Duration(seconds: 2)) {
          _lastBackPressTime = now;
          setState(() => _isExiting = true);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(AppTranslations.getText('press_back_again')),
              duration: const Duration(seconds: 2),
            ),
          );
          Future.delayed(const Duration(seconds: 2), () {
            if (mounted) setState(() => _isExiting = false);
          });
        } else {
          setState(() => _canPop = true);
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) Navigator.pop(context);
          });
        }
      },
      child: Scaffold(
        backgroundColor: settings.modeBackgroundColor(activeMode),
        body: AbsorbPointer(
          absorbing: _isExiting,
          child: Stack(
            children: [
              // Arka plan medya katmanı (Mod bazlı veya genel GIF / Döngülü Video / Görsel)
              if (settings.modeBackgroundMedia(activeMode) != null &&
                  settings.modeBackgroundMedia(activeMode)!.isNotEmpty)
                Positioned.fill(
                  child: RepaintBoundary(
                    child: LoopingMediaWidget(
                      mediaPath: settings.modeBackgroundMedia(activeMode),
                      fit: BoxFit.cover,
                    ),
                  ),
                ),

              // Ana layout
              Positioned.fill(
                child: RepaintBoundary(
                  child: buildLayout(settings, size),
                ),
              ),

              // Direksiyon göstergesi alt-orta, yüksekliğin %10'u (Mod 0-4 ve Mod 7 için)
              if (activeMode < 5 || activeMode == 7)
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  height: size.height * 0.10,
                  child: IgnorePointer(
                    child: CustomizableSteeringBar(
                      angle: steeringAngle,
                      pitch: pitchDeg,
                      indicatorColor: settings.steeringIndicatorColor,
                      bgColor: settings.steeringBgColor,
                      mediaPath: settings.steeringBarMediaPath,
                    ),
                  ),
                ),

              // Geliştirici debug paneli
              // if (_debugMode)
              //   Positioned(
              //     top: 40,
              //     left: 8,
              //     child: IgnorePointer(
              //       child: Container(
              //         padding: const EdgeInsets.symmetric(
              //           horizontal: 10,
              //           vertical: 8,
              //         ),
              //         decoration: BoxDecoration(
              //           color: Colors.black.withValues(alpha: 0.65),
              //           borderRadius: BorderRadius.circular(10),
              //           border: Border.all(
              //             color: Colors.greenAccent.withValues(alpha: 0.6),
              //           ),
              //         ),
              //         child: DefaultTextStyle(
              //           style: const TextStyle(
              //             fontFamily: 'monospace',
              //             fontSize: 11,
              //             color: Colors.greenAccent,
              //             height: 1.5,
              //           ),
              //           child: Column(
              //             crossAxisAlignment: CrossAxisAlignment.start,
              //             mainAxisSize: MainAxisSize.min,
              //             children: [
              //               const Text('DEBUG LOG'),
              //               Text(
              //                 'Steer : ${_lastPayload[0].toString().padLeft(3)}  (raw: ${steeringAngle.toStringAsFixed(3)})',
              //               ),
              //               Text(
              //                 'Gas   : ${_lastPayload[1].toString().padLeft(3)}  (${(gasPercentage * 100).toStringAsFixed(1)}%)',
              //               ),
              //               Text(
              //                 'Brake : ${_lastPayload[2].toString().padLeft(3)}  (${(brakePercentage * 100).toStringAsFixed(1)}%)',
              //               ),
              //               Text(
              //                 'Keys1-8 : 0x${_lastPayload[3].toRadixString(16).padLeft(2, "0").toUpperCase()}  [${_lastPayload[3].toRadixString(2).padLeft(8, "0")}]',
              //               ),
              //               Text(
              //                 'Keys9-16: 0x${_lastPayload[4].toRadixString(16).padLeft(2, "0").toUpperCase()}  [${_lastPayload[4].toRadixString(2).padLeft(8, "0")}]',
              //               ),
              //               if (_lastPayload.length >= 9) ...[
              //                 Text(
              //                   'Sol Joy X: ${_lastPayload[5].toString().padLeft(3)}  (${joy0x.toStringAsFixed(2)})',
              //                 ),
              //                 Text(
              //                   'Sol Joy Y: ${_lastPayload[6].toString().padLeft(3)}  (${joy0y.toStringAsFixed(2)})',
              //                 ),
              //                 Text(
              //                   'Sağ Joy X: ${_lastPayload[7].toString().padLeft(3)}  (${joy1x.toStringAsFixed(2)})',
              //                 ),
              //                 Text(
              //                   'Sağ Joy Y: ${_lastPayload[8].toString().padLeft(3)}  (${joy1y.toStringAsFixed(2)})',
              //                 ),
              //               ],
              //               Text('Bytes: [${_lastPayload.join(", ")}]'),
              //             ],
              //           ),
              //         ),
              //       ),
              //     ),
              //   ),

              // Debug toggle butonu
              // Positioned(
              //   top: 8,
              //   left: 8,
              //   child: GestureDetector(
              //     onTap: () => setState(() => _debugMode = !_debugMode),
              //     child: AnimatedContainer(
              //       duration: const Duration(milliseconds: 200),
              //       padding: const EdgeInsets.symmetric(
              //         horizontal: 8,
              //         vertical: 4,
              //       ),
              //       decoration: BoxDecoration(
              //         color: _debugMode
              //             ? Colors.greenAccent.withValues(alpha: 0.25)
              //             : Colors.white.withValues(alpha: 0.08),
              //         borderRadius: BorderRadius.circular(8),
              //         border: Border.all(
              //           color: _debugMode ? Colors.greenAccent : Colors.white24,
              //         ),
              //       ),
              //       child: Text(
              //         _debugMode ? 'DEV LOG' : 'DEV',
              //         style: TextStyle(
              //           fontSize: 10,
              //           color: _debugMode ? Colors.greenAccent : Colors.white38,
              //           fontWeight: FontWeight.bold,
              //         ),
              //       ),
              //     ),
              //   ),
              // ),
            ],
          ),
        ),
      ),
    );
  }
}
