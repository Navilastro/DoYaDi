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

  bool get _hasGasBar => _items.any((e) => e.type == Layout5ItemType.gasBar);
  bool get _hasBrakeBar =>
      _items.any((e) => e.type == Layout5ItemType.brakeBar);
  bool get _hasLeftJoystick =>
      _items.any((e) => e.type == Layout5ItemType.leftJoystick);
  bool get _hasRightJoystick =>
      _items.any((e) => e.type == Layout5ItemType.rightJoystick);

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
      _items.add(
        Layout5Item(
          id: id,
          type: type,
          left: 0.3,
          top: 0.3,
          width:
              (type == Layout5ItemType.leftJoystick ||
                  type == Layout5ItemType.rightJoystick)
              ? 0.22
              : 0.18,
          height:
              (type == Layout5ItemType.leftJoystick ||
                  type == Layout5ItemType.rightJoystick)
              ? 0.55
              : 0.22,
          label: label,
        ),
      );
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

  Layout5Item? get _selected => _selectedId == null
      ? null
      : _items.cast<Layout5Item?>().firstWhere(
          (e) => e?.id == _selectedId,
          orElse: () => null,
        );

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
          Positioned.fill(child: Container(color: Colors.black45)),
          Positioned(
            top: 4,
            right: 4,
            child: GestureDetector(
              onTap: () => _removeItem(item.id),
              child: Container(
                width: 28,
                height: 28,
                decoration: const BoxDecoration(
                  color: Colors.red,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.close, color: Colors.white, size: 18),
              ),
            ),
          ),
        ],
      );
    }

    return Positioned(
      left: l,
      top: t,
      width: w,
      height: h,
      child: GestureDetector(
        onTap: _editMode ? () => setState(() => _selectedId = item.id) : null,
        onScaleStart: _editMode
            ? (details) {
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
              }
            : null,
        onScaleUpdate: _editMode
            ? (details) {
                setState(() {
                  final idx = _items.indexWhere((e) => e.id == item.id);
                  if (idx < 0) return;

                  // Hareket (Pan)
                  double newLeft =
                      (_items[idx].left +
                              details.focalPointDelta.dx / size.width)
                          .clamp(0.0, 0.95);
                  double newTop =
                      (_items[idx].top +
                              details.focalPointDelta.dy / size.height)
                          .clamp(0.0, 0.95);

                  // Sınırları belirle (Pedallar ekranın yarısına ve tam boyuna kadar çıkabilir)
                  bool isPedal =
                      _items[idx].type == Layout5ItemType.gasBar ||
                      _items[idx].type == Layout5ItemType.brakeBar;
                  double maxW = isPedal ? 0.5 : 0.95;
                  double maxH = isPedal ? 1.0 : 0.95;

                  // Boyutlandırma (Aspect Ratio korunarak)
                  double newW = (_initialScaleW * details.scale).clamp(
                    0.05,
                    maxW,
                  );
                  double newH = (_initialScaleH * details.scale).clamp(
                    0.05,
                    maxH,
                  );

                  // Joystickler döndürülemesin (yön eksenleri bozulur)
                  final isJoystick =
                      _items[idx].type == Layout5ItemType.leftJoystick ||
                      _items[idx].type == Layout5ItemType.rightJoystick;
                  double newRot = isJoystick
                      ? _initialRotation // sabit tut
                      : _initialRotation + details.rotation;

                  _items[idx] = _items[idx].copyWith(
                    left: newLeft,
                    top: newTop,
                    width: newW,
                    height: newH,
                    rotation: newRot,
                  );
                });
              }
            : null,
        onScaleEnd: _editMode
            ? (details) {
                setState(() {
                  _isDragging = false;
                });
              }
            : null,
        child: Transform.rotate(
          angle: item.rotation,
          child: Container(
            decoration: isSelected && _editMode
                ? BoxDecoration(
                    border: Border.all(color: Colors.cyan, width: 2),
                  )
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
    final label =
        item.label ??
        '${_items.indexOf(item) + 1} ${AppTranslations.getText('btn_label_default')}';
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
          PopupMenuItem(
            value: Layout5ItemType.leftJoystick,
            child: Text(
              AppTranslations.getText('add_left_joystick'),
              style: const TextStyle(color: Colors.white),
            ),
          ),
        if (!_hasRightJoystick)
          PopupMenuItem(
            value: Layout5ItemType.rightJoystick,
            child: Text(
              AppTranslations.getText('add_right_joystick'),
              style: const TextStyle(color: Colors.white),
            ),
          ),
        if (!_hasGasBar)
          PopupMenuItem(
            value: Layout5ItemType.gasBar,
            child: Text(
              AppTranslations.getText('add_gas_bar'),
              style: const TextStyle(color: Colors.white),
            ),
          ),
        if (!_hasBrakeBar)
          PopupMenuItem(
            value: Layout5ItemType.brakeBar,
            child: Text(
              AppTranslations.getText('add_brake_bar'),
              style: const TextStyle(color: Colors.white),
            ),
          ),
        PopupMenuItem(
          value: Layout5ItemType.buttonSquare,
          child: Text(
            AppTranslations.getText('add_square_button'),
            style: const TextStyle(color: Colors.white),
          ),
        ),
        PopupMenuItem(
          value: Layout5ItemType.buttonSoft,
          child: Text(
            AppTranslations.getText('add_soft_button'),
            style: const TextStyle(color: Colors.white),
          ),
        ),
        PopupMenuItem(
          value: Layout5ItemType.buttonCircle,
          child: Text(
            AppTranslations.getText('add_circle_button'),
            style: const TextStyle(color: Colors.white),
          ),
        ),
        PopupMenuItem(
          value: Layout5ItemType.touchpad,
          child: Text(
            AppTranslations.getText('add_touchpad'),
            style: const TextStyle(color: Colors.white),
          ),
        ),
      ],
      onSelected: _addItem,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFF40E0D0).withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFF40E0D0)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.add, color: Color(0xFF40E0D0), size: 18),
            const SizedBox(width: 4),
            Text(
              AppTranslations.getText('add'),
              style: const TextStyle(color: Color(0xFF40E0D0), fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }

  Widget _topBtn(
    String label,
    IconData icon,
    bool active,
    VoidCallback onTap, {
    Color color = const Color(0xFF40E0D0),
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: active
              ? color.withValues(alpha: 0.25)
              : Colors.white.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: active ? color : Colors.white24),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: active ? color : Colors.white70, size: 16),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                color: active ? color : Colors.white70,
                fontSize: 12,
              ),
            ),
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

  bool get _isButton =>
      widget.item.type == Layout5ItemType.buttonSquare ||
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
          Text(
            AppTranslations.getText('properties'),
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 12,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 8),

          // Boyut
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
          _label(AppTranslations.getText('rotation_deg')),
          _sizeSlider(
            item.rotation * 180 / pi,
            -180.0,
            180.0,
            (v) => _update(item.copyWith(rotation: v * pi / 180)),
          ),

          const Divider(color: Colors.white12),

          // Arka plan rengi
          _label(AppTranslations.getText('bg_color')),
          _colorPicker(item.bgColor, (c) => _update(item.copyWith(bgColor: c))),
          const SizedBox(height: 6),

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
        ],
      ),
    );
  }

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
                  DropdownButton<double>(
                    value: val,
                    dropdownColor: const Color(0xFF1A1A3E),
                    style: const TextStyle(color: Colors.white),
                    items: List.generate(
                      16,
                      (i) => DropdownMenuItem(
                        value: (i + 1).toDouble(),
                        child: Text(
                          '${AppTranslations.getText('key_prefix')} ${i + 1}',
                        ),
                      ),
                    ),
                    onChanged: (v) {
                      if (v != null) set(() => val = v);
                    },
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
