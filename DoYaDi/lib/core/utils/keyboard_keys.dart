import 'package:doyadi/core/utils/app_translations.dart';

class KeyboardKeys {
  static Map<String, int> get appKeyMap {
    final bool isTurkish = AppTranslations.currentLanguage == 'tr';

    final Map<String, int> base = {
      AppTranslations.getText('none_disabled'): 0,
      AppTranslations.getText('btn_a'): 5,
      AppTranslations.getText('btn_b'): 6,
      AppTranslations.getText('btn_x'): 7,
      AppTranslations.getText('btn_y'): 8,
      AppTranslations.getText('btn_lb'): 1,
      AppTranslations.getText('btn_rb'): 2,
      AppTranslations.getText('btn_guide'): 3,
      AppTranslations.getText('btn_dpad_up'): 9,
      AppTranslations.getText('btn_dpad_down'): 10,
      AppTranslations.getText('btn_dpad_left'): 11,
      AppTranslations.getText('btn_dpad_right'): 12,
      AppTranslations.getText('btn_start'): 13,
      AppTranslations.getText('btn_back'): 14,
      // Xbox L3 / R3 (Analog Stick Click)
      AppTranslations.getText('btn_l3'): 17,
      AppTranslations.getText('btn_r3'): 18,
      // Fare tuşları (temiz isimler)
      AppTranslations.getText('left_click'): 2001,
      AppTranslations.getText('middle_click'): 2002,
      AppTranslations.getText('right_click'): 2003,
      // Klavye tuşları (temiz isimler ve küçük harfler)
      AppTranslations.getText('up_arrow'): 1038,
      AppTranslations.getText('down_arrow'): 1040,
      AppTranslations.getText('left_arrow'): 1037,
      AppTranslations.getText('right_arrow'): 1039,
      'Backspace': 1008,
      'Tab': 1009,
      'Enter': 1013,
      AppTranslations.getText('shift'): 1016,
      'Ctrl': 1017,
      'Alt': 1018,
      'Pause': 1019,
      'Caps Lock': 1020,
      'Esc': 1027,
      AppTranslations.getText('space'): 1032,
      'Page Up': 1033,
      'Page Down': 1034,
      'End': 1035,
      'Home': 1036,
      // F tuşları (VK_F1=0x70=112 → offset 1000 → 1112)
      'F1': 1112,
      'F2': 1113,
      'F3': 1114,
      'F4': 1115,
      'F5': 1116,
      'F6': 1117,
      'F7': 1118,
      'F8': 1119,
      'F9': 1120,
      'F10': 1121,
      'F11': 1122,
      'F12': 1123,
      // Latin harfler
      'a': 1065,
      'b': 1066,
      'c': 1067,
      'd': 1068,
      'e': 1069,
      'f': 1070,
      'g': 1071,
      'h': 1072,
      'i': 1073,
      'j': 1074,
      'k': 1075,
      'l': 1076,
      'm': 1077,
      'n': 1078,
      'o': 1079,
      'p': 1080,
      'q': 1081,
      'r': 1082,
      's': 1083,
      't': 1084,
      'u': 1085,
      'v': 1086,
      'w': 1087,
      'x': 1088,
      'y': 1089,
      'z': 1090,
      // rakamlar
      '1': 1065,
      '2': 1066,
      '3': 1067,
      '4': 1068,
      '5': 1069,
      '6': 1070,
      '7': 1071,
      '8': 1072,
      '9': 1073,
      '0': 1074,
      '\'': 1091,
      '*': 1092,
      '+': 1093,
      '-': 1094,
      '.': 1095,
      '/': 1096,
      '@': 1097,
      '#': 1098,
      '\$': 1099,
      '%': 1100,
      '^': 1101,
      '&': 1102,
      '(': 1103,
      ')': 1104,
      ' ': 1032,
      '[': 1219,
      ']': 1221,
      ';': 1186,
      '\\': 1222,
      ',': 1188,
      '.': 1190,
    };

    // Türkçe dile özel karakterler (yalnızca TR seçiliyse görünür)
    // Windows VK kodları: ğ=0xDB=219, ü=0xDD=221, ş=0xBA=186,
    //                     İ=0xDE=222, ö=0xBF=191, ç=0xDC=220
    // Offset 1000 eklenerek gönderilir, C++ tarafı 1000 çıkarır.
    if (isTurkish) {
      base['ğ'] = 1219; // VK 0xDB=219
      base['ü'] = 1221; // VK 0xDD=221
      base['ş'] = 1186; // VK 0xBA=186
      base['İ'] = 1222; // VK 0xDE=222
      base['ö'] = 1191; // VK 0xBF=191
      base['ç'] = 1220; // VK 0xDC=220
    }

    return base;
  }
}
