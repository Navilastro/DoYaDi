import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../models/app_settings.dart';
import '../models/layout5_item.dart';
import '../widgets/driving_painters.dart';
import '../widgets/driving_tap_zone.dart';
import '../widgets/joystick_widget.dart';
import '../screens/driving_screen_state.dart';
import '../core/utils/app_translations.dart';

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
    if (s.customLayout5Json == null || s.customLayout5Json!.isEmpty) {
      return Center(
        child: Text(
          AppTranslations.getText('please_edit_mod5'),
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
          AppTranslations.getText('design_load_error'),
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

    if (joystickPresent != hasJoy ||
        touchpadPresent != hasTouchpad ||
        keyboardKeysPresent != hasKbKeys) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() {
            joystickPresent = hasJoy;
            touchpadPresent = hasTouchpad;
            keyboardKeysPresent = hasKbKeys;
          });
        }
      });
    }

    return Stack(
      children: items.map((item) => buildMode5Item(item, s, size)).toList(),
    );
  }

  Widget buildMode5Item(Layout5Item item, AppSettings s, Size size) {
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
              joy0x = x;
              joy0y = y;
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

        content = GestureDetector(
          onTapDown: (_) {
            if (item.mode == ButtonMode.key) {
              handleButtonDown(item.keyIndex);
            } else if (item.mode == ButtonMode.gasPct) {
              setState(() => gasPercentage = item.modeValue);
            } else if (item.mode == ButtonMode.brakePct) {
              setState(() => brakePercentage = item.modeValue);
            } else if (item.mode == ButtonMode.macro) {
              executeMacro(item.macro);
            }
          },
          onTapUp: (_) {
            if (item.mode == ButtonMode.key) {
              handleButtonUp(item.keyIndex);
            } else if (item.mode == ButtonMode.gasPct) {
              setState(() => gasPercentage = 0.0);
            } else if (item.mode == ButtonMode.brakePct) {
              setState(() => brakePercentage = 0.0);
            }
          },
          onTapCancel: () {
            if (item.mode == ButtonMode.key) {
              handleButtonUp(item.keyIndex);
            } else if (item.mode == ButtonMode.gasPct) {
              setState(() => gasPercentage = 0.0);
            } else if (item.mode == ButtonMode.brakePct) {
              setState(() => brakePercentage = 0.0);
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
        break;
      case Layout5ItemType.touchpad:
        // Touchpad: accumulates mouse delta; click type determined by finger count
        content = Listener(
          behavior: HitTestBehavior.opaque,
          onPointerDown: (e) {
            tpFingers++;
            if (tpFingers == 1) {
              if (lastTouchpadUpTime != null && DateTime.now().difference(lastTouchpadUpTime!).inMilliseconds < 300) {
                isTouchpadDragging = true;
                setState(() => tpClick = 1);
              } else {
                tpDownTime = DateTime.now();
                isTouchpadDragging = false;
              }
            }
            if (tpFingers == 2) tpWasTwo = true;
            if (tpFingers >= 3) tpWasThree = true;
          },
          onPointerMove: (e) {
            // Accumulate delta — sent in onTick bytes 9-10
            touchpadDeltaX += e.delta.dx;
            touchpadDeltaY += e.delta.dy;
          },
          onPointerUp: (e) {
            tpFingers--;
            if (tpFingers <= 0) {
              tpFingers = 0;
              bool wasDragging = isTouchpadDragging;

              if (!wasDragging && tpDownTime != null) {
                final dur = DateTime.now().difference(tpDownTime!);
                if (dur.inMilliseconds < 250) {
                  // Short tap — determine click type by finger count
                  setState(() {
                    if (tpWasThree) {
                      tpClick = 3; // middle click
                    } else if (tpWasTwo) {
                      tpClick = 2; // right click
                    } else {
                      tpClick = 1; // left click
                    }
                  });
                }
              }
              lastTouchpadUpTime = DateTime.now();
              isTouchpadDragging = false;
              tpWasTwo = false;
              tpWasThree = false;
              tpDownTime = null;

              if (wasDragging) {
                setState(() => tpClick = 0);
              }
            }
          },
          onPointerCancel: (e) {
            tpFingers = 0;
            isTouchpadDragging = false;
            tpWasTwo = false;
            tpWasThree = false;
            tpDownTime = null;
            setState(() => tpClick = 0);
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
}
