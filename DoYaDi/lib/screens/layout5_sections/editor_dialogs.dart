part of '../custom_layout5_editor_screen.dart';
extension _EditorDialogsExt on _CustomLayout5EditorScreenState {
  void _showInfoDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF12122A),
        title: Text(
          AppTranslations.getText('key_mappings'),
          style: const TextStyle(color: Colors.white),
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                AppTranslations.getText('key_mapping_desc'),
                style: const TextStyle(color: Colors.white70, height: 1.5),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              AppTranslations.getText('ok'),
              style: const TextStyle(color: Color(0xFF40E0D0)),
            ),
          ),
        ],
      ),
    );
  }

  void _manageProfiles() {
    final provider = Provider.of<SettingsProvider>(context, listen: false);
    final s = provider.settings;
    final profiles = s.layout5Profiles;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, ss) {
          final ctrl = TextEditingController();
          return AlertDialog(
            backgroundColor: const Color(0xFF12122A),
            title: Text(
              AppTranslations.getText('profiles'),
              style: const TextStyle(color: Colors.white),
            ),
            content: SizedBox(
              width: double.maxFinite,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (profiles.isNotEmpty) ...[
                    DropdownButton<String>(
                      value: s.activeLayout5Profile,
                      dropdownColor: const Color(0xFF1A1A3E),
                      style: const TextStyle(color: Colors.white),
                      isExpanded: true,
                      hint: Text(
                        AppTranslations.getText('select_profile'),
                        style: const TextStyle(color: Colors.white54),
                      ),
                      items: profiles.keys
                          .map(
                            (k) => DropdownMenuItem(value: k, child: Text(k)),
                          )
                          .toList(),
                      onChanged: (val) {
                        if (val != null) {
                          s.activeLayout5Profile = val;
                          s.customLayout5Json = profiles[val];
                          provider.updateSettings(s);
                          setState(() {
                            final list =
                                jsonDecode(s.customLayout5Json!) as List;
                            _items = list
                                .map(
                                  (e) => Layout5Item.fromJson(
                                    e as Map<String, dynamic>,
                                  ),
                                )
                                .toList();
                            _selectedId = null;
                          });
                          Navigator.pop(ctx);
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                  ],
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: ctrl,
                          style: const TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            hintText: AppTranslations.getText(
                              'new_profile_name',
                            ),
                            hintStyle: const TextStyle(color: Colors.white38),
                            isDense: true,
                            enabledBorder: const OutlineInputBorder(
                              borderSide: BorderSide(color: Colors.white24),
                            ),
                            focusedBorder: const OutlineInputBorder(
                              borderSide: BorderSide(color: Color(0xFF40E0D0)),
                            ),
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(
                          Icons.add_circle,
                          color: Color(0xFF40E0D0),
                        ),
                        onPressed: () {
                          if (ctrl.text.isNotEmpty) {
                            final name = ctrl.text;
                            final json = jsonEncode(
                              _items.map((e) => e.toJson()).toList(),
                            );
                            s.layout5Profiles[name] = json;
                            s.activeLayout5Profile = name;
                            s.customLayout5Json = json;
                            provider.updateSettings(s);
                            ss(() {});
                          }
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
            actions: [
              if (s.activeLayout5Profile != null)
                TextButton(
                  onPressed: () {
                    s.layout5Profiles.remove(s.activeLayout5Profile);
                    s.activeLayout5Profile = s.layout5Profiles.isNotEmpty
                        ? s.layout5Profiles.keys.first
                        : null;
                    s.customLayout5Json = s.activeLayout5Profile != null
                        ? s.layout5Profiles[s.activeLayout5Profile!]
                        : null;
                    provider.updateSettings(s);
                    ss(() {});
                  },
                  child: Text(
                    AppTranslations.getText('delete_current_profile'),
                    style: const TextStyle(color: Colors.red),
                  ),
                ),
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(
                  AppTranslations.getText('close'),
                  style: const TextStyle(color: Colors.white54),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  void _save() {
    final provider = Provider.of<SettingsProvider>(context, listen: false);
    final json = jsonEncode(_items.map((e) => e.toJson()).toList());
    provider.saveCustomLayout5(json);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(AppTranslations.getText('layout_saved')),
        duration: const Duration(seconds: 1),
      ),
    );
  }

  void _reset() {
    setState(() {
      _items = defaultLayout5();
      _selectedId = null;
    });
  }

  void _applyTemplate(String json) {
    try {
      final list = jsonDecode(json) as List;
      setState(() {
        _items = list
            .map((e) => Layout5Item.fromJson(e as Map<String, dynamic>))
            .toList();
        _selectedId = null;
      });
    } catch (_) {}
  }

  void _showTemplateDialog() {
    final templates = <Map<String, dynamic>>[
      {
        'name': AppTranslations.getText('tmpl_game'),
        'desc': AppTranslations.getText('tmpl_game_desc'),
        'icon': Icons.sports_esports,
        'color': const Color(0xFF00C853),
        'json': getGameTemplate1(),
      },
      {
        'name': AppTranslations.getText('tmpl_dual_joy'),
        'desc': AppTranslations.getText('tmpl_dual_joy_desc'),
        'icon': Icons.gamepad,
        'color': const Color(0xFF40E0D0),
        'json': getControllerTemplate2(),
      },
      {
        'name': AppTranslations.getText('tmpl_kb_mouse'),
        'desc': AppTranslations.getText('tmpl_kb_mouse_desc'),
        'icon': Icons.keyboard,
        'color': Colors.amber,
        'json': getKeyboardMouseTemplate(),
      },
      {
        'name': AppTranslations.getText('tmpl_full_pad'),
        'desc': AppTranslations.getText('tmpl_full_pad_desc'),
        'icon': Icons.videogame_asset,
        'color': Colors.deepPurpleAccent,
        'json': getFullControllerTemplate(),
      },
      {
        'name': AppTranslations.getText('tmpl_gamer_kb'),
        'desc': AppTranslations.getText('tmpl_gamer_kb_desc'),
        'icon': Icons.keyboard_alt,
        'color': Colors.orangeAccent,
        'json': getGamerKeyboardTemplate(),
      },
    ];

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF12122A),
        title: Text(
          AppTranslations.getText('select_template'),
          style: const TextStyle(color: Colors.white),
        ),
        contentPadding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.separated(
            shrinkWrap: true,
            itemCount: templates.length,
            separatorBuilder: (_, __) =>
                const Divider(color: Colors.white12, height: 1),
            itemBuilder: (ctx, i) {
              final t = templates[i];
              final color = t['color'] as Color;
              return InkWell(
                onTap: () {
                  Navigator.pop(ctx);
                  _applyTemplate(t['json'] as String);
                },
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 10,
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: color.withValues(alpha: 0.4),
                          ),
                        ),
                        child: Icon(
                          t['icon'] as IconData,
                          color: color,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              t['name'] as String,
                              style: TextStyle(
                                color: color,
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              t['desc'] as String,
                              style: const TextStyle(
                                color: Colors.white38,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(
                        Icons.chevron_right,
                        color: Colors.white24,
                        size: 18,
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              AppTranslations.getText('cancel'),
              style: const TextStyle(color: Colors.white54),
            ),
          ),
        ],
      ),
    );
  }

  bool get _isRightAnalogSensorControlled {
    final s = Provider.of<SettingsProvider>(context, listen: false).settings;
    if (s.gyroLookEnabled) return true; // Global gyroLook takes over right analog
    
    try {
      final leftJoy = _items.firstWhere((e) => e.type == Layout5ItemType.leftJoystick);
      return leftJoy.gyroToRightAnalogMode != 0;
    } catch (_) {
      return false;
    }
  }

  bool get _hasLeftJoystick => _items.any((e) => e.type == Layout5ItemType.leftJoystick);
  bool get _hasRightJoystick => _isRightAnalogSensorControlled || _items.any((e) => e.type == Layout5ItemType.rightJoystick);
  bool get _hasGasController => _items.any(
      (e) => e.type == Layout5ItemType.gasBar || e.type == Layout5ItemType.gasPedalIcon);
  bool get _hasBrakeController => _items.any(
      (e) => e.type == Layout5ItemType.brakeBar || e.type == Layout5ItemType.brakePedalIcon);
  bool get _hasClutchController => _isRightAnalogSensorControlled || _items.any(
      (e) => e.type == Layout5ItemType.clutchBar || e.type == Layout5ItemType.clutchIcon);
  bool get _hasHandbrakeController => _isRightAnalogSensorControlled || _items.any(
      (e) => e.type == Layout5ItemType.handbrakeButton || e.type == Layout5ItemType.handbrakeBar || e.type == Layout5ItemType.handbrakeIcon);
  bool get _hasSteeringWheelIcon => _items.any((e) => e.type == Layout5ItemType.steeringWheelIcon);
  bool get _hasSteeringBar => _items.any((e) => e.type == Layout5ItemType.steeringBar);
  void _showConstraintWarning(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: Colors.orangeAccent,
        duration: const Duration(seconds: 3),
      ),
    );
  }
}
