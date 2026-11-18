import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../config/app_config.dart';
import '../providers/settings_provider.dart';
import '../providers/monetization_provider.dart';
import '../models/app_settings.dart';
import '../models/settings_snapshot.dart';
import 'custom_layout5_editor_screen.dart';
import 'addon_manager_tab.dart';
import '../widgets/settings_dialogs.dart';
import '../core/haptic_manager.dart';
import '../core/utils/app_translations.dart';
import '../core/sensor_manager.dart';
import '../widgets/looping_media_widget.dart';

part 'settings_sections/main_tab.dart';
part 'settings_sections/steering_tab.dart';
part 'settings_sections/assign_tab.dart';
part 'settings_sections/colors_tab.dart';
part 'settings_sections/membership_tab.dart';

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
  void setState(VoidCallback fn) => super.setState(fn);

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 6, vsync: this);
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<SettingsProvider>(context);
    final isProUser = Provider.of<MonetizationProvider>(context).isPro;
    final s = provider.settings;
    final ac = s.detailColor;
    final hasBgMedia = AppMediaHelper.hasMedia(s.bgMediaPath);
    final headerTextColor = hasBgMedia ? Colors.white : s.textColor;
    final unselectedColor = hasBgMedia ? Colors.white70 : s.textDisabledColor;

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: s.backgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: headerTextColor,
        flexibleSpace: ClipRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              color: s.surfaceColor.withValues(alpha: hasBgMedia ? 0.42 : 0.78),
            ),
          ),
        ),
        title: Row(
          children: [
            Text(
              AppTranslations.getText('settings'),
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: headerTextColor,
              ),
            ),
            const SizedBox(width: 12),
            Flexible(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: _buildSnapshotSelector(
                  context,
                  provider,
                  s,
                  ac,
                  headerTextColor,
                  hasBgMedia,
                ),
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.info_outline, color: headerTextColor),
            tooltip: AppTranslations.getText('key_mappings'),
            onPressed: () => showKeyMappingsInfoDialog(context, s),
          ),
        ],
        bottom: TabBar(
          controller: _tab,
          indicatorColor: ac,
          labelColor: ac,
          unselectedLabelColor: unselectedColor,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          tabs: [
            Tab(text: AppTranslations.getText('tab_main')),
            Tab(text: AppTranslations.getText('tab_steering')),
            Tab(text: AppTranslations.getText('tab_assign')),
            Tab(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(AppTranslations.getText('tab_colors')),
                  if (!isProUser) ...[
                    const SizedBox(width: 6),
                    const Icon(Icons.lock_outline, size: 15),
                  ],
                ],
              ),
            ),
            Tab(text: AppTranslations.getText('addon_content')),
            Tab(text: AppTranslations.getText('tab_membership')),
          ],
        ),
      ),
      body: Stack(
        children: [
          if (hasBgMedia)
            Positioned.fill(
              child: LoopingMediaWidget(
                mediaPath: s.bgMediaPath,
                fit: BoxFit.cover,
              ),
            ),
          SafeArea(
            bottom: false,
            child: TabBarView(
              controller: _tab,
              children: [
                _buildMain(context, provider, s, ac),
                _buildSteering(context, provider, s, ac),
                _buildAssign(context, provider, s, ac),
                _buildColors(context, provider, s),
                const AddonManagerTab(),
                _buildMembership(context, provider, s, ac),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSnapshotSelector(
    BuildContext context,
    SettingsProvider provider,
    AppSettings s,
    Color ac,
    Color headerTextColor,
    bool hasBgMedia,
  ) {
    final List<SettingsSnapshot> snaps = provider.snapshots;
    final String? validSelectedId = snaps.any((e) => e.id == provider.activeSnapshotId)
        ? provider.activeSnapshotId
        : null;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          height: 34,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: (hasBgMedia ? Colors.black : s.backgroundColor)
                .withValues(alpha: 0.45),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: ac.withValues(alpha: 0.45)),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: validSelectedId,
              hint: Text(
                AppTranslations.getText('snapshots_placeholder'),
                style: TextStyle(
                  color: headerTextColor.withValues(alpha: 0.75),
                  fontSize: 12,
                ),
              ),
              dropdownColor: const Color(0xFF14182B),
              iconEnabledColor: ac,
              style: TextStyle(
                color: headerTextColor,
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
              ),
              items: snaps
                  .map(
                    (snap) => DropdownMenuItem<String>(
                      value: snap.id,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 150),
                        child: Text(
                          snap.name,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  )
                  .toList(),
              onChanged: (id) async {
                if (id == null) return;
                await provider.loadSnapshot(id);
                if (!context.mounted) return;
                final loadedName = snaps
                    .firstWhere((e) => e.id == id, orElse: () => snaps.first)
                    .name;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      '${AppTranslations.getText('snapshot_loaded_msg')} $loadedName',
                    ),
                    duration: const Duration(seconds: 2),
                  ),
                );
              },
            ),
          ),
        ),
        const SizedBox(width: 4),
        IconButton(
          icon: Icon(Icons.bookmark_add_outlined, color: ac, size: 20),
          tooltip: AppTranslations.getText('snapshot_save_tooltip'),
          visualDensity: VisualDensity.compact,
          onPressed: () => _onAddSnapshotPressed(context, provider),
        ),
        if (validSelectedId != null)
          IconButton(
            icon: const Icon(
              Icons.delete_outline,
              color: Colors.redAccent,
              size: 19,
            ),
            tooltip: AppTranslations.getText('snapshot_delete_tooltip'),
            visualDensity: VisualDensity.compact,
            onPressed: () async {
              await provider.deleteSnapshot(validSelectedId);
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    AppTranslations.getText('snapshot_deleted_msg'),
                  ),
                  duration: const Duration(seconds: 2),
                ),
              );
            },
          ),
      ],
    );
  }

  Future<void> _onAddSnapshotPressed(
    BuildContext context,
    SettingsProvider provider,
  ) async {
    final monetization = Provider.of<MonetizationProvider>(
      context,
      listen: false,
    );

    if (!monetization.isPro &&
        provider.snapshots.length >= SettingsProvider.maxFreeSnapshots) {
      await monetization.showPaywall(context);
      return;
    }

    final controller = TextEditingController();
    final confirmedName = await showDialog<String>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: const Color(0xFF14182B),
        title: Text(
          AppTranslations.getText('snapshot_new_title'),
          style: const TextStyle(color: Colors.white, fontSize: 16),
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: AppTranslations.getText('snapshot_name_hint'),
            hintStyle: const TextStyle(color: Colors.white38, fontSize: 13),
            helperText: monetization.isPro
                ? null
                : AppTranslations.getText('snapshot_free_limit_note'),
            helperMaxLines: 2,
            helperStyle: const TextStyle(color: Colors.amberAccent, fontSize: 11),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(),
            child: Text(AppTranslations.getText('cancel')),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(dialogCtx).pop(controller.text),
            child: Text(AppTranslations.getText('save')),
          ),
        ],
      ),
    );
    controller.dispose();

    if (confirmedName == null || !context.mounted) return;
    final saved = await provider.saveSnapshot(
      context: context,
      name: confirmedName,
      monetizationProvider: monetization,
    );
    if (saved && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppTranslations.getText('snapshot_saved_msg')),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }






}
