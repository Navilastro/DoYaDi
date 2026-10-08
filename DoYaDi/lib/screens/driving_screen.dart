import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../core/network/network_manager.dart';
import '../core/utils/app_translations.dart';
import '../core/sensor_manager.dart';
import '../providers/settings_provider.dart';
import '../widgets/driving_painters.dart';
import '../widgets/driving_mode_builders.dart';
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
        DrivingModeBuildMixin<DrivingScreen> {
  late AnimationController _tickController;

  final SensorManager _sensorManager = SensorManager();

  // Geliştirici (debug) modu
  bool _debugMode = false;
  List<int> _lastPayload = [128, 0, 0, 0, 0];

  static const _volumeChannel = MethodChannel('Navilastro.DoYaDi/volume_keys');

  @override
  void initState() {
    super.initState();
    WakelockPlus.enable();

    // Hardware ses tuşu dinleyici
    _volumeChannel.setMethodCallHandler((call) async {
      if (call.method == 'key_event') {
        final settings = Provider.of<SettingsProvider>(
          context,
          listen: false,
        ).settings;
        final String event = call.arguments as String;
        if (event == 'volume_up' && settings.volumeUpAction > 0)
          fireKey(settings.volumeUpAction);
        if (event == 'volume_down' && settings.volumeDownAction > 0)
          fireKey(settings.volumeDownAction);
      }
    });

    // 60 Hz tick
    _tickController =
        AnimationController(vsync: this, duration: const Duration(seconds: 1))
          ..addListener(_onTick)
          ..repeat();

    WidgetsBinding.instance.addPostFrameCallback((_) => _initSensors());
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
    final settings = Provider.of<SettingsProvider>(
      context,
      listen: false,
    ).settings;
    final int currentMode = settings.defaultDrivingMode;

    // SensorManager'dan güncel açı değerlerini al
    if (isGyroLookActive) {
      _sensorManager.rightAnalogMode = settings.gyroLookMode;
      _sensorManager.rightAnalogSensitivity = settings.gyroLookSensitivity;
      _sensorManager.rightAnalogDeadzone = settings.gyroLookDeadzone;
    } else {
      _sensorManager.rightAnalogMode = gyroToRightAnalogMode;
      _sensorManager.rightAnalogSensitivity = gyroRightAnalogSensitivity;
      _sensorManager.rightAnalogDeadzone = gyroRightAnalogDeadzone;
    }
    _sensorManager.mouseMode = gyroToMouseMode;
    _sensorManager.mouseSensitivity = gyroMouseSensitivity;
    _sensorManager.mouseDeadzone = gyroMouseDeadzone;
    steeringAngle = _sensorManager.steeringAngle;
    pitchDeg = _sensorManager.pitchDeg;

    // ── Sensör Bypass (Pil/CPU Optimizasyonu) ──────────────────────────────
    // SADECE ekranda Sol Joystick (Left Joystick) eklenmişse direksiyon devre dışı bırakılır.
    // Sağ Analog veya Debriyaj eklense dahi telefon çevrilmesi (raw değer) DAİMA dinlenir.
    final bool bypassSteering = (currentMode == 5) && leftJoystickPresent;

    // Byte 0: Steering
    // bypass aktifse sabit 128 (merkez) gönder, sensör matematiğini çalıştırma.
    int steerByte;
    if (bypassSteering) {
      steerByte = 128;
    } else {
      steerByte = ((steeringAngle + 1.0) / 2.0 * 255).clamp(0, 255).toInt();
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
    // Oyunda debriyaj bir kez Sağ Analog Eksene atandıktan sonra:
    //   - Buton Modu: Basıldığında anında 0 ile 255 (0.0 veya 1.0) adımı atar.
    //   - İkon Modu: Basılı tutulduğunda ivmelenme süresine göre 0'dan 255'e ramp-up eğrisini izler.
    //   - Bar Modu: Parmağın dikey konum yüzdesine göre 0'dan 255'e anlık % oranını izler.
    if (settings.mod6EnableClutch) {
      if (settings.clutchType == 0) {
        // Buton Modu: Basıldığında 1.0 (255), bırakıldığında 0.0 (0)
        if (pressedKeys.contains(settings.clutchKey)) {
          clutchPercentage = 1.0;
        } else {
          clutchPercentage = 0.0;
        }
      }
    }

    final bool isClutchActive = settings.mod6EnableClutch;
    final bool isHandbrakeBarActive = settings.mod6EnableHandbrake && settings.handbrakeType == 1;

    final List<int> payload = [
      steerByte,
      gasByte,
      brakeByte,
      buttonsHigh, // Byte 3 — XUSB High Byte
      buttonsLow, // Byte 4 — XUSB Low Byte
    ];

    // Determine if we need the extended 16/17-byte payload (static for the layout or active features)
    final bool useExtended =
        joystickPresent || touchpadPresent || keyboardKeysPresent || isClutchActive || isHandbrakeBarActive || isGyroLookActive;

    if (useExtended) {
      // Bytes 5-8: Joystick axes (128 = neutral when no joystick present)
      // Deadzone filtresi
      final double j0x = joy0x.abs() < 0.05 ? 0.0 : joy0x;
      final double j0y = joy0y.abs() < 0.05 ? 0.0 : joy0y;
      final double j1x = joy1x.abs() < 0.05 ? 0.0 : joy1x;
      final double j1y = joy1y.abs() < 0.05 ? 0.0 : joy1y;

      // Üstel hassasiyet eğrisi uygula (Exponential Sensitivity Curve)
      // Item bazlı hassasiyet (sol/sağ ayrı), yoksa global fallback
      final double leftSens = leftJoySensitivity ?? settings.joystickSensitivity;
      final double rightSens = rightJoySensitivity ?? settings.joystickSensitivity;
      final double curve0x = j0x.sign * math.pow(j0x.abs(), leftSens);
      final double curve0y = j0y.sign * math.pow(j0y.abs(), leftSens);
      double curve1x = j1x.sign * math.pow(j1x.abs(), rightSens);
      double curve1y = j1y.sign * math.pow(j1y.abs(), rightSens);
      
      // Gyro-to-Right Analog (eski mod 5 kuralı) veya yeni Global Gyro Look aktifse sensör verisiyle ez
      final bool useSensorRightAnalog = gyroToRightAnalogMode != 0 || isGyroLookActive;
      
      if (useSensorRightAnalog) {
        curve1x = _sensorManager.rightAnalogX;
        curve1y = _sensorManager.rightAnalogY;
      }

      int leftStickXByte = 128;
      int leftStickYByte = 128;
      if (j0x.abs() >= 0.05) {
        leftStickXByte = ((curve0x + 1.0) / 2.0 * 255).clamp(0, 255).round();
        if (leftStickXByte == 127) leftStickXByte = 128;
      }
      if (j0y.abs() >= 0.05) {
        leftStickYByte = ((curve0y + 1.0) / 2.0 * 255).clamp(0, 255).round();
        if (leftStickYByte == 127) leftStickYByte = 128;
      }

      int rightStickXByte = 128;
      if (isHandbrakeBarActive && (!useSensorRightAnalog && j1x.abs() < 0.05)) {
        // El Freni Bar değerini Byte 7'ye (Sağ Analog X) aktar
        rightStickXByte = (handbrakePercentage * 255).clamp(0, 255).round();
      } else if (useSensorRightAnalog || j1x.abs() >= 0.05) {
        rightStickXByte = ((curve1x + 1.0) / 2.0 * 255).clamp(0, 255).round();
        if (rightStickXByte == 127) rightStickXByte = 128;
      }

      int rStickYByte = 128;
      if (isClutchActive && (!useSensorRightAnalog && j1y.abs() < 0.05)) {
        // Debriyaj değerini Byte 8'e (Sağ Analog Y) aktar
        rStickYByte = (clutchPercentage * 255).clamp(0, 255).round();
      } else if (useSensorRightAnalog || j1y.abs() >= 0.05) {
        rStickYByte = ((curve1y + 1.0) / 2.0 * 255).clamp(0, 255).round();
        if (rStickYByte == 127) rStickYByte = 128;
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
      
      if (gyroToMouseMode != 0) {
        totalMouseX += _sensorManager.mouseDeltaX;
        totalMouseY += _sensorManager.mouseDeltaY;
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
      while (kbKeys.length < 4) kbKeys.add(0);
      payload.addAll(kbKeys);

      // Reset touchpad deltas after sending (but NOT clicks, gestures handle their own release)
      touchpadDeltaX = 0.0;
      touchpadDeltaY = 0.0;
    }

    payload.add(221);
    NetworkManager().sendPayloadData(payload);
    if (mounted) setState(() => _lastPayload = payload);
  }

  @override
  void dispose() {
    WakelockPlus.disable();
    _tickController.dispose();
    _sensorManager.dispose();
    super.dispose();
  }

  // UI
  DateTime? _lastBackPressTime;
  bool _isExiting = false;

  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<SettingsProvider>(context).settings;
    final size = MediaQuery.of(context).size;

    return PopScope(
      canPop: false,
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
          Navigator.pop(context);
        }
      },
      child: Scaffold(
        backgroundColor: settings.backgroundColor,
        body: AbsorbPointer(
          absorbing: _isExiting,
          child: Stack(
            children: [
              // Ana layout
              Positioned.fill(child: buildLayout(settings, size)),

              // Direksiyon göstergesi alt-orta, yüksekliğin %10'u
              if (settings.defaultDrivingMode != 5 && settings.defaultDrivingMode != 6)
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  height: size.height * 0.10,
                  child: IgnorePointer(
                    child: RepaintBoundary(
                      child: CustomPaint(
                        painter: SteeringPainter(
                          angle: steeringAngle,
                          pitch: pitchDeg,
                          indicatorColor: settings.steeringIndicatorColor,
                          bgColor: settings.steeringBgColor,
                        ),
                      ),
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
