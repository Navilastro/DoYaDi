import 'dart:convert';
import '../../models/layout5_item.dart';
import 'app_translations.dart';

String getGameTemplate1() {
  final items = [
    Layout5Item(id: 'brake_1', type: Layout5ItemType.brakeBar, left: 0.02, top: 0.1, width: 0.18, height: 0.8),
    Layout5Item(id: 'gas_1', type: Layout5ItemType.gasBar, left: 0.80, top: 0.1, width: 0.18, height: 0.8),
    // Gaz pedalının solu üst kısmı (Tuş 8,6,5,7)
    Layout5Item(id: 'btn_8', type: Layout5ItemType.buttonCircle, left: 0.62, top: 0.25, width: 0.08, height: 0.18, label: 'Y', keyIndex: 8),
    Layout5Item(id: 'btn_6', type: Layout5ItemType.buttonCircle, left: 0.70, top: 0.43, width: 0.08, height: 0.18, label: 'B', keyIndex: 6),
    Layout5Item(id: 'btn_5', type: Layout5ItemType.buttonCircle, left: 0.62, top: 0.61, width: 0.08, height: 0.18, label: 'A', keyIndex: 5),
    Layout5Item(id: 'btn_7', type: Layout5ItemType.buttonCircle, left: 0.54, top: 0.43, width: 0.08, height: 0.18, label: 'X', keyIndex: 7),
    // Fren pedalının sağı alt kısmı (Tuş 9,12,10,11)
    Layout5Item(id: 'btn_9', type: Layout5ItemType.buttonSquare, left: 0.30, top: 0.50, width: 0.08, height: 0.18, label: '↑', keyIndex: 9),
    Layout5Item(id: 'btn_12', type: Layout5ItemType.buttonSquare, left: 0.38, top: 0.68, width: 0.08, height: 0.18, label: '→', keyIndex: 12),
    Layout5Item(id: 'btn_10', type: Layout5ItemType.buttonSquare, left: 0.30, top: 0.86, width: 0.08, height: 0.18, label: '↓', keyIndex: 10),
    Layout5Item(id: 'btn_11', type: Layout5ItemType.buttonSquare, left: 0.22, top: 0.68, width: 0.08, height: 0.18, label: '←', keyIndex: 11),
  ];
  return jsonEncode(items.map((e) => e.toJson()).toList());
}

String getControllerTemplate2() {
  final items = [
    Layout5Item(id: 'l_joy', type: Layout5ItemType.leftJoystick, left: 0.05, top: 0.4, width: 0.22, height: 0.55),
    Layout5Item(id: 'r_joy', type: Layout5ItemType.rightJoystick, left: 0.73, top: 0.4, width: 0.22, height: 0.55),
    Layout5Item(id: 'btn_3', type: Layout5ItemType.buttonCircle, left: 0.46, top: 0.6, width: 0.08, height: 0.18, label: 'Steam', keyIndex: 3),
    // D-Pad
    Layout5Item(id: 'btn_9', type: Layout5ItemType.buttonSquare, left: 0.28, top: 0.50, width: 0.08, height: 0.18, label: '↑', keyIndex: 9),
    Layout5Item(id: 'btn_12', type: Layout5ItemType.buttonSquare, left: 0.36, top: 0.68, width: 0.08, height: 0.18, label: '→', keyIndex: 12),
    Layout5Item(id: 'btn_10', type: Layout5ItemType.buttonSquare, left: 0.28, top: 0.86, width: 0.08, height: 0.18, label: '↓', keyIndex: 10),
    Layout5Item(id: 'btn_11', type: Layout5ItemType.buttonSquare, left: 0.20, top: 0.68, width: 0.08, height: 0.18, label: '←', keyIndex: 11),
    // ABXY
    Layout5Item(id: 'btn_8', type: Layout5ItemType.buttonCircle, left: 0.68, top: 0.15, width: 0.08, height: 0.18, label: 'Y', keyIndex: 8),
    Layout5Item(id: 'btn_6', type: Layout5ItemType.buttonCircle, left: 0.76, top: 0.33, width: 0.08, height: 0.18, label: 'B', keyIndex: 6),
    Layout5Item(id: 'btn_5', type: Layout5ItemType.buttonCircle, left: 0.68, top: 0.51, width: 0.08, height: 0.18, label: 'A', keyIndex: 5),
    Layout5Item(id: 'btn_7', type: Layout5ItemType.buttonCircle, left: 0.60, top: 0.33, width: 0.08, height: 0.18, label: 'X', keyIndex: 7),
    // LB, RB
    Layout5Item(id: 'btn_1', type: Layout5ItemType.buttonSoft, left: 0.05, top: 0.05, width: 0.15, height: 0.15, label: 'LB', keyIndex: 1),
    Layout5Item(id: 'btn_2', type: Layout5ItemType.buttonSoft, left: 0.80, top: 0.05, width: 0.15, height: 0.15, label: 'RB', keyIndex: 2),
  ];
  return jsonEncode(items.map((e) => e.toJson()).toList());
}

String getKeyboardMouseTemplate() {
  final items = [
    Layout5Item(id: 'tp_1', type: Layout5ItemType.touchpad, left: 0.30, top: 0.40, width: 0.40, height: 0.55),
    Layout5Item(id: 'btn_w', type: Layout5ItemType.buttonSquare, left: 0.15, top: 0.30, width: 0.08, height: 0.18, label: 'W', keyIndex: 187),
    Layout5Item(id: 'btn_a', type: Layout5ItemType.buttonSquare, left: 0.07, top: 0.48, width: 0.08, height: 0.18, label: 'A', keyIndex: 165),
    Layout5Item(id: 'btn_s', type: Layout5ItemType.buttonSquare, left: 0.15, top: 0.48, width: 0.08, height: 0.18, label: 'S', keyIndex: 183),
    Layout5Item(id: 'btn_d', type: Layout5ItemType.buttonSquare, left: 0.23, top: 0.48, width: 0.08, height: 0.18, label: 'D', keyIndex: 168),
    Layout5Item(id: 'btn_space', type: Layout5ItemType.buttonSquare, left: 0.07, top: 0.66, width: 0.24, height: 0.18, label: AppTranslations.getText('space'), keyIndex: 132),
    Layout5Item(id: 'btn_shift', type: Layout5ItemType.buttonSquare, left: 0.07, top: 0.84, width: 0.16, height: 0.15, label: AppTranslations.getText('shift'), keyIndex: 116),
  ];
  return jsonEncode(items.map((e) => e.toJson()).toList());
}

/// Tam gamepad düzeni: çift joystick, ABXY, D-Pad, LB/RB, LT/RT (gas/brake bar),
/// Start ve Select tuşları.
String getFullControllerTemplate() {
  final items = [
    // Sol joystick (sol alt)
    Layout5Item(id: 'l_joy', type: Layout5ItemType.leftJoystick, left: 0.03, top: 0.52, width: 0.26, height: 0.45),
    // Sağ joystick (sağ alt)
    Layout5Item(id: 'r_joy', type: Layout5ItemType.rightJoystick, left: 0.71, top: 0.52, width: 0.26, height: 0.45),
    // LT (sol tetik) — gaz bar olarak
    Layout5Item(id: 'lt_bar', type: Layout5ItemType.gasBar, left: 0.00, top: 0.00, width: 0.12, height: 0.30),
    // RT (sağ tetik) — fren bar olarak
    Layout5Item(id: 'rt_bar', type: Layout5ItemType.brakeBar, left: 0.88, top: 0.00, width: 0.12, height: 0.30),
    // LB
    Layout5Item(id: 'btn_lb', type: Layout5ItemType.buttonSoft, left: 0.00, top: 0.30, width: 0.14, height: 0.14, label: 'LB', keyIndex: 1),
    // RB
    Layout5Item(id: 'btn_rb', type: Layout5ItemType.buttonSoft, left: 0.86, top: 0.30, width: 0.14, height: 0.14, label: 'RB', keyIndex: 2),
    // D-Pad (sol orta)
    Layout5Item(id: 'dp_up',   type: Layout5ItemType.buttonSquare, left: 0.27, top: 0.44, width: 0.09, height: 0.16, label: '↑', keyIndex: 9),
    Layout5Item(id: 'dp_right',type: Layout5ItemType.buttonSquare, left: 0.36, top: 0.60, width: 0.09, height: 0.16, label: '→', keyIndex: 12),
    Layout5Item(id: 'dp_down', type: Layout5ItemType.buttonSquare, left: 0.27, top: 0.76, width: 0.09, height: 0.16, label: '↓', keyIndex: 10),
    Layout5Item(id: 'dp_left', type: Layout5ItemType.buttonSquare, left: 0.18, top: 0.60, width: 0.09, height: 0.16, label: '←', keyIndex: 11),
    // ABXY (sağ orta)
    Layout5Item(id: 'btn_y', type: Layout5ItemType.buttonCircle, left: 0.60, top: 0.28, width: 0.09, height: 0.16, label: 'Y', keyIndex: 8),
    Layout5Item(id: 'btn_b', type: Layout5ItemType.buttonCircle, left: 0.69, top: 0.44, width: 0.09, height: 0.16, label: 'B', keyIndex: 6),
    Layout5Item(id: 'btn_a', type: Layout5ItemType.buttonCircle, left: 0.60, top: 0.60, width: 0.09, height: 0.16, label: 'A', keyIndex: 5),
    Layout5Item(id: 'btn_x', type: Layout5ItemType.buttonCircle, left: 0.51, top: 0.44, width: 0.09, height: 0.16, label: 'X', keyIndex: 7),
    // Select & Start (merkez)
    Layout5Item(id: 'btn_sel', type: Layout5ItemType.buttonSoft, left: 0.39, top: 0.07, width: 0.10, height: 0.12, label: 'Sel', keyIndex: 13),
    Layout5Item(id: 'btn_start', type: Layout5ItemType.buttonSoft, left: 0.51, top: 0.07, width: 0.10, height: 0.12, label: 'Start', keyIndex: 14),
    // L3 & R3 (Analog Stick Click — XUSB 0x0040 / 0x0080)
    Layout5Item(id: 'btn_l3', type: Layout5ItemType.buttonSquare, left: 0.28, top: 0.20, width: 0.08, height: 0.15, label: 'L3', keyIndex: 17),
    Layout5Item(id: 'btn_r3', type: Layout5ItemType.buttonSquare, left: 0.64, top: 0.20, width: 0.08, height: 0.15, label: 'R3', keyIndex: 18),
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
    Layout5Item(id: 'kb_w',     type: Layout5ItemType.buttonSquare, left: 0.16, top: 0.10, width: 0.09, height: 0.16, label: 'W',     keyIndex: 1087),
    Layout5Item(id: 'kb_a',     type: Layout5ItemType.buttonSquare, left: 0.07, top: 0.26, width: 0.09, height: 0.16, label: 'A',     keyIndex: 1065),
    Layout5Item(id: 'kb_s',     type: Layout5ItemType.buttonSquare, left: 0.16, top: 0.26, width: 0.09, height: 0.16, label: 'S',     keyIndex: 1083),
    Layout5Item(id: 'kb_d',     type: Layout5ItemType.buttonSquare, left: 0.25, top: 0.26, width: 0.09, height: 0.16, label: 'D',     keyIndex: 1068),
    // Q, E üst sıra
    Layout5Item(id: 'kb_q',     type: Layout5ItemType.buttonSoft,   left: 0.07, top: 0.10, width: 0.09, height: 0.16, label: 'Q',     keyIndex: 1081),
    Layout5Item(id: 'kb_e',     type: Layout5ItemType.buttonSoft,   left: 0.25, top: 0.10, width: 0.09, height: 0.16, label: 'E',     keyIndex: 1069),
    // R, F eylem tuşları
    Layout5Item(id: 'kb_r',     type: Layout5ItemType.buttonSoft,   left: 0.07, top: 0.42, width: 0.09, height: 0.16, label: 'R',     keyIndex: 1082),
    Layout5Item(id: 'kb_f',     type: Layout5ItemType.buttonSoft,   left: 0.16, top: 0.42, width: 0.09, height: 0.16, label: 'F',     keyIndex: 1070),
    // Space (geniş)
    Layout5Item(id: 'kb_space', type: Layout5ItemType.buttonSquare, left: 0.07, top: 0.58, width: 0.28, height: 0.16, label: AppTranslations.getText('space'), keyIndex: 1032),
    // Shift, Ctrl
    Layout5Item(id: 'kb_shift', type: Layout5ItemType.buttonSoft,   left: 0.07, top: 0.74, width: 0.14, height: 0.14, label: AppTranslations.getText('shift'), keyIndex: 1016),
    Layout5Item(id: 'kb_ctrl',  type: Layout5ItemType.buttonSoft,   left: 0.21, top: 0.74, width: 0.14, height: 0.14, label: 'Ctrl',  keyIndex: 1017),
    // F1-F4 (sağ üst köşe, yatay)
    Layout5Item(id: 'kb_f1',    type: Layout5ItemType.buttonSoft,   left: 0.60, top: 0.04, width: 0.09, height: 0.13, label: 'F1',    keyIndex: 1112),
    Layout5Item(id: 'kb_f2',    type: Layout5ItemType.buttonSoft,   left: 0.70, top: 0.04, width: 0.09, height: 0.13, label: 'F2',    keyIndex: 1113),
    Layout5Item(id: 'kb_f3',    type: Layout5ItemType.buttonSoft,   left: 0.80, top: 0.04, width: 0.09, height: 0.13, label: 'F3',    keyIndex: 1114),
    Layout5Item(id: 'kb_f4',    type: Layout5ItemType.buttonSoft,   left: 0.90, top: 0.04, width: 0.09, height: 0.13, label: 'F4',    keyIndex: 1115),
  ];
  return jsonEncode(items.map((e) => e.toJson()).toList());
}
