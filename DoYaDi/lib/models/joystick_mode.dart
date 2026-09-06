/// Joystick çalışma modları.
///
/// Her mod sol ve sağ joystick için ortaklaşa (global) uygulanır.
/// Hassasiyet ayarı ise `Layout5Item.sensitivity` ile öğe bazında ayrı tutulur.
enum JoystickMode {
  /// Sabit — joystick orijinal konumda kalır.
  /// Parmak sınır dışına çıksa bile PointerUp gelene kadar veri akar.
  fixed, // 0

  /// Sürüklenen — parmak hareket ettikçe joystick merkezi takip eder.
  /// Parmak kalktığında yay (spring) animasyonuyla orijinal yerine döner.
  floatingBase, // 1

  /// Belirme — boş alana dokunulduğunda en yakın joystick orada belirir.
  /// Voronoi / mesafe mantığı ile hangi joystick'e ait olduğu belirlenir.
  spawn, // 2

  /// Belirme + Sürükleme — spawn gibi boş alana dokunarak joystick başlatılır,
  /// ancak parmak sürüklendiğinde floating gibi base takip eder.
  /// Parmak kalktığında joystick kaybolur (spawn davranışı).
  floatingSpawn, // 3
}

/// JoystickMode yardımcı uzantıları.
extension JoystickModeX on JoystickMode {
  /// Spawn tabanlı mod mu? (spawn veya floatingSpawn)
  /// Ekrandaki joystick ghost olarak çizilir, etkileşim SpawnLayer'da yönetilir.
  bool get isSpawnLike => this == JoystickMode.spawn || this == JoystickMode.floatingSpawn;

  /// Base sürükleme (floating) davranışı aktif mi?
  bool get isFloating => this == JoystickMode.floatingBase || this == JoystickMode.floatingSpawn;
}
