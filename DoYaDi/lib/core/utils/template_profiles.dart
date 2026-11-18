import 'dart:convert';
import '../../models/layout5_item.dart';
import 'app_translations.dart';

String getGameTemplate1() {
  final items = [
    Layout5Item(
      id: 'brake_1',
      type: Layout5ItemType.brakeBar,
      left: 0.0,
      top: 0.0,
      width: 0.18,
      height: 1,
    ),
    Layout5Item(
      id: 'gas_1',
      type: Layout5ItemType.gasBar,
      left: 0.82,
      top: 0.0,
      width: 0.18,
      height: 1,
    ),
    // Gaz pedalının solu üst kısmı (Tuş 8,6,5,7)
    Layout5Item(
      id: 'btn_8',
      type: Layout5ItemType.buttonCircle,
      left: 0.62,
      top: 0.25,
      width: 0.08,
      height: 0.18,
      label: 'Y',
      keyIndex: 8,
    ),
    Layout5Item(
      id: 'btn_6',
      type: Layout5ItemType.buttonCircle,
      left: 0.70,
      top: 0.43,
      width: 0.08,
      height: 0.18,
      label: 'B',
      keyIndex: 6,
    ),
    Layout5Item(
      id: 'btn_5',
      type: Layout5ItemType.buttonCircle,
      left: 0.62,
      top: 0.61,
      width: 0.08,
      height: 0.18,
      label: 'A',
      keyIndex: 5,
    ),
    Layout5Item(
      id: 'btn_7',
      type: Layout5ItemType.buttonCircle,
      left: 0.54,
      top: 0.43,
      width: 0.08,
      height: 0.18,
      label: 'X',
      keyIndex: 7,
    ),
    // Fren pedalının sağı alt kısmı (Tuş 9,12,10,11)
    Layout5Item(
      id: 'btn_9',
      type: Layout5ItemType.buttonSquare,
      left: 0.30,
      top: 0.45,
      width: 0.08,
      height: 0.18,
      label: '↑',
      keyIndex: 9,
    ),
    Layout5Item(
      id: 'btn_12',
      type: Layout5ItemType.buttonSquare,
      left: 0.38,
      top: 0.63,
      width: 0.08,
      height: 0.18,
      label: '→',
      keyIndex: 12,
    ),
    Layout5Item(
      id: 'btn_10',
      type: Layout5ItemType.buttonSquare,
      left: 0.30,
      top: 0.81,
      width: 0.08,
      height: 0.18,
      label: '↓',
      keyIndex: 10,
    ),
    Layout5Item(
      id: 'btn_11',
      type: Layout5ItemType.buttonSquare,
      left: 0.22,
      top: 0.63,
      width: 0.08,
      height: 0.18,
      label: '←',
      keyIndex: 11,
    ),
  ];
  return jsonEncode(items.map((e) => e.toJson()).toList());
}

String getControllerTemplate2() {
  final items = [
    Layout5Item(
      id: 'l_joy',
      type: Layout5ItemType.leftJoystick,
      left: 0.01,
      top: 0.42,
      width: 0.24,
      height: 0.50,
    ),
    Layout5Item(
      id: 'r_joy',
      type: Layout5ItemType.rightJoystick,
      left: 0.75,
      top: 0.42,
      width: 0.24,
      height: 0.50,
    ),
    Layout5Item(
      id: 'btn_3',
      type: Layout5ItemType.buttonCircle,
      left: 0.60,
      top: 0.75,
      width: 0.12,
      height: 0.18,
      label: 'Ana Ekran',
      keyIndex: 3,
    ),
    // D-Pad
    Layout5Item(
      id: 'btn_9',
      type: Layout5ItemType.buttonSquare,
      left: 0.36,
      top: 0.38,
      width: 0.09,
      height: 0.17,
      label: '↑',
      keyIndex: 9,
    ),
    Layout5Item(
      id: 'btn_12',
      type: Layout5ItemType.buttonSquare,
      left: 0.45,
      top: 0.55,
      width: 0.09,
      height: 0.17,
      label: '→',
      keyIndex: 12,
    ),
    Layout5Item(
      id: 'btn_10',
      type: Layout5ItemType.buttonSquare,
      left: 0.36,
      top: 0.72,
      width: 0.09,
      height: 0.17,
      label: '↓',
      keyIndex: 10,
    ),
    Layout5Item(
      id: 'btn_11',
      type: Layout5ItemType.buttonSquare,
      left: 0.27,
      top: 0.55,
      width: 0.09,
      height: 0.17,
      label: '←',
      keyIndex: 11,
    ),
    // ABXY
    Layout5Item(
      id: 'btn_8',
      type: Layout5ItemType.buttonCircle,
      left: 0.59,
      top: 0.12,
      width: 0.09,
      height: 0.17,
      label: 'Y',
      keyIndex: 8,
    ),
    Layout5Item(
      id: 'btn_6',
      type: Layout5ItemType.buttonCircle,
      left: 0.68,
      top: 0.29,
      width: 0.09,
      height: 0.17,
      label: 'B',
      keyIndex: 6,
    ),
    Layout5Item(
      id: 'btn_5',
      type: Layout5ItemType.buttonCircle,
      left: 0.59,
      top: 0.46,
      width: 0.09,
      height: 0.17,
      label: 'A',
      keyIndex: 5,
    ),
    Layout5Item(
      id: 'btn_7',
      type: Layout5ItemType.buttonCircle,
      left: 0.50,
      top: 0.29,
      width: 0.09,
      height: 0.17,
      label: 'X',
      keyIndex: 7,
    ),
    // L1, R1
    Layout5Item(
      id: 'btn_1',
      type: Layout5ItemType.buttonSoft,
      left: 0.03,
      top: 0.05,
      width: 0.16,
      height: 0.14,
      label: 'L1',
      keyIndex: 1,
    ),
    Layout5Item(
      id: 'btn_2',
      type: Layout5ItemType.buttonSoft,
      left: 0.81,
      top: 0.05,
      width: 0.16,
      height: 0.14,
      label: 'R1',
      keyIndex: 2,
    ),
  ];
  return jsonEncode(items.map((e) => e.toJson()).toList());
}

String getKeyboardMouseTemplate() {
  final items = [
    Layout5Item(
      id: 'tp_1',
      type: Layout5ItemType.touchpad,
      left: 0.60,
      top: 0.40,
      width: 0.40,
      height: 0.60,
    ),
    Layout5Item(
      id: 'btn_w',
      type: Layout5ItemType.buttonSquare,
      left: 0.15,
      top: 0.30,
      width: 0.08,
      height: 0.18,
      label: 'W',
      keyIndex: 187,
    ),
    Layout5Item(
      id: 'btn_a',
      type: Layout5ItemType.buttonSquare,
      left: 0.07,
      top: 0.48,
      width: 0.08,
      height: 0.18,
      label: 'A',
      keyIndex: 165,
    ),
    Layout5Item(
      id: 'btn_s',
      type: Layout5ItemType.buttonSquare,
      left: 0.15,
      top: 0.48,
      width: 0.08,
      height: 0.18,
      label: 'S',
      keyIndex: 183,
    ),
    Layout5Item(
      id: 'btn_d',
      type: Layout5ItemType.buttonSquare,
      left: 0.23,
      top: 0.48,
      width: 0.08,
      height: 0.18,
      label: 'D',
      keyIndex: 168,
    ),
    Layout5Item(
      id: 'btn_space',
      type: Layout5ItemType.buttonSquare,
      left: 0.07,
      top: 0.66,
      width: 0.24,
      height: 0.18,
      label: AppTranslations.getText('space'),
      keyIndex: 132,
    ),
    Layout5Item(
      id: 'btn_shift',
      type: Layout5ItemType.buttonSquare,
      left: 0.07,
      top: 0.84,
      width: 0.16,
      height: 0.15,
      label: AppTranslations.getText('shift'),
      keyIndex: 116,
    ),
    Layout5Item(
      id: 'btn_ctrl',
      type: Layout5ItemType.buttonSquare,
      left: 0.23,
      top: 0.84,
      width: 0.16,
      height: 0.15,
      label: AppTranslations.getText('ctrl'),
      keyIndex: 117,
    ),
  ];
  return jsonEncode(items.map((e) => e.toJson()).toList());
}

/// Tam gamepad düzeni: çift joystick, ABXY, D-Pad, LB/RB, LT/RT (gas/brake bar),
/// Start ve Select tuşları, L3/R3.
/// Sol taraf: LT (fren bar), LB, Sol Joystick, D-Pad
/// Sağ taraf: RT (gaz bar), RB, Sağ Joystick, ABXY
String getFullControllerTemplate() {
  final items = [
    // Sol joystick (L_Joy)
    Layout5Item(
      id: 'l_joy',
      type: Layout5ItemType.leftJoystick,
      left: 0.03,
      top: 0.55,
      width: 0.20,
      height: 0.40,
    ),
    // Sağ joystick (R_Joy)
    Layout5Item(
      id: 'r_joy',
      type: Layout5ItemType.rightJoystick,
      left: 0.77,
      top: 0.55,
      width: 0.20,
      height: 0.40,
    ),
    // LT (sol tetik) — fren bar
    Layout5Item(
      id: 'lt_bar',
      type: Layout5ItemType.brakeBar,
      left: 0.02,
      top: 0.02,
      width: 0.10,
      height: 0.28,
    ),
    // RT (sağ tetik) — gaz bar
    Layout5Item(
      id: 'rt_bar',
      type: Layout5ItemType.gasBar,
      left: 0.88,
      top: 0.02,
      width: 0.10,
      height: 0.28,
    ),
    // L1
    Layout5Item(
      id: 'btn_lb',
      type: Layout5ItemType.buttonSoft,
      left: 0.14,
      top: 0.02,
      width: 0.12,
      height: 0.12,
      label: 'L1',
      keyIndex: 1,
    ),
    // R1
    Layout5Item(
      id: 'btn_rb',
      type: Layout5ItemType.buttonSoft,
      left: 0.74,
      top: 0.02,
      width: 0.12,
      height: 0.12,
      label: 'R1',
      keyIndex: 2,
    ),
    // D-Pad (Up: left 0.28, top 0.35 | Left: 0.20, top 0.48 | Right: 0.36, top 0.48 | Down: 0.28, top 0.61)
    Layout5Item(
      id: 'dp_up',
      type: Layout5ItemType.buttonSquare,
      left: 0.31,
      top: 0.25,
      width: 0.08,
      height: 0.13,
      label: '↑',
      keyIndex: 9,
    ),
    Layout5Item(
      id: 'dp_left',
      type: Layout5ItemType.buttonSquare,
      left: 0.23,
      top: 0.38,
      width: 0.08,
      height: 0.13,
      label: '←',
      keyIndex: 11,
    ),
    Layout5Item(
      id: 'dp_right',
      type: Layout5ItemType.buttonSquare,
      left: 0.39,
      top: 0.38,
      width: 0.08,
      height: 0.13,
      label: '→',
      keyIndex: 12,
    ),
    Layout5Item(
      id: 'dp_down',
      type: Layout5ItemType.buttonSquare,
      left: 0.31,
      top: 0.51,
      width: 0.08,
      height: 0.13,
      label: '↓',
      keyIndex: 10,
    ),
    // ABXY (Y: left 0.82, top 0.15 | X: 0.72, top 0.25 | B: 0.92, top 0.25 | A: 0.82, top 0.35)
    Layout5Item(
      id: 'btn_y',
      type: Layout5ItemType.buttonCircle,
      left: 0.61,
      top: 0.25,
      width: 0.08,
      height: 0.13,
      label: 'Y',
      keyIndex: 8,
    ),
    Layout5Item(
      id: 'btn_x',
      type: Layout5ItemType.buttonCircle,
      left: 0.53,
      top: 0.38,
      width: 0.08,
      height: 0.13,
      label: 'X',
      keyIndex: 7,
    ),
    Layout5Item(
      id: 'btn_b',
      type: Layout5ItemType.buttonCircle,
      left: 0.69,
      top: 0.38,
      width: 0.08,
      height: 0.13,
      label: 'B',
      keyIndex: 6,
    ),
    Layout5Item(
      id: 'btn_a',
      type: Layout5ItemType.buttonCircle,
      left: 0.61,
      top: 0.51,
      width: 0.08,
      height: 0.13,
      label: 'A',
      keyIndex: 5,
    ),
    // Select & Start (merkez)
    Layout5Item(
      id: 'btn_sel',
      type: Layout5ItemType.buttonSoft,
      left: 0.38,
      top: 0.05,
      width: 0.10,
      height: 0.10,
      label: 'Select',
      keyIndex: 13,
    ),
    Layout5Item(
      id: 'btn_start',
      type: Layout5ItemType.buttonSoft,
      left: 0.52,
      top: 0.05,
      width: 0.10,
      height: 0.10,
      label: 'Start',
      keyIndex: 14,
    ),
    // L3 & R3
    Layout5Item(
      id: 'btn_l3',
      type: Layout5ItemType.buttonSquare,
      left: 0.09,
      top: 0.40,
      width: 0.08,
      height: 0.12,
      label: 'L3',
      keyIndex: 17,
    ),
    Layout5Item(
      id: 'btn_r3',
      type: Layout5ItemType.buttonSquare,
      left: 0.83,
      top: 0.40,
      width: 0.08,
      height: 0.12,
      label: 'R3',
      keyIndex: 18,
    ),
  ];
  return jsonEncode(items.map((e) => e.toJson()).toList());
}

/// Oyuncu klavye düzeni: WASD, Space, Shift, Ctrl, Q, E, R, F ve F1-F4.
/// keyIndex >= 100 → C++ tarafı 1000 çıkarır → gerçek VK kodu.
/// W=1087(VK87), A=1065(VK65), S=1083(VK83), D=1068(VK68)
/// Q=1081, E=1069, R=1082, F=1070
/// Space=1032(VK32), Shift=1016(VK16), Ctrl=1017(VK17)
/// F1=1112, F2=1113, F3=1114, F4=1115
String getGamerKeyboardTemplate() {
  final items = [
    // WASD grubu (sol üst)
    Layout5Item(
      id: 'kb_w',
      type: Layout5ItemType.buttonSquare,
      left: 0.16,
      top: 0.10,
      width: 0.09,
      height: 0.16,
      label: 'W',
      keyIndex: 1087,
    ),
    Layout5Item(
      id: 'kb_a',
      type: Layout5ItemType.buttonSquare,
      left: 0.07,
      top: 0.26,
      width: 0.09,
      height: 0.16,
      label: 'A',
      keyIndex: 1065,
    ),
    Layout5Item(
      id: 'kb_s',
      type: Layout5ItemType.buttonSquare,
      left: 0.16,
      top: 0.26,
      width: 0.09,
      height: 0.16,
      label: 'S',
      keyIndex: 1083,
    ),
    Layout5Item(
      id: 'kb_d',
      type: Layout5ItemType.buttonSquare,
      left: 0.25,
      top: 0.26,
      width: 0.09,
      height: 0.16,
      label: 'D',
      keyIndex: 1068,
    ),
    // Q, E üst sıra
    Layout5Item(
      id: 'kb_q',
      type: Layout5ItemType.buttonSoft,
      left: 0.07,
      top: 0.10,
      width: 0.09,
      height: 0.16,
      label: 'Q',
      keyIndex: 1081,
    ),
    Layout5Item(
      id: 'kb_e',
      type: Layout5ItemType.buttonSoft,
      left: 0.25,
      top: 0.10,
      width: 0.09,
      height: 0.16,
      label: 'E',
      keyIndex: 1069,
    ),
    // R, F eylem tuşları
    Layout5Item(
      id: 'kb_r',
      type: Layout5ItemType.buttonSoft,
      left: 0.07,
      top: 0.42,
      width: 0.09,
      height: 0.16,
      label: 'R',
      keyIndex: 1082,
    ),
    Layout5Item(
      id: 'kb_f',
      type: Layout5ItemType.buttonSoft,
      left: 0.16,
      top: 0.42,
      width: 0.09,
      height: 0.16,
      label: 'F',
      keyIndex: 1070,
    ),
    // Space (geniş)
    Layout5Item(
      id: 'kb_space',
      type: Layout5ItemType.buttonSquare,
      left: 0.07,
      top: 0.58,
      width: 0.28,
      height: 0.16,
      label: AppTranslations.getText('space'),
      keyIndex: 1032,
    ),
    // Shift, Ctrl
    Layout5Item(
      id: 'kb_shift',
      type: Layout5ItemType.buttonSoft,
      left: 0.07,
      top: 0.74,
      width: 0.14,
      height: 0.14,
      label: AppTranslations.getText('shift'),
      keyIndex: 1016,
    ),
    Layout5Item(
      id: 'kb_ctrl',
      type: Layout5ItemType.buttonSoft,
      left: 0.21,
      top: 0.74,
      width: 0.14,
      height: 0.14,
      label: 'Ctrl',
      keyIndex: 1017,
    ),
    // F1-F4 (sağ üst köşe, yatay)
    Layout5Item(
      id: 'kb_f1',
      type: Layout5ItemType.buttonSoft,
      left: 0.60,
      top: 0.04,
      width: 0.09,
      height: 0.13,
      label: 'F1',
      keyIndex: 1112,
    ),
    Layout5Item(
      id: 'kb_f2',
      type: Layout5ItemType.buttonSoft,
      left: 0.70,
      top: 0.04,
      width: 0.09,
      height: 0.13,
      label: 'F2',
      keyIndex: 1113,
    ),
    Layout5Item(
      id: 'kb_f3',
      type: Layout5ItemType.buttonSoft,
      left: 0.80,
      top: 0.04,
      width: 0.09,
      height: 0.13,
      label: 'F3',
      keyIndex: 1114,
    ),
    Layout5Item(
      id: 'kb_f4',
      type: Layout5ItemType.buttonSoft,
      left: 0.90,
      top: 0.04,
      width: 0.09,
      height: 0.13,
      label: 'F4',
      keyIndex: 1115,
    ),
  ];
  return jsonEncode(items.map((e) => e.toJson()).toList());
}

Layout5Item _kbKey(
  String id,
  String label,
  int keyIndex,
  double left,
  double top,
  double width,
  double height, {
  bool square = true,
}) {
  return Layout5Item(
    id: id,
    type: square ? Layout5ItemType.buttonSquare : Layout5ItemType.buttonSoft,
    left: left,
    top: top,
    width: width,
    height: height,
    label: label,
    keyIndex: keyIndex,
  );
}

String getFullKeyboardTemplate() {
  final items = <Layout5Item>[
    // Satır 0: Esc + F1..F12 + Del
    _kbKey('fk_esc', 'Esc', 1027, 0.024, 0.03, 0.064, 0.13, square: false),
    for (int i = 0; i < 12; i++)
      _kbKey(
        'fk_f${i + 1}',
        'F${i + 1}',
        1112 + i,
        0.092 + i * 0.068,
        0.03,
        0.064,
        0.13,
        square: false,
      ),
    _kbKey('fk_del', 'Del', 1046, 0.908, 0.03, 0.068, 0.13, square: false),

    // Satır 1: 1..0 + Backspace
    for (final d in [
      ('1', 1049, 0),
      ('2', 1050, 1),
      ('3', 1051, 2),
      ('4', 1052, 3),
      ('5', 1053, 4),
      ('6', 1054, 5),
      ('7', 1055, 6),
      ('8', 1056, 7),
      ('9', 1057, 8),
      ('0', 1048, 9),
    ])
      _kbKey('fk_${d.$1}', d.$1, d.$2, 0.02 + d.$3 * 0.076, 0.19, 0.072, 0.14),
    _kbKey('fk_bksp', 'Bksp', 1008, 0.78, 0.19, 0.196, 0.14, square: false),

    // Satır 2: Tab + Q..P
    _kbKey('fk_tab', 'Tab', 1009, 0.02, 0.36, 0.11, 0.15, square: false),
    for (final k in [
      ('Q', 1081, 0),
      ('W', 1087, 1),
      ('E', 1069, 2),
      ('R', 1082, 3),
      ('T', 1084, 4),
      ('Y', 1089, 5),
      ('U', 1085, 6),
      ('I', 1073, 7),
      ('O', 1079, 8),
      ('P', 1080, 9),
    ])
      _kbKey('fk_${k.$1}', k.$1, k.$2, 0.138 + k.$3 * 0.084, 0.36, 0.079, 0.15),

    // Satır 3: Caps + A..L + Enter
    _kbKey('fk_caps', 'Caps', 1020, 0.02, 0.53, 0.10, 0.15, square: false),
    for (final k in [
      ('A', 1065, 0),
      ('S', 1083, 1),
      ('D', 1068, 2),
      ('F', 1070, 3),
      ('G', 1071, 4),
      ('H', 1072, 5),
      ('J', 1074, 6),
      ('K', 1075, 7),
      ('L', 1076, 8),
    ])
      _kbKey('fk_${k.$1}', k.$1, k.$2, 0.128 + k.$3 * 0.076, 0.53, 0.072, 0.15),
    _kbKey('fk_enter', 'Enter', 1013, 0.816, 0.53, 0.16, 0.15, square: false),

    // Satır 4: Shift + Z..M + , + . + Up Arrow
    _kbKey(
      'fk_shift',
      AppTranslations.getText('shift'),
      1016,
      0.02,
      0.70,
      0.12,
      0.14,
      square: false,
    ),
    for (final k in [
      ('Z', 1090, 0),
      ('X', 1088, 1),
      ('C', 1067, 2),
      ('V', 1086, 3),
      ('B', 1066, 4),
      ('N', 1078, 5),
      ('M', 1077, 6),
    ])
      _kbKey('fk_${k.$1}', k.$1, k.$2, 0.148 + k.$3 * 0.079, 0.70, 0.074, 0.14),
    _kbKey('fk_comma', ',', 1145, 0.703, 0.70, 0.06, 0.14),
    _kbKey('fk_dot', '.', 1146, 0.768, 0.70, 0.06, 0.14),
    _kbKey('fk_up', '↑', 1038, 0.85, 0.70, 0.06, 0.14),

    // Satır 5: Ctrl + Win + Alt + Space + Left/Down/Right Arrows
    _kbKey('fk_ctrl', 'Ctrl', 1017, 0.02, 0.86, 0.09, 0.12, square: false),
    _kbKey('fk_win', 'Win', 1091, 0.115, 0.86, 0.08, 0.12, square: false),
    _kbKey('fk_alt', 'Alt', 1018, 0.20, 0.86, 0.08, 0.12, square: false),
    _kbKey(
      'fk_space',
      AppTranslations.getText('space'),
      1032,
      0.285,
      0.86,
      0.47,
      0.12,
      square: false,
    ),
    _kbKey('fk_left', '←', 1037, 0.785, 0.86, 0.06, 0.12),
    _kbKey('fk_down', '↓', 1040, 0.85, 0.86, 0.06, 0.12),
    _kbKey('fk_right', '→', 1039, 0.915, 0.86, 0.06, 0.12),
  ];
  return jsonEncode(items.map((e) => e.toJson()).toList());
}

String getFullKeyboardTouchpadTemplate() {
  final items = <Layout5Item>[
    // Sol bölüm: Kompakt Tam QWERTY Klavye (0.02..0.64)
    // Satır 0: Esc + 1..0 + Backspace
    _kbKey('kt_esc', 'Esc', 1027, 0.02, 0.04, 0.066, 0.14, square: false),
    for (final d in [
      ('1', 1049, 0),
      ('2', 1050, 1),
      ('3', 1051, 2),
      ('4', 1052, 3),
      ('5', 1053, 4),
      ('6', 1054, 5),
      ('7', 1055, 6),
      ('8', 1056, 7),
      ('9', 1057, 8),
      ('0', 1048, 9),
    ])
      _kbKey('kt_${d.$1}', d.$1, d.$2, 0.09 + d.$3 * 0.049, 0.04, 0.045, 0.14),
    _kbKey('kt_bksp', 'Bksp', 1008, 0.582, 0.04, 0.058, 0.14, square: false),

    // Satır 1: Tab + Q..P
    _kbKey('kt_tab', 'Tab', 1009, 0.02, 0.21, 0.072, 0.15, square: false),
    for (final k in [
      ('Q', 1081, 0),
      ('W', 1087, 1),
      ('E', 1069, 2),
      ('R', 1082, 3),
      ('T', 1084, 4),
      ('Y', 1089, 5),
      ('U', 1085, 6),
      ('I', 1073, 7),
      ('O', 1079, 8),
      ('P', 1080, 9),
    ])
      _kbKey('kt_${k.$1}', k.$1, k.$2, 0.096 + k.$3 * 0.054, 0.21, 0.05, 0.15),

    // Satır 2: Caps + A..L + Enter
    _kbKey('kt_caps', 'Caps', 1020, 0.02, 0.39, 0.076, 0.15, square: false),
    for (final k in [
      ('A', 1065, 0),
      ('S', 1083, 1),
      ('D', 1068, 2),
      ('F', 1070, 3),
      ('G', 1071, 4),
      ('H', 1072, 5),
      ('J', 1074, 6),
      ('K', 1075, 7),
      ('L', 1076, 8),
    ])
      _kbKey('kt_${k.$1}', k.$1, k.$2, 0.10 + k.$3 * 0.052, 0.39, 0.048, 0.15),
    _kbKey('kt_enter', 'Enter', 1013, 0.57, 0.39, 0.07, 0.15, square: false),

    // Satır 3: Shift + Z..M + Up + Del
    _kbKey(
      'kt_shift',
      AppTranslations.getText('shift'),
      1016,
      0.02,
      0.57,
      0.088,
      0.15,
      square: false,
    ),
    for (final k in [
      ('Z', 1090, 0),
      ('X', 1088, 1),
      ('C', 1067, 2),
      ('V', 1086, 3),
      ('B', 1066, 4),
      ('N', 1078, 5),
      ('M', 1077, 6),
    ])
      _kbKey('kt_${k.$1}', k.$1, k.$2, 0.112 + k.$3 * 0.056, 0.57, 0.052, 0.15),
    _kbKey('kt_up', '↑', 1038, 0.515, 0.57, 0.055, 0.15),
    _kbKey('kt_del', 'Del', 1046, 0.575, 0.57, 0.065, 0.15, square: false),

    // Satır 4: Ctrl + Alt + Space + Yön Tuşları
    _kbKey('kt_ctrl', 'Ctrl', 1017, 0.02, 0.76, 0.08, 0.19, square: false),
    _kbKey('kt_alt', 'Alt', 1018, 0.105, 0.76, 0.075, 0.19, square: false),
    _kbKey(
      'kt_space',
      AppTranslations.getText('space'),
      1032,
      0.185,
      0.76,
      0.265,
      0.19,
      square: false,
    ),
    _kbKey('kt_left', '←', 1037, 0.455, 0.76, 0.055, 0.19),
    _kbKey('kt_down', '↓', 1040, 0.515, 0.76, 0.055, 0.19),
    _kbKey('kt_right', '→', 1039, 0.575, 0.76, 0.065, 0.19),

    // Sağ bölüm: Touchpad + Sol/Sağ Tık
    Layout5Item(
      id: 'kt_touchpad',
      type: Layout5ItemType.touchpad,
      left: 0.66,
      top: 0.04,
      width: 0.32,
      height: 0.71,
    ),
    _kbKey(
      'kt_lclick',
      AppTranslations.getText('left_click'),
      2001,
      0.66,
      0.77,
      0.155,
      0.18,
      square: false,
    ),
    _kbKey(
      'kt_rclick',
      AppTranslations.getText('right_click'),
      2003,
      0.825,
      0.77,
      0.155,
      0.18,
      square: false,
    ),
  ];
  return jsonEncode(items.map((e) => e.toJson()).toList());
}
