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
      '1': 1049,
      '2': 1050,
      '3': 1051,
      '4': 1052,
      '5': 1053,
      '6': 1054,
      '7': 1055,
      '8': 1056,
      '9': 1057,
      '0': 1048,
      ' ': 1032,
      '\'': 1222,
      '*': 1106, // Numpad *
      '+': 1137, // Özel Unicode (+)
      '-': 1189, // OEM_MINUS
      '/': 1191, // OEM_2
      '[': 1219, // OEM_4
      ']': 1221, // OEM_6
      ';': 1186, // OEM_1
      '\\': 1220, // OEM_5
      ',': 1188, // OEM_COMMA
      '.': 1190, // OEM_PERIOD
      '=': 1187, // OEM_PLUS
      'del': 1046, // VK_DELETE
      'insert': 1045, // VK_INSERT
      'win': 1091, // VK_LWIN
      'altgr': 1165, // VK_RMENU
      // Özel Shift Karakterleri ve Unicode (Sunucuda 193-213 olarak işlenir)
      '@': 1193,
      '#': 1194,
      '\$': 1195,
      '%': 1196,
      '^': 1197,
      '&': 1198,
      '(': 1199,
      ')': 1200,
      '?': 1201,
      '{': 1202,
      '}': 1203,
      '_': 1204,
      'æ': 1205,
      'Æ': 1206,
      '!': 1207,
      '<': 1208,
      '>': 1209,
      ':': 1210,
      '"': 1211,
      '|': 1212,
      'ı': 1213,
    };

    // Türkçe dile özel karakterler (yalnızca TR seçiliyse görünür)
    // Windows VK kodları: ğ=0xDB=219, ü=0xDD=221, ş=0xBA=186,
    //                     İ=0xDE=222, ö=0xBF=191, ç=0xDC=220
    // Offset 1000 eklenerek gönderilir, C++ tarafı 1000 çıkarır.
    if (isTurkish) {
      base['ğ'] = 1214; // Özel Unicode (1214 -> 214)
      base['ü'] = 1215; // Özel Unicode (1215 -> 215)
      base['ş'] = 1216; // Özel Unicode (1216 -> 216)
      base['İ'] = 1217; // Özel Unicode (1217 -> 217)
      base['ö'] = 1218; // Özel Unicode (1218 -> 218)
      base['ç'] = 1136; // Özel Unicode (1136 -> 136)
    }

    return base;
  }
}
