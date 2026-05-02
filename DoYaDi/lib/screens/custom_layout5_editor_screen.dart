import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/layout5_item.dart';
import '../providers/settings_provider.dart';
import '../widgets/joystick_widget.dart';
import '../widgets/driving_painters.dart';

class CustomLayout5EditorScreen extends StatefulWidget {
  const CustomLayout5EditorScreen({super.key});
  @override
  State<CustomLayout5EditorScreen> createState() => _CustomLayout5EditorScreenState();
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
    if (json != null) {
      try {
        final list = jsonDecode(json) as List;
        _items = list.map((e) => Layout5Item.fromJson(e as Map<String, dynamic>)).toList();
      } catch (_) {
        _items = defaultLayout5();
      }
    } else {
      _items = defaultLayout5();
    }
  }

  void _save() {
    final provider = Provider.of<SettingsProvider>(context, listen: false);
    final json = jsonEncode(_items.map((e) => e.toJson()).toList());
    provider.saveCustomLayout5(json);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Layout kaydedildi'), duration: Duration(seconds: 1)),
    );
  }

  void _reset() {
    setState(() {
      _items = defaultLayout5();
      _selectedId = null;
    });
  }

  bool get _hasGasBar => _items.any((e) => e.type == Layout5ItemType.gasBar);
  bool get _hasBrakeBar => _items.any((e) => e.type == Layout5ItemType.brakeBar);
  bool get _hasLeftJoystick => _items.any((e) => e.type == Layout5ItemType.leftJoystick);
  bool get _hasRightJoystick => _items.any((e) => e.type == Layout5ItemType.rightJoystick);

  void _addItem(Layout5ItemType type) {
    final id = '${type.name}_${DateTime.now().millisecondsSinceEpoch}';
    String? label;
    if (type == Layout5ItemType.buttonSquare ||
        type == Layout5ItemType.buttonSoft ||
        type == Layout5ItemType.buttonCircle) {
      label = null; // default: "$N Buton"
      label = null; // default: "$N Buton"
    }
    setState(() {
      _items.add(Layout5Item(
        id: id,
        type: type,
        left: 0.3,
        top: 0.3,
        width: (type == Layout5ItemType.leftJoystick || type == Layout5ItemType.rightJoystick) ? 0.22 : 0.18,
        height: (type == Layout5ItemType.leftJoystick || type == Layout5ItemType.rightJoystick) ? 0.55 : 0.22,
        label: label,
      ));
      _selectedId = id;
    });
  }

  void _removeItem(String id) {
    setState(() {
      _items.removeWhere((e) => e.id == id);
      if (_selectedId == id) _selectedId = null;
    });
  }

  void _updateItem(Layout5Item updated) {
    setState(() {
      final idx = _items.indexWhere((e) => e.id == updated.id);
      if (idx >= 0) _items[idx] = updated;
    });
  }

  Layout5Item? get _selected =>
      _selectedId == null ? null : _items.cast<Layout5Item?>().firstWhere(
        (e) => e?.id == _selectedId, orElse: () => null);

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return Scaffold(
      backgroundColor: const Color(0xFF050510),
      body: Stack(
        children: [
          // ── Canvas ──────────────────────────────────────────────────────
          Positioned.fill(
            child: GestureDetector(
              onTap: () => setState(() { _selectedId = null; _removeMode = false; }),
              child: Container(color: const Color(0xFF080820)),
            ),
          ),

          // ── Items ────────────────────────────────────────────────────────
          ..._items.map((item) => _buildItem(item, size)),

          // ── Top Bar ─────────────────────────────────────────────────────
          Positioned(
            top: 0, left: 0, right: 0,
            child: Stack(
              children: [
                Positioned.fill(child: IgnorePointer(child: Container(color: Colors.black54))),
                SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _topBtn('Düzenle', Icons.edit, _editMode, () {
                          setState(() { _editMode = !_editMode; _removeMode = false; });
                        }),
                        const SizedBox(width: 12),
                        _topBtn('Kaydet', Icons.save, false, _save,
                            color: const Color(0xFF00C853)),
                        const SizedBox(width: 12),
                        _topBtn('Sıfırla', Icons.refresh, false, _reset,
                            color: Colors.orange),
                        const SizedBox(width: 12),
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
              top: 70, left: 0, right: 0,
              child: Stack(
                children: [
                  Positioned.fill(child: IgnorePointer(child: Container(color: Colors.black45))),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    child: Row(
                      children: [
                        // Ekle
                        _addMenuButton(),
                        const SizedBox(width: 8),
                        // Kaldır
                        _topBtn('Kaldır', Icons.remove_circle, _removeMode, () {
                          setState(() => _removeMode = !_removeMode);
                        }, color: Colors.red),
                        const Spacer(),
                        if (_selected != null)
                          Text('Seçili: ${_selected!.id.split('_').first}',
                              style: const TextStyle(color: Colors.white54, fontSize: 12)),
                      ],
                    ),
                  ),
                ],
              ),
            ),

          // ── Properties panel ─────────────────────────────────────────────
          if (_editMode && _selected != null)
            Positioned(
              right: 0, top: 120, bottom: 0,
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

  Widget _buildItem(Layout5Item item, Size size) {
    final double l = item.left * size.width;
    final double t = item.top * size.height;
    final double w = item.width * size.width;
    final double h = item.height * size.height;
    final bool isSelected = _selectedId == item.id;

    Widget content = _buildItemContent(item, w, h);

    if (_removeMode) {
      content = Stack(
        children: [
          content,
          Positioned.fill(
            child: Container(color: Colors.black45),
          ),
          Positioned(
            top: 4, right: 4,
            child: GestureDetector(
              onTap: () => _removeItem(item.id),
              child: Container(
                width: 28, height: 28,
                decoration: const BoxDecoration(
                  color: Colors.red, shape: BoxShape.circle,
                ),
                child: const Icon(Icons.close, color: Colors.white, size: 18),
              ),
            ),
          ),
        ],
      );
    }

    return Positioned(
      left: l, top: t, width: w, height: h,
      child: GestureDetector(
        onTap: _editMode ? () => setState(() => _selectedId = item.id) : null,
        onScaleStart: _editMode ? (details) {
          setState(() {
            _isDragging = true;
            _selectedId = item.id;
            final idx = _items.indexWhere((e) => e.id == item.id);
            if (idx >= 0) {
              _initialScaleW = _items[idx].width;
              _initialScaleH = _items[idx].height;
              _initialRotation = _items[idx].rotation;
            }
          });
        } : null,
        onScaleUpdate: _editMode ? (details) {
          setState(() {
            final idx = _items.indexWhere((e) => e.id == item.id);
            if (idx < 0) return;
            
            // Hareket (Pan)
            double newLeft = (_items[idx].left + details.focalPointDelta.dx / size.width).clamp(0.0, 0.95);
            double newTop = (_items[idx].top + details.focalPointDelta.dy / size.height).clamp(0.0, 0.95);
            
            // Boyutlandırma (Aspect Ratio korunarak)
            double newW = (_initialScaleW * details.scale).clamp(0.05, 0.95);
            double newH = (_initialScaleH * details.scale).clamp(0.05, 0.95);
            
            // Joystickler döndürülemesin (yön eksenleri bozulur)
            final isJoystick = _items[idx].type == Layout5ItemType.leftJoystick ||
                               _items[idx].type == Layout5ItemType.rightJoystick;
            double newRot = isJoystick
                ? _initialRotation          // sabit tut
                : _initialRotation + details.rotation;

            _items[idx] = _items[idx].copyWith(
              left: newLeft,
              top: newTop,
              width: newW,
              height: newH,
              rotation: newRot,
            );
          });
        } : null,
        onScaleEnd: _editMode ? (details) {
          setState(() {
            _isDragging = false;
          });
        } : null,
        child: Transform.rotate(
          angle: item.rotation,
          child: Container(
            decoration: isSelected && _editMode
                ? BoxDecoration(border: Border.all(color: Colors.cyan, width: 2))
                : null,
            child: content,
          ),
        ),
      ),
    );
  }

  Widget _buildItemContent(Layout5Item item, double w, double h) {
    switch (item.type) {
      case Layout5ItemType.leftJoystick:
      case Layout5ItemType.rightJoystick:
        return JoystickWidget(
          radius: min(w, h) / 2,
          baseColor: item.bgColor,
          thumbColor: item.textColor,
          onChanged: (_, __) {},
        );
      case Layout5ItemType.gasBar:
        return CustomPaint(
          painter: PedalPainter(
            fillPercentage: 0.4,
            baseColor: const Color(0xFF00C853),
            bgColor: item.bgColor,
            yetsoreColor: const Color(0xFFFFD600),
          ),
        );
      case Layout5ItemType.brakeBar:
        return CustomPaint(
          painter: PedalPainter(
            fillPercentage: 0.4,
            baseColor: const Color(0xFFD50000),
            bgColor: item.bgColor,
            yetsoreColor: const Color(0xFFFFD600),
          ),
        );
      default:
        return _buildButtonContent(item, w, h);
    }
  }

  Widget _buildButtonContent(Layout5Item item, double w, double h) {
    final label = item.label ?? '${_items.indexOf(item) + 1} Buton';
    BorderRadius radius;
    switch (item.type) {
      case Layout5ItemType.buttonSoft:
        radius = BorderRadius.circular(16);
        break;
      case Layout5ItemType.buttonCircle:
        radius = BorderRadius.circular(min(w, h) / 2);
        break;
      default:
        radius = BorderRadius.circular(4);
    }
    return Container(
      decoration: BoxDecoration(
        color: item.bgColor,
        borderRadius: radius,
        border: Border.all(color: item.textColor.withValues(alpha: 0.3)),
      ),
      child: Center(
        child: Text(
          label,
          style: TextStyle(
            color: item.textColor,
            fontSize: min(w, h) * 0.18,
            fontWeight: FontWeight.w600,
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  Widget _addMenuButton() {
    return PopupMenuButton<Layout5ItemType>(
      color: const Color(0xFF1A1A3E),
      itemBuilder: (_) => [
        if (!_hasLeftJoystick)
          const PopupMenuItem(value: Layout5ItemType.leftJoystick, child: Text('Sol Joystick', style: TextStyle(color: Colors.white))),
        if (!_hasRightJoystick)
          const PopupMenuItem(value: Layout5ItemType.rightJoystick, child: Text('Sağ Joystick', style: TextStyle(color: Colors.white))),
        if (!_hasGasBar)
          const PopupMenuItem(value: Layout5ItemType.gasBar, child: Text('Gaz Barı', style: TextStyle(color: Colors.white))),
        if (!_hasBrakeBar)
          const PopupMenuItem(value: Layout5ItemType.brakeBar, child: Text('Fren Barı', style: TextStyle(color: Colors.white))),
        const PopupMenuItem(value: Layout5ItemType.buttonSquare, child: Text('Kare Buton', style: TextStyle(color: Colors.white))),
        const PopupMenuItem(value: Layout5ItemType.buttonSoft, child: Text('Yumuşak Kare', style: TextStyle(color: Colors.white))),
        const PopupMenuItem(value: Layout5ItemType.buttonCircle, child: Text('Yuvarlak Buton', style: TextStyle(color: Colors.white))),
      ],
      onSelected: _addItem,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFF40E0D0).withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFF40E0D0)),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.add, color: Color(0xFF40E0D0), size: 18),
            SizedBox(width: 4),
            Text('Ekle', style: TextStyle(color: Color(0xFF40E0D0), fontSize: 13)),
          ],
        ),
      ),
    );
  }

  Widget _topBtn(String label, IconData icon, bool active, VoidCallback onTap,
      {Color color = const Color(0xFF40E0D0)}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: active ? color.withValues(alpha: 0.25) : Colors.white.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: active ? color : Colors.white24),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: active ? color : Colors.white70, size: 16),
            const SizedBox(width: 4),
            Text(label, style: TextStyle(color: active ? color : Colors.white70, fontSize: 12)),
          ],
        ),
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

  @override
  void initState() {
    super.initState();
    _labelCtrl = TextEditingController(text: widget.item.label ?? '');
  }

  @override
  void didUpdateWidget(covariant _PropertiesPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.item.id != widget.item.id) {
      _labelCtrl.text = widget.item.label ?? '';
    }
  }

  @override
  void dispose() {
    _labelCtrl.dispose();
    super.dispose();
  }

  void _update(Layout5Item updated) => widget.onChanged(updated);

  bool get _isButton => widget.item.type == Layout5ItemType.buttonSquare ||
      widget.item.type == Layout5ItemType.buttonSoft ||
      widget.item.type == Layout5ItemType.buttonCircle;

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    return Container(
      color: const Color(0xFF0D0D2A),
      child: ListView(
        padding: const EdgeInsets.all(10),
        children: [
          const Text('Özellikler', style: TextStyle(color: Colors.white70, fontSize: 12, letterSpacing: 1)),
          const SizedBox(height: 8),

          // Boyut
          _label('Genişlik'),
          _sizeSlider(item.width, 0.05, 0.95, (v) => _update(item.copyWith(width: v))),
          _label('Yükseklik'),
          _sizeSlider(item.height, 0.05, 0.95, (v) => _update(item.copyWith(height: v))),
          _label('Döndürme (Derece)'),
          _sizeSlider(item.rotation * 180 / pi, -180.0, 180.0, (v) => _update(item.copyWith(rotation: v * pi / 180))),

          const Divider(color: Colors.white12),

          // Arka plan rengi
          _label('Arka Plan Rengi'),
          _colorPicker(item.bgColor, (c) => _update(item.copyWith(bgColor: c))),
          const SizedBox(height: 6),

          if (_isButton) ...[
            _label('Yazı Rengi'),
            _colorPicker(item.textColor, (c) => _update(item.copyWith(textColor: c))),
            const SizedBox(height: 6),

            _label('Buton Yazısı'),
            TextField(
              controller: _labelCtrl,
              style: const TextStyle(color: Colors.white, fontSize: 13),
              decoration: const InputDecoration(
                hintText: 'Boş → varsayılan',
                hintStyle: TextStyle(color: Colors.white30),
                isDense: true,
                filled: true,
                fillColor: Color(0xFF1A1A3E),
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              ),
              onChanged: (v) => _update(item.copyWith(label: v.isEmpty ? null : v, clearLabel: v.isEmpty)),
            ),
            const Divider(color: Colors.white12),

            _label('Mod'),
            _modeSelector(item),
          ],
        ],
      ),
    );
  }

  Widget _label(String t) => Padding(
    padding: const EdgeInsets.only(bottom: 2, top: 6),
    child: Text(t, style: const TextStyle(color: Colors.white54, fontSize: 11)),
  );

  Widget _sizeSlider(double value, double min, double max, ValueChanged<double> onChanged) {
    return Slider(
      value: value.clamp(min, max),
      min: min, max: max,
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
            width: 32, height: 32,
            decoration: BoxDecoration(
              color: current,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: Colors.white30),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text('R:${(current.r * 255.0).round().clamp(0, 255)} G:${(current.g * 255.0).round().clamp(0, 255)} B:${(current.b * 255.0).round().clamp(0, 255)}',
            style: const TextStyle(color: Colors.white38, fontSize: 11)),
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
            const Text('Aksiyon Modu:', style: TextStyle(color: Colors.white70, fontSize: 12)),
            const SizedBox(width: 8),
            DropdownButton<ButtonMode>(
              value: item.mode,
              dropdownColor: const Color(0xFF1A1A3E),
              style: const TextStyle(color: Colors.white, fontSize: 12),
              items: const [
                DropdownMenuItem(value: ButtonMode.key, child: Text('Tek Tuş')),
                DropdownMenuItem(value: ButtonMode.gasPct, child: Text('Sabit Gaz')),
                DropdownMenuItem(value: ButtonMode.brakePct, child: Text('Sabit Fren')),
                DropdownMenuItem(value: ButtonMode.macro, child: Text('Makro (Sıralı)')),
              ],
              onChanged: (v) {
                if (v != null) _update(item.copyWith(mode: v));
              },
            ),
          ],
        ),
        const SizedBox(height: 8),

        if (item.mode == ButtonMode.key)
          Row(
            children: [
              const Text('Tuş Seçimi:', style: TextStyle(color: Colors.white70, fontSize: 12)),
              const SizedBox(width: 8),
              DropdownButton<int>(
                value: item.keyIndex,
                dropdownColor: const Color(0xFF1A1A3E),
                style: const TextStyle(color: Colors.white),
                items: List.generate(16, (i) => DropdownMenuItem(
                  value: i + 1,
                  child: Text('Tuş ${i + 1}'),
                )),
                onChanged: (v) {
                  if (v != null) _update(item.copyWith(keyIndex: v));
                },
              ),
            ],
          ),

        if (item.mode == ButtonMode.gasPct)
          Row(
            children: [
              const Text('Gaz %:', style: TextStyle(color: Colors.white70, fontSize: 12)),
              Expanded(
                child: Slider(
                  value: item.modeValue,
                  min: 0, max: 1,
                  activeColor: const Color(0xFF00C853),
                  inactiveColor: Colors.white12,
                  onChanged: (v) => _update(item.copyWith(modeValue: v)),
                ),
              ),
              Text('${(item.modeValue * 100).round()}%',
                  style: const TextStyle(color: Colors.white54, fontSize: 11)),
            ],
          ),

        if (item.mode == ButtonMode.brakePct)
          Row(
            children: [
              const Text('Fren %:', style: TextStyle(color: Colors.white70, fontSize: 12)),
              Expanded(
                child: Slider(
                  value: item.modeValue,
                  min: 0, max: 1,
                  activeColor: const Color(0xFFD50000),
                  inactiveColor: Colors.white12,
                  onChanged: (v) => _update(item.copyWith(modeValue: v)),
                ),
              ),
              Text('${(item.modeValue * 100).round()}%',
                  style: const TextStyle(color: Colors.white54, fontSize: 11)),
            ],
          ),

        if (item.mode == ButtonMode.macro)
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Makro Adımları:', style: TextStyle(color: Colors.white70, fontSize: 12)),
              const SizedBox(height: 4),
              if (item.macro.isEmpty)
                const Text('Henüz adım eklenmedi.', style: TextStyle(color: Colors.white38, fontSize: 11)),
              ...item.macro.asMap().entries.map((e) {
                final idx = e.key;
                final act = e.value;
                String txt = '';
                if (act.type == MacroActionType.key) { txt = 'Tuş ${act.value.toInt()}'; }
                else if (act.type == MacroActionType.gasPct) { txt = 'Gaz %${(act.value * 100).toInt()}'; }
                else if (act.type == MacroActionType.brakePct) { txt = 'Fren %${(act.value * 100).toInt()}'; }
                else if (act.type == MacroActionType.delay) { txt = 'Bekle ${act.value.toInt()} ms'; }

                return Row(
                  children: [
                    Text('${idx + 1}. $txt', style: const TextStyle(color: Colors.white54, fontSize: 11)),
                    const Spacer(),
                    GestureDetector(
                      onTap: () {
                        final nm = List<MacroAction>.from(item.macro)..removeAt(idx);
                        _update(item.copyWith(macro: nm));
                      },
                      child: const Icon(Icons.close, color: Colors.red, size: 14),
                    ),
                  ],
                );
              }),
              const SizedBox(height: 8),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF40E0D0).withValues(alpha: 0.2),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                  minimumSize: const Size(0, 30),
                ),
                onPressed: () => _showAddMacroDialog(item),
                child: const Text('Adım Ekle', style: TextStyle(color: Color(0xFF40E0D0), fontSize: 11)),
              ),
            ],
          ),
      ],
    );
  }

  void _showAddMacroDialog(Layout5Item item) {
    MacroActionType selectedType = MacroActionType.key;
    double val = 1.0;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, set) {
          return AlertDialog(
            backgroundColor: const Color(0xFF12122A),
            title: const Text('Makro Adımı Ekle', style: TextStyle(color: Colors.white, fontSize: 14)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButton<MacroActionType>(
                  value: selectedType,
                  dropdownColor: const Color(0xFF1A1A3E),
                  style: const TextStyle(color: Colors.white),
                  items: const [
                    DropdownMenuItem(value: MacroActionType.key, child: Text('Tuş Bas')),
                    DropdownMenuItem(value: MacroActionType.gasPct, child: Text('Gaz Yüzdesi')),
                    DropdownMenuItem(value: MacroActionType.brakePct, child: Text('Fren Yüzdesi')),
                    DropdownMenuItem(value: MacroActionType.delay, child: Text('Gecikme (Bekle)')),
                  ],
                  onChanged: (v) {
                    if (v != null) {
                      set(() {
                        selectedType = v;
                        if (v == MacroActionType.key) { val = 1.0; }
                        else if (v == MacroActionType.gasPct || v == MacroActionType.brakePct) { val = 0.5; }
                        else if (v == MacroActionType.delay) { val = 100.0; }
                      });
                    }
                  },
                ),
                const SizedBox(height: 12),
                if (selectedType == MacroActionType.key)
                  DropdownButton<double>(
                    value: val,
                    dropdownColor: const Color(0xFF1A1A3E),
                    style: const TextStyle(color: Colors.white),
                    items: List.generate(16, (i) => DropdownMenuItem(
                      value: (i + 1).toDouble(),
                      child: Text('Tuş ${i + 1}'),
                    )),
                    onChanged: (v) { if (v != null) set(() => val = v); },
                  ),
                if (selectedType == MacroActionType.gasPct || selectedType == MacroActionType.brakePct)
                  Slider(
                    value: val, min: 0, max: 1,
                    onChanged: (v) => set(() => val = v),
                  ),
                if (selectedType == MacroActionType.delay)
                  Slider(
                    value: val, min: 50, max: 2000, divisions: 39,
                    label: '${val.toInt()} ms',
                    onChanged: (v) => set(() => val = v),
                  ),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('İptal', style: TextStyle(color: Colors.white54))),
              ElevatedButton(
                onPressed: () {
                  final nm = List<MacroAction>.from(item.macro)..add(MacroAction(type: selectedType, value: val));
                  _update(item.copyWith(macro: nm, mode: ButtonMode.macro));
                  Navigator.pop(ctx);
                },
                child: const Text('Ekle'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<Color?> _showRgb(BuildContext context, Color initial) async {
    int r = (initial.r * 255.0).round().clamp(0, 255), g = (initial.g * 255.0).round().clamp(0, 255), b = (initial.b * 255.0).round().clamp(0, 255);
    return showDialog<Color>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, set) {
          final c = Color.fromARGB(255, r, g, b);
          return AlertDialog(
            backgroundColor: const Color(0xFF12122A),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Text('Renk', style: TextStyle(color: Colors.white, fontSize: 15)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(height: 40, decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(8))),
                const SizedBox(height: 12),
                for (final ch in [('R', r, Colors.red), ('G', g, Colors.green), ('B', b, Colors.blue)])
                  Row(
                    children: [
                      SizedBox(width: 16, child: Text(ch.$1, style: TextStyle(color: ch.$3, fontWeight: FontWeight.bold, fontSize: 12))),
                      Expanded(
                        child: Slider(
                          value: ch.$2.toDouble(), min: 0, max: 255, divisions: 255,
                          activeColor: ch.$3, inactiveColor: ch.$3.withValues(alpha: 0.2),
                          onChanged: (v) => set(() {
                            if (ch.$1 == 'R') r = v.round();
                            if (ch.$1 == 'G') g = v.round();
                            if (ch.$1 == 'B') b = v.round();
                          }),
                        ),
                      ),
                      SizedBox(width: 28, child: Text('${ch.$2}', style: const TextStyle(color: Colors.white54, fontSize: 11), textAlign: TextAlign.end)),
                    ],
                  ),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('İptal', style: TextStyle(color: Colors.white54))),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: c),
                onPressed: () => Navigator.pop(ctx, c),
                child: const Text('Uygula', style: TextStyle(color: Colors.white)),
              ),
            ],
          );
        },
      ),
    );
  }
}
