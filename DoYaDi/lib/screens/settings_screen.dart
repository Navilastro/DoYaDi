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

part 'settings_sections/main_tab.dart';
part 'settings_sections/steering_tab.dart';
part 'settings_sections/assign_tab.dart';
part 'settings_sections/colors_tab.dart';

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






}
