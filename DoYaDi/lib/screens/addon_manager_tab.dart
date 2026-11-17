import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/network/addon_network_service.dart';
import '../core/haptic_manager.dart';
import '../providers/connection_provider.dart';
import '../providers/settings_provider.dart';
import '../models/app_settings.dart';
import '../core/utils/app_translations.dart';
import '../widgets/looping_media_widget.dart';

/// Ayarlar ekranındaki "Ek İçerik" (DLC/Addon) sekmesi.
class AddonManagerTab extends StatefulWidget {
  const AddonManagerTab({super.key});

  @override
  State<AddonManagerTab> createState() => _AddonManagerTabState();
}

class _AddonManagerTabState extends State<AddonManagerTab>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  final AddonNetworkService _addonService = AddonNetworkService();
  List<AddonInfo> _addons = [];
  bool _isMasterSwitchActive = false;
  bool _isLoading = false;
  String? _errorMessage;
  bool _telemetryActive = false;
  Timer? _listPollTimer;


  @override
  void initState() {
    super.initState();
    final prov = Provider.of<SettingsProvider>(context, listen: false);
    _isMasterSwitchActive = prov.settings.isAddonMasterSwitchActive || _addonService.isMasterSwitchActive;
    _addonService.isMasterSwitchActive = _isMasterSwitchActive;
    _addons = _addonService.cachedAddons;
    _telemetryActive = _addonService.isTelemetryActive;
    if (_isMasterSwitchActive) {
      _fetchAddons();
      _startListPolling();
    }
  }

  @override
  void dispose() {
    _listPollTimer?.cancel();
    super.dispose();
  }

  void _onMasterSwitchChanged(bool value) {
    _addonService.isMasterSwitchActive = value;
    final prov = Provider.of<SettingsProvider>(context, listen: false);
    prov.settings.isAddonMasterSwitchActive = value;
    prov.updateSettings(prov.settings);

    setState(() {
      _isMasterSwitchActive = value;
    });

    final connProvider = Provider.of<ConnectionProvider>(
      context,
      listen: false,
    );
    final ip = connProvider.connectedIp;

    if (value) {
      // Master Switch AÇILDI → Eklenti listesini getir ve periyodik güncellemeyi başlat
      _fetchAddons();
      _startListPolling();
    } else {
      // Master Switch KAPATILDI → Tüm aktif eklentilere DURDUR komutu yolla ve kapat
      _stopListPolling();
      for (final addon in _addons) {
        if (addon.value) {
          addon.value = false;
          _addonService.sendAddonCommand(ip, addon);
          _addonService.updateActiveAddonState(addon, ip);
        }
      }
      prov.settings.activeAddonIds = [];
      prov.updateSettings(prov.settings);

      HapticManager().setDlcHapticActive(false);
      _stopTelemetry();
      setState(() {
        _telemetryActive = false;
        _errorMessage = null;
      });
    }
  }

  void _startListPolling() {
    _listPollTimer?.cancel();
    // Her 25 saniyede bir eklenti yoksa veya bir şey seçilmediyse listeyi tazele
    _listPollTimer = Timer.periodic(const Duration(seconds: 25), (_) {
      if (_isMasterSwitchActive && mounted) {
        final anyActive = _addons.any((a) => a.value);
        if (!anyActive) {
          _fetchAddons();
        }
      }
    });
  }

  void _stopListPolling() {
    _listPollTimer?.cancel();
    _listPollTimer = null;
  }

  Future<void> _fetchAddons() async {
    if (_isLoading || !_isMasterSwitchActive) return;

    final connProvider = Provider.of<ConnectionProvider>(
      context,
      listen: false,
    );

    if (!connProvider.isConnected) {
      if (_addons.isEmpty) {
        setState(() {
          _errorMessage = AppTranslations.getText('no_connection');
        });
      }
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final ip = connProvider.connectedIp;
    final addons = await _addonService.fetchAddons(ip);

    if (mounted) {
      setState(() {
        _isLoading = false;
        if (addons.isNotEmpty) {
          // Mevcut kullanıcı seçimlerini ve kaydedilmiş ayarları koruyarak listeyi güncelle
          final prov = Provider.of<SettingsProvider>(context, listen: false);
          final savedActiveSet = prov.settings.activeAddonIds.toSet();
          final currentActiveIds = _addons.where((a) => a.value).map((a) => a.id).toSet();
          final allActiveSet = {...savedActiveSet, ...currentActiveIds};

          for (final a in addons) {
            if (allActiveSet.contains(a.id)) {
              a.value = true;
            }
          }
          _addons = addons;
          _addonService.cachedAddons = addons;
          _errorMessage = null;
        } else {
          if (_addons.isEmpty) {
            _errorMessage = AppTranslations.getText('no_addons_found');
          }
        }
      });
    }
  }

  void _toggleAddon(AddonInfo addon, bool value) {
    if (!_isMasterSwitchActive) return;

    final connProvider = Provider.of<ConnectionProvider>(
      context,
      listen: false,
    );
    final ip = connProvider.connectedIp;

    setState(() => addon.value = value);

    final prov = Provider.of<SettingsProvider>(context, listen: false);
    final activeSet = _addons.where((a) => a.value).map((a) => a.id).toList();
    prov.settings.activeAddonIds = activeSet;
    prov.updateSettings(prov.settings);

    // 3-Byte Başlat / Durdur komut paketi gönder
    _addonService.sendAddonCommand(ip, addon);
    _addonService.updateActiveAddonState(addon, ip);

    // Haptic kategorisi kontrolü
    if (addon.category == 'haptic') {
      final anyHapticActive = _addons
          .where((a) => a.category == 'haptic')
          .any((a) => a.value);
      HapticManager().setDlcHapticActive(anyHapticActive);

      if (addon.value) {
        final prov = Provider.of<SettingsProvider>(context, listen: false);
        if (prov.settings.simulatedHapticEnabled) {
          prov.settings.simulatedHapticEnabled = false;
          prov.updateSettings(prov.settings);
        }
      }
    }

    // Dynamic Telemetry Management
    final anyTelemetryNeeded = _addons
        .where((a) => a.category == 'haptic' || a.category == 'telemetry')
        .any((a) => a.value);

    if (anyTelemetryNeeded && !_telemetryActive) {
      _startTelemetry();
    } else if (!anyTelemetryNeeded && _telemetryActive) {
      _stopTelemetry();
    }
  }

  void _startTelemetry() {
    if (_telemetryActive) return;
    setState(() => _telemetryActive = true);

    _addonService.startTelemetryStream().listen(
      (TelemetryData data) {
        // Haptic işleme, AddonNetworkService içindeki
        // global subscription tarafından yapılıyor.
      },
      onError: (error) {
        debugPrint('Telemetry stream error: $error');
        if (mounted) setState(() => _telemetryActive = false);
      },
      onDone: () {
        if (mounted) setState(() => _telemetryActive = false);
      },
    );
  }

  void _stopTelemetry() {
    _addonService.stopTelemetryStream();
    if (mounted) setState(() => _telemetryActive = false);
  }

  Color _categoryColor(String category) {
    switch (category.toLowerCase()) {
      case 'haptic':
        return Colors.cyanAccent;
      case 'visual':
        return Colors.purpleAccent;
      case 'telemetry':
        return Colors.orangeAccent;
      default:
        return Colors.blueAccent;
    }
  }

  IconData _categoryIcon(String category) {
    switch (category.toLowerCase()) {
      case 'haptic':
        return Icons.vibration;
      case 'visual':
        return Icons.visibility;
      case 'telemetry':
        return Icons.speed;
      default:
        return Icons.extension;
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final connProvider = Provider.of<ConnectionProvider>(context);
    final s = Provider.of<SettingsProvider>(context).settings;
    final hasBgMedia = AppMediaHelper.hasMedia(s.bgMediaPath);
    final txt = hasBgMedia ? Colors.white : s.textColor;
    final sub = hasBgMedia ? Colors.white70 : s.textDisabledColor;
    final div = hasBgMedia ? Colors.white24 : s.dividerColor;
    final ac = s.detailColor;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── EKLENTİ PANELİ ANAHTARI (MASTER SWITCH) ──
          GlassContainer(
            isGlassActive: hasBgMedia,
            solidBackgroundColor: s.surfaceColor,
            padding: const EdgeInsets.all(14),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: _isMasterSwitchActive
                  ? ac.withValues(alpha: 0.5)
                  : div,
            ),
            child: Row(
              children: [
                Icon(
                  Icons.extension,
                  color: _isMasterSwitchActive ? ac : sub,
                  size: 26,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        AppTranslations.getText('master_addon_switch'),
                        style: TextStyle(
                          color: txt,
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        AppTranslations.getText('master_addon_switch_desc'),
                        style: TextStyle(
                          color: sub,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: _isMasterSwitchActive,
                  onChanged: _onMasterSwitchChanged,
                  activeThumbColor: ac,
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // ── TELEMETRİ İÇERİK YAPILANDIRMA KARTI ──
          GlassContainer(
            isGlassActive: hasBgMedia,
            solidBackgroundColor: ac.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: ac.withValues(alpha: 0.25)),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: () => _showTelemetryConfigModal(context),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: ac.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(Icons.tune, color: ac, size: 22),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              AppTranslations.getText('configure_telemetry_contents'),
                              style: TextStyle(
                                color: txt,
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              AppTranslations.getText('configure_telemetry_contents_desc'),
                              style: TextStyle(
                                color: sub,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(Icons.arrow_forward_ios, color: sub, size: 14),
                    ],
                  ),
                ),
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Panelin Durumuna Göre İçerik
          if (!_isMasterSwitchActive) ...[
            GlassContainer(
              isGlassActive: hasBgMedia,
              solidBackgroundColor: txt.withValues(alpha: 0.03),
              padding: const EdgeInsets.all(20),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: div),
              child: Column(
                children: [
                  Icon(Icons.power_settings_new,
                      color: sub.withValues(alpha: 0.6), size: 40),
                  const SizedBox(height: 12),
                  Text(
                    AppTranslations.getText('addon_desc'),
                    style: TextStyle(
                      color: sub,
                      fontSize: 12,
                      height: 1.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ] else ...[
            // Bağlantı durumu uyarısı
            if (!connProvider.isConnected) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.warning_amber_rounded,
                        color: Colors.orange, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        AppTranslations.getText('no_connection'),
                        style: const TextStyle(color: Colors.orange, fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],

            // Yükleniyor veya Yenileme Göstergesi
            if (_isLoading) ...[
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.cyanAccent,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      AppTranslations.getText('fetching_addons'),
                      style: const TextStyle(color: Colors.cyanAccent, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],

            // Hata mesajı
            if (_errorMessage != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline, color: Colors.redAccent, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: const TextStyle(color: Colors.redAccent, fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],

            // Telemetri durumu (Gerçek canlı akış kontrolü ile)
            if (_telemetryActive) ...[
              Builder(
                builder: (context) {
                  final isLive = _addonService.isTelemetryLive;
                  final color = isLive ? Colors.greenAccent : Colors.orangeAccent;
                  final text = isLive
                      ? AppTranslations.getText('telemetry_live')
                      : AppTranslations.getText('telemetry_waiting');

                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: color.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: color,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            text,
                            style: TextStyle(
                              color: color,
                              fontSize: 11,
                              fontWeight: isLive ? FontWeight.bold : FontWeight.normal,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
              const SizedBox(height: 12),
            ],

            // Addon listesi
            ..._addons.map((addon) => _buildAddonTile(addon)),
          ],

          const SizedBox(height: 40),
        ],
      ),
    );
  }

  void _showTelemetryConfigModal(BuildContext context, {String? initialCategory}) {
    final s = Provider.of<SettingsProvider>(context, listen: false).settings;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: s.surfaceColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (modalContext) => _TelemetryConfigBottomSheet(initialCategory: initialCategory),
    );
  }

  Widget _buildAddonTile(AddonInfo addon) {
    final s = Provider.of<SettingsProvider>(context, listen: false).settings;
    final hasBgMedia = AppMediaHelper.hasMedia(s.bgMediaPath);
    final txt = hasBgMedia ? Colors.white : s.textColor;
    final sub = hasBgMedia ? Colors.white70 : s.textDisabledColor;
    final div = hasBgMedia ? Colors.white24 : s.dividerColor;
    final catColor = _categoryColor(addon.category);
    final catIcon = _categoryIcon(addon.category);

    return GlassContainer(
      isGlassActive: hasBgMedia,
      solidBackgroundColor: txt.withValues(alpha: 0.04),
      margin: const EdgeInsets.only(bottom: 8),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(
        color: addon.value
            ? catColor.withValues(alpha: 0.4)
            : div,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: catColor.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(catIcon, color: catColor, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          addon.name,
                          style: TextStyle(
                            color: txt,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: catColor.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          addon.category.toUpperCase(),
                          style: TextStyle(
                            color: catColor,
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    addon.id,
                    style: TextStyle(color: sub, fontSize: 11),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: Icon(Icons.tune, color: txt.withValues(alpha: 0.75), size: 20),
              tooltip: AppTranslations.getText('configure_telemetry'),
              onPressed: () => _showTelemetryConfigModal(context, initialCategory: addon.category),
            ),
            Switch(
              value: addon.value,
              onChanged: (v) => _toggleAddon(addon, v),
              activeThumbColor: catColor,
            ),
          ],
        ),
      ),
    );
  }
}

class _TelemetryConfigBottomSheet extends StatefulWidget {
  final String? initialCategory;
  const _TelemetryConfigBottomSheet({this.initialCategory});

  @override
  State<_TelemetryConfigBottomSheet> createState() => _TelemetryConfigBottomSheetState();
}

class _TelemetryConfigBottomSheetState extends State<_TelemetryConfigBottomSheet>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    int initialIndex = 0;
    if (widget.initialCategory != null) {
      final cat = widget.initialCategory!.toLowerCase();
      if (cat == 'visual' || cat == 'telemetry') {
        initialIndex = 1;
      } else if (cat == 'flight') {
        initialIndex = 2;
      }
    }
    _tabController = TabController(length: 3, vsync: this, initialIndex: initialIndex);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final prov = Provider.of<SettingsProvider>(context);
    final s = prov.settings;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: s.textDisabledColor,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Icon(Icons.tune, color: s.detailColor, size: 22),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    AppTranslations.getText('telemetry_config_title'),
                    style: TextStyle(
                      color: s.textColor,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.close, color: s.textDisabledColor, size: 20),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),

          // Tab Bar
          TabBar(
            controller: _tabController,
            indicatorColor: s.detailColor,
            labelColor: s.detailColor,
            unselectedLabelColor: s.textDisabledColor,
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            tabs: [
              Tab(
                icon: const Icon(Icons.vibration, size: 18),
                text: AppTranslations.getText('telemetry_tab_haptic'),
              ),
              Tab(
                icon: const Icon(Icons.speed, size: 18),
                text: AppTranslations.getText('telemetry_tab_hud'),
              ),
              Tab(
                icon: const Icon(Icons.flight, size: 18),
                text: AppTranslations.getText('telemetry_tab_flight'),
              ),
            ],
          ),

          Divider(color: s.dividerColor, height: 1),

          // Tab Views
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                // Tab 1: Haptic
                _buildHapticTab(prov, s),
                // Tab 2: Visual HUD
                _buildHudTab(prov, s),
                // Tab 3: Flight MFD
                _buildFlightTab(prov, s),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHapticTab(SettingsProvider prov, AppSettings s) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildSubItemTile(
          title: AppTranslations.getText('haptic_sub_rpm'),
          subtitle: AppTranslations.getText('haptic_sub_rpm_desc'),
          value: s.dlcHapticRpm,
          color: Colors.cyanAccent,
          icon: Icons.speed,
          onChanged: (v) {
            s.dlcHapticRpm = v;
            prov.updateSettings(s);
          },
        ),
        _buildSubItemTile(
          title: AppTranslations.getText('haptic_sub_slip'),
          subtitle: AppTranslations.getText('haptic_sub_slip_desc'),
          value: s.dlcHapticSlip,
          color: Colors.cyanAccent,
          icon: Icons.album,
          onChanged: (v) {
            s.dlcHapticSlip = v;
            prov.updateSettings(s);
          },
        ),
        _buildSubItemTile(
          title: AppTranslations.getText('haptic_sub_gear'),
          subtitle: AppTranslations.getText('haptic_sub_gear_desc'),
          value: s.dlcHapticGear,
          color: Colors.cyanAccent,
          icon: Icons.electric_bolt,
          onChanged: (v) {
            s.dlcHapticGear = v;
            prov.updateSettings(s);
          },
        ),
        _buildSubItemTile(
          title: AppTranslations.getText('haptic_sub_collision'),
          subtitle: AppTranslations.getText('haptic_sub_collision_desc'),
          value: s.dlcHapticCollision,
          color: Colors.cyanAccent,
          icon: Icons.warning_amber_rounded,
          onChanged: (v) {
            s.dlcHapticCollision = v;
            prov.updateSettings(s);
          },
        ),
        const SizedBox(height: 12),
        _buildResetButton(() {
          s.dlcHapticRpm = false;
          s.dlcHapticSlip = true;
          s.dlcHapticGear = true;
          s.dlcHapticCollision = true;
          prov.updateSettings(s);
        }),
      ],
    );
  }

  Widget _buildHudTab(SettingsProvider prov, AppSettings s) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildSubItemTile(
          title: AppTranslations.getText('hud_sub_rpm_bar'),
          subtitle: AppTranslations.getText('hud_sub_rpm_bar_desc'),
          value: s.hudShowRpm,
          color: Colors.orangeAccent,
          icon: Icons.linear_scale,
          onChanged: (v) {
            s.hudShowRpm = v;
            prov.updateSettings(s);
          },
        ),
        _buildSubItemTile(
          title: AppTranslations.getText('hud_sub_speed'),
          subtitle: AppTranslations.getText('hud_sub_speed_desc'),
          value: s.hudShowSpeed,
          color: Colors.orangeAccent,
          icon: Icons.speed,
          onChanged: (v) {
            s.hudShowSpeed = v;
            prov.updateSettings(s);
          },
        ),
        _buildSubItemTile(
          title: AppTranslations.getText('hud_sub_gear'),
          subtitle: AppTranslations.getText('hud_sub_gear_desc'),
          value: s.hudShowGear,
          color: Colors.orangeAccent,
          icon: Icons.looks_one,
          onChanged: (v) {
            s.hudShowGear = v;
            prov.updateSettings(s);
          },
        ),
        _buildSubItemTile(
          title: AppTranslations.getText('hud_sub_drs_ers'),
          subtitle: AppTranslations.getText('hud_sub_drs_ers_desc'),
          value: s.hudShowDrsErs,
          color: Colors.orangeAccent,
          icon: Icons.battery_charging_full,
          onChanged: (v) {
            s.hudShowDrsErs = v;
            prov.updateSettings(s);
          },
        ),
        _buildSubItemTile(
          title: AppTranslations.getText('hud_sub_pedal_bars'),
          subtitle: AppTranslations.getText('hud_sub_pedal_bars_desc'),
          value: s.hudShowPedalBars,
          color: Colors.orangeAccent,
          icon: Icons.compare_arrows,
          onChanged: (v) {
            s.hudShowPedalBars = v;
            prov.updateSettings(s);
          },
        ),
        _buildSubItemTile(
          title: AppTranslations.getText('hud_sub_tyres'),
          subtitle: AppTranslations.getText('hud_sub_tyres_desc'),
          value: s.hudShowTyres,
          color: Colors.orangeAccent,
          icon: Icons.thermostat,
          onChanged: (v) {
            s.hudShowTyres = v;
            prov.updateSettings(s);
          },
        ),
        _buildSubItemTile(
          title: AppTranslations.getText('hud_sub_rpm_box'),
          subtitle: AppTranslations.getText('hud_sub_rpm_box_desc'),
          value: s.hudShowRpmBox,
          color: Colors.orangeAccent,
          icon: Icons.crop_square,
          onChanged: (v) {
            s.hudShowRpmBox = v;
            prov.updateSettings(s);
          },
        ),
        _buildSubItemTile(
          title: AppTranslations.getText('hud_sub_status_flags'),
          subtitle: AppTranslations.getText('hud_sub_status_flags_desc'),
          value: s.hudShowStatusFlags,
          color: Colors.orangeAccent,
          icon: Icons.flag,
          onChanged: (v) {
            s.hudShowStatusFlags = v;
            prov.updateSettings(s);
          },
        ),
        const SizedBox(height: 12),
        _buildResetButton(() {
          s.hudShowRpm = true;
          s.hudShowSpeed = true;
          s.hudShowGear = true;
          s.hudShowDrsErs = true;
          s.hudShowPedalBars = true;
          s.hudShowTyres = true;
          s.hudShowRpmBox = true;
          s.hudShowStatusFlags = true;
          prov.updateSettings(s);
        }),
      ],
    );
  }

  Widget _buildFlightTab(SettingsProvider prov, AppSettings s) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildSubItemTile(
          title: AppTranslations.getText('mfd_sub_horizon'),
          subtitle: AppTranslations.getText('mfd_sub_horizon_desc'),
          value: s.mfdShowArtificialHorizon,
          color: Colors.purpleAccent,
          icon: Icons.explore,
          onChanged: (v) {
            s.mfdShowArtificialHorizon = v;
            prov.updateSettings(s);
          },
        ),
        _buildSubItemTile(
          title: AppTranslations.getText('mfd_sub_speed_tape'),
          subtitle: AppTranslations.getText('mfd_sub_speed_tape_desc'),
          value: s.mfdShowSpeedTape,
          color: Colors.purpleAccent,
          icon: Icons.speed,
          onChanged: (v) {
            s.mfdShowSpeedTape = v;
            prov.updateSettings(s);
          },
        ),
        _buildSubItemTile(
          title: AppTranslations.getText('mfd_sub_altitude_tape'),
          subtitle: AppTranslations.getText('mfd_sub_altitude_tape_desc'),
          value: s.mfdShowAltitudeTape,
          color: Colors.purpleAccent,
          icon: Icons.height,
          onChanged: (v) {
            s.mfdShowAltitudeTape = v;
            prov.updateSettings(s);
          },
        ),
        _buildSubItemTile(
          title: AppTranslations.getText('mfd_sub_engine_gauges'),
          subtitle: AppTranslations.getText('mfd_sub_engine_gauges_desc'),
          value: s.mfdShowEngineGauges,
          color: Colors.purpleAccent,
          icon: Icons.engineering,
          onChanged: (v) {
            s.mfdShowEngineGauges = v;
            prov.updateSettings(s);
          },
        ),
        const SizedBox(height: 12),
        _buildResetButton(() {
          s.mfdShowArtificialHorizon = true;
          s.mfdShowSpeedTape = true;
          s.mfdShowAltitudeTape = true;
          s.mfdShowEngineGauges = true;
          prov.updateSettings(s);
        }),
      ],
    );
  }

  Widget _buildSubItemTile({
    required String title,
    required String subtitle,
    required bool value,
    required Color color,
    required IconData icon,
    required ValueChanged<bool> onChanged,
  }) {
    final s = Provider.of<SettingsProvider>(context, listen: false).settings;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: s.textColor.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: value ? color.withValues(alpha: 0.35) : s.dividerColor,
        ),
      ),
      child: SwitchListTile(
        value: value,
        onChanged: onChanged,
        activeThumbColor: color,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        secondary: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        title: Text(
          title,
          style: TextStyle(
            color: s.textColor,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: TextStyle(color: s.textDisabledColor, fontSize: 11),
        ),
      ),
    );
  }

  Widget _buildResetButton(VoidCallback onReset) {
    final s = Provider.of<SettingsProvider>(context, listen: false).settings;
    return OutlinedButton.icon(
      onPressed: onReset,
      icon: Icon(Icons.refresh, size: 16, color: s.textDisabledColor),
      label: Text(
        AppTranslations.getText('reset_to_defaults'),
        style: TextStyle(color: s.textDisabledColor, fontSize: 12),
      ),
      style: OutlinedButton.styleFrom(
        side: BorderSide(color: s.dividerColor),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }
}
