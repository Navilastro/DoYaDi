part of '../settings_screen.dart';
extension _SettingsColorsTabExt on _SettingsScreenState {
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
