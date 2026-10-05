import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/settings_provider.dart';
import '../models/app_settings.dart';
import 'custom_layout5_editor_screen.dart';
import 'addon_manager_tab.dart';
import '../widgets/settings_dialogs.dart';
import '../core/haptic_manager.dart';
import '../core/utils/app_translations.dart';
import '../core/sensor_manager.dart';

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
    _tab = TabController(length: 5, vsync: this);
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
        title: Text(
          AppTranslations.getText('settings'),
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        bottom: TabBar(
          controller: _tab,
          indicatorColor: ac,
          labelColor: ac,
          unselectedLabelColor: Colors.white38,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          tabs: [
            Tab(text: AppTranslations.getText('tab_main')),
            Tab(text: AppTranslations.getText('tab_steering')),
            Tab(text: AppTranslations.getText('tab_assign')),
            Tab(text: AppTranslations.getText('tab_colors')),
            Tab(text: AppTranslations.getText('addon_content')),
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
          const AddonManagerTab(),
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
        settingsHeader(AppTranslations.getText('driving_mode')),
        settingsTile(
          title: AppTranslations.getText('default_driving_mode'),
          trailing: Text(
            'Mod ${s.defaultDrivingMode}',
            style: TextStyle(color: ac, fontWeight: FontWeight.bold),
          ),
          onTap: () async {
            final val = await radioDialog<int>(
              ctx: ctx,
              title: AppTranslations.getText('default_driving_mode'),
              current: s.defaultDrivingMode,
              options: {for (var i = 0; i <= 6; i++) 'Mod $i': i},
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
                  ? AppTranslations.getText('edit_custom_layout')
                  : '${AppTranslations.getText('edit_keys')} (Mod ${s.defaultDrivingMode})',
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
              } else if (s.defaultDrivingMode == 6) {
                showMod6KeyAssignmentsDialog(ctx, prov, s, setState);
              } else {
                showModeKeyAssignmentsDialog(
                  ctx,
                  prov,
                  s,
                  s.defaultDrivingMode,
                );
              }
            },
          ),
        ),
        // Mod 6 pedal stili ve konum ayarları (sadece Mod 6 aktifken)
        if (s.defaultDrivingMode == 6) ...[
          settingsTile(
            title: AppTranslations.getText('mod6_pedal_style'),
            trailing: Text(
              s.mod6PedalStyle == 0
                  ? AppTranslations.getText('pedal_style_bar')
                  : AppTranslations.getText('pedal_style_icon'),
              style: TextStyle(color: ac, fontWeight: FontWeight.bold),
            ),
            onTap: () async {
              final val = await radioDialog<int>(
                ctx: ctx,
                title: AppTranslations.getText('mod6_pedal_style'),
                current: s.mod6PedalStyle,
                options: {
                  AppTranslations.getText('pedal_style_bar'): 0,
                  AppTranslations.getText('pedal_style_icon'): 1,
                },
              );
              if (val != null) {
                s.mod6PedalStyle = val;
                prov.updateSettings(s);
                setState(() {});
              }
            },
          ),
          settingsTile(
            title: 'Konum Ayarları (Mod 6)',
            subtitle: 'Sol, Sol-İç, Sağ-İç ve Sağ konumlarına kontrolleri atayın.',
            trailing: Icon(Icons.dashboard_customize, color: ac),
            onTap: () {
              showMod6PositionsDialog(ctx, prov, s, setState);
            },
          ),
        ],
        const Divider(color: Colors.white12, height: 24),
        settingsHeader(AppTranslations.getText('pedal')),
        settingsTile(
          title: AppTranslations.getText('right_pedal_button'),
          subtitle: AppTranslations.getText('right_pedal_desc'),
          trailing: const Icon(Icons.chevron_right, color: Colors.white38),
          onTap: () => showModeKeyAssignmentsDialog(ctx, prov, s, -1),
        ),
        settingsTile(
          title: AppTranslations.getText('left_pedal_button'),
          subtitle: AppTranslations.getText('left_pedal_desc'),
          trailing: const Icon(Icons.chevron_right, color: Colors.white38),
          onTap: () => showModeKeyAssignmentsDialog(ctx, prov, s, -2),
        ),
        const Divider(color: Colors.white12, height: 8),
        settingsTile(
          title: AppTranslations.getText('accel_brake_dist'),
          subtitle: AppTranslations.getText('100_percent_dist'),
          trailing: Text(
            s.swipeSensitivity == 5
                ? '5 mm (for pro)'
                : s.swipeSensitivity == 0
                ? '0 mm'
                : '${s.swipeSensitivity.toInt()} mm',
            style: TextStyle(color: ac, fontWeight: FontWeight.bold),
          ),
          onTap: () async {
            final val = await radioDialog<int>(
              ctx: ctx,
              title: AppTranslations.getText('accel_brake_dist'),
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
          title: AppTranslations.getText('swipe_sens'),
          subtitle: AppTranslations.getText('swipe_sens_desc'),
          trailing: Text(
            s.clickMaxDistance == 0 ? '0 mm' : '${s.clickMaxDistance} mm',
            style: TextStyle(color: ac, fontWeight: FontWeight.bold),
          ),
          onTap: () async {
            final val = await radioDialog<double>(
              ctx: ctx,
              title: AppTranslations.getText('swipe_sens'),
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
          title: AppTranslations.getText('max_click_dur'),
          subtitle: AppTranslations.getText('max_click_dur_desc'),
          trailing: Text(
            s.clickMaxDuration >= 9999
                ? 'unlimited'
                : '${s.clickMaxDuration.toStringAsFixed(2)} sec',
            style: TextStyle(color: ac, fontWeight: FontWeight.bold),
          ),
          onTap: () async {
            final val = await radioDialog<double>(
              ctx: ctx,
              title: AppTranslations.getText('max_click_dur'),
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
        // Pedal İkonu İvmelenme Hızı
        settingsTile(
          title: AppTranslations.getText('pedal_icon_accel_rate'),
          subtitle: AppTranslations.getText('pedal_icon_accel_rate_desc'),
          trailing: Text(
            '${s.pedalIconAccelerationRate.toStringAsFixed(2)} sn (${(s.pedalIconAccelerationRate * 1000).round()} ms)',
            style: TextStyle(color: ac, fontWeight: FontWeight.bold, fontSize: 12),
          ),
          onTap: () async {
            final val = await showAccelerationRateInputDialog(
              ctx,
              title: AppTranslations.getText('pedal_icon_accel_rate'),
              currentSeconds: s.pedalIconAccelerationRate,
            );
            if (val != null) {
              s.pedalIconAccelerationRate = val;
              prov.updateSettings(s);
              setState(() {});
            }
          },
        ),
        const Divider(color: Colors.white12, height: 24),
        // Simüle Edilmiş Haptik
        settingsHeader(AppTranslations.getText('haptic_header')),
        SwitchListTile(
          title: Text(
            AppTranslations.getText('simulated_haptic'),
            style: const TextStyle(color: Colors.white, fontSize: 15),
          ),
          subtitle: Text(
            AppTranslations.getText('simulated_haptic_desc'),
            style: const TextStyle(color: Colors.white38, fontSize: 12),
          ),
          value: s.simulatedHapticEnabled,
          activeThumbColor: ac,
          onChanged: (val) async {
            if (val) {
              await HapticManager().checkAndRequestHapticPermission();
            }
            s.simulatedHapticEnabled = val;
            prov.updateSettings(s);
            setState(() {});
          },
        ),
        if (s.simulatedHapticEnabled) ...[
          Padding(
            padding: const EdgeInsets.only(left: 16, top: 8, bottom: 4),
            child: Text(
              AppTranslations.getText('general_haptic_settings').toUpperCase(),
              style: TextStyle(
                color: ac,
                fontSize: 12,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.8,
              ),
            ),
          ),
          settingsTile(
            title: AppTranslations.getText('haptic_type'),
            trailing: Text(
              s.globalHapticType == 0
                  ? AppTranslations.getText('haptic_type_light')
                  : s.globalHapticType == 1
                  ? AppTranslations.getText('haptic_type_medium')
                  : s.globalHapticType == 2
                  ? AppTranslations.getText('haptic_type_heavy')
                  : s.globalHapticType == 3
                  ? AppTranslations.getText('haptic_type_selection')
                  : AppTranslations.getText('haptic_type_vibrate'),
              style: TextStyle(color: ac, fontWeight: FontWeight.bold),
            ),
            onTap: () async {
              final val = await radioDialog<int>(
                ctx: ctx,
                title: AppTranslations.getText('haptic_type'),
                current: s.globalHapticType,
                options: {
                  AppTranslations.getText('haptic_type_light'): 0,
                  AppTranslations.getText('haptic_type_medium'): 1,
                  AppTranslations.getText('haptic_type_heavy'): 2,
                  AppTranslations.getText('haptic_type_selection'): 3,
                  AppTranslations.getText('haptic_type_vibrate'): 4,
                },
              );
              if (val != null) {
                s.globalHapticType = val;
                prov.updateSettings(s);
                setState(() {});
              }
            },
          ),
          settingsTile(
            title: AppTranslations.getText('haptic_trigger'),
            trailing: Text(
              s.globalHapticTrigger == 0
                  ? AppTranslations.getText('haptic_trigger_down')
                  : s.globalHapticTrigger == 1
                  ? AppTranslations.getText('haptic_trigger_up')
                  : AppTranslations.getText('haptic_trigger_held'),
              style: TextStyle(color: ac, fontWeight: FontWeight.bold),
            ),
            onTap: () async {
              final val = await radioDialog<int>(
                ctx: ctx,
                title: AppTranslations.getText('haptic_trigger'),
                current: s.globalHapticTrigger,
                options: {
                  AppTranslations.getText('haptic_trigger_down'): 0,
                  AppTranslations.getText('haptic_trigger_up'): 1,
                  AppTranslations.getText('haptic_trigger_held'): 2,
                },
              );
              if (val != null) {
                s.globalHapticTrigger = val;
                prov.updateSettings(s);
                setState(() {});
              }
            },
          ),
          const Divider(color: Colors.white12, height: 16),
          Padding(
            padding: const EdgeInsets.only(left: 16, top: 8, bottom: 4),
            child: Text(
              AppTranslations.getText('custom_haptic_settings').toUpperCase(),
              style: TextStyle(
                color: ac,
                fontSize: 12,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.8,
              ),
            ),
          ),
          settingsTile(
            title: AppTranslations.getText('custom_button_haptic_title'),
            subtitle: AppTranslations.getText('custom_haptic_settings_desc'),
            trailing: Icon(Icons.chevron_right, color: ac),
            onTap: () => showCustomButtonHapticDialog(
              ctx,
              prov,
              s,
              setState,
            ),
          ),
        ],
        const Divider(color: Colors.white12, height: 24),
        settingsHeader(AppTranslations.getText('hw_keys')),
        settingsTile(
          title: AppTranslations.getText('vol_up_action'),
          trailing: Text(
            keyName(s.volumeUpAction),
            style: TextStyle(color: ac, fontWeight: FontWeight.bold),
          ),
          onTap: () async {
            final val = await keyDialog(
              ctx,
              AppTranslations.getText('vol_up_action_title'),
              s.volumeUpAction,
            );
            if (val != null) {
              s.volumeUpAction = val;
              prov.updateSettings(s);
              setState(() {});
            }
          },
        ),
        settingsTile(
          title: AppTranslations.getText('vol_down_action'),
          trailing: Text(
            keyName(s.volumeDownAction),
            style: TextStyle(color: ac, fontWeight: FontWeight.bold),
          ),
          onTap: () async {
            final val = await keyDialog(
              ctx,
              AppTranslations.getText('vol_down_action_title'),
              s.volumeDownAction,
            );
            if (val != null) {
              s.volumeDownAction = val;
              prov.updateSettings(s);
              setState(() {});
            }
          },
        ),
        const Divider(color: Colors.white12, height: 24),
        settingsHeader(AppTranslations.getText('language')),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white12),
            ),
            child: Column(
              children: [
                _langTile(
                  ctx: ctx,
                  prov: prov,
                  langCode: 'tr',
                  label: 'Türkçe',
                  flag: '🇹🇷',
                  ac: ac,
                ),
                const Divider(color: Colors.white12, height: 1, indent: 16),
                _langTile(
                  ctx: ctx,
                  prov: prov,
                  langCode: 'en',
                  label: 'English',
                  flag: '🇬🇧',
                  ac: ac,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _langTile({
    required BuildContext ctx,
    required SettingsProvider prov,
    required String langCode,
    required String label,
    required String flag,
    required Color ac,
  }) {
    final isSelected = prov.currentLanguage == langCode;
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () async {
        if (isSelected) return;
        await prov.updateLanguage(langCode);
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Text(flag, style: const TextStyle(fontSize: 22)),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color: isSelected ? ac : Colors.white70,
                  fontSize: 15,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ),
            if (isSelected)
              Icon(Icons.check_circle, color: ac, size: 20)
            else
              const Icon(
                Icons.radio_button_unchecked,
                color: Colors.white24,
                size: 20,
              ),
          ],
        ),
      ),
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
        settingsHeader(AppTranslations.getText('sensor')),
        SwitchListTile(
          title: Text(
            AppTranslations.getText('use_gyro'),
            style: const TextStyle(color: Colors.white, fontSize: 15),
          ),
          subtitle: Text(
            AppTranslations.getText('use_gyro_desc'),
            style: const TextStyle(color: Colors.white38, fontSize: 12),
          ),
          value: s.useGyroscope,
          activeThumbColor: ac,
          onChanged: (val) {
            s.useGyroscope = val;
            prov.updateSettings(s);
          },
        ),
        SwitchListTile(
          title: Text(
            AppTranslations.getText('cumulative_steering'),
            style: const TextStyle(color: Colors.white, fontSize: 15),
          ),
          subtitle: Text(
            AppTranslations.getText('cumulative_steering_desc'),
            style: const TextStyle(color: Colors.white38, fontSize: 12),
          ),
          value: s.isCumulativeSteering,
          activeThumbColor: ac,
          onChanged: (val) {
            s.isCumulativeSteering = val;
            prov.updateSettings(s);
          },
        ),
        settingsTile(
          title: 'Sensör Merkezleme Modu',
          subtitle: s.gyroCenterMode == 0
              ? 'Otomatik (${s.gyroAutoCenterDuration.toInt()} sn hareketsizlik)'
              : s.gyroCenterMode == 1
                  ? 'Ayarlar Sayfasından'
                  : 'Düzenleme Ekranından',
          trailing: Icon(Icons.center_focus_strong, color: ac),
          onTap: () async {
            final val = await radioDialog<int>(
              ctx: ctx,
              title: 'Sensör Merkezleme Modu',
              current: s.gyroCenterMode,
              options: const {
                'Otomatik (Hareketsizlik)': 0,
                'Ayarlar Sayfasından': 1,
                'Düzenleme Ekranından': 2,
              },
            );
            if (val != null) {
              s.gyroCenterMode = val;
              prov.updateSettings(s);
              setState(() {});
            }
          },
        ),
        if (s.gyroCenterMode == 0)
          settingsTile(
            title: 'Otomatik Merkezleme Süresi',
            subtitle: '${s.gyroAutoCenterDuration.toInt()} saniye hareketsiz kalınca sıfırlar.',
            trailing: Text(
              '${s.gyroAutoCenterDuration.toInt()} sn',
              style: TextStyle(color: ac, fontWeight: FontWeight.bold),
            ),
            onTap: () async {
              final val = await radioDialog<double>(
                ctx: ctx,
                title: 'Otomatik Merkezleme Süresi',
                current: s.gyroAutoCenterDuration,
                options: const {
                  '5 sn': 5.0,
                  '10 sn': 10.0,
                  '15 sn': 15.0,
                  '20 sn': 20.0,
                },
              );
              if (val != null) {
                s.gyroAutoCenterDuration = val;
                prov.updateSettings(s);
                setState(() {});
              }
            },
          ),
        SwitchListTile(
          title: const Text(
            'Ölü Alana (Deadzone) Pitch Dahil Et',
            style: TextStyle(color: Colors.white, fontSize: 15),
          ),
          subtitle: const Text(
            'Yukarı/aşağı eksenindeki harekette ölü alan uygular (Sadece Sağ Analog).',
            style: TextStyle(color: Colors.white38, fontSize: 12),
          ),
          value: s.includePitchInDeadzone,
          activeThumbColor: ac,
          onChanged: (val) {
            s.includePitchInDeadzone = val;
            prov.updateSettings(s);
            setState(() {});
          },
        ),
        if (s.gyroCenterMode == 1)
          settingsTile(
            title: 'Merkezi Şimdi Sıfırla',
            subtitle: 'Sensör merkezini o anki duruşa göre ayarlar.',
            trailing: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: ac,
                foregroundColor: Colors.black,
              ),
              onPressed: () {
                SensorManager().recenterGyro();
                ScaffoldMessenger.of(ctx).showSnackBar(
                  const SnackBar(content: Text('Sensör merkezi sıfırlandı.', style: TextStyle(color: Colors.white))),
                );
              },
              child: const Text('Sıfırla'),
            ),
          ),
        settingsTile(
          title: AppTranslations.getText('phone_orientation'),
          subtitle: zeroOrientationOptions.entries
              .firstWhere(
                (e) => e.value == s.zeroOrientation,
                orElse: () => const MapEntry('Auto', 0),
              )
              .key,
          trailing: Icon(Icons.screen_rotation, color: ac),
          onTap: () async {
            final val = await radioDialog<int>(
              ctx: ctx,
              title: AppTranslations.getText('phone_orientation'),
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
        settingsHeader(AppTranslations.getText('steering_sens')),
        settingsTile(
          title: AppTranslations.getText('steering_angle'),
          subtitle: AppTranslations.getText('smaller_more_sens'),
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
            final val = await radioDialog<int>(
              ctx: ctx,
              title: AppTranslations.getText('steering_angle'),
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  AppTranslations.getText('how_it_works'),
                  style: const TextStyle(
                    color: Colors.white70,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  AppTranslations.getText('how_it_works_desc'),
                  style: const TextStyle(
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
        settingsHeader(AppTranslations.getText('key_press_settings')),
        settingsTile(
          title: AppTranslations.getText('global_press_mode'),
          subtitle: AppTranslations.getText('default_button_behavior'),
          trailing: Text(
            [
              AppTranslations.getText('press_mode_instant'),
              AppTranslations.getText('press_mode_duration'),
              AppTranslations.getText('press_mode_toggle'),
              AppTranslations.getText('press_mode_fast'),
            ][s.globalButtonPressMode],
            style: TextStyle(color: ac, fontWeight: FontWeight.bold),
          ),
          onTap: () async {
            final val = await radioDialog<int>(
              ctx: ctx,
              title: AppTranslations.getText('global_press_mode'),
              current: s.globalButtonPressMode,
              options: {
                AppTranslations.getText('press_mode_instant'): 0,
                AppTranslations.getText('press_mode_duration'): 1,
                AppTranslations.getText('press_mode_toggle'): 2,
                AppTranslations.getText('press_mode_fast'): 3,
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
            title: AppTranslations.getText('timed_press_duration'),
            subtitle: AppTranslations.getText('timed_press_desc'),
            trailing: Text(
              '${(s.globalButtonPressDurationMs / 1000).toStringAsFixed(1)} sn',
              style: TextStyle(color: ac, fontWeight: FontWeight.bold),
            ),
            onTap: () async {
              final val = await radioDialog<int>(
                ctx: ctx,
                title: AppTranslations.getText('timed_press_duration'),
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
          title: AppTranslations.getText('custom_press_mode'),
          subtitle: AppTranslations.getText('custom_press_desc'),
          trailing: const Icon(Icons.chevron_right, color: Colors.white38),
          onTap: () => showCustomPressModesDialog(ctx, prov, s),
        ),
        const Divider(color: Colors.white12, height: 24),
        settingsHeader(AppTranslations.getText('right_pedal')),
        swipeTile(
          ac,
          AppTranslations.getText('swipe_up'),
          swipeName(s.gasSwipeUp),
          () => pick(
            '${AppTranslations.getText('right_pedal')} ${AppTranslations.getText('swipe_up')}',
            s.gasSwipeUp,
            (v) => s.gasSwipeUp = v,
          ),
        ),
        swipeTile(
          ac,
          AppTranslations.getText('swipe_down'),
          swipeName(s.gasSwipeDown),
          () => pick(
            '${AppTranslations.getText('right_pedal')} ${AppTranslations.getText('swipe_down')}',
            s.gasSwipeDown,
            (v) => s.gasSwipeDown = v,
          ),
        ),
        swipeTile(
          ac,
          AppTranslations.getText('swipe_left'),
          swipeName(s.gasSwipeLeft),
          () => pick(
            '${AppTranslations.getText('right_pedal')} ${AppTranslations.getText('swipe_left')}',
            s.gasSwipeLeft,
            (v) => s.gasSwipeLeft = v,
          ),
        ),
        swipeTile(
          ac,
          AppTranslations.getText('swipe_right'),
          swipeName(s.gasSwipeRight),
          () => pick(
            '${AppTranslations.getText('right_pedal')} ${AppTranslations.getText('swipe_right')}',
            s.gasSwipeRight,
            (v) => s.gasSwipeRight = v,
          ),
        ),
        swipeTile(
          ac,
          AppTranslations.getText('swipe_ul'),
          swipeName(s.gasSwipeUpLeft),
          () => pick(
            '${AppTranslations.getText('right_pedal')} ${AppTranslations.getText('swipe_ul')}',
            s.gasSwipeUpLeft,
            (v) => s.gasSwipeUpLeft = v,
          ),
        ),
        swipeTile(
          ac,
          AppTranslations.getText('swipe_ur'),
          swipeName(s.gasSwipeUpRight),
          () => pick(
            '${AppTranslations.getText('right_pedal')} ${AppTranslations.getText('swipe_ur')}',
            s.gasSwipeUpRight,
            (v) => s.gasSwipeUpRight = v,
          ),
        ),
        swipeTile(
          ac,
          AppTranslations.getText('swipe_dl'),
          swipeName(s.gasSwipeDownLeft),
          () => pick(
            '${AppTranslations.getText('right_pedal')} ${AppTranslations.getText('swipe_dl')}',
            s.gasSwipeDownLeft,
            (v) => s.gasSwipeDownLeft = v,
          ),
        ),
        swipeTile(
          ac,
          AppTranslations.getText('swipe_dr'),
          swipeName(s.gasSwipeDownRight),
          () => pick(
            '${AppTranslations.getText('right_pedal')} ${AppTranslations.getText('swipe_dr')}',
            s.gasSwipeDownRight,
            (v) => s.gasSwipeDownRight = v,
          ),
        ),
        const Divider(color: Colors.white12, height: 32),
        settingsHeader(AppTranslations.getText('left_pedal')),
        swipeTile(
          ac,
          AppTranslations.getText('swipe_up'),
          swipeName(s.brakeSwipeUp),
          () => pick(
            '${AppTranslations.getText('left_pedal')} ${AppTranslations.getText('swipe_up')}',
            s.brakeSwipeUp,
            (v) => s.brakeSwipeUp = v,
          ),
        ),
        swipeTile(
          ac,
          AppTranslations.getText('swipe_down'),
          swipeName(s.brakeSwipeDown),
          () => pick(
            '${AppTranslations.getText('left_pedal')} ${AppTranslations.getText('swipe_down')}',
            s.brakeSwipeDown,
            (v) => s.brakeSwipeDown = v,
          ),
        ),
        swipeTile(
          ac,
          AppTranslations.getText('swipe_left'),
          swipeName(s.brakeSwipeLeft),
          () => pick(
            '${AppTranslations.getText('left_pedal')} ${AppTranslations.getText('swipe_left')}',
            s.brakeSwipeLeft,
            (v) => s.brakeSwipeLeft = v,
          ),
        ),
        swipeTile(
          ac,
          AppTranslations.getText('swipe_right'),
          swipeName(s.brakeSwipeRight),
          () => pick(
            '${AppTranslations.getText('left_pedal')} ${AppTranslations.getText('swipe_right')}',
            s.brakeSwipeRight,
            (v) => s.brakeSwipeRight = v,
          ),
        ),
        swipeTile(
          ac,
          AppTranslations.getText('swipe_ul'),
          swipeName(s.brakeSwipeUpLeft),
          () => pick(
            '${AppTranslations.getText('left_pedal')} ${AppTranslations.getText('swipe_ul')}',
            s.brakeSwipeUpLeft,
            (v) => s.brakeSwipeUpLeft = v,
          ),
        ),
        swipeTile(
          ac,
          AppTranslations.getText('swipe_ur'),
          swipeName(s.brakeSwipeUpRight),
          () => pick(
            '${AppTranslations.getText('left_pedal')} ${AppTranslations.getText('swipe_ur')}',
            s.brakeSwipeUpRight,
            (v) => s.brakeSwipeUpRight = v,
          ),
        ),
        swipeTile(
          ac,
          AppTranslations.getText('swipe_dl'),
          swipeName(s.brakeSwipeDownLeft),
          () => pick(
            '${AppTranslations.getText('left_pedal')} ${AppTranslations.getText('swipe_dl')}',
            s.brakeSwipeDownLeft,
            (v) => s.brakeSwipeDownLeft = v,
          ),
        ),
        swipeTile(
          ac,
          AppTranslations.getText('swipe_dr'),
          swipeName(s.brakeSwipeDownRight),
          () => pick(
            '${AppTranslations.getText('left_pedal')} ${AppTranslations.getText('swipe_dr')}',
            s.brakeSwipeDownRight,
            (v) => s.brakeSwipeDownRight = v,
          ),
        ),
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
        settingsHeader(AppTranslations.getText('general')),
        row(AppTranslations.getText('bg_color'), s.backgroundColor, (c) {
          s.backgroundColor = c;
          prov.updateSettings(s);
        }),
        row(AppTranslations.getText('accent_color'), s.detailColor, (c) {
          s.detailColor = c;
          prov.updateSettings(s);
        }),
        const Divider(color: Colors.white12, height: 24),
        settingsHeader(AppTranslations.getText('steering_indicator')),
        row(
          AppTranslations.getText('indicator_color'),
          s.steeringIndicatorColor,
          (c) {
            s.steeringIndicatorColor = c;
            prov.updateSettings(s);
          },
        ),
        row(AppTranslations.getText('indicator_bg'), s.steeringBgColor, (c) {
          s.steeringBgColor = c;
          prov.updateSettings(s);
        }),
        const Divider(color: Colors.white12, height: 24),
        settingsHeader(AppTranslations.getText('pedals')),
        row(AppTranslations.getText('gas_color'), s.gasColor, (c) {
          s.gasColor = c;
          prov.updateSettings(s);
        }),
        row(AppTranslations.getText('brake_color'), s.brakeColor, (c) {
          s.brakeColor = c;
          prov.updateSettings(s);
        }),
        row(AppTranslations.getText('feedback_color'), s.yetsoreColor, (c) {
          s.yetsoreColor = c;
          prov.updateSettings(s);
        }),
        row(AppTranslations.getText('pedal_bg'), s.pedalBgColor, (c) {
          s.pedalBgColor = c;
          prov.updateSettings(s);
        }),
        const Divider(color: Colors.white12, height: 24),
        settingsHeader(AppTranslations.getText('mod6_colors')),
        row(AppTranslations.getText('clutch_color'), s.clutchColor, (c) {
          s.clutchColor = c;
          prov.updateSettings(s);
        }),
        row(AppTranslations.getText('clutch_feedback_color'), s.clutchYetsoreColor, (c) {
          s.clutchYetsoreColor = c;
          prov.updateSettings(s);
        }),
        row(AppTranslations.getText('handbrake_color'), s.handbrakeColor, (c) {
          s.handbrakeColor = c;
          prov.updateSettings(s);
        }),
        row(AppTranslations.getText('handbrake_feedback_color'), s.handbrakeYetsoreColor, (c) {
          s.handbrakeYetsoreColor = c;
          prov.updateSettings(s);
        }),
        row(AppTranslations.getText('clutch_button_color'), s.clutchButtonColor, (c) {
          s.clutchButtonColor = c;
          prov.updateSettings(s);
        }),
        row(AppTranslations.getText('clutch_icon_color'), s.clutchIconColor, (c) {
          s.clutchIconColor = c;
          prov.updateSettings(s);
        }),
        row(AppTranslations.getText('handbrake_button_color'), s.handbrakeButtonColor, (c) {
          s.handbrakeButtonColor = c;
          prov.updateSettings(s);
        }),
        row(AppTranslations.getText('handbrake_icon_color'), s.handbrakeIconColor, (c) {
          s.handbrakeIconColor = c;
          prov.updateSettings(s);
        }),
        row(AppTranslations.getText('gas_icon_color'), s.gasIconColor, (c) {
          s.gasIconColor = c;
          prov.updateSettings(s);
        }),
        row(AppTranslations.getText('brake_icon_color'), s.brakeIconColor, (c) {
          s.brakeIconColor = c;
          prov.updateSettings(s);
        }),
        row(AppTranslations.getText('steering_icon_color'), s.steeringWheelColor, (c) {
          s.steeringWheelColor = c;
          prov.updateSettings(s);
        }),
        row(AppTranslations.getText('steering_turn_right_color'), s.steeringTurnRightColor, (c) {
          s.steeringTurnRightColor = c;
          prov.updateSettings(s);
        }),
        row(AppTranslations.getText('steering_turn_left_color'), s.steeringTurnLeftColor, (c) {
          s.steeringTurnLeftColor = c;
          prov.updateSettings(s);
        }),
        const SizedBox(height: 40),
      ],
    );
  }
}
