part of '../settings_screen.dart';
extension _SettingsSteeringTabExt on _SettingsScreenState {
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
        settingsHeader(AppTranslations.getText('gyro_look_header')),
        SwitchListTile(
          title: Text(
            AppTranslations.getText('gyro_look_global'),
            style: const TextStyle(color: Colors.white, fontSize: 15),
          ),
          subtitle: Text(
            AppTranslations.getText('gyro_look_global_desc'),
            style: const TextStyle(color: Colors.white38, fontSize: 12),
          ),
          value: s.gyroLookEnabled,
          activeThumbColor: ac,
          onChanged: (val) {
            s.gyroLookEnabled = val;
            prov.updateSettings(s);
            setState(() {});
          },
        ),
        if (s.gyroLookEnabled) ...[
          settingsTile(
            title: AppTranslations.getText('gyro_look_style'),
            subtitle: s.gyroLookStyle == 0 ? AppTranslations.getText('gyro_look_style_0') : AppTranslations.getText('gyro_look_style_1'),
            trailing: Icon(Icons.style, color: ac),
            onTap: () async {
              final val = await radioDialog<int>(
                ctx: ctx,
                title: AppTranslations.getText('gyro_look_style'),
                current: s.gyroLookStyle,
                options: {
                  AppTranslations.getText('gyro_look_style_0_desc'): 0,
                  AppTranslations.getText('gyro_look_style_1_desc'): 1,
                },
              );
              if (val != null) {
                s.gyroLookStyle = val;
                prov.updateSettings(s);
                setState(() {});
              }
            },
          ),
          settingsTile(
            title: AppTranslations.getText('gyro_look_mode'),
            subtitle: s.gyroLookMode == 1
                ? AppTranslations.getText('gyro_look_mode_normal')
                : s.gyroLookMode == 2
                    ? AppTranslations.getText('gyro_look_mode_fps')
                    : AppTranslations.getText('gyro_look_mode_driver'),
            trailing: Icon(Icons.settings_applications, color: ac),
            onTap: () async {
              final val = await radioDialog<int>(
                ctx: ctx,
                title: AppTranslations.getText('gyro_look_mode'),
                current: s.gyroLookMode,
                options: {
                  AppTranslations.getText('gyro_look_mode_normal'): 1,
                  AppTranslations.getText('gyro_look_mode_fps'): 2,
                  AppTranslations.getText('gyro_look_mode_driver'): 3,
                },
              );
              if (val != null) {
                s.gyroLookMode = val;
                prov.updateSettings(s);
                setState(() {});
              }
            },
          ),
          settingsTile(
            title: AppTranslations.getText('gyro_look_sens'),
            subtitle: s.gyroLookSensitivity.toStringAsFixed(1),
            trailing: SizedBox(
              width: 150,
              child: Slider(
                value: s.gyroLookSensitivity,
                min: 0.2,
                max: 3.0,
                divisions: 28,
                activeColor: ac,
                onChanged: (val) {
                  s.gyroLookSensitivity = val;
                  prov.updateSettings(s);
                  setState(() {});
                },
              ),
            ),
          ),
          settingsTile(
            title: AppTranslations.getText('gyro_look_deadzone'),
            subtitle: '${s.gyroLookDeadzone.toInt()}°',
            trailing: SizedBox(
              width: 150,
              child: Slider(
                value: s.gyroLookDeadzone,
                min: 1.0,
                max: 30.0,
                divisions: 29,
                activeColor: ac,
                onChanged: (val) {
                  s.gyroLookDeadzone = val;
                  prov.updateSettings(s);
                  setState(() {});
                },
              ),
            ),
          ),
        ],
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
}
