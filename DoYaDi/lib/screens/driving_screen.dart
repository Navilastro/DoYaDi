import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../core/network/network_manager.dart';
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

  StreamSubscription? _accelerometerSub;
  StreamSubscription? _gyroscopeSub;

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

    _accelerometerSub = accelerometerEventStream().listen((event) {
      // 1. Gerçek Pitch (Eğim) Açısını Bulma
      double rawPitch;
      if (settings.zeroOrientation == 2) {
        rawPitch = math.atan2(event.x.abs(), -event.z) * (180 / math.pi);
      } else {
        rawPitch = math.atan2(event.x.abs(), event.z) * (180 / math.pi);
      }
      rawPitch -= settings.calibPitchOffset;

      // Pitch'i mutlak değer olarak alıyoruz ki hesaplamalar kolaylaşsın
      double pitch = rawPitch.abs();

      // 2. Dinamik Hassasiyet Çarpanı (Multiplier) Hesaplama
      double multiplier = 1.0; // Varsayılan: Normal Sürüş (70-110 arası)

      // Hassasiyet sınırları
      double minMultiplier = 0.4; // En düşük hassasiyet (Ağır direksiyon)
      double maxMultiplier = 2.5; // En yüksek hassasiyet (Hızlı direksiyon)

      if (pitch >= 50.0 && pitch <= 70.0) {
        // İnce Ayar Bölgesi: 50'de en düşük (0.4), 70'te normal (1.0) olur.
        double t = (pitch - 50.0) / (70.0 - 50.0);
        multiplier = minMultiplier + (t * (1.0 - minMultiplier));
      } else if (pitch >= 110.0 && pitch <= 130.0) {
        // Agresif Dönüş Bölgesi: 110'da normal (1.0), 130'da en yüksek (2.5) olur.
        double t = (pitch - 110.0) / (130.0 - 110.0);
        multiplier = 1.0 + (t * (maxMultiplier - 1.0));
      } else if (pitch < 50.0) {
        // Telefon 50'den de fazla yatırılırsa hassasiyet en düşükte kilitlensin
        multiplier = minMultiplier;
      } else if (pitch > 130.0) {
        // Telefon 130'dan fazla yatırılırsa hassasiyet maksimumda kilitlensin
        multiplier = maxMultiplier;
      }

      // 3. Nihai Direksiyon Verisini Hesaplama ve Oyuna Gönderme
      double maxG = (settings.steeringAngle / 180.0) * 9.8;

      // Roll (Y ekseni) verisini çarpan ile çarpıp -1.0 ile 1.0 arasına sıkıştırıyoruz (clamp)
      double normalized = ((event.y / maxG) * multiplier).clamp(-1.0, 1.0);

      steeringAngle = normalized;
    });

    if (settings.useGyroscope) {
      _gyroscopeSub = gyroscopeEventStream().listen((_) {});
    }
  }

  void _onTick() {
    // 5-byte protocol
    // Byte 0: Steering (-1.0 to 1.0) mapped to 0-255 (128 = center)
    int steerByte = ((steeringAngle + 1.0) / 2.0 * 255).clamp(0, 255).toInt();

    // Byte 1: Gas (0.0 to 1.0) mapped to 0-255
    int gasByte = (gasPercentage * 255).clamp(0, 255).toInt();

    // Byte 2: Brake (0.0 to 1.0) mapped to 0-255
    int brakeByte = (brakePercentage * 255).clamp(0, 255).toInt();

    // Byte 3: Keys 1-8 bitmask
    int keys1to8 = 0;
    for (int i = 1; i <= 8; i++) {
      if (pressedKeys.contains(i)) keys1to8 |= (1 << (i - 1));
    }

    // Byte 4: Keys 9-16 bitmask
    int keys9to16 = 0;
    for (int i = 9; i <= 16; i++) {
      if (pressedKeys.contains(i)) keys9to16 |= (1 << (i - 9));
    }

    final List<int> payload = [
      steerByte,
      gasByte,
      brakeByte,
      keys1to8,
      keys9to16,
    ];

    // Determine if we need the extended 16-byte Mode 5 payload
    final bool useExtended =
        joystickPresent || touchpadPresent || keyboardKeysPresent;

    if (useExtended) {
      // Bytes 5-8: Joystick axes (128 = neutral when no joystick present)
      final double j0x = joy0x.abs() < 0.05 ? 0.0 : joy0x;
      final double j0y = joy0y.abs() < 0.05 ? 0.0 : joy0y;
      final double j1x = joy1x.abs() < 0.05 ? 0.0 : joy1x;
      final double j1y = joy1y.abs() < 0.05 ? 0.0 : joy1y;
      payload.addAll([
        ((j0x + 1.0) / 2.0 * 255).clamp(0, 255).toInt(),
        ((j0y + 1.0) / 2.0 * 255).clamp(0, 255).toInt(),
        ((j1x + 1.0) / 2.0 * 255).clamp(0, 255).toInt(),
        ((j1y + 1.0) / 2.0 * 255).clamp(0, 255).toInt(),
      ]);

      // Bytes 9-10: Touchpad mouse delta (128 = no movement)
      final int mouseX = (128 + touchpadDeltaX.clamp(-127, 127)).toInt();
      final int mouseY = (128 + touchpadDeltaY.clamp(-127, 127)).toInt();
      payload.add(mouseX);
      payload.add(mouseY);

      // Byte 11: Mouse click (0=none, 1=left, 2=right, 3=middle)
      int btnMouseClick = 0;
      if (pressedKeys.contains(2001))
        btnMouseClick = 1;
      else if (pressedKeys.contains(2002))
        btnMouseClick = 2;
      else if (pressedKeys.contains(2003))
        btnMouseClick = 3;
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

      // Reset touchpad deltas and click after sending
      touchpadDeltaX = 0.0;
      touchpadDeltaY = 0.0;
      if (!isTouchpadDragging && tpClick != 0) setState(() => tpClick = 0);
    }

    NetworkManager().sendPayloadData(payload);
    if (mounted) setState(() => _lastPayload = payload);
  }

  @override
  void dispose() {
    WakelockPlus.disable();
    _tickController.dispose();
    _accelerometerSub?.cancel();
    _gyroscopeSub?.cancel();
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
            const SnackBar(
              content: Text('Çıkmak için tekrar geri tuşuna basın'),
              duration: Duration(seconds: 2),
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
              if (_debugMode)
                Positioned(
                  top: 40,
                  left: 8,
                  child: IgnorePointer(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.65),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: Colors.greenAccent.withValues(alpha: 0.6),
                        ),
                      ),
                      child: DefaultTextStyle(
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 11,
                          color: Colors.greenAccent,
                          height: 1.5,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text('DEBUG LOG'),
                            Text(
                              'Steer : ${_lastPayload[0].toString().padLeft(3)}  (raw: ${steeringAngle.toStringAsFixed(3)})',
                            ),
                            Text(
                              'Gas   : ${_lastPayload[1].toString().padLeft(3)}  (${(gasPercentage * 100).toStringAsFixed(1)}%)',
                            ),
                            Text(
                              'Brake : ${_lastPayload[2].toString().padLeft(3)}  (${(brakePercentage * 100).toStringAsFixed(1)}%)',
                            ),
                            Text(
                              'Keys1-8 : 0x${_lastPayload[3].toRadixString(16).padLeft(2, "0").toUpperCase()}  [${_lastPayload[3].toRadixString(2).padLeft(8, "0")}]',
                            ),
                            Text(
                              'Keys9-16: 0x${_lastPayload[4].toRadixString(16).padLeft(2, "0").toUpperCase()}  [${_lastPayload[4].toRadixString(2).padLeft(8, "0")}]',
                            ),
                            if (_lastPayload.length >= 9) ...[
                              Text(
                                'Sol Joy X: ${_lastPayload[5].toString().padLeft(3)}  (${joy0x.toStringAsFixed(2)})',
                              ),
                              Text(
                                'Sol Joy Y: ${_lastPayload[6].toString().padLeft(3)}  (${joy0y.toStringAsFixed(2)})',
                              ),
                              Text(
                                'Sağ Joy X: ${_lastPayload[7].toString().padLeft(3)}  (${joy1x.toStringAsFixed(2)})',
                              ),
                              Text(
                                'Sağ Joy Y: ${_lastPayload[8].toString().padLeft(3)}  (${joy1y.toStringAsFixed(2)})',
                              ),
                            ],
                            Text('Bytes: [${_lastPayload.join(", ")}]'),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

              // Debug toggle butonu
              Positioned(
                top: 8,
                left: 8,
                child: GestureDetector(
                  onTap: () => setState(() => _debugMode = !_debugMode),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: _debugMode
                          ? Colors.greenAccent.withValues(alpha: 0.25)
                          : Colors.white.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: _debugMode ? Colors.greenAccent : Colors.white24,
                      ),
                    ),
                    child: Text(
                      _debugMode ? 'DEV LOG' : 'DEV',
                      style: TextStyle(
                        fontSize: 10,
                        color: _debugMode ? Colors.greenAccent : Colors.white38,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
