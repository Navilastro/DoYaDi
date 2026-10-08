part of '../settings_screen.dart';
extension _SettingsAssignTabExt on _SettingsScreenState {
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
}
