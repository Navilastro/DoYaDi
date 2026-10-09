import 'package:flutter/material.dart';
import '../providers/settings_provider.dart';
import '../models/app_settings.dart';
import '../core/widgets/searchable_key_picker.dart';
import '../core/utils/keyboard_keys.dart';
import '../core/utils/app_translations.dart';

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
    if (v == -1) {
      return AppTranslations.getText('paired').isEmpty
          ? 'Gaz'
          : AppTranslations.currentLanguage == 'en'
          ? 'Gas'
          : 'Gaz';
    }
    if (v == -2) {
      return AppTranslations.currentLanguage == 'en' ? 'Brake' : 'Fren';
    }
    return KeyboardKeys.appKeyMap.entries
        .firstWhere((e) => e.value == v, orElse: () => const MapEntry('Yok', 0))
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
                borderRadius: BorderRadius.circular(18),
              ),
              title: Text(
                title,
                style: const TextStyle(color: Colors.white, fontSize: 15),
              ),
              content: SizedBox(
                width: double.maxFinite,
                child: RadioGroup<R>(
                  groupValue: selected,
                  onChanged: (v) => ss(() => selected = v as R),
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
                              Radio<R>(
                                value: e.value,
                                activeColor: const Color(0xFF40E0D0),
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
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dctx),
                  child: Text(
                    AppTranslations.getText('cancel'),
                    style: const TextStyle(color: Colors.white54),
                  ),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF40E0D0),
                    foregroundColor: Colors.black,
                  ),
                  onPressed: () => Navigator.pop(dctx, selected),
                  child: Text(AppTranslations.getText('apply')),
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
        ctx: ctx,
        title: title,
        current: current,
        options: swipeDirLabels,
      );

  Future<int?> keyDialog(BuildContext ctx, String title, int current) =>
      showSearchableKeyPicker(ctx, current, hideKeyboard: true);

  Future<Color?> showRgbPicker(
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
                child: Text(
                  AppTranslations.getText('cancel'),
                  style: const TextStyle(color: Colors.white54),
                ),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: preview),
                onPressed: () =>
                    Navigator.pop(dctx, Color.fromARGB(255, r, g, b)),
                child: Text(
                  AppTranslations.getText('apply'),
                  style: const TextStyle(color: Colors.white),
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

  Widget swipeTile(Color ac, String dir, String assigned, VoidCallback? onTap) {
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
            keyName(currentVal),
            style: TextStyle(
              color: ac,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
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
                buildKeyTile(
                  AppTranslations.currentLanguage == 'en'
                      ? 'Right Pedal Tap'
                      : 'Sağ Pedala Tıklanınca',
                  s.gasTap,
                  (v) => setStateDialog(() => s.gasTap = v),
                ),
              ];
            } else if (mode == -2) {
              tiles = [
                buildKeyTile(
                  AppTranslations.currentLanguage == 'en'
                      ? 'Left Pedal Tap'
                      : 'Sol Pedala Tıklanınca',
                  s.brakeTap,
                  (v) => setStateDialog(() => s.brakeTap = v),
                ),
              ];
            } else if (mode == 0) {
              tiles = [
                buildKeyTile(
                  AppTranslations.currentLanguage == 'en' ? 'Left' : 'Sol',
                  s.m0TapLeft,
                  (v) => setStateDialog(() => s.m0TapLeft = v),
                ),
                buildKeyTile(
                  AppTranslations.currentLanguage == 'en' ? 'Right' : 'Sağ',
                  s.m0TapRight,
                  (v) => setStateDialog(() => s.m0TapRight = v),
                ),
              ];
            } else if (mode == 1) {
              tiles = [
                buildKeyTile(
                  AppTranslations.currentLanguage == 'en' ? 'Left' : 'Sol',
                  s.m1TapLeft,
                  (v) => setStateDialog(() => s.m1TapLeft = v),
                ),
                buildKeyTile(
                  AppTranslations.currentLanguage == 'en' ? 'Right' : 'Sağ',
                  s.m1TapRight,
                  (v) => setStateDialog(() => s.m1TapRight = v),
                ),
              ];
            } else if (mode == 2) {
              tiles = [
                buildKeyTile(
                  AppTranslations.getText('up_left_key'),
                  s.m2Key1,
                  (v) => setStateDialog(() => s.m2Key1 = v),
                ),
                buildKeyTile(
                  AppTranslations.getText('up_right_key'),
                  s.m2Key2,
                  (v) => setStateDialog(() => s.m2Key2 = v),
                ),
                buildKeyTile(
                  AppTranslations.getText('down_left_key'),
                  s.m2Key3,
                  (v) => setStateDialog(() => s.m2Key3 = v),
                ),
                buildKeyTile(
                  AppTranslations.getText('down_right_key'),
                  s.m2Key4,
                  (v) => setStateDialog(() => s.m2Key4 = v),
                ),
                buildKeyTile(
                  AppTranslations.getText('left_pedal'),
                  s.m2TapLeft,
                  (v) => setStateDialog(() => s.m2TapLeft = v),
                ),
                buildKeyTile(
                  AppTranslations.getText('right_pedal'),
                  s.m2TapRight,
                  (v) => setStateDialog(() => s.m2TapRight = v),
                ),
              ];
            } else if (mode == 3) {
              tiles = [
                buildKeyTile(
                  AppTranslations.getText('up_left_key'),
                  s.m3Key1,
                  (v) => setStateDialog(() => s.m3Key1 = v),
                ),
                buildKeyTile(
                  AppTranslations.getText('up_right_key'),
                  s.m3Key2,
                  (v) => setStateDialog(() => s.m3Key2 = v),
                ),
                buildKeyTile(
                  AppTranslations.getText('down_left_key'),
                  s.m3Key3,
                  (v) => setStateDialog(() => s.m3Key3 = v),
                ),
                buildKeyTile(
                  AppTranslations.getText('down_right_key'),
                  s.m3Key4,
                  (v) => setStateDialog(() => s.m3Key4 = v),
                ),
                buildKeyTile(
                  AppTranslations.getText('down_full_wide_key'),
                  s.m3Key5,
                  (v) => setStateDialog(() => s.m3Key5 = v),
                ),
                buildKeyTile(
                  AppTranslations.getText('left_pedal'),
                  s.m3TapLeft,
                  (v) => setStateDialog(() => s.m3TapLeft = v),
                ),
                buildKeyTile(
                  AppTranslations.getText('right_pedal'),
                  s.m3TapRight,
                  (v) => setStateDialog(() => s.m3TapRight = v),
                ),
              ];
            } else if (mode == 4) {
              tiles = [
                buildKeyTile(
                  AppTranslations.getText('up_left_key'),
                  s.m4Key1,
                  (v) => setStateDialog(() => s.m4Key1 = v),
                ),
                buildKeyTile(
                  AppTranslations.getText('up_right_key'),
                  s.m4Key2,
                  (v) => setStateDialog(() => s.m4Key2 = v),
                ),
                buildKeyTile(
                  AppTranslations.getText('down_left_key'),
                  s.m4Key3,
                  (v) => setStateDialog(() => s.m4Key3 = v),
                ),
                buildKeyTile(
                  AppTranslations.getText('down_right_key'),
                  s.m4Key4,
                  (v) => setStateDialog(() => s.m4Key4 = v),
                ),
                buildKeyTile(
                  AppTranslations.getText('down_full_wide_key'),
                  s.m4KeyBottom,
                  (v) => setStateDialog(() => s.m4KeyBottom = v),
                ),
                buildKeyTile(
                  AppTranslations.getText('left_pedal'),
                  s.m4TapLeft,
                  (v) => setStateDialog(() => s.m4TapLeft = v),
                ),
                buildKeyTile(
                  AppTranslations.getText('right_pedal'),
                  s.m4TapRight,
                  (v) => setStateDialog(() => s.m4TapRight = v),
                ),
              ];
            } else if (mode == 7) {
              tiles = [
                buildKeyTile(
                  'Sol Buton',
                  s.m7Key1,
                  (v) => setStateDialog(() => s.m7Key1 = v),
                ),
                buildKeyTile(
                  'Üst Buton',
                  s.m7Key2,
                  (v) => setStateDialog(() => s.m7Key2 = v),
                ),
                buildKeyTile(
                  'Sağ Buton',
                  s.m7Key3,
                  (v) => setStateDialog(() => s.m7Key3 = v),
                ),
                buildKeyTile(
                  'Alt Buton',
                  s.m7Key4,
                  (v) => setStateDialog(() => s.m7Key4 = v),
                ),
              ];
            }

            return AlertDialog(
              backgroundColor: const Color(0xFF12122A),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
              title: Text(
                mode == -1
                    ? AppTranslations.getText('right_pedal')
                    : mode == -2
                    ? AppTranslations.getText('left_pedal')
                    : 'Mod $mode ${AppTranslations.currentLanguage == 'en' ? 'Key Assignments' : 'Tuş Atamaları'}',
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
                      if (mode == -1) {
                        s.gasTap = 18;
                      } else if (mode == -2) {
                        s.brakeTap = 17;
                      } else if (mode == 0) {
                        s.m0TapLeft = 17;
                        s.m0TapRight = 18;
                      } else if (mode == 1) {
                        s.m1TapLeft = 17;
                        s.m1TapRight = 18;
                      } else if (mode == 2) {
                        s.m2Key1 = 5;
                        s.m2Key2 = 6;
                        s.m2Key3 = 7;
                        s.m2Key4 = 8;
                        s.m2TapLeft = 17;
                        s.m2TapRight = 18;
                      } else if (mode == 3) {
                        s.m3Key1 = 5;
                        s.m3Key2 = 6;
                        s.m3Key3 = 14;
                        s.m3Key4 = 8;
                        s.m3Key5 = 7;
                        s.m3TapLeft = 17;
                        s.m3TapRight = 18;
                      } else if (mode == 4) {
                        s.m4Key1 = 5;
                        s.m4Key2 = 6;
                        s.m4Key3 = 14;
                        s.m4Key4 = 8;
                        s.m4KeyBottom = 7;
                        s.m4TapLeft = 17;
                        s.m4TapRight = 18;
                      } else if (mode == 7) {
                        s.m7Key1 = 7;
                        s.m7Key2 = 8;
                        s.m7Key3 = 6;
                        s.m7Key4 = 5;
                      }
                    });
                  },
                  child: Text(
                    AppTranslations.getText('default'),
                    style: const TextStyle(color: Colors.orange),
                  ),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(dctx),
                  child: Text(
                    AppTranslations.getText('close'),
                    style: const TextStyle(color: Colors.white),
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
                borderRadius: BorderRadius.circular(18),
              ),
              title: Text(
                AppTranslations.getText('custom_press_mode'),
                style: const TextStyle(color: Colors.white, fontSize: 16),
              ),
              content: SizedBox(
                width: double.maxFinite,
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: 16,
                  itemBuilder: (ctx, i) {
                    final keyIndex = i + 1;
                    final currentMode =
                        s.customButtonPressModes[keyIndex] ??
                        s.globalButtonPressMode;
                    String modeName = currentMode == 0
                        ? AppTranslations.getText('press_mode_instant')
                        : currentMode == 1
                        ? AppTranslations.getText('press_mode_duration')
                        : currentMode == 2
                        ? AppTranslations.getText('press_mode_toggle')
                        : AppTranslations.getText('press_mode_fast');
                    if (!s.customButtonPressModes.containsKey(keyIndex)) {
                      modeName +=
                          ' (${AppTranslations.currentLanguage == 'en' ? 'Global' : 'Genel'})';
                    } else if (currentMode == 1) {
                      final dur =
                          s.customButtonPressDurationsMs[keyIndex] ??
                          s.globalButtonPressDurationMs;
                      modeName += ' (${dur / 1000} sn)';
                    }

                    return ListTile(
                      title: Text(
                        '${AppTranslations.getText('key_prefix')} $keyIndex',
                        style: const TextStyle(color: Colors.white),
                      ),
                      subtitle: Text(
                        modeName,
                        style: const TextStyle(color: Colors.white54),
                      ),
                      trailing: const Icon(Icons.edit, color: Colors.white38),
                      onTap: () async {
                        final val = await radioDialog<int?>(
                          ctx: context,
                          title:
                              '${AppTranslations.getText('key_prefix')} $keyIndex ${AppTranslations.currentLanguage == 'en' ? 'Mode' : 'Modu'}',
                          current: s.customButtonPressModes[keyIndex],
                          options: {
                            AppTranslations.getText('press_mode_global'): -1,
                            '${AppTranslations.getText('press_mode_instant')} (0)':
                                0,
                            '${AppTranslations.getText('press_mode_duration')} (1)':
                                1,
                            '${AppTranslations.getText('press_mode_toggle')} (2)':
                                2,
                            '${AppTranslations.getText('press_mode_fast')} (3)':
                                3,
                          },
                        );
                        if (val != null) {
                          if (val == -1) {
                            setStateDialog(() {
                              s.customButtonPressModes.remove(keyIndex);
                              s.customButtonPressDurationsMs.remove(keyIndex);
                            });
                          } else {
                            setStateDialog(
                              () => s.customButtonPressModes[keyIndex] = val,
                            );
                            if (val == 1) {
                              final duration = await radioDialog<int>(
                                ctx: context,
                                title:
                                    '${AppTranslations.getText('timed_press_duration')} (${AppTranslations.getText('key_prefix')} $keyIndex)',
                                current:
                                    s.customButtonPressDurationsMs[keyIndex] ??
                                    s.globalButtonPressDurationMs,
                                options: {
                                  for (var i = 1; i <= 20; i++)
                                    '${(i * 0.5).toStringAsFixed(1)} sn':
                                        i * 500,
                                },
                              );
                              if (duration != null) {
                                setStateDialog(
                                  () =>
                                      s.customButtonPressDurationsMs[keyIndex] =
                                          duration,
                                );
                              } else {
                                if (!s.customButtonPressDurationsMs.containsKey(
                                  keyIndex,
                                )) {
                                  setStateDialog(
                                    () =>
                                        s.customButtonPressDurationsMs[keyIndex] =
                                            s.globalButtonPressDurationMs,
                                  );
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
                  child: Text(
                    AppTranslations.getText('close'),
                    style: const TextStyle(color: Colors.white),
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

  Future<void> showCustomButtonHapticDialog(
    BuildContext ctx,
    SettingsProvider prov,
    AppSettings s,
    void Function(void Function()) setState,
  ) async {
    final ac = s.detailColor;
    final Map<int, String> configurableButtons = {
      5: 'A ${AppTranslations.getText('button_title')}',
      6: 'B ${AppTranslations.getText('button_title')}',
      7: 'X ${AppTranslations.getText('button_title')}',
      8: 'Y ${AppTranslations.getText('button_title')}',
      1: 'LB ${AppTranslations.getText('button_title')}',
      2: 'RB ${AppTranslations.getText('button_title')}',
      9: 'DPAD Up',
      10: 'DPAD Down',
      11: 'DPAD Left',
      12: 'DPAD Right',
      13: 'Start',
      14: 'Back',
      17: 'L3',
      18: 'R3',
      -1: AppTranslations.getText('right_pedal_button'),
      -2: AppTranslations.getText('left_pedal_button'),
    };

    await showDialog(
      context: ctx,
      builder: (dctx) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              backgroundColor: const Color(0xFF1A1A3E),
              title: Text(
                AppTranslations.getText('custom_button_haptic_title'),
                style: const TextStyle(color: Colors.white, fontSize: 16),
              ),
              content: SizedBox(
                width: double.maxFinite,
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: configurableButtons.length,
                  itemBuilder: (context, index) {
                    final keyIndex = configurableButtons.keys.elementAt(index);
                    final name = configurableButtons[keyIndex]!;
                    final bool? isEnabledOverride = s.customButtonHapticEnabled[keyIndex];
                    final int? typeOverride = s.customButtonHapticTypes[keyIndex];
                    final int? triggerOverride = s.customButtonHapticTriggers[keyIndex];

                    String typeName = typeOverride == 0
                        ? AppTranslations.getText('haptic_type_light')
                        : typeOverride == 1
                        ? AppTranslations.getText('haptic_type_medium')
                        : typeOverride == 2
                        ? AppTranslations.getText('haptic_type_heavy')
                        : typeOverride == 3
                        ? AppTranslations.getText('haptic_type_selection')
                        : typeOverride == 4
                        ? AppTranslations.getText('haptic_type_vibrate')
                        : AppTranslations.getText('use_global_setting');

                    String triggerName = triggerOverride == 0
                        ? AppTranslations.getText('haptic_trigger_down')
                        : triggerOverride == 1
                        ? AppTranslations.getText('haptic_trigger_up')
                        : triggerOverride == 2
                        ? AppTranslations.getText('haptic_trigger_held')
                        : AppTranslations.getText('use_global_setting');

                    bool isCustom = typeOverride != null || triggerOverride != null || isEnabledOverride == true;
                    String statusText = isCustom
                        ? 'Özel: $typeName | $triggerName'
                        : AppTranslations.getText('use_global_setting');

                    return ListTile(
                      title: Text(
                        name,
                        style: const TextStyle(color: Colors.white, fontSize: 14),
                      ),
                      subtitle: Text(
                        statusText,
                        style: TextStyle(color: isCustom ? ac : Colors.white38, fontSize: 12),
                      ),
                      trailing: Icon(Icons.chevron_right, color: ac),
                      onTap: () async {
                        // 1. Titreşim Türü (0-4)
                        final typeVal = await radioDialog<int>(
                          ctx: context,
                          title: '$name - ${AppTranslations.getText('haptic_type')}',
                          current: typeOverride ?? -1,
                          options: {
                            AppTranslations.getText('use_global_setting'): -1,
                            AppTranslations.getText('haptic_type_light'): 0,
                            AppTranslations.getText('haptic_type_medium'): 1,
                            AppTranslations.getText('haptic_type_heavy'): 2,
                            AppTranslations.getText('haptic_type_selection'): 3,
                            AppTranslations.getText('haptic_type_vibrate'): 4,
                          },
                        );
                        if (typeVal == null) return;

                        // 2. Tetikleme Zamanı (0-2)
                        final triggerVal = await radioDialog<int>(
                          ctx: context,
                          title: '$name - ${AppTranslations.getText('haptic_trigger')}',
                          current: triggerOverride ?? -1,
                          options: {
                            AppTranslations.getText('use_global_setting'): -1,
                            AppTranslations.getText('haptic_trigger_down'): 0,
                            AppTranslations.getText('haptic_trigger_up'): 1,
                            AppTranslations.getText('haptic_trigger_held'): 2,
                          },
                        );
                        if (triggerVal == null) return;

                        setStateDialog(() {
                          if (typeVal == -1 && triggerVal == -1) {
                            s.customButtonHapticTypes.remove(keyIndex);
                            s.customButtonHapticTriggers.remove(keyIndex);
                            s.customButtonHapticEnabled.remove(keyIndex);
                          } else {
                            if (typeVal != -1) {
                              s.customButtonHapticTypes[keyIndex] = typeVal;
                            } else {
                              s.customButtonHapticTypes.remove(keyIndex);
                            }

                            if (triggerVal != -1) {
                              s.customButtonHapticTriggers[keyIndex] = triggerVal;
                            } else {
                              s.customButtonHapticTriggers.remove(keyIndex);
                            }

                            s.customButtonHapticEnabled[keyIndex] = true;
                          }
                        });
                      },
                    );
                  },
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dctx),
                  child: Text(
                    AppTranslations.getText('close'),
                    style: const TextStyle(color: Colors.white),
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

  // ── Tuşları Düzenle (Mod 6) Birleşik Diyaloğu ─────────────────────────────
  Future<void> showMod6KeyAssignmentsDialog(
    BuildContext ctx,
    SettingsProvider prov,
    AppSettings s,
    void Function(void Function()) setState,
  ) async {
    final ac = s.detailColor;
    int tempSteeringStyle = s.mod6SteeringStyle;
    bool tempEnableClutch = s.mod6EnableClutch;
    int tempClutchType = s.clutchType;
    double tempClutchRate = s.clutchIconAccelerationRate;
    bool tempEnableHandbrake = s.mod6EnableHandbrake;
    int tempHandbrakeType = s.handbrakeType;

    await showDialog(
      context: ctx,
      builder: (dctx) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              backgroundColor: const Color(0xFF1A1A3E),
              title: Text(
                AppTranslations.getText('mod6_key_assignments_title'),
                style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Direksiyon Stili ──
                    Text(AppTranslations.getText('steering_style'), style: const TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.bold)),
                    RadioGroup<int>(
                      groupValue: tempSteeringStyle,
                      onChanged: (v) => setStateDialog(() => tempSteeringStyle = v!),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          RadioListTile<int>(
                            title: Text(AppTranslations.getText('dynamic_fixed_steering'), style: const TextStyle(color: Colors.cyanAccent, fontSize: 13)),
                            subtitle: Text(AppTranslations.getText('dynamic_fixed_steering_desc'), style: const TextStyle(color: Colors.white38, fontSize: 11)),
                            value: 1,
                          ),
                          RadioListTile<int>(
                            title: Text(AppTranslations.getText('rotating_steering'), style: const TextStyle(color: Colors.white, fontSize: 13)),
                            subtitle: Text(AppTranslations.getText('rotating_steering_desc'), style: const TextStyle(color: Colors.white38, fontSize: 11)),
                            value: 0,
                          ),
                        ],
                      ),
                    ),
                    const Divider(color: Colors.white12),

                    // ── Debriyaj Ayarları ──
                    SwitchListTile(
                      title: Text(AppTranslations.getText('show_clutch'), style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
                      value: tempEnableClutch,
                      onChanged: (v) => setStateDialog(() => tempEnableClutch = v),
                      activeThumbColor: ac,
                    ),
                    if (tempEnableClutch) ...[
                      Padding(
                        padding: const EdgeInsets.only(left: 12, top: 4, bottom: 4),
                        child: Text(AppTranslations.getText('clutch_type_label'), style: const TextStyle(color: Colors.white70, fontSize: 12)),
                      ),
                      RadioGroup<int>(
                        groupValue: tempClutchType,
                        onChanged: (v) => setStateDialog(() => tempClutchType = v!),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            RadioListTile<int>(
                              title: Text(AppTranslations.getText('clutch_type_bar'), style: const TextStyle(color: Colors.cyanAccent, fontSize: 13)),
                              value: 1,
                            ),
                            RadioListTile<int>(
                              title: Text(AppTranslations.getText('clutch_type_icon'), style: const TextStyle(color: Colors.cyanAccent, fontSize: 13)),
                              subtitle: Text(AppTranslations.getText('clutch_type_icon_desc'), style: const TextStyle(color: Colors.white38, fontSize: 11)),
                              value: 2,
                            ),
                            if (tempClutchType == 2) ...[
                              Padding(
                                padding: const EdgeInsets.only(left: 24, right: 12, top: 4, bottom: 8),
                                child: InkWell(
                                  onTap: () async {
                                    final newRate = await showAccelerationRateInputDialog(
                                      ctx,
                                      title: AppTranslations.getText('ramp_up_time'),
                                      currentSeconds: tempClutchRate,
                                    );
                                    if (newRate != null) {
                                      setStateDialog(() => tempClutchRate = newRate);
                                    }
                                  },
                                  borderRadius: BorderRadius.circular(8),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                    decoration: BoxDecoration(
                                      color: Colors.black26,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: ac.withValues(alpha: 0.4)),
                                    ),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(AppTranslations.getText('ramp_up_time'), style: const TextStyle(color: Colors.white70, fontSize: 11)),
                                            const SizedBox(height: 2),
                                            Text(
                                              '${tempClutchRate.toStringAsFixed(2)} sn  (${(tempClutchRate * 1000).round()} ms)',
                                              style: TextStyle(color: ac, fontWeight: FontWeight.bold, fontSize: 13),
                                            ),
                                          ],
                                        ),
                                        Row(
                                          children: [
                                            Text(AppTranslations.getText('enter_value'), style: TextStyle(color: ac, fontSize: 12, fontWeight: FontWeight.bold)),
                                            const SizedBox(width: 4),
                                            Icon(Icons.edit_note, color: ac, size: 18),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                            RadioListTile<int>(
                              title: Text(AppTranslations.getText('clutch_type_button'), style: const TextStyle(color: Colors.cyanAccent, fontSize: 13)),
                              subtitle: Text(AppTranslations.getText('clutch_type_button_desc'), style: const TextStyle(color: Colors.white38, fontSize: 11)),
                              value: 0,
                            ),
                          ],
                        ),
                      ),
                    ],
                    const Divider(color: Colors.white12),

                    // ── El Freni Ayarları ──
                    SwitchListTile(
                      title: Text(AppTranslations.getText('show_handbrake'), style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
                      value: tempEnableHandbrake,
                      onChanged: (v) => setStateDialog(() => tempEnableHandbrake = v),
                      activeThumbColor: ac,
                    ),
                    if (tempEnableHandbrake) ...[
                      Padding(
                        padding: const EdgeInsets.only(left: 12, top: 4, bottom: 4),
                        child: Text(AppTranslations.getText('handbrake_type_label'), style: const TextStyle(color: Colors.white70, fontSize: 12)),
                      ),
                      RadioGroup<int>(
                        groupValue: tempHandbrakeType,
                        onChanged: (v) => setStateDialog(() => tempHandbrakeType = v!),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            RadioListTile<int>(
                              title: Text(AppTranslations.getText('handbrake_type_bar'), style: const TextStyle(color: Colors.cyanAccent, fontSize: 13)),
                              subtitle: Text(AppTranslations.getText('handbrake_type_bar_desc'), style: const TextStyle(color: Colors.white38, fontSize: 11)),
                              value: 1,
                            ),
                            RadioListTile<int>(
                              title: Text(AppTranslations.getText('handbrake_type_button'), style: const TextStyle(color: Colors.cyanAccent, fontSize: 13)),
                              subtitle: Text(AppTranslations.getText('handbrake_type_button_desc'), style: const TextStyle(color: Colors.white38, fontSize: 11)),
                              value: 0,
                            ),
                          ],
                        ),
                      ),
                      if (tempHandbrakeType == 0) ...[
                        ListTile(
                          title: Text(AppTranslations.getText('handbrake_key_assign'), style: const TextStyle(color: Colors.white, fontSize: 13)),
                          subtitle: Text(
                            KeyboardKeys.appKeyMap.entries
                                .firstWhere((e) => e.value == s.handbrakeKey, orElse: () => const MapEntry('X Tuşu', 7))
                                .key,
                            style: TextStyle(color: ac, fontWeight: FontWeight.bold, fontSize: 12),
                          ),
                          trailing: Icon(Icons.keyboard, color: ac),
                          onTap: () async {
                            final val = await showSearchableKeyPicker(ctx, s.handbrakeKey);
                            if (val != null) {
                              setStateDialog(() => s.handbrakeKey = val);
                            }
                          },
                        ),
                      ],
                    ],
                    const Divider(color: Colors.white12),

                    // ── Korna Tuş Ataması ──
                    ListTile(
                      title: Text(AppTranslations.getText('horn_key_assign'), style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
                      subtitle: Text(
                        KeyboardKeys.appKeyMap.entries
                            .firstWhere((e) => e.value == s.mod6HornKey, orElse: () => const MapEntry('Y Tuşu', 8))
                            .key,
                        style: TextStyle(color: ac, fontWeight: FontWeight.bold, fontSize: 12),
                      ),
                      trailing: Icon(Icons.sports_motorsports, color: ac),
                      onTap: () async {
                        final val = await showSearchableKeyPicker(ctx, s.mod6HornKey, hideKeyboard: true, hideMacros: true);
                        if (val != null) {
                          setStateDialog(() => s.mod6HornKey = val);
                        }
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dctx),
                  child: Text(AppTranslations.getText('cancel'), style: const TextStyle(color: Colors.white54)),
                ),
                ElevatedButton(
                  onPressed: () {
                    s.mod6SteeringStyle = tempSteeringStyle;
                    s.mod6EnableClutch = tempEnableClutch;
                    s.clutchType = tempClutchType;
                    s.clutchIconAccelerationRate = tempClutchRate;
                    s.mod6EnableHandbrake = tempEnableHandbrake;
                    s.handbrakeType = tempHandbrakeType;

                    prov.updateSettings(s);
                    Navigator.pop(dctx);
                    setState(() {});
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: ac, foregroundColor: Colors.black),
                  child: Text(AppTranslations.getText('save')),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // Alias for backward compatibility if referenced anywhere
  Future<void> showClutchSettingsDialog(
    BuildContext ctx,
    SettingsProvider prov,
    AppSettings s,
    void Function(void Function()) setState,
  ) async {
    await showMod6KeyAssignmentsDialog(ctx, prov, s, setState);
  }

  Future<void> showMod6LayoutDialogWithValidation(
    BuildContext ctx,
    SettingsProvider prov,
    AppSettings s,
    void Function(void Function()) setState,
  ) async {
    await showMod6KeyAssignmentsDialog(ctx, prov, s, setState);
  }

  // ── Mod 6 Konum Ayarları Diyaloğu (Çakışma Kontrollü) ──────────────────────
  Future<void> showMod6PositionsDialog(
    BuildContext ctx,
    SettingsProvider prov,
    AppSettings s,
    void Function(void Function()) setState,
  ) async {
    final ac = s.detailColor;
    int tempLeft = s.mod6SlotLeft;
    int tempLeftInner = s.mod6SlotLeftInner;
    int tempRightInner = s.mod6SlotRightInner;
    int tempRight = s.mod6SlotRight;

    final options = <int, String>{
      0: '0: Yok (Boş)',
      1: '1: Fren Pedalı',
      2: '2: Gaz Pedalı',
      3: '3: Debriyaj',
      4: '4: El Freni',
    };

    await showDialog(
      context: ctx,
      builder: (dctx) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            Widget buildDropdownTile(String label, int val, ValueChanged<int?> onChanged) {
              return ListTile(
                title: Text(label, style: const TextStyle(color: Colors.white, fontSize: 13)),
                trailing: DropdownButton<int>(
                  value: val,
                  dropdownColor: const Color(0xFF222244),
                  style: TextStyle(color: ac, fontSize: 13, fontWeight: FontWeight.bold),
                  items: options.entries
                      .map((e) => DropdownMenuItem<int>(
                            value: e.key,
                            child: Text(e.value),
                          ))
                      .toList(),
                  onChanged: onChanged,
                ),
              );
            }

            return AlertDialog(
              backgroundColor: const Color(0xFF1A1A3E),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Ekrandaki 4 ana konuma yerleştirilecek kontrolleri atayın:',
                    style: TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                  const SizedBox(height: 12),
                  buildDropdownTile('Sol Konum', tempLeft, (v) => setStateDialog(() => tempLeft = v!)),
                  buildDropdownTile('Sol-İç Çapraz Konum', tempLeftInner, (v) => setStateDialog(() => tempLeftInner = v!)),
                  buildDropdownTile('Sağ-İç Çapraz Konum', tempRightInner, (v) => setStateDialog(() => tempRightInner = v!)),
                  buildDropdownTile('Sağ Konum', tempRight, (v) => setStateDialog(() => tempRight = v!)),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dctx),
                  child: Text(AppTranslations.getText('cancel'), style: const TextStyle(color: Colors.white54)),
                ),
                ElevatedButton(
                  onPressed: () {
                    // ── ÇAKIŞMA KONTROLÜ (OVERLAP VALIDATION) ──
                    final assigned = <int>[tempLeft, tempLeftInner, tempRightInner, tempRight]
                        .where((v) => v != 0)
                        .toList();

                    if (assigned.length != assigned.toSet().length) {
                      showDialog(
                        context: dctx,
                        builder: (_) => AlertDialog(
                          backgroundColor: const Color(0xFF2A1212),
                          title: const Row(
                            children: [
                              Icon(Icons.warning, color: Colors.orangeAccent),
                              SizedBox(width: 8),
                              Text('Yerleşim Hatası', style: TextStyle(color: Colors.white)),
                            ],
                          ),
                          content: const Text(
                            'Elemanlar üst üste çakışamaz! Bir konuma birden fazla kontrol atanamaz.',
                            style: TextStyle(color: Colors.white70),
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: const Text('Tamam', style: TextStyle(color: Colors.cyanAccent)),
                            ),
                          ],
                        ),
                      );
                      return; // Kayıt durdurulur!
                    }

                    s.mod6SlotLeft = tempLeft;
                    s.mod6SlotLeftInner = tempLeftInner;
                    s.mod6SlotRightInner = tempRightInner;
                    s.mod6SlotRight = tempRight;

                    prov.updateSettings(s);
                    Navigator.pop(dctx);
                    setState(() {});
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: ac, foregroundColor: Colors.black),
                  child: Text(AppTranslations.getText('save')),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

/// İvmelenme süresi (saniye veya milisaniye türünde) değer girme penceresi.
Future<double?> showAccelerationRateInputDialog(
  BuildContext context, {
  required String title,
  required double currentSeconds,
}) async {
  bool isMs = currentSeconds < 0.1 || (currentSeconds * 1000).round() % 100 == 0 && currentSeconds < 1.0;
  final controller = TextEditingController(
    text: isMs
        ? (currentSeconds * 1000).round().toString()
        : currentSeconds.toStringAsFixed(2).replaceAll(RegExp(r'\.?0+$'), ''),
  );

  final Color ac = Theme.of(context).colorScheme.secondary;

  return showDialog<double>(
    context: context,
    builder: (ctx) {
      return StatefulBuilder(
        builder: (context, setStateDialog) {
          return AlertDialog(
            backgroundColor: const Color(0xFF1E1E2E),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Text(title, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'İvmelenme süresini saniye (sn) veya milisaniye (ms) cinsinden giriniz:',
                  style: TextStyle(color: Colors.white70, fontSize: 12),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: controller,
                        autofocus: true,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                        decoration: InputDecoration(
                          hintText: isMs ? 'Örn: 600' : 'Örn: 0.6',
                          hintStyle: const TextStyle(color: Colors.white30),
                          filled: true,
                          fillColor: Colors.black26,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: ac)),
                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Colors.white24)),
                          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: ac, width: 2)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.black38,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.white12),
                      ),
                      child: Row(
                        children: [
                          GestureDetector(
                            onTap: () {
                              if (isMs) {
                                final text = controller.text.trim().replaceAll(',', '.');
                                final val = double.tryParse(text) ?? 0;
                                controller.text = (val / 1000.0).toStringAsFixed(2).replaceAll(RegExp(r'\.?0+$'), '');
                                setStateDialog(() => isMs = false);
                              }
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              decoration: BoxDecoration(
                                color: !isMs ? ac : Colors.transparent,
                                borderRadius: BorderRadius.circular(7),
                              ),
                              child: Text(
                                'sn',
                                style: TextStyle(
                                  color: !isMs ? Colors.black : Colors.white70,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ),
                          GestureDetector(
                            onTap: () {
                              if (!isMs) {
                                final text = controller.text.trim().replaceAll(',', '.');
                                final val = double.tryParse(text) ?? 0;
                                controller.text = (val * 1000).round().toString();
                                setStateDialog(() => isMs = true);
                              }
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              decoration: BoxDecoration(
                                color: isMs ? ac : Colors.transparent,
                                borderRadius: BorderRadius.circular(7),
                              ),
                              child: Text(
                                'ms',
                                style: TextStyle(
                                  color: isMs ? Colors.black : Colors.white70,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('İptal', style: TextStyle(color: Colors.white54)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: ac),
                onPressed: () {
                  final text = controller.text.trim().replaceAll(',', '.');
                  final parsed = double.tryParse(text);
                  if (parsed != null && parsed > 0) {
                    double finalSec;
                    if (isMs || parsed > 10.0) {
                      finalSec = parsed / 1000.0;
                    } else {
                      finalSec = parsed;
                    }
                    Navigator.pop(ctx, finalSec.clamp(0.05, 10.0));
                  } else {
                    Navigator.pop(ctx);
                  }
                },
                child: const Text('Kaydet', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
              ),
            ],
          );
        },
      );
    },
  );
}
