import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/settings_provider.dart';
import '../models/app_settings.dart';
import 'custom_layout5_editor_screen.dart';
import '../widgets/settings_dialogs.dart';

// Sabitler settings_dialogs.dart'tan geliyor:
// steeringAngles, pedalDistances, swipeSensitivities,
// clickDurations, zeroOrientationOptions, _swipeDirLabels


class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen>
    with SingleTickerProviderStateMixin, SettingsDialogMixin<SettingsScreen> {
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
        title: const Text('Ayarlar',
            style: TextStyle(fontWeight: FontWeight.bold)),
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

  // ── Ana Tab ──────────────────────────────────────────────────────────────

  Widget _buildMain(
    BuildContext ctx,
    SettingsProvider prov,
    AppSettings s,
    Color ac,
  ) {
    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 8),
      children: [
        settingsHeader('Sürüş Modu'),
        settingsTile(
          title: 'Varsayılan sürüş modu',
          trailing: Text('Mod ${s.defaultDrivingMode}',
              style: TextStyle(color: ac, fontWeight: FontWeight.bold)),
          onTap: () async {
            final val = await radioDialog<int>(
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
                  borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () {
              if (s.defaultDrivingMode == 5) {
                Navigator.push(
                  ctx,
                  MaterialPageRoute(
                      builder: (_) => const CustomLayout5EditorScreen()),
                );
              } else {
                showModeKeyAssignmentsDialog(ctx, prov, s, s.defaultDrivingMode);
              }
            },
          ),
        ),
        const Divider(color: Colors.white12, height: 24),
        settingsHeader('Pedal'),
        settingsTile(
          title: 'Sağ Pedal',
          subtitle: 'Varsayılan: Gaz — sağ taraf',
          trailing: const Icon(Icons.chevron_right, color: Colors.white38),
          onTap: () => showModeKeyAssignmentsDialog(ctx, prov, s, -1),
        ),
        settingsTile(
          title: 'Sol Pedal',
          subtitle: 'Varsayılan: Fren — sol taraf',
          trailing: const Icon(Icons.chevron_right, color: Colors.white38),
          onTap: () => showModeKeyAssignmentsDialog(ctx, prov, s, -2),
        ),
        const Divider(color: Colors.white12, height: 8),
        settingsTile(
          title: 'İvmelenme ve Fren mesafesi',
          subtitle: '%100 pedal için gereken mesafe',
          trailing: Text(
            '${s.swipeSensitivity == 5 ? "5 mm (for pro)" : s.swipeSensitivity == 0 ? "0 mm" : "${s.swipeSensitivity.toInt()} mm"}',
            style: TextStyle(color: ac, fontWeight: FontWeight.bold),
          ),
          onTap: () async {
            final val = await radioDialog<int>(
              ctx: ctx,
              title: 'İvmelenme ve Fren Mesafesi',
              current: s.swipeSensitivity.toInt(),
              options: pedalDistances,
            );
            if (val != null) {
              s.swipeSensitivity = val.toDouble();
              prov.updateSettings(s);
              setState(() {});
            }
          },
        ),
        settingsTile(
          title: 'Kaydırma hassasiyeti (tıklama)',
          subtitle: 'Bu mesafeden az kayarsa tıklama sayılır',
          trailing: Text(
            s.clickMaxDistance == 0 ? '0 mm' : '${s.clickMaxDistance} mm',
            style: TextStyle(color: ac, fontWeight: FontWeight.bold),
          ),
          onTap: () async {
            final val = await radioDialog<double>(
              ctx: ctx,
              title: 'Kaydırma Hassasiyeti',
              current: s.clickMaxDistance,
              options: swipeSensitivities,
            );
            if (val != null) {
              s.clickMaxDistance = val;
              prov.updateSettings(s);
              setState(() {});
            }
          },
        ),
        settingsTile(
          title: 'Tıklama üst (maksimum) süresi',
          subtitle: 'Bu süreden kısa dokunma = tıklama',
          trailing: Text(
            s.clickMaxDuration >= 9999
                ? 'unlimited'
                : '${s.clickMaxDuration.toStringAsFixed(2)} sec',
            style: TextStyle(color: ac, fontWeight: FontWeight.bold),
          ),
          onTap: () async {
            final val = await radioDialog<double>(
              ctx: ctx,
              title: 'Tıklama üst süresi',
              current: s.clickMaxDuration,
              options: clickDurations,
            );
            if (val != null) {
              s.clickMaxDuration = val;
              prov.updateSettings(s);
              setState(() {});
            }
          },
        ),
        const Divider(color: Colors.white12, height: 24),
        settingsHeader('Donanım Tuşları'),
        settingsTile(
          title: 'Ses Açma → Tuş',
          trailing: Text(keyName(s.volumeUpAction),
              style: TextStyle(color: ac, fontWeight: FontWeight.bold)),
          onTap: () async {
            final val = await keyDialog(ctx, 'Ses Açma eylemi', s.volumeUpAction);
            if (val != null) {
              s.volumeUpAction = val;
              prov.updateSettings(s);
              setState(() {});
            }
          },
        ),
        settingsTile(
          title: 'Ses Kısma → Tuş',
          trailing: Text(keyName(s.volumeDownAction),
              style: TextStyle(color: ac, fontWeight: FontWeight.bold)),
          onTap: () async {
            final val =
                await keyDialog(ctx, 'Ses Kısma eylemi', s.volumeDownAction);
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

  // ── Direksiyon Tab ───────────────────────────────────────────────────────

  Widget _buildSteering(
    BuildContext ctx,
    SettingsProvider prov,
    AppSettings s,
    Color ac,
  ) {
    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 8),
      children: [
        settingsHeader('Sensör'),
        SwitchListTile(
          title: const Text('Jiroskop kullan',
              style: TextStyle(color: Colors.white, fontSize: 15)),
          subtitle: const Text('İvmeölçer ve jiroskopu birleştirir',
              style: TextStyle(color: Colors.white38, fontSize: 12)),
          value: s.useGyroscope,
          activeThumbColor: ac,
          onChanged: (val) {
            s.useGyroscope = val;
            prov.updateSettings(s);
          },
        ),
        settingsTile(
          title: 'Phone orientation for zero position',
          subtitle: zeroOrientationOptions.entries
              .firstWhere((e) => e.value == s.zeroOrientation,
                  orElse: () => const MapEntry('Auto', 0))
              .key,
          trailing: Icon(Icons.screen_rotation, color: ac),
          onTap: () async {
            final val = await radioDialog<int>(
              ctx: ctx,
              title: 'Phone orientation for zero position',
              current: s.zeroOrientation,
              options: zeroOrientationOptions,
            );
            if (val != null) {
              s.zeroOrientation = val;
              prov.updateSettings(s);
              setState(() {});
            }
          },
        ),
        const Divider(color: Colors.white12, height: 24),
        settingsHeader('Direksiyon Hassasiyeti'),
        settingsTile(
          title: 'Direksiyon açısı',
          subtitle: 'Küçük değer = daha hassas',
          trailing: Text(
            s.steeringAngle <= 1
                ? 'Max level at 1 (1°)'
                : '${s.steeringAngle.toInt()}°',
            style: TextStyle(
                color: ac, fontWeight: FontWeight.bold, fontSize: 16),
          ),
          onTap: () async {
            final val = await radioDialog<int>(
              ctx: ctx,
              title: 'Direksiyon açısı',
              current: s.steeringAngle.toInt(),
              options: steeringAngles,
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
                Text('Nasıl çalışır',
                    style: TextStyle(
                        color: Colors.white70, fontWeight: FontWeight.bold)),
                SizedBox(height: 6),
                Text(
                  '1° — Max level at 1 (ultra duyarlı)\n'
                  '75° — ultra hassas (simülasyon)\n'
                  '180° — dengeli (varsayılan)\n'
                  '540° — gerçekçi araba hissi\n'
                  '1080° — kamyon / simülatör',
                  style: TextStyle(
                      color: Colors.white38, fontSize: 12, height: 1.6),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ── Atama Tab ────────────────────────────────────────────────────────────

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
      final val = await swipeDialog(ctx, label, current);
      if (val != null) {
        save(val);
        prov.updateSettings(s);
        setState(() {});
      }
    }

    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 8),
      children: [
        settingsHeader('Tuş Basış Ayarları'),
        settingsTile(
          title: 'Genel Buton Basış Modu',
          subtitle: 'Varsayılan buton davranışı',
          trailing: Text(
            ['Anlık (Varsayılan)', 'Süreli', 'Sınırsız (Toggle)', 'Hızlı (80ms)'][s.globalButtonPressMode],
            style: TextStyle(color: ac, fontWeight: FontWeight.bold),
          ),
          onTap: () async {
            final val = await radioDialog<int>(
              ctx: ctx,
              title: 'Buton Basış Modu',
              current: s.globalButtonPressMode,
              options: const {
                'Anlık (Varsayılan)': 0,
                'Süreli': 1,
                'Sınırsız (Toggle)': 2,
                'Hızlı (80ms)': 3,
              },
            );
            if (val != null) {
              s.globalButtonPressMode = val;
              prov.updateSettings(s);
              setState(() {});
            }
          },
        ),
        if (s.globalButtonPressMode == 1)
          settingsTile(
            title: 'Süreli Basış Süresi',
            subtitle: 'Buton kaç saniye basılı kalsın?',
            trailing: Text(
              '${(s.globalButtonPressDurationMs / 1000).toStringAsFixed(1)} sn',
              style: TextStyle(color: ac, fontWeight: FontWeight.bold),
            ),
            onTap: () async {
              final val = await radioDialog<int>(
                ctx: ctx,
                title: 'Basış Süresi',
                current: s.globalButtonPressDurationMs,
                options: {
                  for (var i = 1; i <= 20; i++)
                    '${(i * 0.5).toStringAsFixed(1)} sn': i * 500,
                },
              );
              if (val != null) {
                s.globalButtonPressDurationMs = val;
                prov.updateSettings(s);
                setState(() {});
              }
            },
          ),
        settingsTile(
          title: 'Tuşa özel Basış Modu',
          subtitle: 'Her tuş için ayrı basış modu ayarlayın',
          trailing: const Icon(Icons.chevron_right, color: Colors.white38),
          onTap: () => showCustomPressModesDialog(ctx, prov, s),
        ),
        const Divider(color: Colors.white12, height: 24),
        settingsHeader('Sağ Pedal'),
        swipeTile(ac, '↑ Yukarı', swipeName(s.gasSwipeUp),
            () => pick('Sağ Pedal ↑ Yukarı', s.gasSwipeUp, (v) => s.gasSwipeUp = v)),
        swipeTile(ac, '↓ Aşağı', swipeName(s.gasSwipeDown),
            () => pick('Sağ Pedal ↓ Aşağı', s.gasSwipeDown, (v) => s.gasSwipeDown = v)),
        swipeTile(ac, '← Sol', swipeName(s.gasSwipeLeft),
            () => pick('Sağ Pedal ← Sol', s.gasSwipeLeft, (v) => s.gasSwipeLeft = v)),
        swipeTile(ac, '→ Sağ', swipeName(s.gasSwipeRight),
            () => pick('Sağ Pedal → Sağ', s.gasSwipeRight, (v) => s.gasSwipeRight = v)),
        swipeTile(ac, '↖ Sol Üst', swipeName(s.gasSwipeUpLeft),
            () => pick('Sağ Pedal ↖ Sol Üst', s.gasSwipeUpLeft, (v) => s.gasSwipeUpLeft = v)),
        swipeTile(ac, '↗ Sağ Üst', swipeName(s.gasSwipeUpRight),
            () => pick('Sağ Pedal ↗ Sağ Üst', s.gasSwipeUpRight, (v) => s.gasSwipeUpRight = v)),
        swipeTile(ac, '↙ Sol Alt', swipeName(s.gasSwipeDownLeft),
            () => pick('Sağ Pedal ↙ Sol Alt', s.gasSwipeDownLeft, (v) => s.gasSwipeDownLeft = v)),
        swipeTile(ac, '↘ Sağ Alt', swipeName(s.gasSwipeDownRight),
            () => pick('Sağ Pedal ↘ Sağ Alt', s.gasSwipeDownRight, (v) => s.gasSwipeDownRight = v)),
        const Divider(color: Colors.white12, height: 32),
        settingsHeader('Sol Pedal'),
        swipeTile(ac, '↑ Yukarı', swipeName(s.brakeSwipeUp),
            () => pick('Sol Pedal ↑ Yukarı', s.brakeSwipeUp, (v) => s.brakeSwipeUp = v)),
        swipeTile(ac, '↓ Aşağı', swipeName(s.brakeSwipeDown),
            () => pick('Sol Pedal ↓ Aşağı', s.brakeSwipeDown, (v) => s.brakeSwipeDown = v)),
        swipeTile(ac, '← Sol', swipeName(s.brakeSwipeLeft),
            () => pick('Sol Pedal ← Sol', s.brakeSwipeLeft, (v) => s.brakeSwipeLeft = v)),
        swipeTile(ac, '→ Sağ', swipeName(s.brakeSwipeRight),
            () => pick('Sol Pedal → Sağ', s.brakeSwipeRight, (v) => s.brakeSwipeRight = v)),
        swipeTile(ac, '↖ Sol Üst', swipeName(s.brakeSwipeUpLeft),
            () => pick('Sol Pedal ↖ Sol Üst', s.brakeSwipeUpLeft, (v) => s.brakeSwipeUpLeft = v)),
        swipeTile(ac, '↗ Sağ Üst', swipeName(s.brakeSwipeUpRight),
            () => pick('Sol Pedal ↗ Sağ Üst', s.brakeSwipeUpRight, (v) => s.brakeSwipeUpRight = v)),
        swipeTile(ac, '↙ Sol Alt', swipeName(s.brakeSwipeDownLeft),
            () => pick('Sol Pedal ↙ Sol Alt', s.brakeSwipeDownLeft, (v) => s.brakeSwipeDownLeft = v)),
        swipeTile(ac, '↘ Sağ Alt', swipeName(s.brakeSwipeDownRight),
            () => pick('Sol Pedal ↘ Sağ Alt', s.brakeSwipeDownRight, (v) => s.brakeSwipeDownRight = v)),
      ],
    );
  }

  // ── Renkler Tab ──────────────────────────────────────────────────────────

  Widget _buildColors(BuildContext ctx, SettingsProvider prov, AppSettings s) {
    row(String label, Color cur, void Function(Color) cb) =>
        buildColorRow(ctx, prov, s, label, cur, cb);
    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 8),
      children: [
        settingsHeader('Genel'),
        row('Arka plan', s.backgroundColor, (c) {
          s.backgroundColor = c;
          prov.updateSettings(s);
        }),
        row('Vurgu / Detay', s.detailColor, (c) {
          s.detailColor = c;
          prov.updateSettings(s);
        }),
        const Divider(color: Colors.white12, height: 24),
        settingsHeader('Direksiyon göstergesi'),
        row('Gösterge rengi', s.steeringIndicatorColor, (c) {
          s.steeringIndicatorColor = c;
          prov.updateSettings(s);
        }),
        row('Gösterge arka planı', s.steeringBgColor, (c) {
          s.steeringBgColor = c;
          prov.updateSettings(s);
        }),
        const Divider(color: Colors.white12, height: 24),
        settingsHeader('Pedallar'),
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
}
