import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../core/network/network_manager.dart';
import '../models/app_settings.dart';
import '../models/layout5_item.dart';
import '../providers/settings_provider.dart';
import '../widgets/driving_painters.dart';
import '../widgets/joystick_widget.dart';

class _PedalState {
  Offset start;
  bool isLocked = false;
  SwipeDir direction = SwipeDir.none;
  int? activeKey;
  bool isGas;
  bool isBarAction = false;
  _PedalState(this.start, this.isGas);
}

// Yardımcı: Tıklama alanı
class _TapZone extends StatefulWidget {
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _TapZone({
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  State<_TapZone> createState() => _TapZoneState();
}

class _TapZoneState extends State<_TapZone> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: (_) {
        setState(() => _pressed = true);
        widget.onTap();
      },
      onPointerUp: (_) => setState(() => _pressed = false),
      onPointerCancel: (_) => setState(() => _pressed = false),
      child: SizedBox(
        width: double.infinity,
        height: double.infinity,
        child: RepaintBoundary(
          child: CustomPaint(
            painter: TapAreaPainter(
              isPressed: _pressed,
              baseColor: widget.color,
              label: widget.label,
            ),
          ),
        ),
      ),
    );
  }
}

// Ana ekran
class DrivingScreen extends StatefulWidget {
  const DrivingScreen({super.key});

  @override
  State<DrivingScreen> createState() => _DrivingScreenState();
}

class _DrivingScreenState extends State<DrivingScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _tickController;

  double _steeringAngle = 0.0;
  double _gasPercentage = 0.0;
  double _brakePercentage = 0.0;

  // Mode 5: joystick axes
  double _joy0x = 0.0;
  double _joy0y = 0.0;
  double _joy1x = 0.0;
  double _joy1y = 0.0;

  // Mode 5: touchpad delta (accumulated each tick, reset after send)
  double _touchpadDeltaX = 0.0;
  double _touchpadDeltaY = 0.0;
  int _tpClick = 0; // 0=none, 1=left, 2=right, 3=middle

  // Mode 5 layout presence flags — determine whether to use 16-byte payload
  bool _joystickPresent = false;
  bool _touchpadPresent = false;
  bool _keyboardKeysPresent =
      false; // any button with keyIndex >= 100 (keyboard key)

  // Pitch angle computed from accelerometer (degrees) — passed to SteeringPainter
  double _pitchDeg = 0.0;

  // Mode 0: single-pointer management (gas or brake)
  int? _mod0ActivePointer;
  bool _mod0IsGas = false;

  // Basılı tuşlar bitmap (1-8)
  final Set<int> _pressedKeys = {};

  final Map<int, _PedalState> _activePedals = {};

  void _onPedalDown(
    PointerDownEvent e,
    bool isGas, {
    bool forceBarAction = false,
  }) {
    if (Provider.of<SettingsProvider>(
          context,
          listen: false,
        ).settings.defaultDrivingMode ==
        0) {
      if (_mod0ActivePointer != null) return;
      _mod0ActivePointer = e.pointer;
      _mod0IsGas = isGas;
    }
    final st = _PedalState(e.localPosition, isGas);
    if (forceBarAction) {
      // Mod 5 barları: yön algılamaya gerek yok, doğrudan bar kontrol
      st.isLocked = true;
      st.isBarAction = true;
      st.direction = SwipeDir.up; // varsayılan: yukarı kaydırma = artar
    }
    _activePedals[e.pointer] = st;
  }

  void _onPedalMove(PointerMoveEvent e, AppSettings s) {
    final state = _activePedals[e.pointer];
    if (state == null) return;

    final delta = e.localPosition - state.start;

    if (!state.isLocked) {
      if (delta.distance > 15.0) {
        state.isLocked = true;
        double angle = math.atan2(delta.dy, delta.dx) * 180 / math.pi;
        if (angle < 0) angle += 360;

        if (angle >= 337.5 || angle < 22.5) {
          state.direction = SwipeDir.right;
        } else if (angle >= 22.5 && angle < 67.5) {
          state.direction = SwipeDir.downRight;
        } else if (angle >= 67.5 && angle < 112.5) {
          state.direction = SwipeDir.down;
        } else if (angle >= 112.5 && angle < 157.5) {
          state.direction = SwipeDir.downLeft;
        } else if (angle >= 157.5 && angle < 202.5) {
          state.direction = SwipeDir.left;
        } else if (angle >= 202.5 && angle < 247.5) {
          state.direction = SwipeDir.upLeft;
        } else if (angle >= 247.5 && angle < 292.5) {
          state.direction = SwipeDir.up;
        } else if (angle >= 292.5 && angle < 337.5) {
          state.direction = SwipeDir.upRight;
        }

        int mappedKey = 0;
        if (state.isGas) {
          switch (state.direction) {
            case SwipeDir.up:
              mappedKey = s.gasSwipeUp;
              break;
            case SwipeDir.down:
              mappedKey = s.gasSwipeDown;
              break;
            case SwipeDir.left:
              mappedKey = s.gasSwipeLeft;
              break;
            case SwipeDir.right:
              mappedKey = s.gasSwipeRight;
              break;
            case SwipeDir.upLeft:
              mappedKey = s.gasSwipeUpLeft;
              break;
            case SwipeDir.upRight:
              mappedKey = s.gasSwipeUpRight;
              break;
            case SwipeDir.downLeft:
              mappedKey = s.gasSwipeDownLeft;
              break;
            case SwipeDir.downRight:
              mappedKey = s.gasSwipeDownRight;
              break;
            default:
              break;
          }
        } else {
          switch (state.direction) {
            case SwipeDir.up:
              mappedKey = s.brakeSwipeUp;
              break;
            case SwipeDir.down:
              mappedKey = s.brakeSwipeDown;
              break;
            case SwipeDir.left:
              mappedKey = s.brakeSwipeLeft;
              break;
            case SwipeDir.right:
              mappedKey = s.brakeSwipeRight;
              break;
            case SwipeDir.upLeft:
              mappedKey = s.brakeSwipeUpLeft;
              break;
            case SwipeDir.upRight:
              mappedKey = s.brakeSwipeUpRight;
              break;
            case SwipeDir.downLeft:
              mappedKey = s.brakeSwipeDownLeft;
              break;
            case SwipeDir.downRight:
              mappedKey = s.brakeSwipeDownRight;
              break;
            default:
              break;
          }
        }

        if (mappedKey == -1) {
          // Gaz bar aksiyonu: tespit edilen yonu koru, hangi bar dolacagini belirt
          state.isBarAction = true;
          state.isGas = true;
        } else if (mappedKey == -2) {
          // Fren bar aksiyonu: tespit edilen yonu koru
          state.isBarAction = true;
          state.isGas = false;
        } else if (mappedKey > 0) {
          state.activeKey = mappedKey;
          setState(() => _pressedKeys.add(mappedKey));
        } else {
          // mappedKey == 0 (Yok): herhangi bir yone kaydirmak bari doldurur
          state.isBarAction = true;
        }
      }
    } else {
      if (state.isBarAction) {
        final moveDelta = _pedalDeltaDir(
          e,
          s.swipeSensitivity,
          state.direction,
        );
        setState(() {
          if (state.isGas) {
            _gasPercentage = (_gasPercentage + moveDelta).clamp(0.0, 1.0);
          } else {
            _brakePercentage = (_brakePercentage + moveDelta).clamp(0.0, 1.0);
          }
        });
      } else {
        if (state.activeKey != null) {
          if (delta.distance < 10.0) {
            setState(() => _pressedKeys.remove(state.activeKey));
            state.activeKey = null;
            state.isLocked = false; // Reset to detect new direction if needed
          }
        }
      }
    }
  }

  double _pedalDeltaDir(PointerMoveEvent e, double sensitivity, SwipeDir dir) {
    final dx = e.delta.dx;
    final dy = e.delta.dy;
    double dot = 0.0;
    switch (dir) {
      case SwipeDir.up:
        dot = -dy;
        break;
      case SwipeDir.down:
        dot = dy;
        break;
      case SwipeDir.left:
        dot = -dx;
        break;
      case SwipeDir.right:
        dot = dx;
        break;
      case SwipeDir.upLeft:
        dot = -dx - dy;
        break;
      case SwipeDir.upRight:
        dot = dx - dy;
        break;
      case SwipeDir.downLeft:
        dot = -dx + dy;
        break;
      case SwipeDir.downRight:
        dot = dx + dy;
        break;
      default:
        dot = -dy;
        break;
    }
    if (dir == SwipeDir.upLeft ||
        dir == SwipeDir.upRight ||
        dir == SwipeDir.downLeft ||
        dir == SwipeDir.downRight) {
      dot = dot * 0.7071;
    }
    return dot / sensitivity;
  }

  void _onPedalUp(PointerEvent e) {
    if (_mod0ActivePointer == e.pointer) {
      _mod0ActivePointer = null;
    }
    final state = _activePedals.remove(e.pointer);
    if (state != null) {
      setState(() {
        if (state.activeKey != null) {
          _pressedKeys.remove(state.activeKey);
        }
        if (state.isGas) {
          _gasPercentage = 0.0;
        } else {
          _brakePercentage = 0.0;
        }
      });
    }
  }

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

    // Hardware ses tu┼şu dinleyici
    _volumeChannel.setMethodCallHandler((call) async {
      if (call.method == 'key_event') {
        final settings = Provider.of<SettingsProvider>(
          context,
          listen: false,
        ).settings;
        final String event = call.arguments as String;
        if (event == 'volume_up' && settings.volumeUpAction > 0)
          _fireKey(settings.volumeUpAction);
        if (event == 'volume_down' && settings.volumeDownAction > 0)
          _fireKey(settings.volumeDownAction);
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

      // Hassasiyet sınırları (Kendine göre bu ayarları ufak ufak değiştirebilirsin)
      double minMultiplier = 0.4; // En düşük hassasiyet (Ağır direksiyon)
      double maxMultiplier = 2.5; // En yüksek hassasiyet (Hızlı direksiyon)

      if (pitch >= 50.0 && pitch <= 70.0) {
        // İnce Ayar Bölgesi: 50'de en düşük (0.4), 70'te normal (1.0) olur.
        double t = (pitch - 50.0) / (70.0 - 50.0); // 0 ile 1 arası oran
        multiplier = minMultiplier + (t * (1.0 - minMultiplier));
      } else if (pitch >= 110.0 && pitch <= 130.0) {
        // Agresif Dönüş Bölgesi: 110'da normal (1.0), 130'da en yüksek (2.5) olur.
        double t = (pitch - 110.0) / (130.0 - 110.0); // 0 ile 1 arası oran
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

      _steeringAngle = normalized;
    });

    if (settings.useGyroscope) {
      _gyroscopeSub = gyroscopeEventStream().listen((_) {});
    }
  }

  void _onTick() {
    // 5-byte protocol
    // Byte 0: Steering (-1.0 to 1.0) mapped to 0-255 (128 = center)
    int steerByte = ((_steeringAngle + 1.0) / 2.0 * 255).clamp(0, 255).toInt();

    // Byte 1: Gas (0.0 to 1.0) mapped to 0-255
    int gasByte = (_gasPercentage * 255).clamp(0, 255).toInt();

    // Byte 2: Brake (0.0 to 1.0) mapped to 0-255
    int brakeByte = (_brakePercentage * 255).clamp(0, 255).toInt();

    // Byte 3: Keys 1-8 bitmask
    int keys1to8 = 0;
    for (int i = 1; i <= 8; i++) {
      if (_pressedKeys.contains(i)) keys1to8 |= (1 << (i - 1));
    }

    // Byte 4: Keys 9-16 bitmask
    int keys9to16 = 0;
    for (int i = 9; i <= 16; i++) {
      if (_pressedKeys.contains(i)) keys9to16 |= (1 << (i - 9));
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
        _joystickPresent || _touchpadPresent || _keyboardKeysPresent;

    if (useExtended) {
      // Bytes 5-8: Joystick axes (128 = neutral when no joystick present)
      final double j0x = _joy0x.abs() < 0.05 ? 0.0 : _joy0x;
      final double j0y = _joy0y.abs() < 0.05 ? 0.0 : _joy0y;
      final double j1x = _joy1x.abs() < 0.05 ? 0.0 : _joy1x;
      final double j1y = _joy1y.abs() < 0.05 ? 0.0 : _joy1y;
      payload.addAll([
        ((j0x + 1.0) / 2.0 * 255).clamp(0, 255).toInt(),
        ((j0y + 1.0) / 2.0 * 255).clamp(0, 255).toInt(),
        ((j1x + 1.0) / 2.0 * 255).clamp(0, 255).toInt(),
        ((j1y + 1.0) / 2.0 * 255).clamp(0, 255).toInt(),
      ]);

      // Bytes 9-10: Touchpad mouse delta (128 = no movement)
      final int mouseX = (128 + _touchpadDeltaX.clamp(-127, 127)).toInt();
      final int mouseY = (128 + _touchpadDeltaY.clamp(-127, 127)).toInt();
      payload.add(mouseX);
      payload.add(mouseY);

      // Byte 11: Mouse click (0=none, 1=left, 2=right, 3=middle)
      payload.add(_tpClick);

      // Bytes 12-15: Keyboard keys (VK codes for keys with ID >= 100, up to 4 simultaneous)
      final List<int> kbKeys = _pressedKeys
          .where((k) => k >= 100)
          .take(4)
          .toList();
      while (kbKeys.length < 4) kbKeys.add(0);
      payload.addAll(kbKeys);

      // Reset touchpad deltas and click after sending
      _touchpadDeltaX = 0.0;
      _touchpadDeltaY = 0.0;
      if (_tpClick != 0) setState(() => _tpClick = 0);
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

  // Key tetikleme
  void _fireKey(int key) {
    setState(() => _pressedKeys.add(key));
    Future.delayed(const Duration(milliseconds: 80), () {
      if (mounted) setState(() => _pressedKeys.remove(key));
    });
  }

  //UI
  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<SettingsProvider>(context).settings;
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: settings.backgroundColor,
      body: Stack(
        children: [
          // Ana layout
          Positioned.fill(child: _buildLayout(settings, size)),

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
                    angle: _steeringAngle,
                    pitch: _pitchDeg,
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
                          'Steer : ${_lastPayload[0].toString().padLeft(3)}  (raw: ${_steeringAngle.toStringAsFixed(3)})',
                        ),
                        Text(
                          'Gas   : ${_lastPayload[1].toString().padLeft(3)}  (${(_gasPercentage * 100).toStringAsFixed(1)}%)',
                        ),
                        Text(
                          'Brake : ${_lastPayload[2].toString().padLeft(3)}  (${(_brakePercentage * 100).toStringAsFixed(1)}%)',
                        ),
                        Text(
                          'Keys1-8 : 0x${_lastPayload[3].toRadixString(16).padLeft(2, "0").toUpperCase()}  [${_lastPayload[3].toRadixString(2).padLeft(8, "0")}]',
                        ),
                        Text(
                          'Keys9-16: 0x${_lastPayload[4].toRadixString(16).padLeft(2, "0").toUpperCase()}  [${_lastPayload[4].toRadixString(2).padLeft(8, "0")}]',
                        ),
                        if (_lastPayload.length >= 9) ...[
                          Text(
                            'Sol Joy X: ${_lastPayload[5].toString().padLeft(3)}  (${_joy0x.toStringAsFixed(2)})',
                          ),
                          Text(
                            'Sol Joy Y: ${_lastPayload[6].toString().padLeft(3)}  (${_joy0y.toStringAsFixed(2)})',
                          ),
                          Text(
                            'Sağ Joy X: ${_lastPayload[7].toString().padLeft(3)}  (${_joy1x.toStringAsFixed(2)})',
                          ),
                          Text(
                            'Sağ Joy Y: ${_lastPayload[8].toString().padLeft(3)}  (${_joy1y.toStringAsFixed(2)})',
                          ),
                        ],
                        Text('Bytes: [${_lastPayload.join(", ")}]'),
                      ],
                    ),
                  ),
                ),
              ),
            ),

          // Çıkış butonu
          Positioned(
            top: 8,
            right: 8,
            child: IconButton(
              icon: const Icon(Icons.close, color: Colors.white54, size: 28),
              onPressed: () => Navigator.pop(context),
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
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
    );
  }

  Widget _buildLayout(AppSettings settings, Size size) {
    switch (settings.defaultDrivingMode) {
      case 0:
        return _buildMode0(settings, size);
      case 1:
        return _buildMode1(settings, size);
      case 2:
        return _buildMode2(settings, size);
      case 3:
        return _buildMode3(settings, size);
      case 4:
        return _buildMode4(settings, size);
      case 5:
        return _buildMode5(settings, size);
      default:
        return _buildMode0(settings, size);
    }
  }

  // MOD 0: Tek ekran, orta ├ğizgiden sağ-gaz sol-fren
  // Aynı anda sadece biri (gaz VEYA fren), ama tuşlara aynı anda basılabilir.
  // Yardımcı: herhangi yöne kaydırmadan pedal delta hesapla
  // Parmak hangi yöne giderse gitsin hareketin büyüklüğünü al,
  // işaret olarak dikey bileşeni (dy) kullan.
  // Yukarı doğru artı, Aşağı doğru eksi.  (Bar aşağıdan yukarı doğru doluyor.)
  double _pedalDelta(PointerMoveEvent e, double sensitivity) {
    final dx = e.delta.dx;
    final dy = e.delta.dy;
    final magnitude = math.sqrt(dx * dx + dy * dy);
    // dy < 0 = upward = pedal increases (+), dy >= 0 = downward = pedal decreases (-)
    final sign = dy <= 0 ? 1.0 : -1.0;
    return sign * magnitude / sensitivity;
  }

  Widget _buildMode0(AppSettings s, Size size) {
    return Stack(
      children: [
        // Full-screen Listener for gas/brake
        Positioned.fill(
          child: Listener(
            onPointerDown: (e) =>
                _onPedalDown(e, e.localPosition.dx >= size.width / 2),
            onPointerMove: (e) => _onPedalMove(e, s),
            onPointerUp: _onPedalUp,
            onPointerCancel: _onPedalUp,
            child: RepaintBoundary(
              child: CustomPaint(
                painter: _Mode0Painter(
                  gasPercentage: _gasPercentage,
                  brakePercentage: _brakePercentage,
                  isGas: _mod0IsGas,
                  hasActive: _mod0ActivePointer != null,
                  gasColor: s.gasColor,
                  brakeColor: s.brakeColor,
                  bgColor: s.pedalBgColor,
                  yetsoreColor: s.yetsoreColor,
                ),
                child: const SizedBox.expand(),
              ),
            ),
          ),
        ),

        // Left-half tap zone
        Positioned(
          left: 0,
          top: 0,
          width: size.width / 2,
          height: size.height,
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTap: () => _fireKey(s.m0TapLeft),
            child: const SizedBox.expand(),
          ),
        ),

        // Right-half tap zone
        Positioned(
          left: size.width / 2,
          top: 0,
          width: size.width / 2,
          height: size.height,
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTap: () => _fireKey(s.m0TapRight),
            child: const SizedBox.expand(),
          ),
        ),

        // Center divider line
        Positioned(
          left: size.width / 2 - 1,
          top: 0,
          bottom: 0,
          width: 2,
          child: Container(color: Colors.white12),
        ),
      ],
    );
  }

  Widget _buildMode1(AppSettings s, Size size) {
    return Row(
      children: [
        // Left side - Brake
        Expanded(
          child: Stack(
            children: [
              Positioned.fill(
                child: Listener(
                  behavior: HitTestBehavior.opaque,
                  onPointerDown: (e) => _onPedalDown(e, false),
                  onPointerMove: (e) => _onPedalMove(e, s),
                  onPointerUp: _onPedalUp,
                  onPointerCancel: _onPedalUp,
                  child: RepaintBoundary(
                    child: CustomPaint(
                      painter: PedalPainter(
                        fillPercentage: _brakePercentage,
                        baseColor: s.brakeColor,
                        bgColor: s.pedalBgColor,
                        yetsoreColor: s.yetsoreColor,
                      ),
                      child: const SizedBox.expand(),
                    ),
                  ),
                ),
              ),
              // Tap alanı
              Positioned.fill(
                child: Listener(
                  behavior: HitTestBehavior.translucent,
                  onPointerDown: (_) => _fireKey(s.m1TapLeft),
                  child: const SizedBox.expand(),
                ),
              ),
            ],
          ),
        ),
        // Right side - Gas
        Expanded(
          child: Stack(
            children: [
              Positioned.fill(
                child: Listener(
                  behavior: HitTestBehavior.opaque,
                  onPointerDown: (e) => _onPedalDown(e, true),
                  onPointerMove: (e) => _onPedalMove(e, s),
                  onPointerUp: _onPedalUp,
                  onPointerCancel: _onPedalUp,
                  child: RepaintBoundary(
                    child: CustomPaint(
                      painter: PedalPainter(
                        fillPercentage: _gasPercentage,
                        baseColor: s.gasColor,
                        bgColor: s.pedalBgColor,
                        yetsoreColor: s.yetsoreColor,
                      ),
                      child: const SizedBox.expand(),
                    ),
                  ),
                ),
              ),
              // Tap overlay
              Positioned.fill(
                child: Listener(
                  behavior: HitTestBehavior.translucent,
                  onPointerDown: (_) => _fireKey(s.m1TapRight),
                  child: const SizedBox.expand(),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // MOD 2: %30 Fren | %40 Orta 2x2 kare butonlar | %30 Gaz
  Widget _buildMode2(AppSettings s, Size size) {
    return Row(
      children: [
        SizedBox(
          width: size.width * 0.30,
          child: _buildPedalColumn(s, isBrake: true, tapKey: s.m2TapLeft),
        ),
        SizedBox(
          width: size.width * 0.40,
          child: _buildMiddle2x2(
            s,
            k1: s.m2Key1,
            k2: s.m2Key2,
            k3: s.m2Key3,
            k4: s.m2Key4,
          ),
        ),
        SizedBox(
          width: size.width * 0.30,
          child: _buildPedalColumn(s, isBrake: false, tapKey: s.m2TapRight),
        ),
      ],
    );
  }

  // MOD 3: Mod 2 + Orta alt ek tuş
  Widget _buildMode3(AppSettings s, Size size) {
    return Row(
      children: [
        SizedBox(
          width: size.width * 0.30,
          child: _buildPedalColumn(s, isBrake: true, tapKey: s.m3TapLeft),
        ),
        SizedBox(
          width: size.width * 0.40,
          child: _buildMiddle2x2(
            s,
            k1: s.m3Key1,
            k2: s.m3Key2,
            k3: s.m3Key3,
            k4: s.m3Key4,
            k5: s.m3Key5,
          ),
        ),
        SizedBox(
          width: size.width * 0.30,
          child: _buildPedalColumn(s, isBrake: false, tapKey: s.m3TapRight),
        ),
      ],
    );
  }

  // MOD 4: Mod 3 ama Tuş 7 ekran genişliğinde en altta
  Widget _buildMode4(AppSettings s, Size size) {
    return Column(
      children: [
        Expanded(
          child: Row(
            children: [
              SizedBox(
                width: size.width * 0.30,
                child: _buildPedalColumn(s, isBrake: true, tapKey: s.m4TapLeft),
              ),
              SizedBox(
                width: size.width * 0.40,
                child: _buildMiddle2x2(
                  s,
                  k1: s.m4Key1,
                  k2: s.m4Key2,
                  k3: s.m4Key3,
                  k4: s.m4Key4,
                ),
              ),
              SizedBox(
                width: size.width * 0.30,
                child: _buildPedalColumn(
                  s,
                  isBrake: false,
                  tapKey: s.m4TapRight,
                ),
              ),
            ],
          ),
        ),
        // Alt tam genişlik tuş
        SizedBox(
          height: size.height * 0.18,
          child: _TapZone(
            label: 'Tuş ${s.m4KeyBottom}',
            color: s.detailColor,
            onTap: () => _fireKey(s.m4KeyBottom),
          ),
        ),
      ],
    );
  }

  // MOD 5: Özel Tasarım (JSON'dan)
  Widget _buildMode5(AppSettings s, Size size) {
    if (s.customLayout5Json == null || s.customLayout5Json!.isEmpty) {
      return Center(
        child: Text(
          'Lütfen ayarlar ekranından\nMod 5 düzenlemesi yapın ve kaydedin.',
          style: TextStyle(color: s.detailColor, fontSize: 18),
          textAlign: TextAlign.center,
        ),
      );
    }
    List<Layout5Item> items = [];
    try {
      final list = jsonDecode(s.customLayout5Json!) as List;
      items = list
          .map((e) => Layout5Item.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return Center(
        child: Text(
          'Tasarım yüklenemedi. Lütfen tekrar düzenleyin.',
          style: TextStyle(color: s.detailColor),
        ),
      );
    }

    // Detect which advanced items are present — determines whether to use 16-byte payload
    final bool hasJoy = items.any(
      (e) =>
          e.type == Layout5ItemType.leftJoystick ||
          e.type == Layout5ItemType.rightJoystick,
    );
    final bool hasTouchpad = items.any(
      (e) => e.type == Layout5ItemType.touchpad,
    );
    final bool hasKbKeys = items.any(
      (e) =>
          (e.type == Layout5ItemType.buttonSquare ||
              e.type == Layout5ItemType.buttonSoft ||
              e.type == Layout5ItemType.buttonCircle) &&
          e.keyIndex >= 100,
    );

    if (_joystickPresent != hasJoy ||
        _touchpadPresent != hasTouchpad ||
        _keyboardKeysPresent != hasKbKeys) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() {
            _joystickPresent = hasJoy;
            _touchpadPresent = hasTouchpad;
            _keyboardKeysPresent = hasKbKeys;
          });
        }
      });
    }

    return Stack(
      children: items.map((item) => _buildMode5Item(item, s, size)).toList(),
    );
  }

  Widget _buildMode5Item(Layout5Item item, AppSettings s, Size size) {
    final double l = item.left * size.width;
    final double t = item.top * size.height;
    final double w = item.width * size.width;
    final double h = item.height * size.height;

    Widget content;
    switch (item.type) {
      case Layout5ItemType.leftJoystick:
        content = JoystickWidget(
          radius: math.min(w, h) / 2,
          baseColor: item.bgColor,
          thumbColor: item.textColor,
          onChanged: (x, y) {
            setState(() {
              _joy0x = x;
              _joy0y = y;
            });
          },
        );
        break;
      case Layout5ItemType.rightJoystick:
        content = JoystickWidget(
          radius: math.min(w, h) / 2,
          baseColor: item.bgColor,
          thumbColor: item.textColor,
          onChanged: (x, y) {
            setState(() {
              _joy1x = x;
              _joy1y = y;
            });
          },
        );
        break;
      case Layout5ItemType.gasBar:
        content = Listener(
          onPointerDown: (e) => _onPedalDown(e, true, forceBarAction: true),
          onPointerMove: (e) => _onPedalMove(e, s),
          onPointerUp: _onPedalUp,
          onPointerCancel: _onPedalUp,
          child: RepaintBoundary(
            child: CustomPaint(
              painter: PedalPainter(
                fillPercentage: _gasPercentage,
                baseColor: s.gasColor,
                bgColor: item.bgColor,
                yetsoreColor: s.yetsoreColor,
              ),
            ),
          ),
        );
        break;
      case Layout5ItemType.brakeBar:
        content = Listener(
          onPointerDown: (e) => _onPedalDown(e, false, forceBarAction: true),
          onPointerMove: (e) => _onPedalMove(e, s),
          onPointerUp: _onPedalUp,
          onPointerCancel: _onPedalUp,
          child: RepaintBoundary(
            child: CustomPaint(
              painter: PedalPainter(
                fillPercentage: _brakePercentage,
                baseColor: s.brakeColor,
                bgColor: item.bgColor,
                yetsoreColor: s.yetsoreColor,
              ),
            ),
          ),
        );
        break;
      case Layout5ItemType.buttonSquare:
      case Layout5ItemType.buttonSoft:
      case Layout5ItemType.buttonCircle:
        final label = item.label ?? 'Buton';
        BorderRadius radius;
        if (item.type == Layout5ItemType.buttonSoft) {
          radius = BorderRadius.circular(16);
        } else if (item.type == Layout5ItemType.buttonCircle) {
          radius = BorderRadius.circular(math.min(w, h) / 2);
        } else {
          radius = BorderRadius.circular(4);
        }

        content = GestureDetector(
          onTapDown: (_) {
            if (item.mode == ButtonMode.key) {
              _fireKey(item.keyIndex);
            } else if (item.mode == ButtonMode.gasPct) {
              setState(() => _gasPercentage = item.modeValue);
            } else if (item.mode == ButtonMode.brakePct) {
              setState(() => _brakePercentage = item.modeValue);
            } else if (item.mode == ButtonMode.macro) {
              _executeMacro(item.macro);
            }
          },
          onTapUp: (_) {
            if (item.mode == ButtonMode.gasPct)
              setState(() => _gasPercentage = 0.0);
            if (item.mode == ButtonMode.brakePct)
              setState(() => _brakePercentage = 0.0);
          },
          onTapCancel: () {
            if (item.mode == ButtonMode.gasPct)
              setState(() => _gasPercentage = 0.0);
            if (item.mode == ButtonMode.brakePct)
              setState(() => _brakePercentage = 0.0);
          },
          child: Container(
            decoration: BoxDecoration(
              color: item.bgColor,
              borderRadius: radius,
              border: Border.all(color: item.textColor.withValues(alpha: 0.3)),
            ),
            child: Center(
              child: Text(
                label,
                style: TextStyle(
                  color: item.textColor,
                  fontSize: math.min(w, h) * 0.18,
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        );
        break;
      case Layout5ItemType.touchpad:
        // Touchpad: accumulates mouse delta; click type determined by finger count
        int _tpFingers = 0;
        bool _tpWasTwo = false;
        bool _tpWasThree = false;
        DateTime? _tpDownTime;
        content = Listener(
          behavior: HitTestBehavior.opaque,
          onPointerDown: (e) {
            _tpFingers++;
            if (_tpFingers == 1) _tpDownTime = DateTime.now();
            if (_tpFingers == 2) _tpWasTwo = true;
            if (_tpFingers >= 3) _tpWasThree = true;
          },
          onPointerMove: (e) {
            // Accumulate delta — sent in _onTick bytes 9-10
            _touchpadDeltaX += e.delta.dx;
            _touchpadDeltaY += e.delta.dy;
          },
          onPointerUp: (e) {
            _tpFingers--;
            if (_tpFingers <= 0) {
              _tpFingers = 0;
              final dur = _tpDownTime != null
                  ? DateTime.now().difference(_tpDownTime!)
                  : const Duration(seconds: 1);
              if (dur.inMilliseconds < 250) {
                // Short tap — determine click type by finger count
                setState(() {
                  if (_tpWasThree) {
                    _tpClick = 3; // middle click
                  } else if (_tpWasTwo) {
                    _tpClick = 2; // right click
                  } else {
                    _tpClick = 1; // left click
                  }
                });
              }
              _tpWasTwo = false;
              _tpWasThree = false;
              _tpDownTime = null;
            }
          },
          onPointerCancel: (e) {
            _tpFingers = 0;
            _tpWasTwo = false;
            _tpWasThree = false;
            _tpDownTime = null;
          },
          child: Container(
            decoration: BoxDecoration(
              color: item.bgColor,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: item.textColor.withValues(alpha: 0.3)),
            ),
            child: Center(
              child: Icon(
                Icons.mouse,
                color: item.textColor.withValues(alpha: 0.4),
                size: math.min(w, h) * 0.35,
              ),
            ),
          ),
        );
        break;
    }

    return Positioned(
      left: l,
      top: t,
      width: w,
      height: h,
      child: Transform.rotate(angle: item.rotation, child: content),
    );
  }

  void _executeMacro(List<MacroAction> macro) async {
    for (int i = 0; i < macro.length; i++) {
      final act = macro[i];

      if (act.type == MacroActionType.key) {
        _fireKey(act.value.toInt());
      } else if (act.type == MacroActionType.gasPct) {
        setState(() => _gasPercentage = act.value);
      } else if (act.type == MacroActionType.brakePct) {
        setState(() => _brakePercentage = act.value);
      } else if (act.type == MacroActionType.delay) {
        await Future.delayed(Duration(milliseconds: act.value.toInt()));
      }
    }
  }

  // Helper: Pedal column (brake or gas)
  Widget _buildPedalColumn(
    AppSettings s, {
    required bool isBrake,
    required int tapKey,
  }) {
    return Stack(
      children: [
        Positioned.fill(
          child: Listener(
            behavior: HitTestBehavior.opaque,
            onPointerDown: (e) => _onPedalDown(e, !isBrake),
            onPointerMove: (e) => _onPedalMove(e, s),
            onPointerUp: _onPedalUp,
            onPointerCancel: _onPedalUp,
            child: RepaintBoundary(
              child: CustomPaint(
                painter: PedalPainter(
                  fillPercentage: isBrake ? _brakePercentage : _gasPercentage,
                  baseColor: isBrake ? s.brakeColor : s.gasColor,
                  bgColor: s.pedalBgColor,
                  yetsoreColor: s.yetsoreColor,
                ),
                child: const SizedBox.expand(),
              ),
            ),
          ),
        ),
        // Tap overlay
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTap: () => _fireKey(tapKey),
            child: const SizedBox.expand(),
          ),
        ),
      ],
    );
  }

  // Helper: 2x2 center grid (Keys 3-6) + optional Key 7
  Widget _buildMiddle2x2(
    AppSettings s, {
    required int k1,
    required int k2,
    required int k3,
    required int k4,
    int? k5,
  }) {
    final color = s.detailColor;
    return Column(
      children: [
        Expanded(
          child: Row(
            children: [
              Expanded(
                child: _TapZone(
                  label: 'Tuş $k1',
                  color: color,
                  onTap: () => _fireKey(k1),
                ),
              ),
              Expanded(
                child: _TapZone(
                  label: 'Tuş $k2',
                  color: color,
                  onTap: () => _fireKey(k2),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: Row(
            children: [
              Expanded(
                child: _TapZone(
                  label: 'Tuş $k3',
                  color: color,
                  onTap: () => _fireKey(k3),
                ),
              ),
              Expanded(
                child: _TapZone(
                  label: 'Tuş $k4',
                  color: color,
                  onTap: () => _fireKey(k4),
                ),
              ),
            ],
          ),
        ),
        if (k5 != null)
          Expanded(
            child: _TapZone(
              label: 'Tuş $k5',
              color: color,
              onTap: () => _fireKey(k5),
            ),
          ),
      ],
    );
  }
}

// Mod 0 özel painter ÔÇö tam ekran, gaz veya fren rengi
class _Mode0Painter extends CustomPainter {
  final double gasPercentage;
  final double brakePercentage;
  final bool isGas;
  final bool hasActive;
  final Color gasColor;
  final Color brakeColor;
  final Color bgColor;
  final Color yetsoreColor;

  _Mode0Painter({
    required this.gasPercentage,
    required this.brakePercentage,
    required this.isGas,
    required this.hasActive,
    required this.gasColor,
    required this.brakeColor,
    required this.bgColor,
    required this.yetsoreColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Arka plan
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..color = bgColor,
    );

    if (!hasActive) return;

    final double pct = isGas ? gasPercentage : brakePercentage;
    final Color baseColor = isGas ? gasColor : brakeColor;

    if (pct <= 0) return;

    final double fillH = size.height * pct;
    canvas.drawRect(
      Rect.fromLTWH(0, size.height - fillH, size.width, fillH),
      Paint()..color = baseColor,
    );

    // Yetsore
    if (pct >= 0.7) {
      final double fraction = ((pct - 0.7) / 0.3).clamp(0.0, 1.0);
      final double yH = fraction * size.height * 0.20;
      if (yH > 0) {
        canvas.drawRect(
          Rect.fromLTWH(0, size.height - yH, size.width, yH),
          Paint()..color = yetsoreColor,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _Mode0Painter old) =>
      old.gasPercentage != gasPercentage ||
      old.brakePercentage != brakePercentage ||
      old.isGas != isGas ||
      old.hasActive != hasActive;
}
