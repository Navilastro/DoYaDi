import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:provider/provider.dart';
import '../models/app_settings.dart';
import '../models/layout5_item.dart';
import '../providers/settings_provider.dart';
import '../core/haptic_manager.dart';

// ────────────────────────────────────────────────────────────────────────────
// Yardımcı enum
// ────────────────────────────────────────────────────────────────────────────
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

// ────────────────────────────────────────────────────────────────────────────
// Pedal dokunma state'i
// ────────────────────────────────────────────────────────────────────────────
class PedalTouchState {
  Offset start;
  DateTime startTime;
  bool isLocked = false;
  SwipeDir direction = SwipeDir.none;
  int? activeKey;
  bool isGas;
  bool isBarAction = false;
  int? tapKey;
  Map<int, int>? customSwipeKeys;

  PedalTouchState(this.start, this.isGas, this.startTime, {this.tapKey, this.customSwipeKeys});
}

// ────────────────────────────────────────────────────────────────────────────
// Pedal ve input logic mixin — _DrivingScreenState tarafından kullanılır.
// ────────────────────────────────────────────────────────────────────────────
mixin DrivingInputMixin<T extends StatefulWidget> on State<T> {
  double steeringAngle = 0.0;
  double gasPercentage = 0.0;
  double brakePercentage = 0.0;

  // Mode 5: joystick axes
  double joy0x = 0.0;
  double joy0y = 0.0;
  double joy1x = 0.0;
  double joy1y = 0.0;

  // Mode 5: touchpad delta (accumulated each tick, reset after send)
  double touchpadDeltaX = 0.0;
  double touchpadDeltaY = 0.0;
  int tpClick = 0; // 0=none, 1=left, 2=right, 3=middle
  Set<int> tpActivePointers = {};
  int get tpFingers => tpActivePointers.length;
  bool tpWasTwo = false;
  bool tpWasThree = false;
  DateTime? tpDownTime;
  DateTime? lastTouchpadUpTime;
  bool isTouchpadDragging = false;
  double tpTotalMoveDistance = 0.0;
  
  // Touchpad Gestures
  int tpMaxFingers = 0;
  double tpGestureStartX = 0.0;
  double tpGestureStartY = 0.0;
  double tpGestureAccumX = 0.0;
  double tpGestureAccumY = 0.0;

  // Mode 5 layout presence flags — determine whether to use 16-byte payload
  bool leftJoystickPresent = false;
  bool rightJoystickPresent = false;
  bool get joystickPresent => leftJoystickPresent || rightJoystickPresent;
  bool touchpadPresent = false;
  bool keyboardKeysPresent = false;
  
  // Gyro-to-Right Analog (Sol Joystick üzerinde)
  int gyroToRightAnalogMode = 0; // 0=Kapalı, 1=Pilot, 2=FPS
  double gyroRightAnalogSensitivity = 1.0;
  double gyroRightAnalogDeadzone = 7.0;

  // Gyro-to-Mouse (Touchpad üzerinde)
  int gyroToMouseMode = 0; // 0=Kapalı, 1=Pilot, 2=FPS
  double gyroMouseSensitivity = 1.0;
  double gyroMouseDeadzone = 7.0;

  // Sensörle Bakış (Global Ayar) Aktiflik Durumu
  bool get isGyroLookActive {
    final s = Provider.of<SettingsProvider>(context, listen: false).settings;
    if (!s.gyroLookEnabled || s.gyroLookMode == 0) return false;
    
    // Sıfır noktası modunda direksiyon açısı kontrolü
    if (s.gyroLookStyle == 0) {
      // Mod 5'te sol joystick varsa direksiyon kuralı geçersiz
      if (s.defaultDrivingMode == 5 && leftJoystickPresent) return true;
      // Yoksa direksiyon sıfıra yakın olmalı (%5 eşik)
      return steeringAngle.abs() < 0.05;
    }
    
    // TrackPoint modu her zaman aktif
    return true;
  }

  // Mode 5: Joystick item bazlı hassasiyet (sol/sağ ayrı)
  // Layout parse edilirken set edilir. null ise global fallback kullanılır.
  double? leftJoySensitivity;
  double? rightJoySensitivity;

  // Mode 5: Spawn modu — aktif spawn bilgisi (hangi joystick spawn edildi)
  // null = hiçbiri spawn değil, true = sol aktif, false = sağ aktif
  bool? spawnActiveIsLeft;

  // Mode 5/6: pedal icon acceleration state
  double gasPedalIconValue = 0.0;
  double brakePedalIconValue = 0.0;
  bool gasPedalIconPressed = false;
  bool brakePedalIconPressed = false;

  // Debriyaj ve El Freni State
  double clutchPercentage = 0.0;
  double clutchIconValue = 0.0;
  bool clutchIconPressed = false;
  double handbrakePercentage = 0.0;
  bool handbrakePressed = false;

  // Pitch angle computed from accelerometer (degrees) — passed to SteeringPainter
  double pitchDeg = 0.0;

  // Mode 0: single-pointer management (gas or brake)
  int? mod0ActivePointer;
  bool mod0IsGas = false;

  // Basılı tuşlar bitmap (1-16)
  final Set<int> pressedKeys = {};
  final Map<int, Timer> _buttonTimers = {};
  // Hızlı (mode 3): basılı tutulurken tekrar ateşlemeyi engelleyen kilit
  final Set<int> _quickFireLocked = {};

  final Map<int, PedalTouchState> activePedals = {};

  // ──────────────────────────────────────────────────────────────────────────
  // Pedal event handlers
  // ──────────────────────────────────────────────────────────────────────────

  void onPedalDown(
    PointerDownEvent e,
    bool isGas, {
    bool forceBarAction = false,
    int? tapKey,
    Map<int, int>? customSwipeKeys,
  }) {
    if (Provider.of<SettingsProvider>(
          context,
          listen: false,
        ).settings.defaultDrivingMode ==
        0) {
      if (mod0ActivePointer != null) return;
      mod0ActivePointer = e.pointer;
      mod0IsGas = isGas;
    }
    final st = PedalTouchState(
      e.localPosition,
      isGas,
      DateTime.now(),
      tapKey: tapKey,
      customSwipeKeys: customSwipeKeys,
    );
    if (forceBarAction) {
      // Mod 5 barları: yön algılamaya gerek yok, doğrudan bar kontrol
      st.isLocked = true;
      st.isBarAction = true;
      st.direction = SwipeDir.up; // varsayılan: yukarı kaydırma = artar
    }
    activePedals[e.pointer] = st;
  }

  void onPedalMove(PointerMoveEvent e, AppSettings s) {
    final state = activePedals[e.pointer];
    if (state == null) return;

    final delta = e.localPosition - state.start;

    if (!state.isLocked) {
      if (delta.distance > s.clickMaxDistance) {
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
        if (state.customSwipeKeys != null) {
          mappedKey = state.customSwipeKeys![state.direction.index] ?? -1;
        } else if (state.isGas) {
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
          // Gaz bar aksiyonu
          state.isBarAction = true;
          state.isGas = true;
        } else if (mappedKey == -2) {
          // Fren bar aksiyonu
          state.isBarAction = true;
          state.isGas = false;
        } else if (mappedKey > 0) {
          state.activeKey = mappedKey;
          setState(() => pressedKeys.add(mappedKey));
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
            gasPercentage = (gasPercentage + moveDelta).clamp(0.0, 1.0);
          } else {
            brakePercentage = (brakePercentage + moveDelta).clamp(0.0, 1.0);
          }
        });
        // Haptic geri bildirim (bar değer değişiminde)
        final settings = Provider.of<SettingsProvider>(
          context,
          listen: false,
        ).settings;
        HapticManager().triggerLight(settings);
      } else {
        if (state.activeKey != null) {
          if (delta.distance < 10.0) {
            setState(() => pressedKeys.remove(state.activeKey));
            state.activeKey = null;
            state.isLocked = false;
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

  void onPedalUp(PointerEvent e) {
    if (mod0ActivePointer == e.pointer) {
      mod0ActivePointer = null;
    }
    final state = activePedals.remove(e.pointer);
    if (state != null) {
      // TIKLAMAYI ONAYLAMA VEYA REDDETME
      if (!state.isLocked && state.tapKey != null) {
        final settings = Provider.of<SettingsProvider>(
          context,
          listen: false,
        ).settings;
        final dur = DateTime.now().difference(state.startTime);

        if (dur.inMilliseconds < settings.clickMaxDuration * 1000) {
          handleButtonDown(state.tapKey!);
          Future.delayed(const Duration(milliseconds: 50), () {
            if (mounted) handleButtonUp(state.tapKey!);
          });
        }
      }

      setState(() {
        if (state.activeKey != null) {
          pressedKeys.remove(state.activeKey);
        }
        if (state.isGas) {
          gasPercentage = 0.0;
        } else {
          brakePercentage = 0.0;
        }
      });
    }
  }

  final Map<int, Timer> _hapticPeriodicTimers = {};

  void _triggerHapticForButton(int key, bool isDown) {
    final s = Provider.of<SettingsProvider>(context, listen: false).settings;
    final buttonOverride = s.customButtonHapticEnabled[key];
    final isEnabled = buttonOverride ?? s.simulatedHapticEnabled;
    if (!isEnabled) return;

    final type = s.customButtonHapticTypes[key] ?? s.globalHapticType;
    final trigger = s.customButtonHapticTriggers[key] ?? s.globalHapticTrigger;

    if (isDown) {
      if (trigger == 0) {
        // 0: Basılınca (onDown)
        HapticManager().triggerHapticType(s, type, force: true);
      } else if (trigger == 2) {
        // 2: Basıldığı Süre Boyunca (whileHeld)
        _hapticPeriodicTimers[key]?.cancel();
        HapticManager().triggerHapticType(s, type, force: true);
        _hapticPeriodicTimers[key] = Timer.periodic(const Duration(milliseconds: 180), (_) {
          if (mounted) HapticManager().triggerHapticType(s, type, force: true);
        });
      } else if (trigger == 3) {
        // 3: Aktif Olduğu Süre Boyunca (whileActive)
        _hapticPeriodicTimers[key]?.cancel();
        if (pressedKeys.contains(key)) {
          HapticManager().triggerHapticType(s, type, force: true);
          _hapticPeriodicTimers[key] = Timer.periodic(const Duration(milliseconds: 180), (_) {
            if (mounted && pressedKeys.contains(key)) {
              HapticManager().triggerHapticType(s, type, force: true);
            } else {
              _hapticPeriodicTimers[key]?.cancel();
              _hapticPeriodicTimers.remove(key);
            }
          });
        }
      }
    } else {
      // isDown == false
      if (trigger == 1) {
        // 1: Basıldıktan Sonra (onUp)
        HapticManager().triggerHapticType(s, type, force: true);
      }
      if (trigger == 2) {
        _hapticPeriodicTimers[key]?.cancel();
        _hapticPeriodicTimers.remove(key);
      }
      if (trigger == 3 && !pressedKeys.contains(key)) {
        _hapticPeriodicTimers[key]?.cancel();
        _hapticPeriodicTimers.remove(key);
      }
    }
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Key tetikleme
  // ──────────────────────────────────────────────────────────────────────────
  void handleButtonDown(int key) {
    if (key <= 0) return;
    final s = Provider.of<SettingsProvider>(context, listen: false).settings;

    // Parallel Macro: ID >= 3000 olan tuşlar aynı anda basılır
    if (key >= 3000) {
      final macroKeys = s.customMacros[key];
      if (macroKeys != null && macroKeys.isNotEmpty) {
        setState(() {
          for (final k in macroKeys) {
            pressedKeys.add(k);
          }
        });
        _triggerHapticForButton(key, true);
        // Kısa süre sonra hepsini kaldır (Anlık mod gibi davranır)
        Future.delayed(const Duration(milliseconds: 80), () {
          if (mounted) {
            setState(() {
              for (final k in macroKeys) {
                pressedKeys.remove(k);
              }
            });
            _triggerHapticForButton(key, false);
          }
        });
      }
      return;
    }

    final mode = s.customButtonPressModes[key] ?? s.globalButtonPressMode;

    if (mode == 2) {
      // Toggle
      if (pressedKeys.contains(key)) {
        setState(() => pressedKeys.remove(key));
        _triggerHapticForButton(key, false);
      } else {
        setState(() => pressedKeys.add(key));
        _triggerHapticForButton(key, true);
      }
    } else if (mode == 1) {
      // Süreli
      setState(() => pressedKeys.add(key));
      _triggerHapticForButton(key, true);
      _buttonTimers[key]?.cancel();
      final dur =
          s.customButtonPressDurationsMs[key] ?? s.globalButtonPressDurationMs;
      _buttonTimers[key] = Timer(Duration(milliseconds: dur), () {
        if (mounted) setState(() => pressedKeys.remove(key));
      });
    } else if (mode == 3) {
      // Hızlı (Tek Tık) - Parmak basılı tutulduğu sürece tekrar ateşlemez
      if (_quickFireLocked.contains(key)) return;
      _quickFireLocked.add(key);
      setState(() => pressedKeys.add(key));
      _triggerHapticForButton(key, true);
      _buttonTimers[key]?.cancel();
      _buttonTimers[key] = Timer(const Duration(milliseconds: 80), () {
        if (mounted) setState(() => pressedKeys.remove(key));
      });
    } else {
      // Anlık (mode 0)
      setState(() => pressedKeys.add(key));
      _triggerHapticForButton(key, true);
    }
  }

  void handleButtonUp(int key) {
    if (key <= 0) return;
    // Parallel Macro'lar kendi timer'larıyla kapanır, burada bir şey yapmaya gerek yok
    if (key >= 3000) return;
    final s = Provider.of<SettingsProvider>(context, listen: false).settings;
    final mode = s.customButtonPressModes[key] ?? s.globalButtonPressMode;
    if (mode == 0) {
      // Sadece Anlık modda parmak kalkınca hemen kapanır.
      setState(() => pressedKeys.remove(key));
      _triggerHapticForButton(key, false);
    } else if (mode == 3) {
      // Hızlı modda: parmak/tuş kalkınca kilidi aç, yeni basışa izin ver
      _quickFireLocked.remove(key);
      _triggerHapticForButton(key, false);
    }
  }

  // Makrolar için: anlık press + 80ms sonra release
  void fireKey(int key) {
    if (key <= 0) return;
    setState(() => pressedKeys.add(key));
    Future.delayed(const Duration(milliseconds: 80), () {
      if (mounted) setState(() => pressedKeys.remove(key));
    });
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Makro çalıştırma
  // ──────────────────────────────────────────────────────────────────────────
  void executeMacro(List<MacroAction> macro) async {
    for (int i = 0; i < macro.length; i++) {
      final act = macro[i];
      if (act.type == MacroActionType.key) {
        fireKey(act.value.toInt());
      } else if (act.type == MacroActionType.gasPct) {
        setState(() => gasPercentage = act.value);
      } else if (act.type == MacroActionType.brakePct) {
        setState(() => brakePercentage = act.value);
      } else if (act.type == MacroActionType.delay) {
        await Future.delayed(Duration(milliseconds: act.value.toInt()));
      }
    }
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Gesture Macro çalıştırma (Çok parmaklı jestler için)
  // ──────────────────────────────────────────────────────────────────────────
  void fireGestureMacro(List<int> keys) {
    if (keys.isEmpty) return;
    setState(() {
      for (final k in keys) {
        if (k > 0) pressedKeys.add(k);
      }
    });
    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted) {
        setState(() {
          for (final k in keys) {
            if (k > 0) pressedKeys.remove(k);
          }
        });
      }
    });
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Debriyaj İkon İvmelenme Yardımcıları (0 -> %100 ramp-up)
  // ──────────────────────────────────────────────────────────────────────────
  void startClutchIconAcceleration(AppSettings s) {
    if (!clutchIconPressed) return;
    final rate = s.clutchIconAccelerationRate;
    final step = 0.033 / math.max(0.1, rate);

    setState(() {
      clutchIconValue = (clutchIconValue + step).clamp(0.0, 1.0);
      clutchPercentage = clutchIconValue;
    });

    SchedulerBinding.instance.addPostFrameCallback((_) {
      _clutchIconAccelTick(s);
    });
  }

  void _clutchIconAccelTick(AppSettings s) {
    if (!clutchIconPressed || !mounted) return;
    final rate = s.clutchIconAccelerationRate;
    final step = 0.033 / math.max(0.1, rate);

    setState(() {
      clutchIconValue = (clutchIconValue + step).clamp(0.0, 1.0);
      clutchPercentage = clutchIconValue;
    });

    SchedulerBinding.instance.addPostFrameCallback((_) {
      _clutchIconAccelTick(s);
    });
  }
}
