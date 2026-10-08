import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/layout5_item.dart';

import '../providers/settings_provider.dart';
import '../core/widgets/searchable_key_picker.dart';
import '../core/utils/keyboard_keys.dart';
import '../widgets/joystick_widget.dart';
import '../widgets/driving_painters.dart';
import '../core/utils/app_translations.dart';
import '../core/utils/template_profiles.dart';
import '../widgets/dynamic_steering_painter.dart';
import '../core/sensor_manager.dart';

part 'layout5_sections/editor_dialogs.dart';
part 'layout5_sections/editor_items.dart';
part 'layout5_sections/editor_canvas.dart';
part 'layout5_sections/properties_panel_widgets.dart';
part 'layout5_sections/properties_panel_dialogs.dart';

class CustomLayout5EditorScreen extends StatefulWidget {
  const CustomLayout5EditorScreen({super.key});
  @override
  State<CustomLayout5EditorScreen> createState() =>
      _CustomLayout5EditorScreenState();
}

class _CustomLayout5EditorScreenState extends State<CustomLayout5EditorScreen> {
  List<Layout5Item> _items = [];
  bool _editMode = false;
  bool _removeMode = false;
  String? _selectedId;
  bool _isDragging = false;

  double _initialScaleW = 1.0;
  double _initialScaleH = 1.0;
  double _initialRotation = 0.0;

  @override
  void initState() {
    super.initState();
    final provider = Provider.of<SettingsProvider>(context, listen: false);
    final json = provider.settings.customLayout5Json;
    if (json != null && json.isNotEmpty) {
      try {
        final list = jsonDecode(json) as List;
        _items = list
            .map((e) => Layout5Item.fromJson(e as Map<String, dynamic>))
            .toList();
      } catch (_) {
        _items = defaultLayout5();
      }
    } else {
      _items = defaultLayout5();
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final s = Provider.of<SettingsProvider>(context).settings;
    return Scaffold(
      backgroundColor: const Color(0xFF050510),
      body: Stack(
        children: [
          // ── Canvas ──────────────────────────────────────────────────────
          Positioned.fill(
            child: GestureDetector(
              onTap: () => setState(() {
                _selectedId = null;
                _removeMode = false;
              }),
              child: Container(color: const Color(0xFF080820)),
            ),
          ),

          // ── Items ────────────────────────────────────────────────────────
          ..._items.map((item) => _buildItem(item, size)),

          // ── Top Bar ─────────────────────────────────────────────────────
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Stack(
              children: [
                Positioned.fill(
                  child: IgnorePointer(child: Container(color: Colors.black54)),
                ),
                SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _topBtn(
                          AppTranslations.getText('profiles'),
                          Icons.folder,
                          false,
                          _manageProfiles,
                          color: Colors.blueAccent,
                        ),
                        const SizedBox(width: 8),
                        _topBtn(
                          AppTranslations.getText('templates'),
                          Icons.dashboard_customize,
                          false,
                          _showTemplateDialog,
                          color: Colors.deepPurpleAccent,
                        ),
                        const SizedBox(width: 8),
                        _topBtn(
                          AppTranslations.getText('edit'),
                          Icons.edit,
                          _editMode,
                          () {
                            setState(() {
                              _editMode = !_editMode;
                              _removeMode = false;
                            });
                          },
                        ),
                        const SizedBox(width: 8),
                        _topBtn(
                          AppTranslations.getText('save'),
                          Icons.save,
                          false,
                          _save,
                          color: const Color(0xFF00C853),
                        ),
                        const SizedBox(width: 8),
                        _topBtn(
                          AppTranslations.getText('reset'),
                          Icons.refresh,
                          false,
                          _reset,
                          color: Colors.orange,
                        ),
                        const SizedBox(width: 8),
                        if (s.gyroCenterMode == 2) ...[
                          _topBtn(
                            'Sıfırla',
                            Icons.center_focus_strong,
                            false,
                            () {
                              SensorManager().recenterGyro();
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Sensör merkezi sıfırlandı.', style: TextStyle(color: Colors.white))),
                              );
                            },
                            color: Colors.pinkAccent,
                          ),
                          const SizedBox(width: 8),
                        ],
                        IconButton(
                          icon: const Icon(
                            Icons.info_outline,
                            color: Colors.white70,
                          ),
                          onPressed: _showInfoDialog,
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.white70),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ── Edit toolbar ─────────────────────────────────────────────────
          if (_editMode)
            Positioned(
              top: 70,
              left: 0,
              right: 0,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: IgnorePointer(
                      child: Container(color: Colors.black45),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    child: Row(
                      children: [
                        // Ekle
                        _addMenuButton(),
                        const SizedBox(width: 8),
                        // Kaldır
                        _topBtn(
                          AppTranslations.getText('remove'),
                          Icons.remove_circle,
                          _removeMode,
                          () {
                            setState(() => _removeMode = !_removeMode);
                          },
                          color: Colors.red,
                        ),
                        const Spacer(),
                        if (_selected != null)
                          Text(
                            '${AppTranslations.getText('selected')}: ${_selected!.id.split('_').first}',
                            style: const TextStyle(
                              color: Colors.white54,
                              fontSize: 12,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

          // ── Properties panel ─────────────────────────────────────────────
          if (_editMode && _selected != null)
            Positioned(
              right: 0,
              top: 120,
              bottom: 0,
              width: 220,
              child: AnimatedOpacity(
                opacity: _isDragging ? 0.3 : 1.0,
                duration: const Duration(milliseconds: 200),
                child: _PropertiesPanel(
                  item: _selected!,
                  onChanged: _updateItem,
                ),
              ),
            ),
        ],
      ),
    );
  }
  }

// ─────────────────────────────────────────────
// Properties Panel
// ─────────────────────────────────────────────
class _PropertiesPanel extends StatefulWidget {
  final Layout5Item item;
  final void Function(Layout5Item) onChanged;
  const _PropertiesPanel({required this.item, required this.onChanged});

  @override
  State<_PropertiesPanel> createState() => _PropertiesPanelState();
}

class _PropertiesPanelState extends State<_PropertiesPanel> {
  late TextEditingController _labelCtrl;
  late TextEditingController _zIndexCtrl;
  bool _lockAspectRatio = false;
  double _currentRatio = 1.0;
  bool _showSwipeSettings = false;

  @override
  void initState() {
    super.initState();
    _labelCtrl = TextEditingController(text: widget.item.label ?? '');
    _zIndexCtrl = TextEditingController(text: widget.item.zIndex.toString());
  }

  @override
  void didUpdateWidget(covariant _PropertiesPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.item.id != widget.item.id) {
      _labelCtrl.text = widget.item.label ?? '';
      _zIndexCtrl.text = widget.item.zIndex.toString();
      _lockAspectRatio = false;
      _currentRatio = 1.0;
      _showSwipeSettings = false;
    }
  }

  @override
  void dispose() {
    _labelCtrl.dispose();
    _zIndexCtrl.dispose();
    super.dispose();
  }

  void _update(Layout5Item updated) => widget.onChanged(updated);

  bool get _isButton =>
      widget.item.type == Layout5ItemType.buttonSquare ||
      widget.item.type == Layout5ItemType.buttonSoft ||
      widget.item.type == Layout5ItemType.buttonCircle;

  bool get _isBar =>
      widget.item.type == Layout5ItemType.gasBar ||
      widget.item.type == Layout5ItemType.brakeBar ||
      widget.item.type == Layout5ItemType.clutchBar ||
      widget.item.type == Layout5ItemType.handbrakeBar;

  bool get _isJoystick =>
      widget.item.type == Layout5ItemType.leftJoystick ||
      widget.item.type == Layout5ItemType.rightJoystick;

  bool get _isIcon =>
      widget.item.type == Layout5ItemType.gasPedalIcon ||
      widget.item.type == Layout5ItemType.brakePedalIcon;

  @override
  Widget build(BuildContext context) {
    if (_showSwipeSettings) {
      return _buildSwipeSettingsView(context, widget.item);
    }
    final item = widget.item;
    return Container(
      color: const Color(0xFF0D0D2A),
      child: ListView(
        padding: const EdgeInsets.all(10),
        children: [
          Text(
            AppTranslations.getText('properties'),
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 12,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 8),

          // ── En-Boy Oranı Kilidi ──
          if (!_isJoystick && !_isIcon) ...[
            Row(
              children: [
                SizedBox(
                  width: 20,
                  height: 20,
                  child: Checkbox(
                    value: _lockAspectRatio,
                    activeColor: const Color(0xFF40E0D0),
                    side: const BorderSide(color: Colors.white38),
                    onChanged: (v) {
                      setState(() {
                        _lockAspectRatio = v ?? false;
                        if (_lockAspectRatio && item.height > 0) {
                          _currentRatio = item.width / item.height;
                        }
                      });
                    },
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  AppTranslations.getText('width-height_ratio-lock'),
                  style: TextStyle(color: Colors.white54, fontSize: 11),
                ),
              ],
            ),
            const SizedBox(height: 4),
          ],

          // ── Boyut Slider'ları ──
          if (_isJoystick || _isIcon) ...[
            _label(AppTranslations.getText('size')),
            _sizeSlider(
              item.width,
              0.05,
              0.95,
              (v) {
                // Determine physical screen aspect ratio to make it a perfect square
                final size = MediaQuery.of(context).size;
                final screenRatio = size.width / size.height;
                _update(item.copyWith(width: v, height: v * screenRatio));
              },
            ),
          ] else if (_lockAspectRatio) ...[
            _label(AppTranslations.getText('size')),
            _sizeSlider(
              item.width,
              0.05,
              0.95,
              (v) => _update(item.copyWith(width: v, height: v / _currentRatio)),
            ),
          ] else ...[
            _label(AppTranslations.getText('width')),
            _sizeSlider(
              item.width,
              0.05,
              0.95,
              (v) => _update(item.copyWith(width: v)),
            ),
            _label(AppTranslations.getText('height')),
            _sizeSlider(
              item.height,
              0.05,
              0.95,
              (v) => _update(item.copyWith(height: v)),
            ),
          ],

          // ── D\u00f6nd\u00fcrme (Rotation) + Mıknatıs + Sıfırlama ──
          _label(AppTranslations.getText('rotation_deg')),
          Row(
            children: [
              Expanded(
                child: _sizeSlider(
                  item.rotation * 180 / pi,
                  -180.0,
                  180.0,
                  (v) {
                    // Mıknatıs: -5..+5 derece arası → 0
                    final snapped = (v >= -5.0 && v <= 5.0) ? 0.0 : v;
                    _update(item.copyWith(rotation: snapped * pi / 180));
                  },
                ),
              ),
              SizedBox(
                width: 28,
                height: 28,
                child: IconButton(
                  padding: EdgeInsets.zero,
                  iconSize: 18,
                  tooltip: AppTranslations.getText('rotation_reset'),
                  icon: const Icon(Icons.refresh, color: Color(0xFF40E0D0)),
                  onPressed: () => _update(item.copyWith(rotation: 0.0)),
                ),
              ),
            ],
          ),
          
          const Divider(color: Colors.white12),
          
          // ── Z-Index (Katman Sırası) ──
          _label(AppTranslations.getText('z_index')),
          TextField(
            controller: _zIndexCtrl,
            style: const TextStyle(color: Colors.white, fontSize: 13),
            keyboardType: const TextInputType.numberWithOptions(signed: true),
            decoration: const InputDecoration(
              isDense: true,
              filled: true,
              fillColor: Color(0xFF1A1A3E),
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.symmetric(
                horizontal: 8,
                vertical: 6,
              ),
            ),
            onChanged: (v) {
              final parsed = int.tryParse(v);
              if (parsed != null) {
                _update(item.copyWith(zIndex: parsed));
              }
            },
          ),

          // ── Joystick Hassasiyet (Sensitivity) ──
          if (_isJoystick) ...[
            const Divider(color: Colors.white12),

            // Joystick Modu Seçici (Global — sol/sağ ortak)
            _label(AppTranslations.getText('joystick_mode')),
            Builder(
              builder: (ctx) {
                final provider = Provider.of<SettingsProvider>(ctx, listen: false);
                final currentMode = provider.settings.joystickMode.clamp(0, 3);
                return DropdownButton<int>(
                  value: currentMode,
                  dropdownColor: const Color(0xFF1A1A3E),
                  isExpanded: true,
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                  items: [
                    DropdownMenuItem(
                      value: 0,
                      child: Text(
                        AppTranslations.getText('joystick_mode_fixed'),
                        style: const TextStyle(color: Colors.white),
                      ),
                    ),
                    DropdownMenuItem(
                      value: 1,
                      child: Text(
                        AppTranslations.getText('joystick_mode_floating'),
                        style: const TextStyle(color: Colors.white),
                      ),
                    ),
                    DropdownMenuItem(
                      value: 2,
                      child: Text(
                        AppTranslations.getText('joystick_mode_spawn'),
                        style: const TextStyle(color: Colors.white),
                      ),
                    ),
                    DropdownMenuItem(
                      value: 3,
                      child: Text(
                        AppTranslations.getText('joystick_mode_floating_spawn'),
                        style: const TextStyle(color: Colors.white),
                      ),
                    ),
                  ],
                  onChanged: (v) {
                    if (v != null) {
                      provider.settings.joystickMode = v;
                      provider.saveSettings();
                      setState(() {});
                    }
                  },
                );
              },
            ),
            const SizedBox(height: 4),

            // Hassasiyet (öğe bazında, sol/sağ ayrı)
            _label(AppTranslations.getText('sensivity')),
            Row(
              children: [
                Expanded(
                  child: Slider(
                    value: item.sensitivity.clamp(0.5, 3.0),
                    min: 0.5,
                    max: 3.0,
                    divisions: 25,
                    activeColor: const Color(0xFF40E0D0),
                    inactiveColor: Colors.white12,
                    onChanged: (v) => _update(item.copyWith(sensitivity: v)),
                  ),
                ),
                Text(
                  item.sensitivity.toStringAsFixed(1),
                  style: const TextStyle(color: Colors.white54, fontSize: 11),
                ),
              ],
            ),
            
            if (item.type == Layout5ItemType.leftJoystick) ...[
              const SizedBox(height: 8),
              _label(AppTranslations.getText('gyro_to_right_analog')),
              Container(
                height: 36,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                decoration: BoxDecoration(
                  color: Colors.white12,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<int>(
                    value: item.gyroToRightAnalogMode,
                    dropdownColor: const Color(0xFF1A1A3E),
                    isExpanded: true,
                    icon: const Icon(Icons.arrow_drop_down, color: Colors.white54, size: 20),
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                    onChanged: (v) {
                      if (v != null) _update(item.copyWith(gyroToRightAnalogMode: v));
                    },
                    items: const [
                      DropdownMenuItem(value: 0, child: Text('Kapalı')),
                      DropdownMenuItem(value: 1, child: Text('Normal (Mutlak)')),
                      DropdownMenuItem(value: 2, child: Text('FPS Modu (Sürüklenmeli)')),
                      DropdownMenuItem(value: 3, child: Text('Sürücü Modu (Kafadan Bakış)')),
                    ],
                  ),
                ),
              ),
              if (item.gyroToRightAnalogMode != 0) ...[
                const SizedBox(height: 8),
                _label('Gyro Hassasiyeti'),
                Row(
                  children: [
                    Expanded(
                      child: Slider(
                        value: item.gyroRightAnalogSensitivity.clamp(0.1, 10.0),
                        min: 0.1,
                        max: 10.0,
                        activeColor: const Color(0xFF40E0D0),
                        inactiveColor: Colors.white12,
                        onChanged: (v) => _update(item.copyWith(gyroRightAnalogSensitivity: v)),
                      ),
                    ),
                    Text(
                      item.gyroRightAnalogSensitivity.toStringAsFixed(2),
                      style: const TextStyle(color: Colors.white54, fontSize: 11),
                    ),
                    IconButton(
                      icon: const Icon(Icons.refresh, color: Colors.white54, size: 16),
                      onPressed: () => _update(item.copyWith(gyroRightAnalogSensitivity: 1.0)),
                      constraints: const BoxConstraints(),
                      padding: const EdgeInsets.only(left: 8),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                _label('Ölü Alan (Derece)'),
                Row(
                  children: [
                    Expanded(
                      child: Slider(
                        value: item.gyroRightAnalogDeadzone.clamp(0.0, 20.0),
                        min: 0.0,
                        max: 20.0,
                        activeColor: const Color(0xFF40E0D0),
                        inactiveColor: Colors.white12,
                        onChanged: (v) => _update(item.copyWith(gyroRightAnalogDeadzone: v)),
                      ),
                    ),
                    Text(
                      '${item.gyroRightAnalogDeadzone.toStringAsFixed(1)}°',
                      style: const TextStyle(color: Colors.white54, fontSize: 11),
                    ),
                    IconButton(
                      icon: const Icon(Icons.refresh, color: Colors.white54, size: 16),
                      onPressed: () => _update(item.copyWith(gyroRightAnalogDeadzone: 7.0)),
                      constraints: const BoxConstraints(),
                      padding: const EdgeInsets.only(left: 8),
                    ),
                  ],
                ),
              ],
            ],
          ],

          if (item.type == Layout5ItemType.touchpad) ...[
            const SizedBox(height: 8),
            _label('Sensörü Fareye Çevir (Gyro-to-Mouse)'),
            Container(
              height: 36,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              decoration: BoxDecoration(
                color: Colors.white12,
                borderRadius: BorderRadius.circular(4),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<int>(
                  value: item.gyroToMouseMode,
                  dropdownColor: const Color(0xFF1A1A3E),
                  isExpanded: true,
                  icon: const Icon(Icons.arrow_drop_down, color: Colors.white54, size: 20),
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                  onChanged: (v) {
                    if (v != null) _update(item.copyWith(gyroToMouseMode: v));
                  },
                  items: const [
                    DropdownMenuItem(value: 0, child: Text('Kapalı')),
                    DropdownMenuItem(value: 1, child: Text('Normal (Mutlak)')),
                    DropdownMenuItem(value: 2, child: Text('FPS Modu (Hız/Sürüklenmeli)')),
                    DropdownMenuItem(value: 3, child: Text('Sürücü Modu (Kafadan Bakış)')),
                  ],
                ),
              ),
            ),
            if (item.gyroToMouseMode != 0) ...[
              const SizedBox(height: 8),
              _label('Fare Gyro Hassasiyeti'),
              Row(
                children: [
                  Expanded(
                    child: Slider(
                      value: item.gyroMouseSensitivity.clamp(0.1, 10.0),
                      min: 0.1,
                      max: 10.0,
                      activeColor: const Color(0xFF40E0D0),
                      inactiveColor: Colors.white12,
                      onChanged: (v) => _update(item.copyWith(gyroMouseSensitivity: v)),
                    ),
                  ),
                  Text(
                    item.gyroMouseSensitivity.toStringAsFixed(2),
                    style: const TextStyle(color: Colors.white54, fontSize: 11),
                  ),
                  IconButton(
                    icon: const Icon(Icons.refresh, color: Colors.white54, size: 16),
                    onPressed: () => _update(item.copyWith(gyroMouseSensitivity: 1.0)),
                    constraints: const BoxConstraints(),
                    padding: const EdgeInsets.only(left: 8),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              _label('Fare Ölü Alan (Derece)'),
              Row(
                children: [
                  Expanded(
                    child: Slider(
                      value: item.gyroMouseDeadzone.clamp(0.0, 20.0),
                      min: 0.0,
                      max: 20.0,
                      activeColor: const Color(0xFF40E0D0),
                      inactiveColor: Colors.white12,
                      onChanged: (v) => _update(item.copyWith(gyroMouseDeadzone: v)),
                    ),
                  ),
                  Text(
                    '${item.gyroMouseDeadzone.toStringAsFixed(1)}°',
                    style: const TextStyle(color: Colors.white54, fontSize: 11),
                  ),
                  IconButton(
                    icon: const Icon(Icons.refresh, color: Colors.white54, size: 16),
                    onPressed: () => _update(item.copyWith(gyroMouseDeadzone: 7.0)),
                    constraints: const BoxConstraints(),
                    padding: const EdgeInsets.only(left: 8),
                  ),
                ],
              ),
            ],
          ],

          const Divider(color: Colors.white12),

          // Arka plan rengi
          _label(AppTranslations.getText('bg_color')),
          _colorPicker(item.bgColor, (c) => _update(item.copyWith(bgColor: c))),
          const SizedBox(height: 6),

          // Haptik geri bildirim switch'i
          const Divider(color: Colors.white12),
          Row(
            children: [
              Expanded(
                child: Text(
                  AppTranslations.getText('haptic_add'),
                  style: const TextStyle(color: Colors.white54, fontSize: 11),
                ),
              ),
              SizedBox(
                height: 28,
                child: Switch(
                  value: item.enableHaptic,
                  activeThumbColor: const Color(0xFF40E0D0),
                  onChanged: (v) => _update(item.copyWith(enableHaptic: v)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          if (item.enableHaptic) ...[
            Row(
              children: [
                Text(
                  AppTranslations.getText('haptic_type'),
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
                const SizedBox(width: 8),
                DropdownButton<int?>(
                  value: item.customHapticType,
                  dropdownColor: const Color(0xFF1A1A3E),
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                  items: [
                    DropdownMenuItem(
                      value: null,
                      child: Text(AppTranslations.getText('use_global_setting')),
                    ),
                    DropdownMenuItem(
                      value: 0,
                      child: Text(AppTranslations.getText('haptic_type_light')),
                    ),
                    DropdownMenuItem(
                      value: 1,
                      child: Text(AppTranslations.getText('haptic_type_medium')),
                    ),
                    DropdownMenuItem(
                      value: 2,
                      child: Text(AppTranslations.getText('haptic_type_heavy')),
                    ),
                    DropdownMenuItem(
                      value: 3,
                      child: Text(AppTranslations.getText('haptic_type_selection')),
                    ),
                    DropdownMenuItem(
                      value: 4,
                      child: Text(AppTranslations.getText('haptic_type_vibrate')),
                    ),
                  ],
                  onChanged: (v) {
                    _update(
                      item.copyWith(
                        customHapticType: v,
                        clearCustomHapticType: v == null,
                      ),
                    );
                  },
                ),
              ],
            ),
            Row(
              children: [
                Text(
                  AppTranslations.getText('haptic_trigger'),
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
                const SizedBox(width: 8),
                DropdownButton<int?>(
                  value: item.customHapticTrigger,
                  dropdownColor: const Color(0xFF1A1A3E),
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                  items: [
                    DropdownMenuItem(
                      value: null,
                      child: Text(AppTranslations.getText('use_global_setting')),
                    ),
                    DropdownMenuItem(
                      value: 0,
                      child: Text(AppTranslations.getText('haptic_trigger_down')),
                    ),
                    DropdownMenuItem(
                      value: 1,
                      child: Text(AppTranslations.getText('haptic_trigger_up')),
                    ),
                    DropdownMenuItem(
                      value: 2,
                      child: Text(AppTranslations.getText('haptic_trigger_held')),
                    ),
                    DropdownMenuItem(
                      value: 3,
                      child: Text(AppTranslations.getText('haptic_trigger_active')),
                    ),
                  ],
                  onChanged: (v) {
                    _update(
                      item.copyWith(
                        customHapticTrigger: v,
                        clearCustomHapticTrigger: v == null,
                      ),
                    );
                  },
                ),
              ],
            ),
          ],

          if (_isButton) ...[
            _label(AppTranslations.getText('text_color')),
            _colorPicker(
              item.textColor,
              (c) => _update(item.copyWith(textColor: c)),
            ),
            const SizedBox(height: 6),

            _label(AppTranslations.getText('button_text')),
            TextField(
              controller: _labelCtrl,
              style: const TextStyle(color: Colors.white, fontSize: 13),
              decoration: InputDecoration(
                hintText: AppTranslations.getText('empty_default'),
                hintStyle: const TextStyle(color: Colors.white30),
                isDense: true,
                filled: true,
                fillColor: const Color(0xFF1A1A3E),
                border: const OutlineInputBorder(),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 6,
                ),
              ),
              onChanged: (v) => _update(
                item.copyWith(
                  label: v.isEmpty ? null : v,
                  clearLabel: v.isEmpty,
                ),
              ),
            ),
            const Divider(color: Colors.white12),

            _label(AppTranslations.getText('mode')),
            _modeSelector(item),
          ],
          
          if (_isBar) ...[
            const Divider(color: Colors.white12),
            ElevatedButton.icon(
              onPressed: () {
                setState(() {
                  _showSwipeSettings = true;
                });
              },
              icon: const Icon(Icons.touch_app, size: 16),
              label: const Text('Bar Tuşlarını Ayarla'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1A1A3E),
                foregroundColor: const Color(0xFF40E0D0),
                alignment: Alignment.centerLeft,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
            ),
          ],
        ],
      ),
    );
  }

}
