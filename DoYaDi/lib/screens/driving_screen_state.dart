import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/app_settings.dart';
import '../models/layout5_item.dart';
import '../providers/settings_provider.dart';

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

  PedalTouchState(this.start, this.isGas, this.startTime, {this.tapKey});
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
  int tpFingers = 0;
  bool tpWasTwo = false;
  bool tpWasThree = false;
  DateTime? tpDownTime;
  DateTime? lastTouchpadUpTime;
  bool isTouchpadDragging = false;

  // Mode 5 layout presence flags — determine whether to use 16-byte payload
  bool joystickPresent = false;
  bool touchpadPresent = false;
  bool keyboardKeysPresent = false;

  // Pitch angle computed from accelerometer (degrees) — passed to SteeringPainter
  double pitchDeg = 0.0;

  // Mode 0: single-pointer management (gas or brake)
  int? mod0ActivePointer;
  bool mod0IsGas = false;

  // Basılı tuşlar bitmap (1-16)
  final Set<int> pressedKeys = {};
  final Map<int, Timer> _buttonTimers = {};

  final Map<int, PedalTouchState> activePedals = {};

  // ──────────────────────────────────────────────────────────────────────────
  // Pedal event handlers
  // ──────────────────────────────────────────────────────────────────────────

  void onPedalDown(
    PointerDownEvent e,
    bool isGas, {
    bool forceBarAction = false,
    int? tapKey,
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
    final st = PedalTouchState(e.localPosition, isGas, DateTime.now(), tapKey: tapKey);
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
        final settings = Provider.of<SettingsProvider>(context, listen: false).settings;
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
        // Kısa süre sonra hepsini kaldır (Anlık mod gibi davranır)
        Future.delayed(const Duration(milliseconds: 80), () {
          if (mounted) {
            setState(() {
              for (final k in macroKeys) {
                pressedKeys.remove(k);
              }
            });
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
      } else {
        setState(() => pressedKeys.add(key));
      }
    } else if (mode == 1) {
      // Süreli
      setState(() => pressedKeys.add(key));
      _buttonTimers[key]?.cancel();
      final dur = s.customButtonPressDurationsMs[key] ?? s.globalButtonPressDurationMs;
      _buttonTimers[key] = Timer(Duration(milliseconds: dur), () {
        if (mounted) setState(() => pressedKeys.remove(key));
      });
    } else if (mode == 3) {
      // Hızlı (Tek Tık) - Yalnızca bir anlık basış gönderir
      setState(() => pressedKeys.add(key));
      _buttonTimers[key]?.cancel();
      _buttonTimers[key] = Timer(const Duration(milliseconds: 30), () {
        if (mounted) setState(() => pressedKeys.remove(key));
      });
    } else {
      // Anlık (mode 0)
      setState(() => pressedKeys.add(key));
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
    }
  }

  // Makrolar için (eski 80ms)
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
}
