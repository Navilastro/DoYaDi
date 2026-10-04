import 'dart:ui';

// ---- Enum Tanımları ----

enum Layout5ItemType {
  leftJoystick,
  gasBar,
  brakeBar,
  buttonSquare,
  buttonSoft,
  buttonCircle,
  rightJoystick,
  touchpad,
  gasPedalIcon,   // Gaz pedal ikonu (en fazla 1 adet)
  brakePedalIcon, // Fren pedal ikonu (en fazla 1 adet)
  clutchBar,      // Debriyaj barı (en fazla 1 adet)
  clutchIcon,     // Debriyaj ikonu (en fazla 1 adet)
  handbrakeButton,// El freni butonu (en fazla 1 adet) - Eski Sürüm Uyumluluğu
  handbrakeBar,   // El freni barı (en fazla 1 adet)
  handbrakeIcon,  // El freni ikonu (en fazla 1 adet)
  steeringWheelIcon, // Direksiyon ikonu (sadece görsel, en fazla 1 adet)
}

enum ButtonMode {
  key, // Belirli bir tuşa atanmış (keyIndex: 1-25)
  gasPct, // Belirli bir gaz yüzdesi
  brakePct, // Belirli bir fren yüzdesi
  macro, // Makro
  handbrakePct, // Belirli bir el freni yüzdesi
  clutchPct, // Belirli bir debriyaj yüzdesi
}

enum MacroActionType { key, gasPct, brakePct, delay }

class MacroAction {
  final MacroActionType type;
  final double value; // tuş için 1-25, pct için 0.0-1.0, delay için milisaniye

  MacroAction({required this.type, required this.value});

  Map<String, dynamic> toJson() => {'type': type.index, 'value': value};

  factory MacroAction.fromJson(Map<String, dynamic> json) => MacroAction(
    type: MacroActionType.values[json['type'] as int],
    value: (json['value'] as num).toDouble(),
  );
}

// ---- Model ----

class Layout5Item {
  final String id;
  final Layout5ItemType type;

  // Pozisyon/boyut — normalize (0.0 - 1.0), ekran boyutuna göre hesaplanır
  double left; // sol kenar
  double top; // üst kenar
  double width; // genişlik
  double height; // yükseklik
  double rotation; // dönüş (radyan cinsinden, 0.0 - 2*pi veya derece)

  // Görsel
  Color bgColor;
  Color textColor;
  String? label; // null → varsayılan "{N} Buton"
  
  // Z-Index (Katman Sırası)
  int zIndex;

  // Mod
  ButtonMode mode;
  int keyIndex; // mode == key için (1-25)
  double modeValue; // mode == gasPct/brakePct için (0.0 - 1.0)
  List<MacroAction> macro; // mode == macro için aksiyon listesi

  // Hassasiyet (Joystick için)
  double sensitivity; // 0.5 - 3.0, varsayılan 1.0

  // Buton Basılma Modu
  int?
  customPressMode; // 0: Anlık, 1: Süreli, 2: Toggle, 3: Hızlı | null: Global kullan
  int? customPressDurationMs; // int or null: Global kullan

  // Haptik geri bildirim
  bool enableHaptic; // true ise dokunulduğunda titreşim tetiklenir
  int? customHapticType; // 0: Hafif, 1: Orta, 2: Ağır, 3: Seçim, 4: Titreşim | null: Global
  int? customHapticTrigger; // 0: Basılınca, 1: Bırakılınca, 2: Basıldığı Süre, 3: Aktif Süre | null: Global
  
  // Gyro-to-Right Analog (Joystick üzerinden)
  int gyroToRightAnalogMode; // 0: Kapalı, 1: Pilot (Mutlak), 2: FPS (Hassas/Sürüklenmeli)
  double gyroRightAnalogSensitivity;
  double gyroRightAnalogDeadzone; // Ölü alan (derece)

  // Gyro-to-Mouse (Touchpad üzerinden)
  int gyroToMouseMode; // 0: Kapalı, 1: Pilot, 2: FPS
  double gyroMouseSensitivity;
  double gyroMouseDeadzone; // Ölü alan (derece)

  Layout5Item({
    required this.id,
    required this.type,
    this.left = 0.1,
    this.top = 0.1,
    this.width = 0.2,
    this.height = 0.2,
    this.rotation = 0.0,
    this.bgColor = const Color(0xFF1A1A3E),
    this.textColor = const Color(0xFFFFFFFF),
    this.label,
    this.zIndex = 1,
    this.mode = ButtonMode.key,
    this.keyIndex = 3,
    this.modeValue = 1.0,
    this.macro = const [],
    this.sensitivity = 1.0,
    this.customPressMode,
    this.customPressDurationMs,
    this.enableHaptic = false,
    this.customHapticType,
    this.customHapticTrigger,
    this.gyroToRightAnalogMode = 0,
    this.gyroRightAnalogSensitivity = 1.0,
    this.gyroRightAnalogDeadzone = 7.0,
    this.gyroToMouseMode = 0,
    this.gyroMouseSensitivity = 1.0,
    this.gyroMouseDeadzone = 7.0,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'type': type.index,
    'left': left,
    'top': top,
    'width': width,
    'height': height,
    'rotation': rotation,
    'bgColor': bgColor.toARGB32(),
    'textColor': textColor.toARGB32(),
    'label': label,
    'zIndex': zIndex,
    'mode': mode.index,
    'keyIndex': keyIndex,
    'modeValue': modeValue,
    'macro': macro.map((e) => e.toJson()).toList(),
    'sensitivity': sensitivity,
    'customPressMode': customPressMode,
    'customPressDurationMs': customPressDurationMs,
    'enableHaptic': enableHaptic,
    'customHapticType': customHapticType,
    'customHapticTrigger': customHapticTrigger,
    'gyroToRightAnalogMode': gyroToRightAnalogMode,
    'gyroRightAnalogSensitivity': gyroRightAnalogSensitivity,
    'gyroRightAnalogDeadzone': gyroRightAnalogDeadzone,
    'gyroToMouseMode': gyroToMouseMode,
    'gyroMouseSensitivity': gyroMouseSensitivity,
    'gyroMouseDeadzone': gyroMouseDeadzone,
  };

  factory Layout5Item.fromJson(Map<String, dynamic> json) {
    List<MacroAction> parsedMacro = [];
    if (json['macro'] != null) {
      final list = json['macro'] as List;
      if (list.isNotEmpty) {
        if (list.first is int) {
          parsedMacro = list
              .map(
                (e) => MacroAction(
                  type: MacroActionType.key,
                  value: (e as int).toDouble(),
                ),
              )
              .toList();
        } else {
          parsedMacro = list
              .map((e) => MacroAction.fromJson(e as Map<String, dynamic>))
              .toList();
        }
      }
    }

    return Layout5Item(
      id: json['id'] as String,
      type: Layout5ItemType.values[json['type'] as int],
      left: (json['left'] as num).toDouble(),
      top: (json['top'] as num).toDouble(),
      width: (json['width'] as num).toDouble(),
      height: (json['height'] as num).toDouble(),
      rotation: json['rotation'] != null
          ? (json['rotation'] as num).toDouble()
          : 0.0,
      bgColor: Color(json['bgColor'] as int),
      textColor: Color(json['textColor'] as int),
      label: json['label'] as String?,
      zIndex: json['zIndex'] as int? ?? 1,
      mode: ButtonMode.values[json['mode'] as int],
      keyIndex: json['keyIndex'] as int,
      modeValue: (json['modeValue'] as num).toDouble(),
      macro: parsedMacro,
      sensitivity: json['sensitivity'] != null
          ? (json['sensitivity'] as num).toDouble()
          : 1.0,
      customPressMode: json['customPressMode'] as int?,
      customPressDurationMs: json['customPressDurationMs'] as int?,
      enableHaptic: json['enableHaptic'] as bool? ?? false,
      customHapticType: json['customHapticType'] as int?,
      customHapticTrigger: json['customHapticTrigger'] as int?,
      gyroToRightAnalogMode: json['gyroToRightAnalogMode'] as int? ?? (json['gyroToRightAnalog'] == true ? 2 : 0), // Geriye dönük uyumluluk
      gyroRightAnalogSensitivity: json['gyroRightAnalogSensitivity'] != null ? (json['gyroRightAnalogSensitivity'] as num).toDouble() : (json['gyroSensitivity'] != null ? (json['gyroSensitivity'] as num).toDouble() : 1.0),
      gyroRightAnalogDeadzone: json['gyroRightAnalogDeadzone'] != null ? (json['gyroRightAnalogDeadzone'] as num).toDouble() : 7.0,
      gyroToMouseMode: json['gyroToMouseMode'] as int? ?? 0,
      gyroMouseSensitivity: json['gyroMouseSensitivity'] != null ? (json['gyroMouseSensitivity'] as num).toDouble() : 1.0,
      gyroMouseDeadzone: json['gyroMouseDeadzone'] != null ? (json['gyroMouseDeadzone'] as num).toDouble() : 7.0,
    );
  }

  Layout5Item copyWith({
    String? id,
    Layout5ItemType? type,
    double? left,
    double? top,
    double? width,
    double? height,
    double? rotation,
    Color? bgColor,
    Color? textColor,
    String? label,
    bool clearLabel = false,
    int? zIndex,
    ButtonMode? mode,
    int? keyIndex,
    double? modeValue,
    List<MacroAction>? macro,
    double? sensitivity,
    int? customPressMode,
    bool clearCustomPressMode = false,
    int? customPressDurationMs,
    bool clearCustomPressDurationMs = false,
    bool? enableHaptic,
    int? customHapticType,
    bool clearCustomHapticType = false,
    int? customHapticTrigger,
    bool clearCustomHapticTrigger = false,
    int? gyroToRightAnalogMode,
    double? gyroRightAnalogSensitivity,
    double? gyroRightAnalogDeadzone,
    int? gyroToMouseMode,
    double? gyroMouseSensitivity,
    double? gyroMouseDeadzone,
  }) {
    return Layout5Item(
      id: id ?? this.id,
      type: type ?? this.type,
      left: left ?? this.left,
      top: top ?? this.top,
      width: width ?? this.width,
      height: height ?? this.height,
      rotation: rotation ?? this.rotation,
      bgColor: bgColor ?? this.bgColor,
      textColor: textColor ?? this.textColor,
      label: clearLabel ? null : (label ?? this.label),
      zIndex: zIndex ?? this.zIndex,
      mode: mode ?? this.mode,
      keyIndex: keyIndex ?? this.keyIndex,
      modeValue: modeValue ?? this.modeValue,
      macro: macro ?? this.macro,
      sensitivity: sensitivity ?? this.sensitivity,
      customPressMode: clearCustomPressMode
          ? null
          : (customPressMode ?? this.customPressMode),
      customPressDurationMs: clearCustomPressDurationMs
          ? null
          : (customPressDurationMs ?? this.customPressDurationMs),
      enableHaptic: enableHaptic ?? this.enableHaptic,
      customHapticType: clearCustomHapticType
          ? null
          : (customHapticType ?? this.customHapticType),
      customHapticTrigger: clearCustomHapticTrigger
          ? null
          : (customHapticTrigger ?? this.customHapticTrigger),
      gyroToRightAnalogMode: gyroToRightAnalogMode ?? this.gyroToRightAnalogMode,
      gyroRightAnalogSensitivity: gyroRightAnalogSensitivity ?? this.gyroRightAnalogSensitivity,
      gyroRightAnalogDeadzone: gyroRightAnalogDeadzone ?? this.gyroRightAnalogDeadzone,
      gyroToMouseMode: gyroToMouseMode ?? this.gyroToMouseMode,
      gyroMouseSensitivity: gyroMouseSensitivity ?? this.gyroMouseSensitivity,
      gyroMouseDeadzone: gyroMouseDeadzone ?? this.gyroMouseDeadzone,
    );
  }
}

// ---- Varsayılan Layout ----

List<Layout5Item> defaultLayout5() {
  return [
    Layout5Item(
      id: 'brake_bar',
      type: Layout5ItemType.brakeBar,
      left: 0.01,
      top: 0.05,
      width: 0.18,
      height: 0.90,
      bgColor: const Color(0xFF050525),
    ),
    Layout5Item(
      id: 'gas_bar',
      type: Layout5ItemType.gasBar,
      left: 0.81,
      top: 0.05,
      width: 0.18,
      height: 0.90,
      bgColor: const Color(0xFF050525),
    ),
    Layout5Item(
      id: 'leftJoystick_0',
      type: Layout5ItemType.leftJoystick,
      left: 0.38,
      top: 0.20,
      width: 0.10,
      height: 0.46,
      bgColor: const Color(0xFF1A1A3E),
    ),
    Layout5Item(
      id: 'rightJoystick_0',
      type: Layout5ItemType.rightJoystick,
      left: 0.62,
      top: 0.20,
      width: 0.10,
      height: 0.46,
      bgColor: const Color(0xFF1A1A3E),
    ),
  ];
}
