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
