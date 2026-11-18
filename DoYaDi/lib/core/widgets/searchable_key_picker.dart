import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../utils/keyboard_keys.dart';
import '../../providers/settings_provider.dart';
import '../utils/app_translations.dart';

class SearchableKeyPicker extends StatefulWidget {
  final int currentKey;
  final bool hideMacros;
  final bool hideKeyboard;

  const SearchableKeyPicker({
    super.key,
    required this.currentKey,
    this.hideMacros = false,
    this.hideKeyboard = false,
  });

  @override
  State<SearchableKeyPicker> createState() => _SearchableKeyPickerState();
}

class _SearchableKeyPickerState extends State<SearchableKeyPicker>
    with SingleTickerProviderStateMixin {
  String _searchQuery = '';
  TabController? _tabController;
  late List<Widget> _tabs;

  @override
  void initState() {
    super.initState();
    _setupTabs();
  }

  void _setupTabs() {
    _tabs = [Tab(text: AppTranslations.getText('keys'))];
    if (!widget.hideKeyboard) {
      _tabs.add(Tab(text: AppTranslations.getText('keyboard')));
      _tabs.add(Tab(text: AppTranslations.getText('touch_mouse_tab')));
    }
    if (!widget.hideMacros) {
      _tabs.add(Tab(text: AppTranslations.getText('macros')));
    }

    if (_tabs.length > 1) {
      _tabController = TabController(length: _tabs.length, vsync: this);
    }
  }

  @override
  void dispose() {
    _tabController?.dispose();
    super.dispose();
  }

  String _formatMacroStep(int step, String keyboardPrefix) {
    if (step <= -30000) {
      final pct = -(step + 30000);
      return '${AppTranslations.getText('brake_pct')} $pct%';
    }
    if (step <= -20000) {
      final pct = -(step + 20000);
      return '${AppTranslations.getText('gas_pct')} $pct%';
    }
    if (step <= -10000) {
      final ms = -(step + 10000);
      return '$ms ms';
    }
    return KeyboardKeys.getKeyLabel(step).replaceAll(keyboardPrefix, '');
  }

  void _createNewMacro(BuildContext context, SettingsProvider prov) async {
    final existingSerialIds = prov.settings.customMacros.keys
        .where((k) => k >= 2010 && k < 3000);
    final newMacroId = existingSerialIds.isEmpty
        ? 2010
        : existingSerialIds.reduce((a, b) => a > b ? a : b) + 1;

    final List<int> steps = [];
    int stepKind = 0; // 0: Tuş, 1: Gecikme (ms), 2: Gaz %, 3: Fren %
    int draftKey = 5;
    double draftSlider = 200.0;
    final keyboardPrefix = '${AppTranslations.getText('keyboard')}: ';

    await showDialog(
      context: context,
      builder: (dctx) => StatefulBuilder(
        builder: (dctx, setDialogState) {
          return AlertDialog(
            backgroundColor: const Color(0xFF12122A),
            title: Text(
              AppTranslations.getText('create_new_macro'),
              style: const TextStyle(color: Colors.white),
            ),
            content: SizedBox(
              width: double.maxFinite,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      AppTranslations.getText('serial_macro_desc'),
                      style: const TextStyle(
                        color: Color(0xFF40E0D0),
                        fontSize: 12,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (steps.isEmpty)
                      Text(
                        AppTranslations.getText('no_macro_steps_yet'),
                        style: const TextStyle(
                          color: Colors.white38,
                          fontSize: 12,
                        ),
                      )
                    else
                      ...steps.asMap().entries.map((e) {
                        final idx = e.key;
                        final st = e.value;
                        return Container(
                          margin: const EdgeInsets.only(bottom: 4),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1A1A3E),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  '${idx + 1}. ${_formatMacroStep(st, keyboardPrefix)}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                              IconButton(
                                icon: const Icon(
                                  Icons.close,
                                  color: Colors.redAccent,
                                  size: 16,
                                ),
                                visualDensity: VisualDensity.compact,
                                padding: EdgeInsets.zero,
                                onPressed: () =>
                                    setDialogState(() => steps.removeAt(idx)),
                              ),
                            ],
                          ),
                        );
                      }),
                    const Divider(color: Colors.white12, height: 20),
                    DropdownButton<int>(
                      value: stepKind,
                      isExpanded: true,
                      dropdownColor: const Color(0xFF1A1A3E),
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                      items: [
                        DropdownMenuItem(
                          value: 0,
                          child: Text(AppTranslations.getText('step_key_press')),
                        ),
                        DropdownMenuItem(
                          value: 1,
                          child: Text(AppTranslations.getText('step_delay')),
                        ),
                        DropdownMenuItem(
                          value: 2,
                          child: Text(AppTranslations.getText('step_gas_pct')),
                        ),
                        DropdownMenuItem(
                          value: 3,
                          child: Text(AppTranslations.getText('step_brake_pct')),
                        ),
                      ],
                      onChanged: (v) {
                        if (v == null) return;
                        setDialogState(() {
                          stepKind = v;
                          if (v == 1) {
                            draftSlider = 200.0;
                          } else if (v == 2 || v == 3) {
                            draftSlider = 50.0;
                          }
                        });
                      },
                    ),
                    const SizedBox(height: 8),
                    if (stepKind == 0)
                      OutlinedButton.icon(
                        icon: const Icon(Icons.keyboard, size: 16),
                        label: Text(
                          KeyboardKeys.getKeyLabel(draftKey),
                          style: const TextStyle(color: Color(0xFF40E0D0)),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Colors.white24),
                        ),
                        onPressed: () async {
                          final k = await showSearchableKeyPicker(
                            context,
                            draftKey,
                            hideMacros: true,
                          );
                          if (k != null && k > 0) {
                            setDialogState(() => draftKey = k);
                          }
                        },
                      ),
                    if (stepKind == 1)
                      Row(
                        children: [
                          Expanded(
                            child: Slider(
                              value: draftSlider.clamp(50.0, 2000.0),
                              min: 50,
                              max: 2000,
                              divisions: 39,
                              activeColor: const Color(0xFF40E0D0),
                              onChanged: (v) =>
                                  setDialogState(() => draftSlider = v),
                            ),
                          ),
                          Text(
                            '${draftSlider.round()} ms',
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    if (stepKind == 2 || stepKind == 3)
                      Row(
                        children: [
                          Expanded(
                            child: Slider(
                              value: draftSlider.clamp(0.0, 100.0),
                              min: 0,
                              max: 100,
                              divisions: 20,
                              activeColor: stepKind == 2
                                  ? const Color(0xFF00C853)
                                  : Colors.redAccent,
                              onChanged: (v) =>
                                  setDialogState(() => draftSlider = v),
                            ),
                          ),
                          Text(
                            '${draftSlider.round()}%',
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    const SizedBox(height: 8),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.add),
                      label: Text(AppTranslations.getText('add_step')),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1A1A3E),
                        foregroundColor: Colors.white,
                      ),
                      onPressed: () {
                        setDialogState(() {
                          if (stepKind == 0 && draftKey > 0) {
                            steps.add(draftKey);
                          } else if (stepKind == 1) {
                            steps.add(-10000 - draftSlider.round());
                          } else if (stepKind == 2) {
                            steps.add(-20000 - draftSlider.round());
                          } else if (stepKind == 3) {
                            steps.add(-30000 - draftSlider.round());
                          }
                        });
                      },
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dctx),
                child: Text(
                  AppTranslations.getText('cancel'),
                  style: const TextStyle(color: Colors.white54),
                ),
              ),
              ElevatedButton(
                onPressed: steps.isNotEmpty
                    ? () {
                        prov.settings.customMacros[newMacroId] = steps;
                        prov.updateSettings(prov.settings);
                        Navigator.pop(dctx);
                        setState(() {});
                      }
                    : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF40E0D0),
                  foregroundColor: Colors.black,
                ),
                child: Text(AppTranslations.getText('save')),
              ),
            ],
          );
        },
      ),
    );
  }

  /// Parallel Macro: tuşlar aynı anda basılır (Ctrl+S gibi kombolar)
  void _createParallelMacro(BuildContext context, SettingsProvider prov) async {
    // Parallel makro için özel bir ID aralığı kullanıyoruz: 3000+
    final newMacroId =
        prov.settings.customMacros.keys.where((k) => k >= 3000).isEmpty
        ? 3000
        : prov.settings.customMacros.keys
                  .where((k) => k >= 3000)
                  .reduce((a, b) => a > b ? a : b) +
              1;

    List<int> selectedKeys = [];
    await showDialog(
      context: context,
      builder: (dctx) => StatefulBuilder(
        builder: (dctx, setDialogState) {
          return AlertDialog(
            backgroundColor: const Color(0xFF12122A),
            title: Text(
              AppTranslations.getText('create_parallel_macro'),
              style: const TextStyle(color: Colors.white),
            ),
            content: SizedBox(
              width: double.maxFinite,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    AppTranslations.getText('parallel_macro_desc'),
                    style: const TextStyle(
                      color: Colors.amber,
                      fontSize: 12,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    AppTranslations.getText('max_4_keys'),
                    style: const TextStyle(color: Colors.white54, fontSize: 12),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: selectedKeys.map((k) {
                      String kName = KeyboardKeys.appKeyMap.entries
                          .firstWhere(
                            (e) => e.value == k,
                            orElse: () => const MapEntry('?', 0),
                          )
                          .key;
                      return Chip(
                        backgroundColor: const Color(
                          0xFF40E0D0,
                        ).withValues(alpha: 0.2),
                        label: Text(
                          kName,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF40E0D0),
                          ),
                        ),
                        onDeleted: () {
                          setDialogState(() => selectedKeys.remove(k));
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 12),
                  if (selectedKeys.length < 4)
                    ElevatedButton.icon(
                      icon: const Icon(Icons.add),
                      label: Text(AppTranslations.getText('add_key')),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1A1A3E),
                        foregroundColor: Colors.white,
                      ),
                      onPressed: () async {
                        final k = await showSearchableKeyPicker(
                          context,
                          0,
                          hideMacros: true,
                        );
                        if (k != null && k > 0) {
                          setDialogState(() {
                            if (selectedKeys.length < 4) selectedKeys.add(k);
                          });
                        }
                      },
                    ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dctx),
                child: Text(
                  AppTranslations.getText('cancel'),
                  style: const TextStyle(color: Colors.white54),
                ),
              ),
              ElevatedButton(
                onPressed: selectedKeys.isNotEmpty
                    ? () {
                        // Parallel makroyu negatif değerlerle işaretliyoruz (ID >= 3000)
                        prov.settings.customMacros[newMacroId] = selectedKeys;
                        prov.updateSettings(prov.settings);
                        Navigator.pop(dctx);
                        setState(() {});
                      }
                    : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF40E0D0),
                  foregroundColor: Colors.black,
                ),
                child: Text(AppTranslations.getText('save')),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final prov = Provider.of<SettingsProvider>(context);
    final Map<String, int> allKeys = KeyboardKeys.appKeyMap;

    // Tuşlar sekmesi: sadece e.value < 1000 → Xbox / gamepad tuşları (L3, R3 dahil)
    // Fare tuşları (2001-2003) Dokunmatik Fare sekmesine aittir, buraya gelmez.
    final tuslarKeys = allKeys.entries
        .where(
          (e) =>
              e.value < 1000 &&
              e.key.toLowerCase().contains(_searchQuery.toLowerCase()),
        )
        .toList();

    // Klavye sekmesi: 1000 <= e.value < 2000
    final klavyeKeys = allKeys.entries
        .where(
          (e) =>
              e.value >= 1000 &&
              e.value < 2000 &&
              e.key.toLowerCase().contains(_searchQuery.toLowerCase()),
        )
        .toList();

    // Dokunmatik Fare sekmesi: "Dokunmatik Fare: ..." prefix'ine sahip girişler veya value >= 2000
    final fareKeys = allKeys.entries
        .where(
          (e) =>
              e.value >= 2000 &&
              e.key.toLowerCase().contains(_searchQuery.toLowerCase()),
        )
        .toList();

    List<Widget> tabViews = [_buildKeysTab(tuslarKeys)];
    if (!widget.hideKeyboard) {
      tabViews.add(_buildKeysTab(klavyeKeys));
      tabViews.add(_buildKeysTab(fareKeys));
    }
    if (!widget.hideMacros) tabViews.add(_buildMacrosTab(prov));

    return Container(
      color: const Color(0xFF12122A),
      height: MediaQuery.of(context).size.height * 0.8,
      child: Column(
        children: [
          if (_tabController != null)
            Container(
              padding: const EdgeInsets.all(8),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: Colors.white12)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TabBar(
                      controller: _tabController,
                      indicatorColor: const Color(0xFF40E0D0),
                      labelColor: const Color(0xFF40E0D0),
                      unselectedLabelColor: Colors.white38,
                      isScrollable: true,
                      tabAlignment: TabAlignment.start,
                      tabs: _tabs,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white54),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
          if (_tabController == null)
            Container(
              padding: const EdgeInsets.all(16),
              alignment: Alignment.centerRight,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white54),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          Expanded(
            child: _tabController == null
                ? tabViews.first
                : TabBarView(controller: _tabController, children: tabViews),
          ),
        ],
      ),
    );
  }

  Widget _buildKeysTab(List<MapEntry<String, int>> filteredKeys) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: TextField(
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: AppTranslations.getText('search_key'),
              hintStyle: const TextStyle(color: Colors.white38),
              prefixIcon: const Icon(Icons.search, color: Colors.white54),
              filled: true,
              fillColor: const Color(0xFF1A1A3E),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(vertical: 0),
            ),
            onChanged: (val) {
              setState(() {
                _searchQuery = val;
              });
            },
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: filteredKeys.length,
            itemBuilder: (context, index) {
              final entry = filteredKeys[index];
              final isSelected = entry.value == widget.currentKey;

              return InkWell(
                onTap: () => Navigator.pop(context, entry.value),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? const Color(0xFF40E0D0).withValues(alpha: 0.1)
                        : Colors.transparent,
                    border: const Border(
                      bottom: BorderSide(color: Colors.white12),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        entry.key,
                        style: TextStyle(
                          color: isSelected
                              ? const Color(0xFF40E0D0)
                              : Colors.white70,
                          fontWeight: isSelected
                              ? FontWeight.bold
                              : FontWeight.normal,
                        ),
                      ),
                      if (isSelected)
                        const Icon(
                          Icons.check,
                          color: Color(0xFF40E0D0),
                          size: 20,
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildMacrosTab(SettingsProvider prov) {
    // Sequential makrolar: ID 2000-2999
    final seqMacros = prov.settings.customMacros.entries
        .where((e) => e.key < 3000)
        .toList();
    // Parallel makrolar: ID 3000+
    final parMacros = prov.settings.customMacros.entries
        .where((e) => e.key >= 3000)
        .toList();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.add),
                  label: Text(AppTranslations.getText('create_new_macro')),
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size.fromHeight(44),
                    backgroundColor: const Color(0xFF40E0D0),
                    foregroundColor: Colors.black,
                  ),
                  onPressed: () => _createNewMacro(context, prov),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.merge_type),
                  label: Text(AppTranslations.getText('parallel_macro')),
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size.fromHeight(44),
                    backgroundColor: Colors.amber.shade700,
                    foregroundColor: Colors.black,
                  ),
                  onPressed: () => _createParallelMacro(context, prov),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: prov.settings.customMacros.isEmpty
              ? Center(
                  child: Text(
                    AppTranslations.getText('no_macros'),
                    style: const TextStyle(color: Colors.white38),
                  ),
                )
              : ListView(
                  children: [
                    // Sequential Macros section
                    if (seqMacros.isNotEmpty) ...[
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                        child: Text(
                          AppTranslations.getText(
                            'create_new_macro',
                          ).toUpperCase(),
                          style: const TextStyle(
                            color: Color(0xFF40E0D0),
                            fontSize: 11,
                            letterSpacing: 1.2,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      ...seqMacros.map(
                        (entry) =>
                            _buildMacroTile(entry, prov, isParallel: false),
                      ),
                    ],
                    // Parallel Macros section
                    if (parMacros.isNotEmpty) ...[
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                        child: Text(
                          AppTranslations.getText(
                            'parallel_macro',
                          ).toUpperCase(),
                          style: const TextStyle(
                            color: Colors.amber,
                            fontSize: 11,
                            letterSpacing: 1.2,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      ...parMacros.map(
                        (entry) =>
                            _buildMacroTile(entry, prov, isParallel: true),
                      ),
                    ],
                  ],
                ),
        ),
      ],
    );
  }

  Widget _buildMacroTile(
    MapEntry<int, List<int>> entry,
    SettingsProvider prov, {
    required bool isParallel,
  }) {
    final mId = entry.key;
    final mKeys = entry.value;
    final isSelected = mId == widget.currentKey;
    final accentColor = isParallel ? Colors.amber : const Color(0xFF40E0D0);

    final keyboardPrefix = '${AppTranslations.getText('keyboard')}: ';
    String mStr = mKeys
        .map((k) => _formatMacroStep(k, keyboardPrefix))
        .join(isParallel ? ' + ' : ' → ');

    return InkWell(
      onTap: () => Navigator.pop(context, mId),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? accentColor.withValues(alpha: 0.1)
              : Colors.transparent,
          border: const Border(bottom: BorderSide(color: Colors.white12)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isParallel
                        ? '${AppTranslations.getText('parallel_macro')}: $mStr'
                        : '${AppTranslations.getText('macro_prefix')}$mStr',
                    style: TextStyle(
                      color: isSelected ? accentColor : Colors.white70,
                      fontWeight: isSelected
                          ? FontWeight.bold
                          : FontWeight.normal,
                    ),
                  ),
                  if (isParallel)
                    Text(
                      'Ctrl+S gibi kombinasyon',
                      style: TextStyle(
                        color: Colors.amber.withValues(alpha: 0.6),
                        fontSize: 11,
                      ),
                    ),
                ],
              ),
            ),
            Row(
              children: [
                if (isSelected) Icon(Icons.check, color: accentColor, size: 20),
                IconButton(
                  icon: const Icon(
                    Icons.delete,
                    color: Colors.redAccent,
                    size: 20,
                  ),
                  onPressed: () {
                    prov.settings.customMacros.remove(mId);
                    prov.updateSettings(prov.settings);
                    setState(() {});
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

Future<int?> showSearchableKeyPicker(
  BuildContext context,
  int currentKey, {
  bool hideMacros = false,
  bool hideKeyboard = false,
}) {
  if (hideMacros && hideKeyboard) {
    return showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF12122A),
        contentPadding: EdgeInsets.zero,
        content: SizedBox(
          width: double.maxFinite,
          height: MediaQuery.of(context).size.height * 0.6,
          child: Column(
            children: [
              Expanded(
                child: SearchableKeyPicker(
                  currentKey: currentKey,
                  hideMacros: true,
                  hideKeyboard: true,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
  return showModalBottomSheet<int>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        child: SearchableKeyPicker(
          currentKey: currentKey,
          hideMacros: hideMacros,
          hideKeyboard: hideKeyboard,
        ),
      ),
    ),
  );
}
