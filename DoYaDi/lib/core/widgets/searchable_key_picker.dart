import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../utils/keyboard_keys.dart';
import '../../providers/settings_provider.dart';

class SearchableKeyPicker extends StatefulWidget {
  final int currentKey;
  final bool hideMacros;
  final bool hideKeyboard;
  
  const SearchableKeyPicker({Key? key, required this.currentKey, this.hideMacros = false, this.hideKeyboard = false}) : super(key: key);

  @override
  State<SearchableKeyPicker> createState() => _SearchableKeyPickerState();
}

class _SearchableKeyPickerState extends State<SearchableKeyPicker> with SingleTickerProviderStateMixin {
  String _searchQuery = '';
  TabController? _tabController;
  late List<Widget> _tabs;
  
  @override
  void initState() {
    super.initState();
    _setupTabs();
  }

  void _setupTabs() {
    _tabs = [const Tab(text: 'Tuşlar')];
    if (!widget.hideKeyboard) _tabs.add(const Tab(text: 'Klavye'));
    if (!widget.hideMacros) _tabs.add(const Tab(text: 'Makrolar'));
    
    if (_tabs.length > 1) {
      _tabController = TabController(length: _tabs.length, vsync: this);
    }
  }

  @override
  void dispose() {
    _tabController?.dispose();
    super.dispose();
  }

  void _createNewMacro(BuildContext context, SettingsProvider prov) async {
    final newMacroId = prov.settings.customMacros.keys.isEmpty 
        ? 2000 
        : prov.settings.customMacros.keys.reduce((a, b) => a > b ? a : b) + 1;
    
    List<int> selectedKeys = [];
    await showDialog(
      context: context,
      builder: (dctx) => StatefulBuilder(
        builder: (dctx, setDialogState) {
          return AlertDialog(
            backgroundColor: const Color(0xFF12122A),
            title: const Text('Yeni Makro Oluştur', style: TextStyle(color: Colors.white)),
            content: SizedBox(
              width: double.maxFinite,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('En fazla 4 tuş ekleyebilirsiniz.', style: TextStyle(color: Colors.white54, fontSize: 12)),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: selectedKeys.map((k) {
                      String kName = KeyboardKeys.appKeyMap.entries.firstWhere((e) => e.value == k, orElse: () => const MapEntry('?', 0)).key;
                      return Chip(
                        label: Text(kName, style: const TextStyle(fontSize: 12)),
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
                      label: const Text('Tuş Ekle'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1A1A3E),
                        foregroundColor: Colors.white,
                      ),
                      onPressed: () async {
                        final k = await showSearchableKeyPicker(context, 0, hideMacros: true);
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
                child: const Text('İptal', style: TextStyle(color: Colors.white54)),
              ),
              ElevatedButton(
                onPressed: selectedKeys.isNotEmpty ? () {
                  prov.settings.customMacros[newMacroId] = selectedKeys;
                  prov.updateSettings(prov.settings);
                  Navigator.pop(dctx);
                  setState(() {});
                } : null,
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF40E0D0), foregroundColor: Colors.black),
                child: const Text('Kaydet'),
              ),
            ],
          );
        }
      )
    );
  }
  
  @override
  Widget build(BuildContext context) {
    final prov = Provider.of<SettingsProvider>(context);
    final Map<String, int> allKeys = KeyboardKeys.appKeyMap;
    
    // Tuşlar (Xbox + Yok) (values < 100)
    final tuslarKeys = allKeys.entries
        .where((e) => e.value < 100 && e.key.toLowerCase().contains(_searchQuery.toLowerCase()))
        .toList();

    // Klavye Tuşları (values >= 100)
    final klavyeKeys = allKeys.entries
        .where((e) => e.value >= 100 && e.key.toLowerCase().contains(_searchQuery.toLowerCase()))
        .toList();

    List<Widget> tabViews = [_buildKeysTab(tuslarKeys)];
    if (!widget.hideKeyboard) tabViews.add(_buildKeysTab(klavyeKeys));
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
              : TabBarView(
                  controller: _tabController,
                  children: tabViews,
                ),
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
              hintText: 'Tuş Ara...',
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
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: isSelected ? const Color(0xFF40E0D0).withValues(alpha: 0.1) : Colors.transparent,
                    border: const Border(bottom: BorderSide(color: Colors.white12)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        entry.key,
                        style: TextStyle(
                          color: isSelected ? const Color(0xFF40E0D0) : Colors.white70,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                      if (isSelected)
                        const Icon(Icons.check, color: Color(0xFF40E0D0), size: 20),
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
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: ElevatedButton.icon(
            icon: const Icon(Icons.add),
            label: const Text('Yeni Makro Oluştur'),
            style: ElevatedButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
              backgroundColor: const Color(0xFF40E0D0),
              foregroundColor: Colors.black,
            ),
            onPressed: () => _createNewMacro(context, prov),
          ),
        ),
        Expanded(
          child: prov.settings.customMacros.isEmpty 
            ? const Center(child: Text('Henüz makro oluşturulmadı.', style: TextStyle(color: Colors.white38)))
            : ListView.builder(
                itemCount: prov.settings.customMacros.length,
                itemBuilder: (context, index) {
                  final entry = prov.settings.customMacros.entries.elementAt(index);
                  final mId = entry.key;
                  final mKeys = entry.value;
                  final isSelected = mId == widget.currentKey;
                  
                  String mStr = mKeys.map((k) => KeyboardKeys.appKeyMap.entries.firstWhere((e) => e.value == k, orElse: () => const MapEntry('?', 0)).key.replaceAll('Klavye: ', '')).join(' + ');

                  return InkWell(
                    onTap: () => Navigator.pop(context, mId),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: isSelected ? const Color(0xFF40E0D0).withValues(alpha: 0.1) : Colors.transparent,
                        border: const Border(bottom: BorderSide(color: Colors.white12)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              'Makro: $mStr',
                              style: TextStyle(
                                color: isSelected ? const Color(0xFF40E0D0) : Colors.white70,
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                              ),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete, color: Colors.redAccent, size: 20),
                            onPressed: () {
                              prov.settings.customMacros.remove(mId);
                              prov.updateSettings(prov.settings);
                              setState(() {});
                            },
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
}

Future<int?> showSearchableKeyPicker(BuildContext context, int currentKey, {bool hideMacros = false, bool hideKeyboard = false}) {
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
              Expanded(child: SearchableKeyPicker(currentKey: currentKey, hideMacros: true, hideKeyboard: true)),
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
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        child: SearchableKeyPicker(currentKey: currentKey, hideMacros: hideMacros, hideKeyboard: hideKeyboard),
      ),
    ),
  );
}
