import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import '../models/app_settings.dart';
import '../models/layout5_item.dart';
import '../models/joystick_mode.dart';
import '../widgets/driving_painters.dart';
import '../widgets/dynamic_steering_painter.dart';
import '../widgets/driving_tap_zone.dart';
import '../widgets/joystick_widget.dart';
import '../widgets/joystick/joystick_spawn_layer.dart';
import '../screens/driving_screen_state.dart';
import '../core/utils/app_translations.dart';
import '../core/sensor_manager.dart';
import '../core/haptic_manager.dart';

/// Tüm mod build metodlarını barındıran mixin.
/// DrivingInputMixin ile birlikte kullanılır.
mixin DrivingModeBuildMixin<T extends StatefulWidget>
    on State<T>, DrivingInputMixin<T> {
  Widget buildLayout(AppSettings settings, Size size) {
    switch (settings.defaultDrivingMode) {
      case 0:
        return buildMode0(settings, size);
      case 1:
        return buildMode1(settings, size);
      case 2:
        return buildMode2(settings, size);
      case 3:
        return buildMode3(settings, size);
      case 4:
        return buildMode4(settings, size);
      case 5:
        return buildMode5(settings, size);
      case 6:
        return buildMode6(settings, size);
      default:
        return buildMode0(settings, size);
    }
  }

  // ──────────────────────────────────────────────────────────────────────────
  // MOD 0: Tek ekran, orta çizgiden sağ-gaz sol-fren
  // ──────────────────────────────────────────────────────────────────────────
  Widget buildMode0(AppSettings s, Size size) {
    return Stack(
      children: [
        // Tam ekran Listener — gaz/fren
        Positioned.fill(
          child: Listener(
            behavior: HitTestBehavior.opaque,
            onPointerDown: (e) => onPedalDown(
              e,
              e.localPosition.dx >= size.width / 2,
              tapKey: e.localPosition.dx >= size.width / 2 ? s.gasTap : s.brakeTap,
            ),
            onPointerMove: (e) => onPedalMove(e, s),
            onPointerUp: onPedalUp,
            onPointerCancel: onPedalUp,
            child: RepaintBoundary(
              child: CustomPaint(
                painter: Mode0Painter(
                  gasPercentage: gasPercentage,
                  brakePercentage: brakePercentage,
                  isGas: mod0IsGas,
                  hasActive: mod0ActivePointer != null,
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

  // ──────────────────────────────────────────────────────────────────────────
  // MOD 1: Sol Fren | Sağ Gaz
  // ──────────────────────────────────────────────────────────────────────────
  Widget buildMode1(AppSettings s, Size size) {
    return Row(
      children: [
        // Left side - Brake
        Expanded(
          child: Stack(
            children: [
              Positioned.fill(
                child: Listener(
                  behavior: HitTestBehavior.opaque,
                  onPointerDown: (e) => onPedalDown(e, false, tapKey: s.brakeTap),
                  onPointerMove: (e) => onPedalMove(e, s),
                  onPointerUp: onPedalUp,
                  onPointerCancel: onPedalUp,
                  child: RepaintBoundary(
                    child: CustomPaint(
                      painter: PedalPainter(
                        fillPercentage: brakePercentage,
                        baseColor: s.brakeColor,
                        bgColor: s.pedalBgColor,
                        yetsoreColor: s.yetsoreColor,
                      ),
                      child: const SizedBox.expand(),
                    ),
                  ),
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
                  onPointerDown: (e) => onPedalDown(e, true, tapKey: s.gasTap),
                  onPointerMove: (e) => onPedalMove(e, s),
                  onPointerUp: onPedalUp,
                  onPointerCancel: onPedalUp,
                  child: RepaintBoundary(
                    child: CustomPaint(
                      painter: PedalPainter(
                        fillPercentage: gasPercentage,
                        baseColor: s.gasColor,
                        bgColor: s.pedalBgColor,
                        yetsoreColor: s.yetsoreColor,
                      ),
                      child: const SizedBox.expand(),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ──────────────────────────────────────────────────────────────────────────
  // MOD 2: %30 Fren | %40 Orta 2x2 kare butonlar | %30 Gaz
  // ──────────────────────────────────────────────────────────────────────────
  Widget buildMode2(AppSettings s, Size size) {
    return Row(
      children: [
        SizedBox(
          width: size.width * 0.30,
          child: buildPedalColumn(s, isBrake: true, tapKey: s.brakeTap),
        ),
        SizedBox(
          width: size.width * 0.40,
          child: buildMiddle2x2(
            s,
            k1: s.m2Key1,
            k2: s.m2Key2,
            k3: s.m2Key3,
            k4: s.m2Key4,
          ),
        ),
        SizedBox(
          width: size.width * 0.30,
          child: buildPedalColumn(s, isBrake: false, tapKey: s.gasTap),
        ),
      ],
    );
  }

  // ──────────────────────────────────────────────────────────────────────────
  // MOD 3: Mod 2 + Orta alt ek tuş
  // ──────────────────────────────────────────────────────────────────────────
  Widget buildMode3(AppSettings s, Size size) {
    return Row(
      children: [
        SizedBox(
          width: size.width * 0.30,
          child: buildPedalColumn(s, isBrake: true, tapKey: s.brakeTap),
        ),
        SizedBox(
          width: size.width * 0.40,
          child: buildMiddle2x2(
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
          child: buildPedalColumn(s, isBrake: false, tapKey: s.gasTap),
        ),
      ],
    );
  }

  // ──────────────────────────────────────────────────────────────────────────
  // MOD 4: Mod 3 ama alt tam genişlik tuş
  // ──────────────────────────────────────────────────────────────────────────
  Widget buildMode4(AppSettings s, Size size) {
    return Column(
      children: [
        Expanded(
          child: Row(
            children: [
              SizedBox(
                width: size.width * 0.30,
                child: buildPedalColumn(s, isBrake: true, tapKey: s.brakeTap),
              ),
              SizedBox(
                width: size.width * 0.40,
                child: buildMiddle2x2(
                  s,
                  k1: s.m4Key1,
                  k2: s.m4Key2,
                  k3: s.m4Key3,
                  k4: s.m4Key4,
                ),
              ),
              SizedBox(
                width: size.width * 0.30,
                child: buildPedalColumn(
                  s,
                  isBrake: false,
                  tapKey: s.gasTap,
                ),
              ),
            ],
          ),
        ),
        // Alt tam genişlik tuş
        SizedBox(
          height: size.height * 0.18,
          child: TapZone(
            label: '${AppTranslations.getText('key_prefix')} ${s.m4KeyBottom}',
            color: s.detailColor,
            onDown: () => handleButtonDown(s.m4KeyBottom),
            onUp: () => handleButtonUp(s.m4KeyBottom),
          ),
        ),
      ],
    );
  }

  // ──────────────────────────────────────────────────────────────────────────
  // MOD 5: Özel Tasarım (JSON'dan)
  // ──────────────────────────────────────────────────────────────────────────
  Widget buildMode5(AppSettings s, Size size) {
    List<Layout5Item> items = [];
    if (s.customLayout5Json == null || s.customLayout5Json!.isEmpty) {
      items = defaultLayout5();
    } else {
      try {
        final list = jsonDecode(s.customLayout5Json!) as List;
        items = list
            .map((e) => Layout5Item.fromJson(e as Map<String, dynamic>))
            .toList();
      } catch (_) {
        items = defaultLayout5();
      }
    }
    
    // Katman sırasına (Z-Index) göre küçükten büyüğe sırala
    items.sort((a, b) => a.zIndex.compareTo(b.zIndex));

    // Detect which advanced items are present — determines whether to use 16-byte payload
    final bool hasLeftJoy = items.any((e) => e.type == Layout5ItemType.leftJoystick);
    final bool hasRightJoy = items.any((e) => e.type == Layout5ItemType.rightJoystick);
    
    final Layout5Item? leftJoyItem = items.cast<Layout5Item?>().firstWhere(
      (e) => e != null && e.type == Layout5ItemType.leftJoystick,
      orElse: () => null,
    );
    final int parsedGyroRightAnalogMode = leftJoyItem?.gyroToRightAnalogMode ?? 0;
    final double parsedGyroRightAnalogSensitivity = leftJoyItem?.gyroRightAnalogSensitivity ?? 1.0;
    final double parsedGyroRightAnalogDeadzone = leftJoyItem?.gyroRightAnalogDeadzone ?? 7.0;

    final Layout5Item? touchpadItem = items.cast<Layout5Item?>().firstWhere(
      (e) => e != null && e.type == Layout5ItemType.touchpad,
      orElse: () => null,
    );
    final int parsedGyroMouseMode = touchpadItem?.gyroToMouseMode ?? 0;
    final double parsedGyroMouseSensitivity = touchpadItem?.gyroMouseSensitivity ?? 1.0;
    final double parsedGyroMouseDeadzone = touchpadItem?.gyroMouseDeadzone ?? 7.0;

    final bool hasTouchpad = items.any(
      (e) => e.type == Layout5ItemType.touchpad,
    );
    final bool hasKbKeys = items.any(
      (e) =>
          (e.type == Layout5ItemType.buttonSquare ||
              e.type == Layout5ItemType.buttonSoft ||
              e.type == Layout5ItemType.buttonCircle) &&
          (e.mode == ButtonMode.macro ||
              e.macro.isNotEmpty ||
              e.keyIndex >= 100 ||
              e.keyIndex >= 2000),
    );

    // Item bazlı hassasiyet değerlerini çıkar (sol/sağ ayrı)
    double? parsedLeftSens;
    double? parsedRightSens;
    for (final item in items) {
      if (item.type == Layout5ItemType.leftJoystick) {
        parsedLeftSens = item.sensitivity;
      } else if (item.type == Layout5ItemType.rightJoystick) {
        parsedRightSens = item.sensitivity;
      }
    }

    if (leftJoystickPresent != hasLeftJoy ||
        rightJoystickPresent != hasRightJoy ||
        touchpadPresent != hasTouchpad ||
        keyboardKeysPresent != hasKbKeys ||
        leftJoySensitivity != parsedLeftSens ||
        rightJoySensitivity != parsedRightSens ||
        gyroToRightAnalogMode != parsedGyroRightAnalogMode ||
        gyroRightAnalogSensitivity != parsedGyroRightAnalogSensitivity ||
        gyroRightAnalogDeadzone != parsedGyroRightAnalogDeadzone ||
        gyroToMouseMode != parsedGyroMouseMode ||
        gyroMouseSensitivity != parsedGyroMouseSensitivity ||
        gyroMouseDeadzone != parsedGyroMouseDeadzone) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() {
            leftJoystickPresent = hasLeftJoy;
            rightJoystickPresent = hasRightJoy;
            touchpadPresent = hasTouchpad;
            keyboardKeysPresent = hasKbKeys;
            leftJoySensitivity = parsedLeftSens;
            rightJoySensitivity = parsedRightSens;
            gyroToRightAnalogMode = parsedGyroRightAnalogMode;
            gyroRightAnalogSensitivity = parsedGyroRightAnalogSensitivity;
            gyroRightAnalogDeadzone = parsedGyroRightAnalogDeadzone;
            gyroToMouseMode = parsedGyroMouseMode;
            gyroMouseSensitivity = parsedGyroMouseSensitivity;
            gyroMouseDeadzone = parsedGyroMouseDeadzone;
          });
        }
      });
    }

    // Joystick modu
    final joystickMode = JoystickMode.values[s.joystickMode.clamp(0, 3)];

    // Spawn modu için joystick bilgilerini topla
    List<JoystickSpawnInfo> spawnInfos = [];
    if (joystickMode.isSpawnLike) {
      for (final item in items) {
        if (item.type == Layout5ItemType.leftJoystick ||
            item.type == Layout5ItemType.rightJoystick) {
          final cx = item.left * size.width + item.width * size.width / 2;
          final cy = item.top * size.height + item.height * size.height / 2;
          final r = math.min(
            item.width * size.width,
            item.height * size.height,
          ) / 2;
          spawnInfos.add(JoystickSpawnInfo(
            originCenter: Offset(cx, cy),
            radius: r,
            isLeft: item.type == Layout5ItemType.leftJoystick,
            baseColor: item.bgColor,
            thumbColor: item.textColor,
          ));
        }
      }
    }

    return Stack(
      clipBehavior: Clip.none,
      children: [
        // Spawn tabanlı modlar: şeffaf dokunma yakalama katmanı
        // ÖNCE yerleştirilir ki üstündeki butonlar/touchpad hit test önceliği alsın.
        // Yalnızca boş alanlara dokunulduğunda aktifleşir.
        if (joystickMode.isSpawnLike && spawnInfos.isNotEmpty)
          Positioned.fill(
            child: JoystickSpawnLayer(
              joystickInfos: spawnInfos,
              floatingEnabled: joystickMode.isFloating,
              onJoy0Changed: (x, y) => setState(() {
                joy0x = x;
                joy0y = y;
              }),
              onJoy1Changed: (x, y) => setState(() {
                joy1x = x;
                joy1y = y;
              }),
              onActiveChanged: (isLeft) => setState(() {
                spawnActiveIsLeft = isLeft;
              }),
            ),
          ),

        // Normal item'lar (üst katman — hit test önceliği bunlarda)
        ...items.map((item) => buildMode5Item(item, s, size, joystickMode)).toList(),
      ],
    );
  }

  Widget buildMode5Item(Layout5Item item, AppSettings s, Size size, [JoystickMode joystickMode = JoystickMode.fixed]) {
    final double l = item.left * size.width;
    final double t = item.top * size.height;
    final double w = item.width * size.width;
    final double h = item.height * size.height;

    Widget content;
    switch (item.type) {
      case Layout5ItemType.leftJoystick:
        // Spawn tabanlı modlarda: aktif olan joystick spawn layer'da çizilir,
        // orijinal konumdaki ghost yarı saydam gösterilir
        final bool isSpawnHidden = joystickMode.isSpawnLike && spawnActiveIsLeft == true;
        final double ghostOpacity = joystickMode.isSpawnLike
            ? (isSpawnHidden ? 0.0 : 0.2)
            : 1.0;

        content = JoystickWidget(
          radius: math.min(w, h) / 2,
          baseColor: item.bgColor,
          thumbColor: item.textColor,
          mode: joystickMode,
          ghostOpacity: ghostOpacity,
          onChanged: (x, y) {
            setState(() {
              joy0x = x;
              joy0y = y;
            });
          },
        );
        break;
      case Layout5ItemType.rightJoystick:
        final bool isSpawnHidden = joystickMode.isSpawnLike && spawnActiveIsLeft == false;
        final double ghostOpacity = joystickMode.isSpawnLike
            ? (isSpawnHidden ? 0.0 : 0.2)
            : 1.0;

        content = JoystickWidget(
          radius: math.min(w, h) / 2,
          baseColor: item.bgColor,
          thumbColor: item.textColor,
          mode: joystickMode,
          ghostOpacity: ghostOpacity,
          onChanged: (x, y) {
            setState(() {
              joy1x = x;
              joy1y = y;
            });
          },
        );
        break;
      case Layout5ItemType.gasBar:
        content = Listener(
          onPointerDown: (e) => onPedalDown(e, true, forceBarAction: true),
          onPointerMove: (e) => onPedalMove(e, s),
          onPointerUp: onPedalUp,
          onPointerCancel: onPedalUp,
          child: RepaintBoundary(
            child: CustomPaint(
              painter: PedalPainter(
                fillPercentage: gasPercentage,
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
          onPointerDown: (e) => onPedalDown(e, false, forceBarAction: true),
          onPointerMove: (e) => onPedalMove(e, s),
          onPointerUp: onPedalUp,
          onPointerCancel: onPedalUp,
          child: RepaintBoundary(
            child: CustomPaint(
              painter: PedalPainter(
                fillPercentage: brakePercentage,
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
        final label = item.label ?? AppTranslations.getText('button_text');
        BorderRadius radius;
        if (item.type == Layout5ItemType.buttonSoft) {
          radius = BorderRadius.circular(16);
        } else if (item.type == Layout5ItemType.buttonCircle) {
          radius = BorderRadius.circular(math.min(w, h) / 2);
        } else {
          radius = BorderRadius.circular(4);
        }

        content = Listener(
          behavior: HitTestBehavior.opaque,
          onPointerDown: (_) {
            if (item.mode == ButtonMode.key) {
              if (item.customPressMode != null) {
                try {
                  s.customButtonPressModes[item.keyIndex] = item.customPressMode!;
                } catch (_) {
                  s.customButtonPressModes = Map<int, int>.from(s.customButtonPressModes);
                  s.customButtonPressModes[item.keyIndex] = item.customPressMode!;
                }
              }
              if (item.customPressDurationMs != null) {
                try {
                  s.customButtonPressDurationsMs[item.keyIndex] = item.customPressDurationMs!;
                } catch (_) {
                  s.customButtonPressDurationsMs = Map<int, int>.from(s.customButtonPressDurationsMs);
                  s.customButtonPressDurationsMs[item.keyIndex] = item.customPressDurationMs!;
                }
              }
              try {
                s.customButtonHapticEnabled[item.keyIndex] = item.enableHaptic;
              } catch (_) {
                s.customButtonHapticEnabled = Map<int, bool>.from(s.customButtonHapticEnabled);
                s.customButtonHapticEnabled[item.keyIndex] = item.enableHaptic;
              }
              if (item.enableHaptic) {
                try {
                  s.customButtonHapticTypes[item.keyIndex] = item.customHapticType ?? s.globalHapticType;
                } catch (_) {
                  s.customButtonHapticTypes = Map<int, int>.from(s.customButtonHapticTypes);
                  s.customButtonHapticTypes[item.keyIndex] = item.customHapticType ?? s.globalHapticType;
                }
                try {
                  s.customButtonHapticTriggers[item.keyIndex] = item.customHapticTrigger ?? s.globalHapticTrigger;
                } catch (_) {
                  s.customButtonHapticTriggers = Map<int, int>.from(s.customButtonHapticTriggers);
                  s.customButtonHapticTriggers[item.keyIndex] = item.customHapticTrigger ?? s.globalHapticTrigger;
                }
              }
              handleButtonDown(item.keyIndex);
            } else if (item.mode == ButtonMode.gasPct) {
              if (item.enableHaptic || s.simulatedHapticEnabled) {
                HapticManager().triggerHapticType(s, item.customHapticType ?? s.globalHapticType, force: true);
              }
              setState(() => gasPercentage = item.modeValue);
            } else if (item.mode == ButtonMode.brakePct) {
              if (item.enableHaptic || s.simulatedHapticEnabled) {
                HapticManager().triggerHapticType(s, item.customHapticType ?? s.globalHapticType, force: true);
              }
              setState(() => brakePercentage = item.modeValue);
            } else if (item.mode == ButtonMode.handbrakePct) {
              if (item.enableHaptic || s.simulatedHapticEnabled) {
                HapticManager().triggerHapticType(s, item.customHapticType ?? s.globalHapticType, force: true);
              }
              setState(() {
                handbrakePressed = true;
                handbrakePercentage = item.modeValue;
              });
            } else if (item.mode == ButtonMode.clutchPct) {
              if (item.enableHaptic || s.simulatedHapticEnabled) {
                HapticManager().triggerHapticType(s, item.customHapticType ?? s.globalHapticType, force: true);
              }
              setState(() => clutchPercentage = item.modeValue);
            } else if (item.mode == ButtonMode.macro) {
              if (item.enableHaptic || s.simulatedHapticEnabled) {
                HapticManager().triggerHapticType(s, item.customHapticType ?? s.globalHapticType, force: true);
              }
              executeMacro(item.macro);
            }
          },
          onPointerUp: (_) {
            if (item.mode == ButtonMode.key) {
              handleButtonUp(item.keyIndex);
            } else if (item.mode == ButtonMode.gasPct) {
              setState(() => gasPercentage = 0.0);
            } else if (item.mode == ButtonMode.brakePct) {
              setState(() => brakePercentage = 0.0);
            } else if (item.mode == ButtonMode.handbrakePct) {
              setState(() {
                handbrakePressed = false;
                handbrakePercentage = 0.0;
              });
            } else if (item.mode == ButtonMode.clutchPct) {
              setState(() => clutchPercentage = 0.0);
            }
          },
          onPointerCancel: (_) {
            if (item.mode == ButtonMode.key) {
              handleButtonUp(item.keyIndex);
            } else if (item.mode == ButtonMode.gasPct) {
              setState(() => gasPercentage = 0.0);
            } else if (item.mode == ButtonMode.brakePct) {
              setState(() => brakePercentage = 0.0);
            } else if (item.mode == ButtonMode.handbrakePct) {
              setState(() {
                handbrakePressed = false;
                handbrakePercentage = 0.0;
              });
            } else if (item.mode == ButtonMode.clutchPct) {
              setState(() => clutchPercentage = 0.0);
            }
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
      case Layout5ItemType.touchpad:
        if (item.gyroToMouseMode != 0) {
          // Eğer Touchpad Gyro-to-Mouse için kullanılıyorsa, sürüş ekranında görünmez olur
          content = const SizedBox.shrink();
          break;
        }

        // Touchpad: accumulates mouse delta; click type determined by finger count
        content = Listener(
          behavior: HitTestBehavior.opaque,
          onPointerDown: (e) {
            tpActivePointers.add(e.pointer);
            if (tpFingers > tpMaxFingers) tpMaxFingers = tpFingers;
            if (tpFingers == 1) {
              tpTotalMoveDistance = 0.0;
              tpGestureStartX = e.localPosition.dx;
              tpGestureStartY = e.localPosition.dy;
              tpGestureAccumX = 0.0;
              tpGestureAccumY = 0.0;
              if (lastTouchpadUpTime != null && DateTime.now().difference(lastTouchpadUpTime!).inMilliseconds < 300) {
                isTouchpadDragging = true;
                setState(() => tpClick = 1);
              } else {
                tpDownTime = DateTime.now();
                isTouchpadDragging = false;
              }
            }
            if (tpFingers == 2) {
              tpWasTwo = true;
              if (isTouchpadDragging) {
                isTouchpadDragging = false;
                setState(() => tpClick = 0);
              }
            }
            if (tpFingers >= 3) tpWasThree = true;
          },
          onPointerMove: (e) {
            // Accumulate delta — sent in onTick bytes 9-10
            if (tpFingers == 1) {
              touchpadDeltaX += e.delta.dx;
              touchpadDeltaY += e.delta.dy;
            }
            tpTotalMoveDistance += e.delta.distance;
            tpGestureAccumX += e.delta.dx;
            tpGestureAccumY += e.delta.dy;
            
            // 2-Finger Continuous Scroll (Wheel)
            if (tpFingers == 2 && tpMaxFingers == 2) {
              if (e.delta.dy < -1.0) { // Scroll Up input -> reverse to Scroll Down (5)
                setState(() => tpClick = 5);
              } else if (e.delta.dy > 1.0) { // Scroll Down input -> reverse to Scroll Up (4)
                setState(() => tpClick = 4);
              } else {
                setState(() => tpClick = 0);
              }
            }
          },
          onPointerUp: (e) {
            tpActivePointers.remove(e.pointer);
            if (tpFingers <= 0) {
              bool wasDragging = isTouchpadDragging;
              
              double deltaX = tpGestureAccumX;
              double deltaY = tpGestureAccumY;

              // Tıklama ile sürüklemeyi ayır: parmak sürüklendiyse tıklama üretme!
              if (!wasDragging && tpDownTime != null && tpTotalMoveDistance < 8.0) {
                final dur = DateTime.now().difference(tpDownTime!);
                if (dur.inMilliseconds < 250) {
                  // Short tap — determine click type by finger count
                  int clickType = 1;
                  if (tpWasThree) {
                    clickType = 3; // middle click
                  } else if (tpWasTwo) {
                    clickType = 2; // right click
                  }
                  
                  setState(() => tpClick = clickType);
                  Future.delayed(const Duration(milliseconds: 50), () {
                    if (mounted && tpClick == clickType) setState(() => tpClick = 0);
                  });
                }
              } else if (tpTotalMoveDistance > 30.0) {
                // Makro Kısayollar (3 veya 4 parmak jest tamamlandığında)
                if (tpMaxFingers == 3) {
                  if (deltaY.abs() > deltaX.abs()) {
                    if (deltaY > 0) {
                      fireGestureMacro([1091, 1068]); // 3-Finger Down (Win+D)
                    } else {
                      fireGestureMacro([1091, 1068]); // 3-Finger Up (Win+D)
                    }
                  } else {
                    if (deltaX < 0) {
                      fireGestureMacro([1018, 1016, 1009]); // 3-Finger Left (Alt+Shift+Tab)
                    } else {
                      fireGestureMacro([1018, 1009]); // 3-Finger Right (Alt+Tab)
                    }
                  }
                } else if (tpMaxFingers == 4) {
                  if (deltaX.abs() > deltaY.abs()) {
                    if (deltaX > 0) {
                      fireGestureMacro([1017, 1091, 1039]); // 4-Finger Right (Ctrl+Win+Right)
                    } else {
                      fireGestureMacro([1017, 1091, 1037]); // 4-Finger Left (Ctrl+Win+Left)
                    }
                  }
                }
              }

              lastTouchpadUpTime = DateTime.now();
              isTouchpadDragging = false;
              tpWasTwo = false;
              tpWasThree = false;
              tpDownTime = null;
              tpTotalMoveDistance = 0.0;
              tpMaxFingers = 0;

              if (wasDragging) {
                setState(() => tpClick = 0);
              }
            }
          },
          onPointerCancel: (e) {
            tpActivePointers.remove(e.pointer);
            if (tpFingers <= 0) {
              tpActivePointers.clear();
              tpMaxFingers = 0;
              isTouchpadDragging = false;
              tpWasTwo = false;
              tpWasThree = false;
              tpDownTime = null;
              tpTotalMoveDistance = 0.0;
              setState(() => tpClick = 0);
            }
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
      case Layout5ItemType.gasPedalIcon:
      case Layout5ItemType.brakePedalIcon:
        final isGasIcon = item.type == Layout5ItemType.gasPedalIcon;
        content = Listener(
          behavior: HitTestBehavior.opaque,
          onPointerDown: (_) {
            if (isGasIcon) {
              gasPedalIconPressed = true;
              _startPedalIconAcceleration(true, s);
            } else {
              brakePedalIconPressed = true;
              _startPedalIconAcceleration(false, s);
            }
            if (item.enableHaptic) {
              HapticManager().triggerForItem(s, item.enableHaptic);
            }
          },
          onPointerMove: (_) {
            // Sürükleme hareketi pedal ivmelenmesini kesmez.
          },
          onPointerUp: (_) {
            if (isGasIcon) {
              gasPedalIconPressed = false;
              setState(() {
                gasPedalIconValue = 0.0;
                gasPercentage = 0.0;
              });
            } else {
              brakePedalIconPressed = false;
              setState(() {
                brakePedalIconValue = 0.0;
                brakePercentage = 0.0;
              });
            }
          },
          onPointerCancel: (_) {
            if (isGasIcon) {
              gasPedalIconPressed = false;
              setState(() {
                gasPedalIconValue = 0.0;
                gasPercentage = 0.0;
              });
            } else {
              brakePedalIconPressed = false;
              setState(() {
                brakePedalIconValue = 0.0;
                brakePercentage = 0.0;
              });
            }
          },
          child: RepaintBoundary(
            child: CustomPaint(
              painter: PedalIconPainter(
                fillPercentage:
                    isGasIcon ? gasPedalIconValue : brakePedalIconValue,
                baseColor: isGasIcon ? s.gasColor : s.brakeColor,
                isGas: isGasIcon,
              ),
            ),
          ),
        );
        break;
      case Layout5ItemType.clutchBar:
        content = Builder(
          builder: (bctx) {
            return Listener(
              behavior: HitTestBehavior.opaque,
              onPointerDown: (e) {
                final box = bctx.findRenderObject() as RenderBox?;
                if (box != null) {
                  final localPos = box.globalToLocal(e.position);
                  final pct = (1.0 - (localPos.dy / box.size.height)).clamp(0.0, 1.0);
                  setState(() => clutchPercentage = pct);
                }
                HapticManager().triggerLight(s);
              },
              onPointerMove: (e) {
                final box = bctx.findRenderObject() as RenderBox?;
                if (box != null) {
                  final localPos = box.globalToLocal(e.position);
                  final pct = (1.0 - (localPos.dy / box.size.height)).clamp(0.0, 1.0);
                  setState(() => clutchPercentage = pct);
                }
              },
              onPointerUp: (_) => setState(() => clutchPercentage = 0.0),
              onPointerCancel: (_) => setState(() => clutchPercentage = 0.0),
              child: RepaintBoundary(
                child: CustomPaint(
                  painter: PedalPainter(
                    fillPercentage: clutchPercentage,
                    baseColor: Colors.blueAccent,
                    bgColor: item.bgColor,
                    yetsoreColor: s.yetsoreColor,
                  ),
                ),
              ),
            );
          },
        );
        break;
      case Layout5ItemType.clutchIcon:
        content = Listener(
          behavior: HitTestBehavior.opaque,
          onPointerDown: (_) {
            clutchIconPressed = true;
            startClutchIconAcceleration(s);
            HapticManager().triggerLight(s);
          },
          onPointerUp: (_) {
            clutchIconPressed = false;
            setState(() {
              clutchIconValue = 0.0;
              clutchPercentage = 0.0;
            });
          },
          onPointerCancel: (_) {
            clutchIconPressed = false;
            setState(() {
              clutchIconValue = 0.0;
              clutchPercentage = 0.0;
            });
          },
          child: RepaintBoundary(
            child: CustomPaint(
              painter: PedalIconPainter(
                fillPercentage: clutchIconValue,
                baseColor: Colors.blueAccent,
                isGas: false,
              ),
            ),
          ),
        );
        break;
      case Layout5ItemType.handbrakeBar:
        content = Builder(
          builder: (bctx) {
            return Listener(
              behavior: HitTestBehavior.opaque,
              onPointerDown: (e) {
                final box = bctx.findRenderObject() as RenderBox?;
                if (box != null) {
                  final localPos = box.globalToLocal(e.position);
                  final pct = (1.0 - (localPos.dy / box.size.height)).clamp(0.0, 1.0);
                  setState(() => handbrakePercentage = pct);
                }
                HapticManager().triggerLight(s);
              },
              onPointerMove: (e) {
                final box = bctx.findRenderObject() as RenderBox?;
                if (box != null) {
                  final localPos = box.globalToLocal(e.position);
                  final pct = (1.0 - (localPos.dy / box.size.height)).clamp(0.0, 1.0);
                  setState(() => handbrakePercentage = pct);
                }
              },
              onPointerUp: (_) => setState(() => handbrakePercentage = 0.0),
              onPointerCancel: (_) => setState(() => handbrakePercentage = 0.0),
              child: RepaintBoundary(
                child: CustomPaint(
                  painter: PedalPainter(
                    fillPercentage: handbrakePercentage,
                    baseColor: Colors.redAccent,
                    bgColor: item.bgColor,
                    yetsoreColor: s.yetsoreColor,
                  ),
                ),
              ),
            );
          },
        );
        break;
      case Layout5ItemType.handbrakeIcon:
        content = Listener(
          behavior: HitTestBehavior.opaque,
          onPointerDown: (_) {
            setState(() {
              handbrakePressed = true;
              handbrakePercentage = 1.0;
            });
            HapticManager().triggerLight(s);
          },
          onPointerUp: (_) {
            setState(() {
              handbrakePressed = false;
              handbrakePercentage = 0.0;
            });
          },
          onPointerCancel: (_) {
            setState(() {
              handbrakePressed = false;
              handbrakePercentage = 0.0;
            });
          },
          child: Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: handbrakePressed ? Colors.redAccent : Colors.redAccent.withOpacity(0.15),
              border: Border.all(
                color: Colors.redAccent,
                width: 2.5,
              ),
            ),
            child: Center(
              child: Text(
                '(P)',
                style: TextStyle(
                  color: handbrakePressed ? Colors.white : Colors.redAccent,
                  fontWeight: FontWeight.bold,
                  fontSize: math.min(w, h) * 0.45,
                ),
              ),
            ),
          ),
        );
        break;
      case Layout5ItemType.steeringWheelIcon:
        final sensor = SensorManager();
        final steerRad = steeringAngle * 75.0 * math.pi / 180.0;
        final deg = sensor.pitchDeg;

        Widget steeringWidget;
        if (s.mod6SteeringStyle == 1) {
          steeringWidget = RepaintBoundary(
            child: CustomPaint(
              painter: DynamicSteeringWheelPainter(
                steeringRatio: steeringAngle,
                totalAngleDegrees: deg * (s.steeringAngle / 180.0),
                turnRightColor: item.textColor,
                turnLeftColor: item.textColor,
                baseColor: item.textColor.withValues(alpha: 0.3),
              ),
              child: const SizedBox.expand(),
            ),
          );
        } else {
          steeringWidget = RepaintBoundary(
            child: CustomPaint(
              painter: SteeringWheelPainter(
                angle: steerRad,
                fullTurns: sensor.fullTurns,
                rimColor: item.textColor,
              ),
              child: const SizedBox.expand(),
            ),
          );
        }
        
        content = Opacity(
          opacity: 0.85,
          child: steeringWidget,
        );
        break;
      case Layout5ItemType.handbrakeButton:
        content = Listener(
          onPointerDown: (_) {
            handleButtonDown(s.handbrakeKey);
            HapticManager().triggerLight(s);
          },
          onPointerUp: (_) => handleButtonUp(s.handbrakeKey),
          onPointerCancel: (_) => handleButtonUp(s.handbrakeKey),
          child: Container(
            decoration: BoxDecoration(
              color: pressedKeys.contains(s.handbrakeKey)
                  ? Colors.redAccent
                  : const Color(0xFF381E1E),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.redAccent),
            ),
            child: const Center(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.sports_motorsports, color: Colors.redAccent, size: 16),
                  SizedBox(width: 4),
                  Text('EL FRENİ', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ),
        );
        break;
    }
    // Floating modda joystick base sürüklenebilir — Positioned sınırlarını aşamaması
    // için OverflowBox ile sarılır.
    final bool isFloatingJoy = (item.type == Layout5ItemType.leftJoystick ||
        item.type == Layout5ItemType.rightJoystick) &&
        joystickMode == JoystickMode.floatingBase;

    final Widget child = isFloatingJoy
        ? OverflowBox(
            alignment: Alignment.center,
            maxWidth: double.infinity,
            maxHeight: double.infinity,
            child: SizedBox(
              width: w,
              height: h,
              child: Transform.rotate(angle: item.rotation, child: content),
            ),
          )
        : Transform.rotate(angle: item.rotation, child: content);

    return Positioned(
      left: l,
      top: t,
      width: w,
      height: h,
      child: child,
    );
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Yardımcılar
  // ──────────────────────────────────────────────────────────────────────────

  /// Pedal sütunu (fren veya gaz)
  Widget buildPedalColumn(
    AppSettings s, {
    required bool isBrake,
    required int tapKey,
  }) {
    return Stack(
      children: [
        Positioned.fill(
          child: Listener(
            behavior: HitTestBehavior.opaque,
            onPointerDown: (e) => onPedalDown(e, !isBrake, tapKey: tapKey),
            onPointerMove: (e) => onPedalMove(e, s),
            onPointerUp: onPedalUp,
            onPointerCancel: onPedalUp,
            child: RepaintBoundary(
              child: CustomPaint(
                painter: PedalPainter(
                  fillPercentage: isBrake ? brakePercentage : gasPercentage,
                  baseColor: isBrake ? s.brakeColor : s.gasColor,
                  bgColor: s.pedalBgColor,
                  yetsoreColor: s.yetsoreColor,
                ),
                child: const SizedBox.expand(),
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// 2x2 center grid (k1-k4) + opsiyonel k5
  Widget buildMiddle2x2(
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
                child: TapZone(
                  label: '${AppTranslations.getText('key_prefix')} $k1',
                  color: color,
                  onDown: () => handleButtonDown(k1),
                  onUp: () => handleButtonUp(k1),
                ),
              ),
              Expanded(
                child: TapZone(
                  label: '${AppTranslations.getText('key_prefix')} $k2',
                  color: color,
                  onDown: () => handleButtonDown(k2),
                  onUp: () => handleButtonUp(k2),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: Row(
            children: [
              Expanded(
                child: TapZone(
                  label: '${AppTranslations.getText('key_prefix')} $k3',
                  color: color,
                  onDown: () => handleButtonDown(k3),
                  onUp: () => handleButtonUp(k3),
                ),
              ),
              Expanded(
                child: TapZone(
                  label: '${AppTranslations.getText('key_prefix')} $k4',
                  color: color,
                  onDown: () => handleButtonDown(k4),
                  onUp: () => handleButtonUp(k4),
                ),
              ),
            ],
          ),
        ),
        if (k5 != null)
          Expanded(
            child: TapZone(
              label: '${AppTranslations.getText('key_prefix')} $k5',
              color: color,
              onDown: () => handleButtonDown(k5),
              onUp: () => handleButtonUp(k5),
            ),
          ),
      ],
    );
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Pedal İkonu İvmelenme Yardımcısı
  // ──────────────────────────────────────────────────────────────────────────
  void _startPedalIconAcceleration(bool isGas, AppSettings s) {
    final rate = s.pedalIconAccelerationRate; // saniye (0→%100)
    // Her frame'de güncelleme yap (60 Hz tick'te çağrılır)
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _pedalIconAccelTick(isGas, rate);
    });
  }

  void _pedalIconAccelTick(bool isGas, double rate) {
    if (!mounted) return;
    final pressed = isGas ? gasPedalIconPressed : brakePedalIconPressed;
    if (!pressed) return;

    setState(() {
      final increment = 1.0 / (rate * 60); // 60 fps varsayımı
      if (isGas) {
        gasPedalIconValue = (gasPedalIconValue + increment).clamp(0.0, 1.0);
        gasPercentage = gasPedalIconValue;
      } else {
        brakePedalIconValue = (brakePedalIconValue + increment).clamp(0.0, 1.0);
        brakePercentage = brakePedalIconValue;
      }
    });

    // Sonraki frame'i planla
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _pedalIconAccelTick(isGas, rate);
    });
  }

  // ──────────────────────────────────────────────────────────────────────────
  // MOD 6: Görsel Sürüş — Direksiyon simidi + Gaz/Fren
  // ──────────────────────────────────────────────────────────────────────────
  Widget buildMode6(AppSettings s, Size size) {
    final sensor = SensorManager();
    final steerRad = steeringAngle * 75.0 * math.pi / 180.0;

    // Pedal kontrol widget'ı (Bar veya İkon)
    Widget gasControl;
    Widget brakeControl;

    if (s.mod6PedalStyle == 1) {
      // Pedal İkonu (Listener ile dokunma ve hafif sürükleme kesilmelerini önler)
      gasControl = Listener(
        behavior: HitTestBehavior.opaque,
        onPointerDown: (_) {
          gasPedalIconPressed = true;
          _startPedalIconAcceleration(true, s);
          HapticManager().triggerLight(s);
        },
        onPointerMove: (_) {
          // Parmağın hafif kayması/titremesi ivmelenmeyi KESMEZ.
        },
        onPointerUp: (_) {
          gasPedalIconPressed = false;
          setState(() {
            gasPedalIconValue = 0.0;
            gasPercentage = 0.0;
          });
        },
        onPointerCancel: (_) {
          gasPedalIconPressed = false;
          setState(() {
            gasPedalIconValue = 0.0;
            gasPercentage = 0.0;
          });
        },
        child: RepaintBoundary(
          child: CustomPaint(
            painter: PedalIconPainter(
              fillPercentage: gasPedalIconValue,
              baseColor: s.gasIconColor,
              isGas: true,
            ),
            child: const SizedBox.expand(),
          ),
        ),
      );
      brakeControl = Listener(
        behavior: HitTestBehavior.opaque,
        onPointerDown: (_) {
          brakePedalIconPressed = true;
          _startPedalIconAcceleration(false, s);
          HapticManager().triggerLight(s);
        },
        onPointerMove: (_) {
          // Parmağın hafif kayması/titremesi ivmelenmeyi KESMEZ.
        },
        onPointerUp: (_) {
          brakePedalIconPressed = false;
          setState(() {
            brakePedalIconValue = 0.0;
            brakePercentage = 0.0;
          });
        },
        onPointerCancel: (_) {
          brakePedalIconPressed = false;
          setState(() {
            brakePedalIconValue = 0.0;
            brakePercentage = 0.0;
          });
        },
        child: RepaintBoundary(
          child: CustomPaint(
            painter: PedalIconPainter(
              fillPercentage: brakePedalIconValue,
              baseColor: s.brakeIconColor,
              isGas: false,
            ),
            child: const SizedBox.expand(),
          ),
        ),
      );
    } else {
      // Bar (varsayılan)
      gasControl = Listener(
        onPointerDown: (e) => onPedalDown(e, true, forceBarAction: true),
        onPointerMove: (e) => onPedalMove(e, s),
        onPointerUp: onPedalUp,
        onPointerCancel: onPedalUp,
        child: RepaintBoundary(
          child: CustomPaint(
            painter: PedalPainter(
              fillPercentage: gasPercentage,
              baseColor: s.gasColor,
              bgColor: s.pedalBgColor,
              yetsoreColor: s.yetsoreColor,
            ),
            child: const SizedBox.expand(),
          ),
        ),
      );
      brakeControl = Listener(
        onPointerDown: (e) => onPedalDown(e, false, forceBarAction: true),
        onPointerMove: (e) => onPedalMove(e, s),
        onPointerUp: onPedalUp,
        onPointerCancel: onPedalUp,
        child: RepaintBoundary(
          child: CustomPaint(
            painter: PedalPainter(
              fillPercentage: brakePercentage,
              baseColor: s.brakeColor,
              bgColor: s.pedalBgColor,
              yetsoreColor: s.yetsoreColor,
            ),
            child: const SizedBox.expand(),
          ),
        ),
      );
    }

    // ── Direksiyon Kontrolü ──
    Widget steeringWidget;
    if (s.mod6SteeringStyle == 1) {
      // Dinamik Sabit Direksiyon (Varsayılan)
      final deg = sensor.pitchDeg; // direksiyon açı hesabı
      steeringWidget = RepaintBoundary(
        child: CustomPaint(
          painter: DynamicSteeringWheelPainter(
            steeringRatio: steeringAngle,
            totalAngleDegrees: deg * (s.steeringAngle / 180.0),
            turnRightColor: s.steeringTurnRightColor,
            turnLeftColor: s.steeringTurnLeftColor,
            baseColor: s.steeringWheelColor,
          ),
          child: const SizedBox.expand(),
        ),
      );
    } else {
      // Dönen Direksiyon
      steeringWidget = RepaintBoundary(
        child: CustomPaint(
          painter: SteeringWheelPainter(
            angle: steerRad,
            fullTurns: sensor.fullTurns,
            rimColor: s.steeringIndicatorColor,
          ),
          child: const SizedBox.expand(),
        ),
      );
    }

    // ── Debriyaj Kontrolü (Opsiyonel) ──
    Widget? clutchWidget;
    if (s.mod6EnableClutch) {
      if (s.clutchType == 0) {
        // Buton
        clutchWidget = Listener(
          onPointerDown: (_) {
            handleButtonDown(s.clutchKey);
            HapticManager().triggerLight(s);
          },
          onPointerUp: (_) => handleButtonUp(s.clutchKey),
          onPointerCancel: (_) => handleButtonUp(s.clutchKey),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: pressedKeys.contains(s.clutchKey)
                  ? s.clutchColor
                  : s.clutchButtonColor,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: s.clutchColor.withValues(alpha: 0.5)),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.tune, color: Colors.cyanAccent, size: 16),
                SizedBox(width: 6),
                Text(
                  'DEBRİYAJ',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        );
      } else if (s.clutchType == 2) {
        // İkon (İvmelenmeli)
        clutchWidget = Listener(
          behavior: HitTestBehavior.opaque,
          onPointerDown: (_) {
            clutchIconPressed = true;
            startClutchIconAcceleration(s);
            HapticManager().triggerLight(s);
          },
          onPointerUp: (_) {
            clutchIconPressed = false;
            setState(() {
              clutchIconValue = 0.0;
              clutchPercentage = 0.0;
            });
          },
          onPointerCancel: (_) {
            clutchIconPressed = false;
            setState(() {
              clutchIconValue = 0.0;
              clutchPercentage = 0.0;
            });
          },
          child: SizedBox(
            width: 70,
            height: 70,
            child: CustomPaint(
              painter: PedalIconPainter(
                fillPercentage: clutchIconValue,
                baseColor: s.clutchIconColor,
                isGas: false,
              ),
            ),
          ),
        );
      } else {
        // Bar (Slider) - Gerçek Dikey Analog Kaydırıcı
        clutchWidget = SizedBox(
          width: 60,
          height: 120,
          child: Builder(
            builder: (bctx) {
              return Listener(
                behavior: HitTestBehavior.opaque,
                onPointerDown: (e) {
                  final box = bctx.findRenderObject() as RenderBox?;
                  if (box != null) {
                    final localPos = box.globalToLocal(e.position);
                    final pct = (1.0 - (localPos.dy / box.size.height)).clamp(0.0, 1.0);
                    setState(() => clutchPercentage = pct);
                  }
                  HapticManager().triggerLight(s);
                },
                onPointerMove: (e) {
                  final box = bctx.findRenderObject() as RenderBox?;
                  if (box != null) {
                    final localPos = box.globalToLocal(e.position);
                    final pct = (1.0 - (localPos.dy / box.size.height)).clamp(0.0, 1.0);
                    setState(() => clutchPercentage = pct);
                  }
                },
                onPointerUp: (_) => setState(() => clutchPercentage = 0.0),
                onPointerCancel: (_) => setState(() => clutchPercentage = 0.0),
                child: CustomPaint(
                  painter: PedalPainter(
                    fillPercentage: clutchPercentage,
                    baseColor: s.clutchColor,
                    bgColor: s.pedalBgColor,
                    yetsoreColor: s.clutchYetsoreColor,
                  ),
                ),
              );
            },
          ),
        );
      }
    }

    // ── El Freni Kontrolü (Opsiyonel) ──
    Widget? handbrakeWidget;
    if (s.mod6EnableHandbrake) {
      if (s.handbrakeType == 1) {
        // Bar (Slider) - Gerçek Dikey Analog Kaydırıcı (Sağ Analog Yatay Eksene Gönderilir)
        handbrakeWidget = SizedBox(
          width: 60,
          height: 120,
          child: Builder(
            builder: (bctx) {
              return Listener(
                behavior: HitTestBehavior.opaque,
                onPointerDown: (e) {
                  final box = bctx.findRenderObject() as RenderBox?;
                  if (box != null) {
                    final localPos = box.globalToLocal(e.position);
                    final pct = (1.0 - (localPos.dy / box.size.height)).clamp(0.0, 1.0);
                    setState(() => handbrakePercentage = pct);
                  }
                  HapticManager().triggerLight(s);
                },
                onPointerMove: (e) {
                  final box = bctx.findRenderObject() as RenderBox?;
                  if (box != null) {
                    final localPos = box.globalToLocal(e.position);
                    final pct = (1.0 - (localPos.dy / box.size.height)).clamp(0.0, 1.0);
                    setState(() => handbrakePercentage = pct);
                  }
                },
                onPointerUp: (_) => setState(() => handbrakePercentage = 0.0),
                onPointerCancel: (_) => setState(() => handbrakePercentage = 0.0),
                child: CustomPaint(
                  painter: PedalPainter(
                    fillPercentage: handbrakePercentage,
                    baseColor: s.handbrakeColor,
                    bgColor: s.pedalBgColor,
                    yetsoreColor: s.handbrakeYetsoreColor,
                  ),
                ),
              );
            },
          ),
        );
      } else {
        // Buton (Dijital Tuş)
        handbrakeWidget = Listener(
          onPointerDown: (_) {
            handleButtonDown(s.handbrakeKey);
            HapticManager().triggerLight(s);
          },
          onPointerUp: (_) => handleButtonUp(s.handbrakeKey),
          onPointerCancel: (_) => handleButtonUp(s.handbrakeKey),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: pressedKeys.contains(s.handbrakeKey)
                  ? s.handbrakeColor
                  : s.handbrakeButtonColor,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: s.handbrakeColor.withValues(alpha: 0.5)),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.sports_motorsports, color: Colors.redAccent, size: 16),
                SizedBox(width: 6),
                Text(
                  'EL FRENİ',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        );
      }
    }

    // Helper: Slot ID -> Widget Map
    Widget? getSlotWidget(int slotId) {
      if (slotId == 1) return brakeControl;
      if (slotId == 2) return gasControl;
      if (slotId == 3 && s.mod6EnableClutch) return clutchWidget;
      if (slotId == 4 && s.mod6EnableHandbrake) return handbrakeWidget;
      return null;
    }

    final leftWidget = getSlotWidget(s.mod6SlotLeft);
    final leftInnerWidget = getSlotWidget(s.mod6SlotLeftInner);
    final rightInnerWidget = getSlotWidget(s.mod6SlotRightInner);
    final rightWidget = getSlotWidget(s.mod6SlotRight);

    // Helper: Slot Widget'ını alta ortalayarak sarmala
    Widget wrapSlotWidget(Widget child) {
      return Align(
        alignment: Alignment.bottomCenter,
        child: child,
      );
    }

    return Stack(
      children: [
        // ── 3. ORTA ALAN: Direksiyon Simidi (Ekranın %32'si - Ortada) ──
        Positioned(
          left: size.width * 0.34,
          right: size.width * 0.34,
          top: 0,
          bottom: 0,
          child: steeringWidget,
        ),

        // ── DIREKSİYON GÖBEĞİNDEKİ KORNA BUTONU (Mavi Göbek Çapında) ──
        Builder(
          builder: (_) {
            final minDim = math.min(size.width, size.height);
            final hubDiameter = (minDim / 2.2) * 0.70; // Mavi göbek çapı
            final isHornPressed = pressedKeys.contains(s.mod6HornKey);

            return Positioned(
              left: (size.width - hubDiameter) / 2,
              top: (size.height - hubDiameter) / 2,
              width: hubDiameter,
              height: hubDiameter,
              child: Listener(
                behavior: HitTestBehavior.opaque,
                onPointerDown: (_) {
                  handleButtonDown(s.mod6HornKey);
                  HapticManager().triggerMedium(s);
                },
                onPointerUp: (_) => handleButtonUp(s.mod6HornKey),
                onPointerCancel: (_) => handleButtonUp(s.mod6HornKey),
                child: Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isHornPressed
                        ? Colors.cyanAccent.withValues(alpha: 0.35)
                        : Colors.transparent,
                    border: isHornPressed
                        ? Border.all(color: Colors.cyanAccent, width: 2)
                        : null,
                  ),
                  child: isHornPressed
                      ? const Center(
                          child: Icon(Icons.volume_up, color: Colors.cyanAccent, size: 20),
                        )
                      : null,
                ),
              ),
            );
          },
        ),

        // ── 1. SOL DIŞ SLOT (Sol Kenar - Daha Büyük Ölçek: %17 genişlik, %82 yükseklik) ──
        if (leftWidget != null)
          Positioned(
            left: size.width * 0.01,
            bottom: size.height * 0.02,
            width: size.width * 0.17,
            height: size.height * 0.82,
            child: wrapSlotWidget(leftWidget),
          ),

        // ── 2. SOL İÇ SLOT (Orta-Sol - Daha Küçük Ölçek: %15 genişlik, %68 yükseklik) ──
        if (leftInnerWidget != null)
          Positioned(
            left: size.width * 0.185,
            bottom: size.height * 0.02,
            width: size.width * 0.15,
            height: size.height * 0.68,
            child: wrapSlotWidget(leftInnerWidget),
          ),

        // ── 4. SAĞ İÇ SLOT (Orta-Sağ - Daha Küçük Ölçek: %15 genişlik, %68 yükseklik) ──
        if (rightInnerWidget != null)
          Positioned(
            right: size.width * 0.185,
            bottom: size.height * 0.02,
            width: size.width * 0.15,
            height: size.height * 0.68,
            child: wrapSlotWidget(rightInnerWidget),
          ),

        // ── 5. SAĞ DIŞ SLOT (Sağ Kenar - Daha Büyük Ölçek: %17 genişlik, %82 yükseklik) ──
        if (rightWidget != null)
          Positioned(
            right: size.width * 0.01,
            bottom: size.height * 0.02,
            width: size.width * 0.17,
            height: size.height * 0.82,
            child: wrapSlotWidget(rightWidget),
          ),
      ],
    );
  }
}
