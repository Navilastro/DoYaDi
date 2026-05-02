import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/settings_provider.dart';
import '../models/app_settings.dart';
import 'custom_layout5_editor_screen.dart';

// ── Direksiyon: 1'den 1080'e tüm değerler (Max level at 1) ─────────────────
final _steeringAngles = {
  'Max level at 1 (1°)': 1,
  for (int v = 2; v <= 10; v++) '$v°': v,
  for (int v = 15; v <= 30; v += 5) '$v°': v,
  for (int v = 40; v <= 90; v += 10) '$v°': v,
  '100°': 100,
  '120°': 120,
  '150°': 150,
  '180° (Varsayılan)': 180,
  '270°': 270,
  '360°': 360,
  '540°': 540,
  '720°': 720,
  '900°': 900,
  '1080°': 1080,
};

// ── Pedal ivme mesafesi: 0-80 mm (5 mm = Pro) ───────────────────────────────
final _pedalDistances = <String, int>{
  '0 mm': 0,
  '5 mm (for pro)': 5,
  '10 mm': 10,
  '15 mm': 15,
  '20 mm (Varsayılan)': 20,
  '25 mm': 25,
  '30 mm': 30,
  '35 mm': 35,
  '40 mm': 40,
  '45 mm': 45,
  '50 mm': 50,
  '60 mm': 60,
  '70 mm': 70,
  '80 mm': 80,
};

// ── Kaydırma hassasiyeti (mm) ────────────────────────────────────────────────
final _swipeSensitivities = <String, double>{
  '0 mm': 0.0,
  '0.125 mm': 0.125,
  '0.25 mm': 0.25,
  '0.5 mm': 0.5,
  '0.75 mm': 0.75,
  '1.0 mm': 1.0,
  '1.25 mm': 1.25,
  '1.5 mm': 1.5,
  '1.75 mm': 1.75,
  '2.0 mm': 2.0,
  '2.25 mm': 2.25,
  '2.5 mm': 2.5,
  '2.75 mm': 2.75,
  '3.0 mm': 3.0,
  '3.5 mm': 3.5,
  '4.0 mm': 4.0,
};

// ── Tıklama üst süresi ───────────────────────────────────────────────────────
final _clickDurations = <String, double>{
  '0.05 sec': 0.05,
  '0.1 sec': 0.1,
  '0.2 sec': 0.2,
  '0.3 sec (Varsayılan)': 0.30,
  '0.4 sec': 0.4,
  '0.5 sec': 0.5,
  '0.6 sec': 0.6,
  '0.7 sec': 0.7,
  '0.8 sec': 0.8,
  '0.9 sec': 0.9,
  '1.0 sec': 1.0,
  'unlimited': 9999.0,
};

// ── Sıfır konum yönelimi ─────────────────────────────────────────────────────
const _zeroOrientationOptions = <String, int>{
  'Auto': 0,
  'Screen faces on top': 1,
  'Screen faces on your body': 2,
};

// ── Swipe atama seçenekleri ──────────────────────────────────────────────────
const _swipeDirLabels = <String, int>{
  'Bar Doldur ↑ (Yukarı Başlat)': -1,
  'Bar Doldur ↓ (Aşağı Başlat)': -2,
  'Yok (Devre Dışı)': 0,
  'Tuş 1': 1,
  'Tuş 2': 2,
  'Tuş 3': 3,
  'Tuş 4': 4,
  'Tuş 5': 5,
  'Tuş 6': 6,
  'Tuş 7': 7,
  'Tuş 8': 8,
  'Tuş 9': 9,
  'Tuş 10': 10,
  'Tuş 11': 11,
  'Tuş 12': 12,
  'Tuş 13': 13,
  'Tuş 14': 14,
  'Tuş 15': 15,
  'Tuş 16': 16,
};

const _keyLabels = <String, int>{
  'Yok (Devre Dışı)': 0,
  'Tuş 1': 1,
  'Tuş 2': 2,
  'Tuş 3': 3,
  'Tuş 4': 4,
  'Tuş 5': 5,
  'Tuş 6': 6,
  'Tuş 7': 7,
  'Tuş 8': 8,
  'Tuş 9': 9,
  'Tuş 10': 10,
  'Tuş 11': 11,
  'Tuş 12': 12,
  'Tuş 13': 13,
  'Tuş 14': 14,
  'Tuş 15': 15,
  'Tuş 16': 16,
};

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tab;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  String _keyName(int v) => _keyLabels.entries
      .firstWhere((e) => e.value == v, orElse: () => const MapEntry('?', 0))
      .key;

  String _swipeName(int v) {
    if (v == -1) return 'Bar ↑';
    if (v == -2) return 'Bar ↓';
    return _keyLabels.entries
        .firstWhere((e) => e.value == v, orElse: () => const MapEntry('Yok', 0))
        .key;
  }

  Future<T?> _radioDialog<T>({
    required BuildContext ctx,
    required String title,
    required T current,
    required Map<String, T> options,
  }) {
    return showDialog<T>(
      context: ctx,
      builder: (dctx) {
        T selected = current;
        return StatefulBuilder(
          builder: (dctx, ss) {
            return AlertDialog(
              backgroundColor: const Color(0xFF12122A),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
              title: Text(
                title,
                style: const TextStyle(color: Colors.white, fontSize: 15),
              ),
              content: SizedBox(
                width: double.maxFinite,
                child: ListView(
                  shrinkWrap: true,
                  children: options.entries.map((e) {
                    final isSel = selected == e.value;
                    return InkWell(
                      onTap: () => ss(() => selected = e.value),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        child: Row(
                          children: [
                            Radio<T>(
                              value: e.value,
                              groupValue: selected,
                              activeColor: const Color(0xFF40E0D0),
                              onChanged: (v) => ss(() => selected = v as T),
                            ),
                            Text(
                              e.key,
                              style: TextStyle(
                                color: isSel
                                    ? const Color(0xFF40E0D0)
                                    : Colors.white70,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dctx),
                  child: const Text(
                    'İptal',
                    style: TextStyle(color: Colors.white54),
                  ),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF40E0D0),
                    foregroundColor: Colors.black,
                  ),
                  onPressed: () => Navigator.pop(dctx, selected),
                  child: const Text('Uygula'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<int?> _swipeDialog(BuildContext ctx, String title, int current) =>
      _radioDialog<int>(
        ctx: ctx,
        title: title,
        current: current,
        options: _swipeDirLabels,
      );

  Future<int?> _keyDialog(BuildContext ctx, String title, int current) =>
      _radioDialog<int>(
        ctx: ctx,
        title: title,
        current: current,
        options: _keyLabels,
      );

  Future<Color?> _showRgbPicker(
    BuildContext ctx,
    Color initial,
    String title,
  ) async {
    int r = (initial.r * 255.0).round().clamp(0, 255);
    int g = (initial.g * 255.0).round().clamp(0, 255);
    int b = (initial.b * 255.0).round().clamp(0, 255);
    return showDialog<Color>(
      context: ctx,
      builder: (dctx) => StatefulBuilder(
        builder: (dctx, ss) {
          final preview = Color.fromARGB(255, r, g, b);
          return AlertDialog(
            backgroundColor: const Color(0xFF12122A),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
            title: Text(
              title,
              style: const TextStyle(color: Colors.white, fontSize: 15),
            ),
            content: SizedBox(
              width: double.maxFinite,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      height: 50,
                      decoration: BoxDecoration(
                        color: preview,
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    const SizedBox(height: 16),
                    _rgbSlider('R', r, Colors.red, ss, (v) => r = v),
                    _rgbSlider('G', g, Colors.green, ss, (v) => g = v),
                    _rgbSlider('B', b, Colors.blue, ss, (v) => b = v),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dctx),
                child: const Text(
                  'İptal',
                  style: TextStyle(color: Colors.white54),
                ),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: preview),
                onPressed: () =>
                    Navigator.pop(dctx, Color.fromARGB(255, r, g, b)),
                child: const Text(
                  'Uygula',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _rgbSlider(
    String ch,
    int val,
    Color tc,
    StateSetter ss,
    void Function(int) cb,
  ) {
    return Row(
      children: [
        SizedBox(
          width: 18,
          child: Text(
            ch,
            style: TextStyle(
              color: tc,
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
          ),
        ),
        Expanded(
          child: SliderTheme(
            data: SliderThemeData(
              activeTrackColor: tc,
              thumbColor: tc,
              inactiveTrackColor: tc.withValues(alpha: 0.2),
              overlayColor: tc.withValues(alpha: 0.1),
            ),
            child: Slider(
              value: val.toDouble(),
              min: 0,
              max: 255,
              divisions: 255,
              onChanged: (v) => ss(() => cb(v.round())),
            ),
          ),
        ),
        SizedBox(
          width: 34,
          child: Text(
            val.toString(),
            style: const TextStyle(color: Colors.white70, fontSize: 12),
            textAlign: TextAlign.end,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<SettingsProvider>(context);
    final s = provider.settings;
    final ac = s.detailColor;

    return Scaffold(
      backgroundColor: s.backgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.white,
        title: const Text(
          'Ayarlar',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        bottom: TabBar(
          controller: _tab,
          indicatorColor: ac,
          labelColor: ac,
          unselectedLabelColor: Colors.white38,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          tabs: const [
            Tab(text: 'Ana'),
            Tab(text: 'Direksiyon'),
            Tab(text: 'Atama'),
            Tab(text: 'Renkler'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tab,
        children: [
          _buildMain(context, provider, s, ac),
          _buildSteering(context, provider, s, ac),
          _buildAssign(context, provider, s, ac),
          _buildColors(context, provider, s),
        ],
      ),
    );
  }

  Widget _buildMain(
    BuildContext ctx,
    SettingsProvider prov,
    AppSettings s,
    Color ac,
  ) {
    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 8),
      children: [
        _header('Sürüş Modu'),
        _tile(
          title: 'Varsayılan sürüş modu',
          trailing: Text(
            'Mod ${s.defaultDrivingMode}',
            style: TextStyle(color: ac, fontWeight: FontWeight.bold),
          ),
          onTap: () async {
            final val = await _radioDialog<int>(
              ctx: ctx,
              title: 'Varsayılan sürüş modu',
              current: s.defaultDrivingMode,
              options: {for (var i = 0; i <= 5; i++) 'Mod $i': i},
            );
            if (val != null) {
              s.defaultDrivingMode = val;
              prov.updateSettings(s);
              setState(() {});
            }
          },
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: ElevatedButton.icon(
            icon: const Icon(Icons.edit),
            label: Text(
              s.defaultDrivingMode == 5
                  ? 'Özel Düzeni Düzenle (Mod 5)'
                  : 'Tuşları Düzenle (Mod ${s.defaultDrivingMode})',
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: ac,
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: () {
              if (s.defaultDrivingMode == 5) {
                Navigator.push(
                  ctx,
                  MaterialPageRoute(
                    builder: (_) => const CustomLayout5EditorScreen(),
                  ),
                );
              } else {
                _showModeKeyAssignmentsDialog(
                  ctx,
                  prov,
                  s,
                  s.defaultDrivingMode,
                );
              }
            },
          ),
        ),
        const Divider(color: Colors.white12, height: 24),
        _header('Pedal'),
        _tile(
          title: 'Sağ Pedal',
          subtitle: 'Varsayılan: Gaz — sağ taraf',
          trailing: const Icon(Icons.chevron_right, color: Colors.white38),
          onTap: () => _showModeKeyAssignmentsDialog(ctx, prov, s, -1),
        ),
        _tile(
          title: 'Sol Pedal',
          subtitle: 'Varsayılan: Fren — sol taraf',
          trailing: const Icon(Icons.chevron_right, color: Colors.white38),
          onTap: () => _showModeKeyAssignmentsDialog(ctx, prov, s, -2),
        ),
        const Divider(color: Colors.white12, height: 8),
        _tile(
          title: 'İvmelenme ve Fren mesafesi',
          subtitle: '%100 pedal için gereken mesafe',
          trailing: Text(
            '${s.swipeSensitivity == 5
                ? "5 mm (for pro)"
                : s.swipeSensitivity == 0
                ? "0 mm"
                : "${s.swipeSensitivity.toInt()} mm"}',
            style: TextStyle(color: ac, fontWeight: FontWeight.bold),
          ),
          onTap: () async {
            final val = await _radioDialog<int>(
              ctx: ctx,
              title: 'İvmelenme ve Fren Mesafesi',
              current: s.swipeSensitivity.toInt(),
              options: _pedalDistances,
            );
            if (val != null) {
              s.swipeSensitivity = val.toDouble();
              prov.updateSettings(s);
              setState(() {});
            }
          },
        ),
        _tile(
          title: 'Kaydırma hassasiyeti (tıklama)',
          subtitle: 'Bu mesafeden az kayarsa tıklama sayılır',
          trailing: Text(
            s.clickMaxDistance == 0 ? '0 mm' : '${s.clickMaxDistance} mm',
            style: TextStyle(color: ac, fontWeight: FontWeight.bold),
          ),
          onTap: () async {
            final val = await _radioDialog<double>(
              ctx: ctx,
              title: 'Kaydırma Hassasiyeti',
              current: s.clickMaxDistance,
              options: _swipeSensitivities,
            );
            if (val != null) {
              s.clickMaxDistance = val;
              prov.updateSettings(s);
              setState(() {});
            }
          },
        ),
        _tile(
          title: 'Tıklama üst (maksimum) süresi',
          subtitle: 'Bu süreden kısa dokunma = tıklama',
          trailing: Text(
            s.clickMaxDuration >= 9999
                ? 'unlimited'
                : '${s.clickMaxDuration.toStringAsFixed(2)} sec',
            style: TextStyle(color: ac, fontWeight: FontWeight.bold),
          ),
          onTap: () async {
            final val = await _radioDialog<double>(
              ctx: ctx,
              title: 'Tıklama üst süresi',
              current: s.clickMaxDuration,
              options: _clickDurations,
            );
            if (val != null) {
              s.clickMaxDuration = val;
              prov.updateSettings(s);
              setState(() {});
            }
          },
        ),
        const Divider(color: Colors.white12, height: 24),
        _header('Donanım Tuşları'),
        _tile(
          title: 'Ses Açma → Tuş',
          trailing: Text(
            _keyName(s.volumeUpAction),
            style: TextStyle(color: ac, fontWeight: FontWeight.bold),
          ),
          onTap: () async {
            final val = await _keyDialog(
              ctx,
              'Ses Açma eylemi',
              s.volumeUpAction,
            );
            if (val != null) {
              s.volumeUpAction = val;
              prov.updateSettings(s);
              setState(() {});
            }
          },
        ),
        _tile(
          title: 'Ses Kısma → Tuş',
          trailing: Text(
            _keyName(s.volumeDownAction),
            style: TextStyle(color: ac, fontWeight: FontWeight.bold),
          ),
          onTap: () async {
            final val = await _keyDialog(
              ctx,
              'Ses Kısma eylemi',
              s.volumeDownAction,
            );
            if (val != null) {
              s.volumeDownAction = val;
              prov.updateSettings(s);
              setState(() {});
            }
          },
        ),
      ],
    );
  }

  Widget _buildSteering(
    BuildContext ctx,
    SettingsProvider prov,
    AppSettings s,
    Color ac,
  ) {
    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 8),
      children: [
        _header('Sensör'),
        SwitchListTile(
          title: const Text(
            'Jiroskop kullan',
            style: TextStyle(color: Colors.white, fontSize: 15),
          ),
          subtitle: const Text(
            'İvmeölçer ve jiroskopu birleştirir',
            style: TextStyle(color: Colors.white38, fontSize: 12),
          ),
          value: s.useGyroscope,
          activeThumbColor: ac,
          onChanged: (val) {
            s.useGyroscope = val;
            prov.updateSettings(s);
          },
        ),
        _tile(
          title: 'Phone orientation for zero position',
          subtitle: _zeroOrientationOptions.entries
              .firstWhere(
                (e) => e.value == s.zeroOrientation,
                orElse: () => const MapEntry('Auto', 0),
              )
              .key,
          trailing: Icon(Icons.screen_rotation, color: ac),
          onTap: () async {
            final val = await _radioDialog<int>(
              ctx: ctx,
              title: 'Phone orientation for zero position',
              current: s.zeroOrientation,
              options: _zeroOrientationOptions,
            );
            if (val != null) {
              s.zeroOrientation = val;
              prov.updateSettings(s);
              setState(() {});
            }
          },
        ),
        const Divider(color: Colors.white12, height: 24),
        _header('Direksiyon Hassasiyeti'),
        _tile(
          title: 'Direksiyon açısı',
          subtitle: 'Küçük değer = daha hassas',
          trailing: Text(
            s.steeringAngle <= 1
                ? 'Max level at 1 (1°)'
                : '${s.steeringAngle.toInt()}°',
            style: TextStyle(
              color: ac,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          onTap: () async {
            final val = await _radioDialog<int>(
              ctx: ctx,
              title: 'Direksiyon açısı',
              current: s.steeringAngle.toInt(),
              options: _steeringAngles,
            );
            if (val != null) {
              s.steeringAngle = val.toDouble();
              prov.updateSettings(s);
              setState(() {});
            }
          },
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white12),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Nasıl çalışır',
                  style: TextStyle(
                    color: Colors.white70,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 6),
                Text(
                  '1° — Max level at 1 (ultra duyarlı)\n'
                  '75° — ultra hassas (simülasyon)\n'
                  '180° — dengeli (varsayılan)\n'
                  '540° — gerçekçi araba hissi\n'
                  '1080° — kamyon / simülatör',
                  style: TextStyle(
                    color: Colors.white38,
                    fontSize: 12,
                    height: 1.6,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAssign(
    BuildContext ctx,
    SettingsProvider prov,
    AppSettings s,
    Color ac,
  ) {
    Future<void> pick(
      String label,
      int current,
      void Function(int) save,
    ) async {
      final val = await _swipeDialog(ctx, label, current);
      if (val != null) {
        save(val);
        prov.updateSettings(s);
        setState(() {});
      }
    }

    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 8),
      children: [
        _header('Sağ Pedal (Gaz) — Kaydırma Yönleri'),
        _swipeTile(
          ac,
          '↑ Yukarı',
          _swipeName(s.gasSwipeUp),
          () => pick('Gaz ↑ Yukarı', s.gasSwipeUp, (v) => s.gasSwipeUp = v),
        ),
        _swipeTile(
          ac,
          '↓ Aşağı',
          _swipeName(s.gasSwipeDown),
          () => pick('Gaz ↓ Aşağı', s.gasSwipeDown, (v) => s.gasSwipeDown = v),
        ),
        _swipeTile(
          ac,
          '← Sol',
          _swipeName(s.gasSwipeLeft),
          () => pick('Gaz ← Sol', s.gasSwipeLeft, (v) => s.gasSwipeLeft = v),
        ),
        _swipeTile(
          ac,
          '→ Sağ',
          _swipeName(s.gasSwipeRight),
          () => pick('Gaz → Sağ', s.gasSwipeRight, (v) => s.gasSwipeRight = v),
        ),
        _swipeTile(
          ac,
          '↖ Sol Üst',
          _swipeName(s.gasSwipeUpLeft),
          () => pick(
            'Gaz ↖ Sol Üst',
            s.gasSwipeUpLeft,
            (v) => s.gasSwipeUpLeft = v,
          ),
        ),
        _swipeTile(
          ac,
          '↗ Sağ Üst',
          _swipeName(s.gasSwipeUpRight),
          () => pick(
            'Gaz ↗ Sağ Üst',
            s.gasSwipeUpRight,
            (v) => s.gasSwipeUpRight = v,
          ),
        ),
        _swipeTile(
          ac,
          '↙ Sol Alt',
          _swipeName(s.gasSwipeDownLeft),
          () => pick(
            'Gaz ↙ Sol Alt',
            s.gasSwipeDownLeft,
            (v) => s.gasSwipeDownLeft = v,
          ),
        ),
        _swipeTile(
          ac,
          '↘ Sağ Alt',
          _swipeName(s.gasSwipeDownRight),
          () => pick(
            'Gaz ↘ Sağ Alt',
            s.gasSwipeDownRight,
            (v) => s.gasSwipeDownRight = v,
          ),
        ),

        const Divider(color: Colors.white12, height: 32),
        _header('Sol Pedal (Fren) — Kaydırma Yönleri'),
        _swipeTile(
          ac,
          '↑ Yukarı',
          _swipeName(s.brakeSwipeUp),
          () =>
              pick('Fren ↑ Yukarı', s.brakeSwipeUp, (v) => s.brakeSwipeUp = v),
        ),
        _swipeTile(
          ac,
          '↓ Aşağı',
          _swipeName(s.brakeSwipeDown),
          () => pick(
            'Fren ↓ Aşağı',
            s.brakeSwipeDown,
            (v) => s.brakeSwipeDown = v,
          ),
        ),
        _swipeTile(
          ac,
          '← Sol',
          _swipeName(s.brakeSwipeLeft),
          () =>
              pick('Fren ← Sol', s.brakeSwipeLeft, (v) => s.brakeSwipeLeft = v),
        ),
        _swipeTile(
          ac,
          '→ Sağ',
          _swipeName(s.brakeSwipeRight),
          () => pick(
            'Fren → Sağ',
            s.brakeSwipeRight,
            (v) => s.brakeSwipeRight = v,
          ),
        ),
        _swipeTile(
          ac,
          '↖ Sol Üst',
          _swipeName(s.brakeSwipeUpLeft),
          () => pick(
            'Fren ↖ Sol Üst',
            s.brakeSwipeUpLeft,
            (v) => s.brakeSwipeUpLeft = v,
          ),
        ),
        _swipeTile(
          ac,
          '↗ Sağ Üst',
          _swipeName(s.brakeSwipeUpRight),
          () => pick(
            'Fren ↗ Sağ Üst',
            s.brakeSwipeUpRight,
            (v) => s.brakeSwipeUpRight = v,
          ),
        ),
        _swipeTile(
          ac,
          '↙ Sol Alt',
          _swipeName(s.brakeSwipeDownLeft),
          () => pick(
            'Fren ↙ Sol Alt',
            s.brakeSwipeDownLeft,
            (v) => s.brakeSwipeDownLeft = v,
          ),
        ),
        _swipeTile(
          ac,
          '↘ Sağ Alt',
          _swipeName(s.brakeSwipeDownRight),
          () => pick(
            'Fren ↘ Sağ Alt',
            s.brakeSwipeDownRight,
            (v) => s.brakeSwipeDownRight = v,
          ),
        ),
      ],
    );
  }

  Widget _swipeTile(
    Color ac,
    String dir,
    String assigned,
    VoidCallback? onTap,
  ) {
    final isFixed = onTap == null;
    return ListTile(
      dense: true,
      leading: Text(
        dir.substring(0, 2),
        style: const TextStyle(fontSize: 20, color: Colors.white70),
      ),
      title: Text(
        dir.substring(2).trim(),
        style: const TextStyle(color: Colors.white, fontSize: 14),
      ),
      trailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: isFixed
              ? Colors.white.withValues(alpha: 0.05)
              : ac.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isFixed ? Colors.white12 : ac.withValues(alpha: 0.4),
          ),
        ),
        child: Text(
          isFixed ? 'Bar (fixed)' : assigned,
          style: TextStyle(
            color: isFixed ? Colors.white38 : ac,
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      onTap: onTap,
    );
  }

  Widget _buildColors(BuildContext ctx, SettingsProvider prov, AppSettings s) {
    row(String label, Color cur, void Function(Color) cb) =>
        _buildColorRow(ctx, prov, s, label, cur, cb);
    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 8),
      children: [
        _header('Genel'),
        row('Arka plan', s.backgroundColor, (c) {
          s.backgroundColor = c;
          prov.updateSettings(s);
        }),
        row('Vurgu / Detay', s.detailColor, (c) {
          s.detailColor = c;
          prov.updateSettings(s);
        }),
        const Divider(color: Colors.white12, height: 24),
        _header('Direksiyon göstergesi'),
        row('Gösterge rengi', s.steeringIndicatorColor, (c) {
          s.steeringIndicatorColor = c;
          prov.updateSettings(s);
        }),
        row('Gösterge arka planı', s.steeringBgColor, (c) {
          s.steeringBgColor = c;
          prov.updateSettings(s);
        }),
        const Divider(color: Colors.white12, height: 24),
        _header('Pedallar'),
        row('Gaz rengi', s.gasColor, (c) {
          s.gasColor = c;
          prov.updateSettings(s);
        }),
        row('Fren rengi', s.brakeColor, (c) {
          s.brakeColor = c;
          prov.updateSettings(s);
        }),
        row('Geri bildirim (>%70)', s.yetsoreColor, (c) {
          s.yetsoreColor = c;
          prov.updateSettings(s);
        }),
        row('Pedal arka planı', s.pedalBgColor, (c) {
          s.pedalBgColor = c;
          prov.updateSettings(s);
        }),
        const SizedBox(height: 40),
      ],
    );
  }

  Widget _header(String t) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
    child: Text(
      t.toUpperCase(),
      style: const TextStyle(
        color: Colors.white38,
        fontSize: 11,
        letterSpacing: 1.4,
        fontWeight: FontWeight.w600,
      ),
    ),
  );

  Widget _tile({
    required String title,
    String? subtitle,
    Widget? trailing,
    VoidCallback? onTap,
  }) {
    return ListTile(
      title: Text(
        title,
        style: const TextStyle(color: Colors.white, fontSize: 15),
      ),
      subtitle: subtitle != null
          ? Text(
              subtitle,
              style: const TextStyle(color: Colors.white38, fontSize: 12),
            )
          : null,
      trailing: trailing,
      onTap: onTap,
    );
  }

  Widget _buildColorRow(
    BuildContext ctx,
    SettingsProvider prov,
    AppSettings s,
    String label,
    Color current,
    void Function(Color) onChanged,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () async {
          final c = await _showRgbPicker(ctx, current, label);
          if (c != null) onChanged(c);
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white12),
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: current,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.white30, width: 1.5),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                    ),
                    Text(
                      'R:${(current.r * 255).round()}  G:${(current.g * 255).round()}  B:${(current.b * 255).round()}',
                      style: const TextStyle(
                        color: Colors.white38,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: Colors.white38),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showModeKeyAssignmentsDialog(
    BuildContext context,
    SettingsProvider prov,
    AppSettings s,
    int mode,
  ) async {
    final ac = s.detailColor;

    Widget buildKeyTile(
      String label,
      int currentVal,
      void Function(int) onChanged,
    ) {
      return ListTile(
        title: Text(
          label,
          style: const TextStyle(color: Colors.white, fontSize: 14),
        ),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: ac.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: ac.withValues(alpha: 0.4)),
          ),
          child: Text(
            _keyName(currentVal),
            style: TextStyle(
              color: ac,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        onTap: () async {
          final val = await _keyDialog(context, label, currentVal);
          if (val != null) {
            onChanged(val);
          }
        },
      );
    }

    await showDialog(
      context: context,
      builder: (dctx) {
        return StatefulBuilder(
          builder: (dctx, setStateDialog) {
            List<Widget> tiles = [];
            if (mode == -1) {
              // Sağ Pedal bilgi dialogı
              tiles = [
                const ListTile(
                  title: Text(
                    'Sağ Pedal = Gaz',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  subtitle: Text(
                    'Sağ pedalın kaydırma yönleri "Atama" sekmesinde yapılandırılır.\n'
                    'Varsayılan: ↑ Yukarı kaydırma = Bar Doldur ↑',
                    style: TextStyle(color: Colors.white54, fontSize: 13),
                  ),
                ),
              ];
            } else if (mode == -2) {
              // Sol Pedal bilgi dialogı
              tiles = [
                const ListTile(
                  title: Text(
                    'Sol Pedal = Fren',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  subtitle: Text(
                    'Sol pedalın kaydırma yönleri "Atama" sekmesinde yapılandırılır.\n'
                    'Varsayılan: ↑ Yukarı kaydırma = Bar Doldur ↑',
                    style: TextStyle(color: Colors.white54, fontSize: 13),
                  ),
                ),
              ];
            } else if (mode == 0) {
              tiles = [
                buildKeyTile('Ekran Sol Yarı Tıklama', s.m0TapLeft, (v) {
                  setStateDialog(() => s.m0TapLeft = v);
                }),
                buildKeyTile('Ekran Sağ Yarı Tıklama', s.m0TapRight, (v) {
                  setStateDialog(() => s.m0TapRight = v);
                }),
              ];
            } else if (mode == 1) {
              tiles = [
                buildKeyTile('Sol Pedal Tıklama', s.m1TapLeft, (v) {
                  setStateDialog(() => s.m1TapLeft = v);
                }),
                buildKeyTile('Sağ Pedal Tıklama', s.m1TapRight, (v) {
                  setStateDialog(() => s.m1TapRight = v);
                }),
              ];
            } else if (mode == 2) {
              tiles = [
                buildKeyTile('Üst-Sol Tuş', s.m2Key1, (v) {
                  setStateDialog(() => s.m2Key1 = v);
                }),
                buildKeyTile('Üst-Sağ Tuş', s.m2Key2, (v) {
                  setStateDialog(() => s.m2Key2 = v);
                }),
                buildKeyTile('Alt-Sol Tuş', s.m2Key3, (v) {
                  setStateDialog(() => s.m2Key3 = v);
                }),
                buildKeyTile('Alt-Sağ Tuş', s.m2Key4, (v) {
                  setStateDialog(() => s.m2Key4 = v);
                }),
                buildKeyTile('Fren Pedal Tıklama', s.m2TapLeft, (v) {
                  setStateDialog(() => s.m2TapLeft = v);
                }),
                buildKeyTile('Gaz Pedal Tıklama', s.m2TapRight, (v) {
                  setStateDialog(() => s.m2TapRight = v);
                }),
              ];
            } else if (mode == 3) {
              tiles = [
                buildKeyTile('Üst-Sol Tuş', s.m3Key1, (v) {
                  setStateDialog(() => s.m3Key1 = v);
                }),
                buildKeyTile('Üst-Sağ Tuş', s.m3Key2, (v) {
                  setStateDialog(() => s.m3Key2 = v);
                }),
                buildKeyTile('Alt-Sol Tuş', s.m3Key3, (v) {
                  setStateDialog(() => s.m3Key3 = v);
                }),
                buildKeyTile('Alt-Sağ Tuş', s.m3Key4, (v) {
                  setStateDialog(() => s.m3Key4 = v);
                }),
                buildKeyTile('Orta Alt Tuş', s.m3Key5, (v) {
                  setStateDialog(() => s.m3Key5 = v);
                }),
                buildKeyTile('Fren Pedal Tıklama', s.m3TapLeft, (v) {
                  setStateDialog(() => s.m3TapLeft = v);
                }),
                buildKeyTile('Gaz Pedal Tıklama', s.m3TapRight, (v) {
                  setStateDialog(() => s.m3TapRight = v);
                }),
              ];
            } else if (mode == 4) {
              tiles = [
                buildKeyTile('Üst-Sol Tuş', s.m4Key1, (v) {
                  setStateDialog(() => s.m4Key1 = v);
                }),
                buildKeyTile('Üst-Sağ Tuş', s.m4Key2, (v) {
                  setStateDialog(() => s.m4Key2 = v);
                }),
                buildKeyTile('Alt-Sol Tuş', s.m4Key3, (v) {
                  setStateDialog(() => s.m4Key3 = v);
                }),
                buildKeyTile('Alt-Sağ Tuş', s.m4Key4, (v) {
                  setStateDialog(() => s.m4Key4 = v);
                }),
                buildKeyTile('Alt Tam Genişlik Tuş', s.m4KeyBottom, (v) {
                  setStateDialog(() => s.m4KeyBottom = v);
                }),
                buildKeyTile('Fren Pedal Tıklama', s.m4TapLeft, (v) {
                  setStateDialog(() => s.m4TapLeft = v);
                }),
                buildKeyTile('Gaz Pedal Tıklama', s.m4TapRight, (v) {
                  setStateDialog(() => s.m4TapRight = v);
                }),
              ];
            }

            return AlertDialog(
              backgroundColor: const Color(0xFF12122A),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
              title: Text(
                mode == -1
                    ? 'Sağ Pedal (Gaz)'
                    : mode == -2
                    ? 'Sol Pedal (Fren)'
                    : 'Mod $mode Tuş Atamaları',
                style: const TextStyle(color: Colors.white, fontSize: 16),
              ),
              content: SizedBox(
                width: double.maxFinite,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: tiles,
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    setStateDialog(() {
                      if (mode == 0) {
                        s.m0TapLeft = 4;
                        s.m0TapRight = 3;
                      } else if (mode == 1) {
                        s.m1TapLeft = 4;
                        s.m1TapRight = 3;
                      } else if (mode == 2) {
                        s.m2Key1 = 5;
                        s.m2Key2 = 6;
                        s.m2Key3 = 7;
                        s.m2Key4 = 8;
                        s.m2TapLeft = 4;
                        s.m2TapRight = 3;
                      } else if (mode == 3) {
                        s.m3Key1 = 5;
                        s.m3Key2 = 6;
                        s.m3Key3 = 7;
                        s.m3Key4 = 8;
                        s.m3Key5 = 9;
                        s.m3TapLeft = 4;
                        s.m3TapRight = 3;
                      } else if (mode == 4) {
                        s.m4Key1 = 5;
                        s.m4Key2 = 6;
                        s.m4Key3 = 7;
                        s.m4Key4 = 8;
                        s.m4KeyBottom = 9;
                        s.m4TapLeft = 4;
                        s.m4TapRight = 3;
                      }
                    });
                  },
                  child: const Text(
                    'Varsayılan',
                    style: TextStyle(color: Colors.orange),
                  ),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(dctx),
                  child: const Text(
                    'Kapat',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
    prov.updateSettings(s);
    setState(() {});
  }
}
