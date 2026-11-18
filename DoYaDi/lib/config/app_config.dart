/// Uygulama Flavor'larını (varyantlarını) tanımlayan enum.
enum AppFlavor {
  /// OyuKu: Virtual Improved Gamepad — Tüm modlar (0-10) + Sınırsız Mod 5 Editörü.
  oyuku,

  /// DoYaDi: Virtual Racing Wheel — Sadece sürüş modları [0, 1, 2, 3, 4, 6, 7, 8], Mod 5 kapalı.
  doyadi,

  /// VirPleLev: Virtual Plane Lever — Sadece uçak modları [9, 10], Mod 5 kapalı.
  virplelev,

  /// SanReVye: Virtual Mouse Keyboard — Sadece kısıtlı Mod 5 [5] (Klavye, Makro, Touchpad).
  sanrevye,

  /// Admin (VIP): Tüm modlar (0-10) + Reklamsız ve Sınırsız PRO deneyimi.
  admin,
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
      'virplelev' || 'planelever' || 'plane_lever' || 'plane-lever' =>
        AppFlavor.virplelev,
      'sanrevye' => AppFlavor.sanrevye,
      'admin' || 'boss' || 'doyadiboss' => AppFlavor.admin,
      _ => defaultFlavor,
    };
    init(resolved);
  }

  /// Admin (VIP) sürümü mü aktif? Reklam ve paywall kısıtlamalarını tamamen kaldırır.
  bool get isVIP => _currentFlavor == AppFlavor.admin;

  /// Flavor'a göre görünen uygulama adı.
  String get appName {
    switch (_currentFlavor) {
      case AppFlavor.oyuku:
        return 'OyuKu';
      case AppFlavor.doyadi:
        return 'DoYaDi';
      case AppFlavor.virplelev:
        return 'VirPleLev';
      case AppFlavor.sanrevye:
        return 'SanReVye';
      case AppFlavor.admin:
        return 'DoYaDi Boss';
    }
  }

  /// Bu flavor'da kullanılmasına izin verilen mod numaraları listesi.
  List<int> get allowedModes {
    switch (_currentFlavor) {
      case AppFlavor.oyuku:
      case AppFlavor.admin:
        return const [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10];
      case AppFlavor.doyadi:
        return const [0, 1, 2, 3, 4, 6, 7, 8];
      case AppFlavor.virplelev:
        return const [9, 10];
      case AppFlavor.sanrevye:
        return const [5];
    }
  }

  /// OyuKu ve Admin flavor'larında tüm Mod 5 özellikleri (Joystick, Direksiyon, Pedal vb.) açıktır.
  bool get hasFullMod5 =>
      _currentFlavor == AppFlavor.oyuku || _currentFlavor == AppFlavor.admin;

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
