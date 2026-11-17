/// Uygulama Flavor'larını (varyantlarını) tanımlayan enum.
enum AppFlavor {
  /// Tüm modları (0-10) ve tam Mod 5'i içeren ana/kapsamlı sürüm.
  oyuku,

  /// Mod 0, 1, 2, 3, 4, 6, 7, 8 sürüş modlarını içeren sürüm.
  doyadi,

  /// Uçak kokpit ve HUD modlarını (9, 10) içeren sürüm.
  planeLever,

  /// Yalnızca sanal klavye/fare amaçlı kısıtlı Mod 5'i (5) içeren sürüm.
  sanrevye,
}

/// Tek kod tabanından 4 farklı uygulama üretebilmek için merkezi yapılandırma sınıfı.
class AppConfig {
  AppConfig._internal();

  static final AppConfig instance = AppConfig._internal();

  AppFlavor _currentFlavor = AppFlavor.oyuku;

  /// Aktif uygulama flavor'ı.
  AppFlavor get currentFlavor => _currentFlavor;

  /// Uygulamayı belirtilen [flavor] ile başlatır.
  void init(AppFlavor flavor) {
    _currentFlavor = flavor;
  }

  /// `--flavor <ad>` (`FLUTTER_APP_FLAVOR`) veya `--dart-define=FLAVOR=...`
  /// parametresinden flavor'ı okuyarak başlatır.
  /// Tanımlı değilse veya geçersizse [defaultFlavor] kullanılır.
  void initFromEnvironment({AppFlavor defaultFlavor = AppFlavor.oyuku}) {
    const String customDefine = String.fromEnvironment('FLAVOR', defaultValue: '');
    const String flutterFlavor = String.fromEnvironment(
      'FLUTTER_APP_FLAVOR',
      defaultValue: '',
    );
    final String raw = customDefine.trim().isNotEmpty
        ? customDefine
        : flutterFlavor;
    final AppFlavor resolved = switch (raw.trim().toLowerCase()) {
      'oyuku' => AppFlavor.oyuku,
      'doyadi' => AppFlavor.doyadi,
      'planelever' || 'plane_lever' || 'plane-lever' => AppFlavor.planeLever,
      'sanrevye' => AppFlavor.sanrevye,
      _ => defaultFlavor,
    };
    init(resolved);
  }

  /// Flavor'a göre görünen uygulama adı.
  String get appName {
    switch (_currentFlavor) {
      case AppFlavor.oyuku:
        return 'OyuKu';
      case AppFlavor.doyadi:
        return 'DoYaDi';
      case AppFlavor.planeLever:
        return 'Plane Lever';
      case AppFlavor.sanrevye:
        return 'SanReVye';
    }
  }

  /// Bu flavor'da kullanılmasına izin verilen mod numaraları listesi.
  List<int> get allowedModes {
    switch (_currentFlavor) {
      case AppFlavor.oyuku:
        return const [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10];
      case AppFlavor.doyadi:
        return const [0, 1, 2, 3, 4, 6, 7, 8];
      case AppFlavor.planeLever:
        return const [9, 10];
      case AppFlavor.sanrevye:
        return const [5];
    }
  }

  /// OyuKu flavor'ında tüm Mod 5 özellikleri (Joystick, Direksiyon, Pedal vb.) açıktır.
  bool get hasFullMod5 => _currentFlavor == AppFlavor.oyuku;

  /// SanReVye flavor'ında Mod 5 yalnızca Klavye Tuşu, Touchpad ve Makro ile kısıtlıdır.
  bool get hasRestrictedMod5 => _currentFlavor == AppFlavor.sanrevye;

  /// Belirtilen [mode] numarasının bu flavor'da izinli olup olmadığını döndürür.
  bool isModeAllowed(int mode) => allowedModes.contains(mode);

  /// Verilen [mode] izinli değilse flavor'ın ilk izinli modunu döndürür.
  int sanitizeMode(int mode) {
    final modes = allowedModes;
    if (modes.contains(mode)) return mode;
    return modes.first;
  }
}
