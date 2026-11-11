part of '../settings_screen.dart';
extension _SettingsColorsTabExt on _SettingsScreenState {
  Future<void> _showDriverNameDialog(
    BuildContext ctx,
    SettingsProvider prov,
    AppSettings s,
  ) async {
    final defaultName = AppTranslations.getText('default_driver_name');
    final prefix = AppTranslations.getText('welcome_prefix');
    final controller = TextEditingController(text: s.customDriverName);

    final String? result = await showDialog<String>(
      context: ctx,
      builder: (dctx) {
        return StatefulBuilder(
          builder: (dctx, setStateDialog) {
            final currentInput = controller.text.trim();
            final previewSuffix =
                currentInput.isEmpty ? defaultName : currentInput;

            return AlertDialog(
              backgroundColor: const Color(0xFF12122A),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
              actionsOverflowButtonSpacing: 8,
              actionsOverflowDirection: VerticalDirection.down,
              title: Text(
                AppTranslations.getText('driver_title_dialog_title'),
                style: const TextStyle(color: Colors.white, fontSize: 15),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      AppTranslations.getText('driver_title_dialog_desc'),
                      style: const TextStyle(color: Colors.white60, fontSize: 12),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: controller,
                      maxLength: 24,
                      style: const TextStyle(color: Colors.white, fontSize: 15),
                      onChanged: (_) => setStateDialog(() {}),
                      decoration: InputDecoration(
                        prefixText: '$prefix ',
                        prefixStyle: TextStyle(
                          color: s.detailColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                        hintText: defaultName,
                        hintStyle: const TextStyle(color: Colors.white30),
                        counterStyle: const TextStyle(color: Colors.white38, fontSize: 11),
                        filled: true,
                        fillColor: Colors.white.withValues(alpha: 0.05),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Colors.white24),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: s.detailColor, width: 1.5),
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: s.detailColor.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: s.detailColor.withValues(alpha: 0.3),
                        ),
                      ),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          '$prefix $previewSuffix',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: s.detailColor,
                            fontSize: 14,
                            fontStyle: FontStyle.italic,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dctx, ''),
                  child: Text(
                    '${AppTranslations.getText('default')} ($defaultName)',
                    style: const TextStyle(color: Colors.amberAccent, fontSize: 12),
                  ),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(dctx),
                  child: Text(
                    AppTranslations.getText('cancel'),
                    style: const TextStyle(color: Colors.white54),
                  ),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: s.detailColor,
                    foregroundColor: Colors.black,
                  ),
                  onPressed: () => Navigator.pop(dctx, controller.text.trim()),
                  child: Text(AppTranslations.getText('apply')),
                ),
              ],
            );
          },
        );
      },
    );

    if (result != null) {
      s.customDriverName = result;
      prov.updateSettings(s);
    }
  }

  Widget _buildDriverGreetingRow(
    BuildContext ctx,
    SettingsProvider prov,
    AppSettings s,
  ) {
    final prefix = AppTranslations.getText('welcome_prefix');
    final defaultName = AppTranslations.getText('default_driver_name');
    final effectiveName = s.customDriverName.trim().isNotEmpty
        ? s.customDriverName.trim()
        : defaultName;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _showDriverNameDialog(ctx, prov, s),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: s.detailColor.withValues(alpha: 0.35)),
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: s.detailColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: s.detailColor.withValues(alpha: 0.5),
                    width: 1.5,
                  ),
                ),
                child: Icon(
                  Icons.drive_file_rename_outline,
                  color: s.detailColor,
                  size: 20,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      AppTranslations.getText('driver_title_label'),
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$prefix $effectiveName',
                      style: TextStyle(
                        color: s.detailColor,
                        fontSize: 12,
                        fontStyle: FontStyle.italic,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: s.detailColor.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: s.detailColor.withValues(alpha: 0.4)),
                ),
                child: Text(
                  effectiveName,
                  style: TextStyle(
                    color: s.detailColor,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              const Icon(Icons.chevron_right, color: Colors.white38),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildColors(BuildContext ctx, SettingsProvider prov, AppSettings s) {
    row(String label, Color cur, void Function(Color) cb) =>
        buildColorRow(ctx, prov, s, label, cur, cb);
    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 8),
      children: [
        settingsHeader(AppTranslations.getText('welcome_header_section')),
        _buildDriverGreetingRow(ctx, prov, s),
        const Divider(color: Colors.white12, height: 24),
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
