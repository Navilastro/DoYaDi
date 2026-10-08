part of '../custom_layout5_editor_screen.dart';
extension _PropertiesPanelWidgetsExt on _PropertiesPanelState {
  Widget _label(String t) => Padding(
    padding: const EdgeInsets.only(bottom: 2, top: 6),
    child: Text(t, style: const TextStyle(color: Colors.white54, fontSize: 11)),
  );

  Widget _sizeSlider(
    double value,
    double min,
    double max,
    ValueChanged<double> onChanged,
  ) {
    return Slider(
      value: value.clamp(min, max),
      min: min,
      max: max,
      activeColor: const Color(0xFF40E0D0),
      inactiveColor: Colors.white12,
      onChanged: onChanged,
    );
  }

  Widget _colorPicker(Color current, void Function(Color) onChanged) {
    return Row(
      children: [
        GestureDetector(
          onTap: () async {
            final c = await _showRgb(context, current);
            if (c != null) onChanged(c);
          },
          child: Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: current,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: Colors.white30),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          'R:${(current.r * 255.0).round().clamp(0, 255)} G:${(current.g * 255.0).round().clamp(0, 255)} B:${(current.b * 255.0).round().clamp(0, 255)}',
          style: const TextStyle(color: Colors.white38, fontSize: 11),
        ),
      ],
    );
  }

  Widget _modeSelector(Layout5Item item) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Mode Seçimi (Radyo Butonları gibi veya Dropdown)
        Row(
          children: [
            Text(
              AppTranslations.getText('action_mode'),
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
            const SizedBox(width: 8),
            DropdownButton<ButtonMode>(
              value: item.mode,
              dropdownColor: const Color(0xFF1A1A3E),
              style: const TextStyle(color: Colors.white, fontSize: 12),
              items: [
                DropdownMenuItem(
                  value: ButtonMode.key,
                  child: Text(AppTranslations.getText('mode_single_key')),
                ),
                DropdownMenuItem(
                  value: ButtonMode.gasPct,
                  child: Text(AppTranslations.getText('mode_fixed_gas')),
                ),
                DropdownMenuItem(
                  value: ButtonMode.brakePct,
                  child: Text(AppTranslations.getText('mode_fixed_brake')),
                ),
                DropdownMenuItem(
                  value: ButtonMode.macro,
                  child: Text(AppTranslations.getText('mode_macro')),
                ),
                DropdownMenuItem(
                  value: ButtonMode.handbrakePct,
                  child: Text(AppTranslations.getText('mode_handbrake_pct')),
                ),
                DropdownMenuItem(
                  value: ButtonMode.clutchPct,
                  child: Text(AppTranslations.getText('mode_clutch_pct')),
                ),
              ],
              onChanged: (v) {
                if (v != null) _update(item.copyWith(mode: v));
              },
            ),
          ],
        ),
        const SizedBox(height: 8),

        if (item.mode == ButtonMode.key)
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    AppTranslations.getText('key_selection'),
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                  const SizedBox(width: 8),
                  TextButton(
                    onPressed: () async {
                      final val = await showSearchableKeyPicker(
                        context,
                        item.keyIndex,
                      );
                      if (val != null) _update(item.copyWith(keyIndex: val));
                    },
                    child: Text(
                      item.keyIndex >= 2000
                          ? '${AppTranslations.getText('macro_prefix')}${item.keyIndex - 1999}'
                          : KeyboardKeys.appKeyMap.entries
                                .firstWhere(
                                  (e) => e.value == item.keyIndex,
                                  orElse: () => MapEntry(
                                    AppTranslations.getText('select_key'),
                                    0,
                                  ),
                                )
                                .key,
                      style: const TextStyle(color: Color(0xFF40E0D0)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Text(
                    AppTranslations.getText('press_mode'),
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                  const SizedBox(width: 8),
                  DropdownButton<int?>(
                    value: item.customPressMode,
                    dropdownColor: const Color(0xFF1A1A3E),
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                    items: [
                      DropdownMenuItem(
                        value: null,
                        child: Text(
                          AppTranslations.getText('press_mode_global'),
                        ),
                      ),
                      DropdownMenuItem(
                        value: 0,
                        child: Text(
                          AppTranslations.getText('press_mode_instant'),
                        ),
                      ),
                      DropdownMenuItem(
                        value: 1,
                        child: Text(
                          AppTranslations.getText('press_mode_duration'),
                        ),
                      ),
                      DropdownMenuItem(
                        value: 2,
                        child: Text(
                          AppTranslations.getText('press_mode_toggle'),
                        ),
                      ),
                      DropdownMenuItem(
                        value: 3,
                        child: Text(AppTranslations.getText('press_mode_fast')),
                      ),
                    ],
                    onChanged: (v) => _update(
                      item.copyWith(
                        customPressMode: v,
                        clearCustomPressMode: v == null,
                      ),
                    ),
                  ),
                ],
              ),
              if (item.customPressMode == 1)
                Row(
                  children: [
                    Text(
                      AppTranslations.getText('duration'),
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                    ),
                    Expanded(
                      child: Slider(
                        value: (item.customPressDurationMs ?? 300).toDouble(),
                        min: 50,
                        max: 10000,
                        divisions: 199,
                        activeColor: const Color(0xFF40E0D0),
                        inactiveColor: Colors.white12,
                        onChanged: (v) => _update(
                          item.copyWith(customPressDurationMs: v.toInt()),
                        ),
                      ),
                    ),
                    Text(
                      '${((item.customPressDurationMs ?? 300) / 1000.0).toStringAsFixed(1)}s',
                      style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
            ],
          ),

        if (item.mode == ButtonMode.gasPct)
          Row(
            children: [
              Text(
                AppTranslations.getText('gas_pct'),
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
              Expanded(
                child: Slider(
                  value: item.modeValue,
                  min: 0,
                  max: 1,
                  activeColor: const Color(0xFF00C853),
                  inactiveColor: Colors.white12,
                  onChanged: (v) => _update(item.copyWith(modeValue: v)),
                ),
              ),
              Text(
                '${(item.modeValue * 100).round()}%',
                style: const TextStyle(color: Colors.white54, fontSize: 11),
              ),
            ],
          ),

        if (item.mode == ButtonMode.brakePct)
          Row(
            children: [
              Text(
                AppTranslations.getText('brake_pct'),
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
              Expanded(
                child: Slider(
                  value: item.modeValue,
                  min: 0,
                  max: 1,
                  activeColor: const Color(0xFFD50000),
                  inactiveColor: Colors.white12,
                  onChanged: (v) => _update(item.copyWith(modeValue: v)),
                ),
              ),
              Text(
                '${(item.modeValue * 100).round()}%',
                style: const TextStyle(color: Colors.white54, fontSize: 11),
              ),
            ],
          ),

        if (item.mode == ButtonMode.handbrakePct)
          Row(
            children: [
              Text(
                AppTranslations.getText('mode_handbrake_pct'),
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
              Expanded(
                child: Slider(
                  value: item.modeValue,
                  min: 0,
                  max: 1,
                  activeColor: const Color(0xFFFF9800),
                  inactiveColor: Colors.white12,
                  onChanged: (v) => _update(item.copyWith(modeValue: v)),
                ),
              ),
              Text(
                '${(item.modeValue * 100).round()}%',
                style: const TextStyle(color: Colors.white54, fontSize: 11),
              ),
            ],
          ),

        if (item.mode == ButtonMode.clutchPct)
          Row(
            children: [
              Text(
                AppTranslations.getText('mode_clutch_pct'),
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
              Expanded(
                child: Slider(
                  value: item.modeValue,
                  min: 0,
                  max: 1,
                  activeColor: const Color(0xFF2196F3),
                  inactiveColor: Colors.white12,
                  onChanged: (v) => _update(item.copyWith(modeValue: v)),
                ),
              ),
              Text(
                '${(item.modeValue * 100).round()}%',
                style: const TextStyle(color: Colors.white54, fontSize: 11),
              ),
            ],
          ),

        if (item.mode == ButtonMode.macro)
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                AppTranslations.getText('macro_steps'),
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
              const SizedBox(height: 4),
              if (item.macro.isEmpty)
                Text(
                  AppTranslations.getText('no_macro_steps_yet'),
                  style: const TextStyle(color: Colors.white38, fontSize: 11),
                ),
              ...item.macro.asMap().entries.map((e) {
                final idx = e.key;
                final act = e.value;
                String txt = '';
                if (act.type == MacroActionType.key) {
                  txt =
                      '${AppTranslations.getText('key_prefix')} ${act.value.toInt()}';
                } else if (act.type == MacroActionType.gasPct) {
                  txt =
                      '${AppTranslations.getText('gas_pct')} ${(act.value * 100).toInt()}%';
                } else if (act.type == MacroActionType.brakePct) {
                  txt =
                      '${AppTranslations.getText('brake_pct')} ${(act.value * 100).toInt()}%';
                } else if (act.type == MacroActionType.delay) {
                  txt =
                      '${AppTranslations.getText('step_delay')} ${act.value.toInt()} ms';
                }

                return Row(
                  children: [
                    Text(
                      '${idx + 1}. $txt',
                      style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 11,
                      ),
                    ),
                    const Spacer(),
                    GestureDetector(
                      onTap: () {
                        final nm = List<MacroAction>.from(item.macro)
                          ..removeAt(idx);
                        _update(item.copyWith(macro: nm));
                      },
                      child: const Icon(
                        Icons.close,
                        color: Colors.red,
                        size: 14,
                      ),
                    ),
                  ],
                );
              }),
              const SizedBox(height: 8),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(
                    0xFF40E0D0,
                  ).withValues(alpha: 0.2),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 0,
                  ),
                  minimumSize: const Size(0, 30),
                ),
                onPressed: () => _showAddMacroDialog(item),
                child: Text(
                  AppTranslations.getText('add_step'),
                  style: const TextStyle(
                    color: Color(0xFF40E0D0),
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ),      ],
    );
  }

  Widget _buildSwipeSettingsView(BuildContext context, Layout5Item item) {
    return Container(
      color: const Color(0xFF0D0D2A),
      child: ListView(
        padding: const EdgeInsets.all(10),
        children: [
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white70),
                onPressed: () {
                  setState(() {
                    _showSwipeSettings = false;
                  });
                },
              ),
              const Expanded(
                child: Text(
                  'Bar Tuşları / Kaydırma',
                  style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const Divider(color: Colors.white24),
          const SizedBox(height: 10),
          _label('Dokunma (Tap) Tuşu'),
          _keyDropdown(item.tapKey ?? 0, (v) {
            item.tapKey = v == 0 ? null : v;
            _update(item);
          }),
          
          _label('Yukarı Kaydırma'),
          _keyDropdown(item.customSwipeKeys?[1] ?? 0, (v) => _updateSwipeKey(item, 1, v)),
          
          _label('Aşağı Kaydırma'),
          _keyDropdown(item.customSwipeKeys?[2] ?? 0, (v) => _updateSwipeKey(item, 2, v)),
          
          _label('Sola Kaydırma'),
          _keyDropdown(item.customSwipeKeys?[3] ?? 0, (v) => _updateSwipeKey(item, 3, v)),
          
          _label('Sağa Kaydırma'),
          _keyDropdown(item.customSwipeKeys?[4] ?? 0, (v) => _updateSwipeKey(item, 4, v)),
          
          _label('Sol Yukarı Kaydırma'),
          _keyDropdown(item.customSwipeKeys?[5] ?? 0, (v) => _updateSwipeKey(item, 5, v)),
          
          _label('Sağ Yukarı Kaydırma'),
          _keyDropdown(item.customSwipeKeys?[6] ?? 0, (v) => _updateSwipeKey(item, 6, v)),
          
          _label('Sol Aşağı Kaydırma'),
          _keyDropdown(item.customSwipeKeys?[7] ?? 0, (v) => _updateSwipeKey(item, 7, v)),
          
          _label('Sağ Aşağı Kaydırma'),
          _keyDropdown(item.customSwipeKeys?[8] ?? 0, (v) => _updateSwipeKey(item, 8, v)),
        ],
      ),
    );
  }

  Widget _keyDropdown(int value, void Function(int) onChanged) {
    return InkWell(
      onTap: () async {
        final val = await showSearchableKeyPicker(context, value);
        if (val != null) onChanged(val);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A3E),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: Colors.white24),
        ),
        child: Text(
          value == 0
              ? 'Atanmadı'
              : (value >= 2000
                  ? '${AppTranslations.getText('macro_prefix')}${value - 1999}'
                  : KeyboardKeys.appKeyMap.entries
                      .firstWhere(
                        (e) => e.value == value,
                        orElse: () => MapEntry(AppTranslations.getText('select_key'), 0),
                      )
                      .key),
          style: const TextStyle(color: Color(0xFF40E0D0)),
        ),
      ),
    );
  }

  void _updateSwipeKey(Layout5Item item, int dir, int v) {
    if (item.customSwipeKeys == null) {
      item.customSwipeKeys = {};
    }
    if (v == 0) {
      item.customSwipeKeys!.remove(dir);
    } else {
      item.customSwipeKeys![dir] = v;
    }
    if (item.customSwipeKeys!.isEmpty) {
      item.customSwipeKeys = null;
    }
    _update(item);
  }
}
