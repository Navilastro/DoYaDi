import 'package:flutter/material.dart';
import '../providers/settings_provider.dart';
import '../models/app_settings.dart';
import '../core/widgets/searchable_key_picker.dart';
import '../core/utils/keyboard_keys.dart';

// ── Direksiyon: 1'den 1080'e tüm değerler ───────────────────────────────────
final steeringAngles = {
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

// ── Pedal ivme mesafesi ──────────────────────────────────────────────────────
final pedalDistances = <String, int>{
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

// ── Kaydırma hassasiyeti ─────────────────────────────────────────────────────
final swipeSensitivities = <String, double>{
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
final clickDurations = <String, double>{
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
const zeroOrientationOptions = <String, int>{
  'Auto': 0,
  'Screen faces on top': 1,
  'Screen faces on your body': 2,
};

// ── Swipe atama seçenekleri ──────────────────────────────────────────────────
const swipeDirLabels = <String, int>{
  'Gaz': -1,
  'Fren': -2,
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


// ────────────────────────────────────────────────────────────────────────────
// Ortak dialog/helper mixin — SettingsScreen tarafından kullanılır.
// ────────────────────────────────────────────────────────────────────────────
mixin SettingsDialogMixin<T extends StatefulWidget> on State<T> {
  String keyName(int v) {
    if (v >= 2000) return 'Makro ${v - 1999}';
    return KeyboardKeys.appKeyMap.entries
        .firstWhere((e) => e.value == v, orElse: () => const MapEntry('?', 0))
        .key;
  }

  String swipeName(int v) {
    if (v == -1) return 'Gaz';
    if (v == -2) return 'Fren';
    return KeyboardKeys.appKeyMap.entries
        .firstWhere(
            (e) => e.value == v, orElse: () => const MapEntry('Yok', 0))
        .key;
  }

  Future<R?> radioDialog<R>({
    required BuildContext ctx,
    required String title,
    required R current,
    required Map<String, R> options,
  }) {
    return showDialog<R>(
      context: ctx,
      builder: (dctx) {
        R selected = current;
        return StatefulBuilder(
          builder: (dctx, ss) {
            return AlertDialog(
              backgroundColor: const Color(0xFF12122A),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18)),
              title: Text(title,
                  style: const TextStyle(color: Colors.white, fontSize: 15)),
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
                            horizontal: 8, vertical: 2),
                        child: Row(
                          children: [
                            Radio<R>(
                              value: e.value,
                              groupValue: selected,
                              activeColor: const Color(0xFF40E0D0),
                              onChanged: (v) => ss(() => selected = v as R),
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
                  child: const Text('İptal',
                      style: TextStyle(color: Colors.white54)),
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

  Future<int?> swipeDialog(BuildContext ctx, String title, int current) =>
      radioDialog<int>(
          ctx: ctx, title: title, current: current, options: swipeDirLabels);

  Future<int?> keyDialog(BuildContext ctx, String title, int current) =>
      showSearchableKeyPicker(ctx, current, hideKeyboard: true);

  Future<Color?> showRgbPicker(
      BuildContext ctx, Color initial, String title) async {
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
                borderRadius: BorderRadius.circular(18)),
            title: Text(title,
                style: const TextStyle(color: Colors.white, fontSize: 15)),
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
                child: const Text('İptal',
                    style: TextStyle(color: Colors.white54)),
              ),
              ElevatedButton(
                style:
                    ElevatedButton.styleFrom(backgroundColor: preview),
                onPressed: () =>
                    Navigator.pop(dctx, Color.fromARGB(255, r, g, b)),
                child: const Text('Uygula',
                    style: TextStyle(color: Colors.white)),
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
          child: Text(ch,
              style: TextStyle(
                  color: tc, fontWeight: FontWeight.bold, fontSize: 13)),
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
          child: Text(val.toString(),
              style: const TextStyle(color: Colors.white70, fontSize: 12),
              textAlign: TextAlign.end),
        ),
      ],
    );
  }

  // ── Shared UI helpers ────────────────────────────────────────────────────

  Widget settingsHeader(String t) => Padding(
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

  Widget settingsTile({
    required String title,
    String? subtitle,
    Widget? trailing,
    VoidCallback? onTap,
  }) {
    return ListTile(
      title: Text(title,
          style: const TextStyle(color: Colors.white, fontSize: 15)),
      subtitle: subtitle != null
          ? Text(subtitle,
              style: const TextStyle(color: Colors.white38, fontSize: 12))
          : null,
      trailing: trailing,
      onTap: onTap,
    );
  }

  Widget swipeTile(
    Color ac,
    String dir,
    String assigned,
    VoidCallback? onTap,
  ) {
    final isFixed = onTap == null;
    return ListTile(
      dense: true,
      leading: Text(dir.substring(0, 2),
          style: const TextStyle(fontSize: 20, color: Colors.white70)),
      title: Text(dir.substring(2).trim(),
          style: const TextStyle(color: Colors.white, fontSize: 14)),
      trailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: isFixed
              ? Colors.white.withValues(alpha: 0.05)
              : ac.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color:
                isFixed ? Colors.white12 : ac.withValues(alpha: 0.4),
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

  Widget buildColorRow(
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
          final c = await showRgbPicker(ctx, current, label);
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
                    Text(label,
                        style: const TextStyle(
                            color: Colors.white, fontSize: 14)),
                    Text(
                      'R:${(current.r * 255).round()}  G:${(current.g * 255).round()}  B:${(current.b * 255).round()}',
                      style: const TextStyle(
                          color: Colors.white38, fontSize: 12),
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

  // ── Mode key assignments dialog ──────────────────────────────────────────

  Future<void> showModeKeyAssignmentsDialog(
    BuildContext ctx,
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
        title: Text(label,
            style: const TextStyle(color: Colors.white, fontSize: 14)),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: ac.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: ac.withValues(alpha: 0.4)),
          ),
          child: Text(
            keyName(currentVal),
            style: TextStyle(
                color: ac, fontSize: 12, fontWeight: FontWeight.bold),
          ),
        ),
        onTap: () async {
          final val = await keyDialog(ctx, label, currentVal);
          if (val != null) onChanged(val);
        },
      );
    }

    await showDialog(
      context: ctx,
      builder: (dctx) {
        return StatefulBuilder(
          builder: (dctx, setStateDialog) {
            List<Widget> tiles = [];
            if (mode == -1) {
              tiles = [
                const ListTile(
                  title: Text('Sağ Pedal = Gaz',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.bold)),
                  subtitle: Text(
                    'Sağ pedalın kaydırma yönleri "Atama" sekmesinde yapılandırılır.\n'
                    'Varsayılan: ↑ Yukarı kaydırma = Bar Doldur ↑',
                  ),
                ),
                buildKeyTile('Sağ Pedala Tıklanınca', s.gasTap, (v) => setStateDialog(() => s.gasTap = v)),
              ];
            } else if (mode == -2) {
              tiles = [
                const ListTile(
                  title: Text('Sol Pedal = Fren',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.bold)),
                  subtitle: Text(
                    'Sol pedalın kaydırma yönleri "Atama" sekmesinde yapılandırılır.\n'
                    'Varsayılan: ↑ Yukarı kaydırma = Bar Doldur ↑',
                  ),
                ),
                buildKeyTile('Sol Pedala Tıklanınca', s.brakeTap, (v) => setStateDialog(() => s.brakeTap = v)),
              ];
            } else if (mode == 0) {
              tiles = [
                buildKeyTile('Ekran Sol Yarı Tıklama', s.m0TapLeft,
                    (v) => setStateDialog(() => s.m0TapLeft = v)),
                buildKeyTile('Ekran Sağ Yarı Tıklama', s.m0TapRight,
                    (v) => setStateDialog(() => s.m0TapRight = v)),
              ];
            } else if (mode == 1) {
              tiles = [
                buildKeyTile('Sol Pedal Tıklama', s.m1TapLeft,
                    (v) => setStateDialog(() => s.m1TapLeft = v)),
                buildKeyTile('Sağ Pedal Tıklama', s.m1TapRight,
                    (v) => setStateDialog(() => s.m1TapRight = v)),
              ];
            } else if (mode == 2) {
              tiles = [
                buildKeyTile('Üst-Sol Tuş', s.m2Key1,
                    (v) => setStateDialog(() => s.m2Key1 = v)),
                buildKeyTile('Üst-Sağ Tuş', s.m2Key2,
                    (v) => setStateDialog(() => s.m2Key2 = v)),
                buildKeyTile('Alt-Sol Tuş', s.m2Key3,
                    (v) => setStateDialog(() => s.m2Key3 = v)),
                buildKeyTile('Alt-Sağ Tuş', s.m2Key4,
                    (v) => setStateDialog(() => s.m2Key4 = v)),
                buildKeyTile('Fren Pedal Tıklama', s.m2TapLeft,
                    (v) => setStateDialog(() => s.m2TapLeft = v)),
                buildKeyTile('Gaz Pedal Tıklama', s.m2TapRight,
                    (v) => setStateDialog(() => s.m2TapRight = v)),
              ];
            } else if (mode == 3) {
              tiles = [
                buildKeyTile('Üst-Sol Tuş', s.m3Key1,
                    (v) => setStateDialog(() => s.m3Key1 = v)),
                buildKeyTile('Üst-Sağ Tuş', s.m3Key2,
                    (v) => setStateDialog(() => s.m3Key2 = v)),
                buildKeyTile('Alt-Sol Tuş', s.m3Key3,
                    (v) => setStateDialog(() => s.m3Key3 = v)),
                buildKeyTile('Alt-Sağ Tuş', s.m3Key4,
                    (v) => setStateDialog(() => s.m3Key4 = v)),
                buildKeyTile('Orta Alt Tuş', s.m3Key5,
                    (v) => setStateDialog(() => s.m3Key5 = v)),
                buildKeyTile('Fren Pedal Tıklama', s.m3TapLeft,
                    (v) => setStateDialog(() => s.m3TapLeft = v)),
                buildKeyTile('Gaz Pedal Tıklama', s.m3TapRight,
                    (v) => setStateDialog(() => s.m3TapRight = v)),
              ];
            } else if (mode == 4) {
              tiles = [
                buildKeyTile('Üst-Sol Tuş', s.m4Key1,
                    (v) => setStateDialog(() => s.m4Key1 = v)),
                buildKeyTile('Üst-Sağ Tuş', s.m4Key2,
                    (v) => setStateDialog(() => s.m4Key2 = v)),
                buildKeyTile('Alt-Sol Tuş', s.m4Key3,
                    (v) => setStateDialog(() => s.m4Key3 = v)),
                buildKeyTile('Alt-Sağ Tuş', s.m4Key4,
                    (v) => setStateDialog(() => s.m4Key4 = v)),
                buildKeyTile('Alt Tam Genişlik Tuş', s.m4KeyBottom,
                    (v) => setStateDialog(() => s.m4KeyBottom = v)),
                buildKeyTile('Fren Pedal Tıklama', s.m4TapLeft,
                    (v) => setStateDialog(() => s.m4TapLeft = v)),
                buildKeyTile('Gaz Pedal Tıklama', s.m4TapRight,
                    (v) => setStateDialog(() => s.m4TapRight = v)),
              ];
            }

            return AlertDialog(
              backgroundColor: const Color(0xFF12122A),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18)),
              title: Text(
                mode == -1
                    ? 'Sağ Pedal (Gaz)'
                    : mode == -2
                        ? 'Sol Pedal (Fren)'
                        : 'Mod $mode Tuş Atamaları',
                style:
                    const TextStyle(color: Colors.white, fontSize: 16),
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
                      if (mode == -1) {
                        s.gasTap = 3;
                      } else if (mode == -2) {
                        s.brakeTap = 4;
                      } else if (mode == 0) {
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
                        s.m3Key3 = 13;
                        s.m3Key4 = 8;
                        s.m3Key5 = 7;
                        s.m3TapLeft = 4;
                        s.m3TapRight = 3;
                      } else if (mode == 4) {
                        s.m4Key1 = 5;
                        s.m4Key2 = 6;
                        s.m4Key3 = 13;
                        s.m4Key4 = 8;
                        s.m4KeyBottom = 7;
                        s.m4TapLeft = 4;
                        s.m4TapRight = 3;
                      }
                    });
                  },
                  child: const Text('Varsayılan',
                      style: TextStyle(color: Colors.orange)),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(dctx),
                  child: const Text('Kapat',
                      style: TextStyle(color: Colors.white)),
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

  Future<void> showCustomPressModesDialog(
    BuildContext ctx,
    SettingsProvider prov,
    AppSettings s,
  ) async {
    await showDialog(
      context: ctx,
      builder: (dctx) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              backgroundColor: const Color(0xFF12122A),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18)),
              title: const Text('Tuşa Özel Basış Modu',
                  style: TextStyle(color: Colors.white, fontSize: 16)),
              content: SizedBox(
                width: double.maxFinite,
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: 16,
                  itemBuilder: (ctx, i) {
                    final keyIndex = i + 1;
                    final currentMode = s.customButtonPressModes[keyIndex] ??
                        s.globalButtonPressMode;
                    String modeName = currentMode == 0
                        ? 'Anlık'
                        : currentMode == 1
                            ? 'Süreli'
                            : currentMode == 2
                                ? 'Toggle'
                                : 'Hızlı';
                    if (!s.customButtonPressModes.containsKey(keyIndex)) {
                      modeName += ' (Global)';
                    } else if (currentMode == 1) {
                      final dur = s.customButtonPressDurationsMs[keyIndex] ?? s.globalButtonPressDurationMs;
                      modeName += ' (${dur / 1000} sn)';
                    }

                    return ListTile(
                      title: Text('Tuş $keyIndex',
                          style: const TextStyle(color: Colors.white)),
                      subtitle: Text(modeName,
                          style:
                              const TextStyle(color: Colors.white54)),
                      trailing: const Icon(Icons.edit, color: Colors.white38),
                      onTap: () async {
                        final val = await radioDialog<int?>(
                          ctx: context,
                          title: 'Tuş $keyIndex Modu',
                          current: s.customButtonPressModes[keyIndex],
                          options: const {
                            'Global Ayarı Kullan': -1,
                            'Anlık (0)': 0,
                            'Süreli (1)': 1,
                            'Toggle (2)': 2,
                            'Hızlı (3)': 3,
                          },
                        );
                        if (val != null) {
                          if (val == -1) {
                            setStateDialog(() {
                              s.customButtonPressModes.remove(keyIndex);
                              s.customButtonPressDurationsMs.remove(keyIndex);
                            });
                          } else {
                            setStateDialog(() => s.customButtonPressModes[keyIndex] = val);
                            if (val == 1) {
                              final duration = await radioDialog<int>(
                                ctx: context,
                                title: 'Süre (Tuş $keyIndex)',
                                current: s.customButtonPressDurationsMs[keyIndex] ?? s.globalButtonPressDurationMs,
                                options: {
                                  for (var i = 1; i <= 20; i++)
                                    '${(i * 0.5).toStringAsFixed(1)} sn': i * 500,
                                },
                              );
                              if (duration != null) {
                                setStateDialog(() => s.customButtonPressDurationsMs[keyIndex] = duration);
                              } else {
                                if (!s.customButtonPressDurationsMs.containsKey(keyIndex)) {
                                  setStateDialog(() => s.customButtonPressDurationsMs[keyIndex] = s.globalButtonPressDurationMs);
                                }
                              }
                            }
                          }
                        }
                      },
                    );
                  },
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dctx),
                  child: const Text('Kapat',
                      style: TextStyle(color: Colors.white)),
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
