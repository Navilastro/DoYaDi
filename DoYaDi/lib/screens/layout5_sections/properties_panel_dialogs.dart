part of '../custom_layout5_editor_screen.dart';
extension _PropertiesPanelDialogsExt on _PropertiesPanelState {
  void _showAddMacroDialog(Layout5Item item) {
    MacroActionType selectedType = MacroActionType.key;
    double val = 1.0;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, set) {
          return AlertDialog(
            backgroundColor: const Color(0xFF12122A),
            title: Text(
              AppTranslations.getText('add_macro_step'),
              style: const TextStyle(color: Colors.white, fontSize: 14),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButton<MacroActionType>(
                  value: selectedType,
                  dropdownColor: const Color(0xFF1A1A3E),
                  style: const TextStyle(color: Colors.white),
                  items: [
                    DropdownMenuItem(
                      value: MacroActionType.key,
                      child: Text(AppTranslations.getText('step_key_press')),
                    ),
                    DropdownMenuItem(
                      value: MacroActionType.gasPct,
                      child: Text(AppTranslations.getText('step_gas_pct')),
                    ),
                    DropdownMenuItem(
                      value: MacroActionType.brakePct,
                      child: Text(AppTranslations.getText('step_brake_pct')),
                    ),
                    DropdownMenuItem(
                      value: MacroActionType.delay,
                      child: Text(AppTranslations.getText('step_delay')),
                    ),
                  ],
                  onChanged: (v) {
                    if (v != null) {
                      set(() {
                        selectedType = v;
                        if (v == MacroActionType.key) {
                          val = 1.0;
                        } else if (v == MacroActionType.gasPct ||
                            v == MacroActionType.brakePct) {
                          val = 0.5;
                        } else if (v == MacroActionType.delay) {
                          val = 100.0;
                        }
                      });
                    }
                  },
                ),
                const SizedBox(height: 12),
                if (selectedType == MacroActionType.key)
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1A1A3E),
                    ),
                    onPressed: () async {
                      final newVal = await showSearchableKeyPicker(
                        ctx,
                        val.toInt(),
                      );
                      if (newVal != null) {
                        set(() => val = newVal.toDouble());
                      }
                    },
                    child: Text(
                      val >= 2000
                          ? '${AppTranslations.getText('macro_prefix')}${val.toInt() - 1999}'
                          : val >= 1000
                              ? KeyboardKeys.appKeyMap.entries
                                  .firstWhere(
                                      (e) => e.value == val.toInt(),
                                      orElse: () => const MapEntry('', 0))
                                  .key
                              : '${AppTranslations.getText('key_prefix')} ${val.toInt()}',
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                if (selectedType == MacroActionType.gasPct ||
                    selectedType == MacroActionType.brakePct)
                  Slider(
                    value: val,
                    min: 0,
                    max: 1,
                    onChanged: (v) => set(() => val = v),
                  ),
                if (selectedType == MacroActionType.delay)
                  Slider(
                    value: val,
                    min: 50,
                    max: 2000,
                    divisions: 39,
                    label: '${val.toInt()} ms',
                    onChanged: (v) => set(() => val = v),
                  ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(
                  AppTranslations.getText('cancel'),
                  style: const TextStyle(color: Colors.white54),
                ),
              ),
              ElevatedButton(
                onPressed: () {
                  final nm = List<MacroAction>.from(item.macro)
                    ..add(MacroAction(type: selectedType, value: val));
                  _update(item.copyWith(macro: nm, mode: ButtonMode.macro));
                  Navigator.pop(ctx);
                },
                child: Text(AppTranslations.getText('add')),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<Color?> _showRgb(BuildContext context, Color initial) async {
    int r = (initial.r * 255.0).round().clamp(0, 255),
        g = (initial.g * 255.0).round().clamp(0, 255),
        b = (initial.b * 255.0).round().clamp(0, 255);
    return showDialog<Color>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, set) {
          final c = Color.fromARGB(255, r, g, b);
          return AlertDialog(
            backgroundColor: const Color(0xFF12122A),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: Text(
              AppTranslations.getText('color'),
              style: const TextStyle(color: Colors.white, fontSize: 15),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  height: 40,
                  decoration: BoxDecoration(
                    color: c,
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                const SizedBox(height: 12),
                for (final ch in [
                  ('R', r, Colors.red),
                  ('G', g, Colors.green),
                  ('B', b, Colors.blue),
                ])
                  Row(
                    children: [
                      SizedBox(
                        width: 16,
                        child: Text(
                          ch.$1,
                          style: TextStyle(
                            color: ch.$3,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Slider(
                          value: ch.$2.toDouble(),
                          min: 0,
                          max: 255,
                          divisions: 255,
                          activeColor: ch.$3,
                          inactiveColor: ch.$3.withValues(alpha: 0.2),
                          onChanged: (v) => set(() {
                            if (ch.$1 == 'R') r = v.round();
                            if (ch.$1 == 'G') g = v.round();
                            if (ch.$1 == 'B') b = v.round();
                          }),
                        ),
                      ),
                      SizedBox(
                        width: 28,
                        child: Text(
                          '${ch.$2}',
                          style: const TextStyle(
                            color: Colors.white54,
                            fontSize: 11,
                          ),
                          textAlign: TextAlign.end,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(
                  AppTranslations.getText('cancel'),
                  style: const TextStyle(color: Colors.white54),
                ),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: c),
                onPressed: () => Navigator.pop(ctx, c),
                child: Text(
                  AppTranslations.getText('apply'),
                  style: const TextStyle(color: Colors.white),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
