part of '../settings_screen.dart';
extension _SettingsMainTabExt on _SettingsScreenState {
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
              options: {
                for (var i = 0; i <= 6; i++) 'Mod $i': i,
                'Mod 7 — F1 Telemetri HUD': 7,
                'Mod 8 — Rahat Sürüş': 8,
                'Mod 9 — Uçuş Kontrolü': 9,
                'Mod 10 — Uçuş MFD': 10,
              },
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

}
