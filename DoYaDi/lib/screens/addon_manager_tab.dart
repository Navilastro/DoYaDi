import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/network/addon_network_service.dart';
import '../services/telemetry_listener_service.dart';
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
  final Set<String> _expandedAddonIds = {};
  bool _isMasterSwitchActive = false;
  bool _isLoading = false;
  String? _errorMessage;
  bool _telemetryActive = false;
  Timer? _listPollTimer;

  @override
  void initState() {
    super.initState();
    final prov = Provider.of<SettingsProvider>(context, listen: false);
    _isMasterSwitchActive =
        prov.settings.isAddonMasterSwitchActive || _addonService.isMasterSwitchActive;
    _addonService.isMasterSwitchActive = _isMasterSwitchActive;
    _addons = _addonService.cachedAddons;
    _telemetryActive =
        _addonService.isTelemetryActive || TelemetryListenerService().isListening;
    for (final a in _addons) {
      if (a.value && _hasSubSettings(a)) {
        _expandedAddonIds.add(a.id);
      }
    }
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

  bool _hasSubSettings(AddonInfo addon) {
    final cat = addon.category.toLowerCase();
    return cat == 'haptic' || cat == 'telemetry' || cat == 'visual';
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
      TelemetryListenerService().stop();
      setState(() {
        _expandedAddonIds.clear();
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
              if (_hasSubSettings(a)) {
                _expandedAddonIds.add(a.id);
              }
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

    setState(() {
      addon.value = value;
      if (value && _hasSubSettings(addon)) {
        _expandedAddonIds.add(addon.id);
      }
    });

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
        if (prov.settings.simulatedHapticEnabled) {
          prov.settings.simulatedHapticEnabled = false;
          prov.updateSettings(prov.settings);
        }
      }
    }

    // Genişletilmiş HUD / Görsel Telemetri (port 8892) kontrolü
    final anyExtendedNeeded = _addons
        .where((a) => a.category == 'telemetry' || a.category == 'visual')
        .any((a) => a.value);
    if (anyExtendedNeeded && !TelemetryListenerService().isListening) {
      TelemetryListenerService().filterAlpha = prov.settings.f1LowPassAlpha;
      TelemetryListenerService().start();
    } else if (!anyExtendedNeeded && TelemetryListenerService().isListening) {
      TelemetryListenerService().stop();
    }

    // Haptic / Standart Telemetri (port 8890) kontrolü
    final anyBaseTelemetryNeeded = _addons
        .where((a) => a.category == 'haptic')
        .any((a) => a.value);

    if (anyBaseTelemetryNeeded && !_addonService.isTelemetryActive) {
      _startTelemetry();
    } else if (!anyBaseTelemetryNeeded && _addonService.isTelemetryActive) {
      _stopTelemetry();
    }

    if (mounted) {
      setState(() {
        _telemetryActive = anyBaseTelemetryNeeded || anyExtendedNeeded;
      });
    }
  }

  void _startTelemetry() {
    if (_addonService.isTelemetryActive) return;

    _addonService.startTelemetryStream().listen(
      (TelemetryData data) {
        // Haptic işleme, AddonNetworkService içindeki
        // global subscription tarafından yapılıyor.
      },
      onError: (error) {
        debugPrint('Telemetry stream error: $error');
        if (mounted) {
          setState(() {
            _telemetryActive = TelemetryListenerService().isListening;
          });
        }
      },
      onDone: () {
        if (mounted) {
          setState(() {
            _telemetryActive = TelemetryListenerService().isListening;
          });
        }
      },
    );
  }

  void _stopTelemetry() {
    _addonService.stopTelemetryStream();
    if (mounted) {
      setState(() {
        _telemetryActive = TelemetryListenerService().isListening;
      });
    }
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
    final prov = Provider.of<SettingsProvider>(context);
    final s = prov.settings;
    final hasBgMedia = AppMediaHelper.hasMedia(s.bgMediaPath);
    final txt = hasBgMedia ? Colors.white : s.textColor;
    final sub = hasBgMedia ? Colors.white70 : s.textDisabledColor;
    final div = hasBgMedia ? Colors.white24 : s.dividerColor;
    final ac = s.detailColor;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: SizedBox(
        width: double.infinity,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
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
                  final isLive = _addonService.isTelemetryLive ||
                      TelemetryListenerService().isLive;
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

            // Sunucudan gelen gerçek eklenti / telemetri kutuları (bitişik alt dallarıyla)
            ..._addons.map((addon) => _buildAddonTile(addon, prov, s)),
          ],

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildAddonTile(
    AddonInfo addon,
    SettingsProvider prov,
    AppSettings s,
  ) {
    final hasBgMedia = AppMediaHelper.hasMedia(s.bgMediaPath);
    final txt = hasBgMedia ? Colors.white : s.textColor;
    final sub = hasBgMedia ? Colors.white70 : s.textDisabledColor;
    final div = hasBgMedia ? Colors.white24 : s.dividerColor;
    final catColor = _categoryColor(addon.category);
    final catIcon = _categoryIcon(addon.category);
    final bool hasSub = _hasSubSettings(addon);
    final bool isExpanded = hasSub && _expandedAddonIds.contains(addon.id);

    return GlassContainer(
      isGlassActive: hasBgMedia,
      solidBackgroundColor: txt.withValues(alpha: 0.04),
      margin: const EdgeInsets.only(bottom: 10),
      borderRadius: BorderRadius.circular(14),
      border: Border.all(
        color: addon.value
            ? catColor.withValues(alpha: 0.45)
            : div,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Üst Kutu: Gelen Telemetri / Eklenti Satırı
          InkWell(
            borderRadius: BorderRadius.vertical(
              top: const Radius.circular(14),
              bottom: isExpanded ? Radius.zero : const Radius.circular(14),
            ),
            onTap: hasSub
                ? () {
                    setState(() {
                      if (isExpanded) {
                        _expandedAddonIds.remove(addon.id);
                      } else {
                        _expandedAddonIds.add(addon.id);
                      }
                    });
                  }
                : null,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
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
                  if (hasSub)
                    IconButton(
                      icon: Icon(
                        isExpanded
                            ? Icons.keyboard_arrow_up_rounded
                            : Icons.tune_rounded,
                        color: isExpanded ? catColor : txt.withValues(alpha: 0.75),
                        size: 20,
                      ),
                      tooltip: AppTranslations.getText('configure_telemetry'),
                      onPressed: () {
                        setState(() {
                          if (isExpanded) {
                            _expandedAddonIds.remove(addon.id);
                          } else {
                            _expandedAddonIds.add(addon.id);
                          }
                        });
                      },
                    ),
                  Switch(
                    value: addon.value,
                    onChanged: (v) => _toggleAddon(addon, v),
                    activeThumbColor: catColor,
                  ),
                ],
              ),
            ),
          ),

          // Kutuyla Bitişik Alt Dal: Yalnızca Bu Telemetrinin Kendi Ayarları
          if (isExpanded) ...[
            Divider(color: div, height: 1),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(14, 10, 12, 12),
              decoration: BoxDecoration(
                color: txt.withValues(alpha: 0.02),
                borderRadius: const BorderRadius.vertical(
                  bottom: Radius.circular(14),
                ),
              ),
              child: Container(
                padding: const EdgeInsets.only(left: 12),
                decoration: BoxDecoration(
                  border: Border(
                    left: BorderSide(
                      color: catColor.withValues(alpha: 0.45),
                      width: 2,
                    ),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: _buildAddonSubSettings(
                    addon: addon,
                    prov: prov,
                    s: s,
                    catColor: catColor,
                    txt: txt,
                    sub: sub,
                    div: div,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  List<Widget> _buildAddonSubSettings({
    required AddonInfo addon,
    required SettingsProvider prov,
    required AppSettings s,
    required Color catColor,
    required Color txt,
    required Color sub,
    required Color div,
  }) {
    final String cat = addon.category.toLowerCase();

    if (cat == 'haptic') {
      return [
        _buildSubSettingRow(
          title: AppTranslations.getText('haptic_sub_rpm'),
          subtitle: AppTranslations.getText('haptic_sub_rpm_desc'),
          value: s.dlcHapticRpm,
          color: catColor,
          icon: Icons.speed,
          txt: txt,
          sub: sub,
          div: div,
          onChanged: (v) {
            s.dlcHapticRpm = v;
            prov.updateSettings(s);
          },
        ),
        _buildSubSettingRow(
          title: AppTranslations.getText('haptic_sub_slip'),
          subtitle: AppTranslations.getText('haptic_sub_slip_desc'),
          value: s.dlcHapticSlip,
          color: catColor,
          icon: Icons.album,
          txt: txt,
          sub: sub,
          div: div,
          onChanged: (v) {
            s.dlcHapticSlip = v;
            prov.updateSettings(s);
          },
        ),
        _buildSubSettingRow(
          title: AppTranslations.getText('haptic_sub_gear'),
          subtitle: AppTranslations.getText('haptic_sub_gear_desc'),
          value: s.dlcHapticGear,
          color: catColor,
          icon: Icons.electric_bolt,
          txt: txt,
          sub: sub,
          div: div,
          onChanged: (v) {
            s.dlcHapticGear = v;
            prov.updateSettings(s);
          },
        ),
        _buildSubSettingRow(
          title: AppTranslations.getText('haptic_sub_collision'),
          subtitle: AppTranslations.getText('haptic_sub_collision_desc'),
          value: s.dlcHapticCollision,
          color: catColor,
          icon: Icons.warning_amber_rounded,
          txt: txt,
          sub: sub,
          div: div,
          onChanged: (v) {
            s.dlcHapticCollision = v;
            prov.updateSettings(s);
          },
        ),
        const SizedBox(height: 6),
        _buildInlineResetButton(
          sub: sub,
          div: div,
          onReset: () {
            s.dlcHapticRpm = false;
            s.dlcHapticSlip = true;
            s.dlcHapticGear = true;
            s.dlcHapticCollision = true;
            prov.updateSettings(s);
          },
        ),
      ];
    }

    if (cat == 'telemetry' || cat == 'visual') {
      final lowerName = addon.name.toLowerCase();
      final bool isFlightAddon =
          addon.numericId == 102 ||
          lowerName.contains('flight') ||
          lowerName.contains('uçuş') ||
          lowerName.contains('mfd') ||
          lowerName.contains('war thunder');

      if (isFlightAddon) {
        return [
          _buildSubSettingRow(
            title: AppTranslations.getText('mfd_sub_horizon'),
            subtitle: AppTranslations.getText('mfd_sub_horizon_desc'),
            value: s.mfdShowArtificialHorizon,
            color: catColor,
            icon: Icons.explore,
            txt: txt,
            sub: sub,
            div: div,
            onChanged: (v) {
              s.mfdShowArtificialHorizon = v;
              prov.updateSettings(s);
            },
          ),
          _buildSubSettingRow(
            title: AppTranslations.getText('mfd_sub_speed_tape'),
            subtitle: AppTranslations.getText('mfd_sub_speed_tape_desc'),
            value: s.mfdShowSpeedTape,
            color: catColor,
            icon: Icons.speed,
            txt: txt,
            sub: sub,
            div: div,
            onChanged: (v) {
              s.mfdShowSpeedTape = v;
              prov.updateSettings(s);
            },
          ),
          _buildSubSettingRow(
            title: AppTranslations.getText('mfd_sub_altitude_tape'),
            subtitle: AppTranslations.getText('mfd_sub_altitude_tape_desc'),
            value: s.mfdShowAltitudeTape,
            color: catColor,
            icon: Icons.height,
            txt: txt,
            sub: sub,
            div: div,
            onChanged: (v) {
              s.mfdShowAltitudeTape = v;
              prov.updateSettings(s);
            },
          ),
          _buildSubSettingRow(
            title: AppTranslations.getText('mfd_sub_engine_gauges'),
            subtitle: AppTranslations.getText('mfd_sub_engine_gauges_desc'),
            value: s.mfdShowEngineGauges,
            color: catColor,
            icon: Icons.settings_input_component,
            txt: txt,
            sub: sub,
            div: div,
            onChanged: (v) {
              s.mfdShowEngineGauges = v;
              prov.updateSettings(s);
            },
          ),
          const SizedBox(height: 6),
          _buildInlineResetButton(
            sub: sub,
            div: div,
            onReset: () {
              s.mfdShowArtificialHorizon = true;
              s.mfdShowSpeedTape = true;
              s.mfdShowAltitudeTape = true;
              s.mfdShowEngineGauges = true;
              prov.updateSettings(s);
            },
          ),
        ];
      }

      return [
        _buildSubSettingRow(
          title: AppTranslations.getText('hud_sub_rpm_bar'),
          subtitle: AppTranslations.getText('hud_sub_rpm_bar_desc'),
          value: s.hudShowRpm,
          color: catColor,
          icon: Icons.linear_scale,
          txt: txt,
          sub: sub,
          div: div,
          onChanged: (v) {
            s.hudShowRpm = v;
            prov.updateSettings(s);
          },
        ),
        _buildSubSettingRow(
          title: AppTranslations.getText('hud_sub_speed'),
          subtitle: AppTranslations.getText('hud_sub_speed_desc'),
          value: s.hudShowSpeed,
          color: catColor,
          icon: Icons.speed,
          txt: txt,
          sub: sub,
          div: div,
          onChanged: (v) {
            s.hudShowSpeed = v;
            prov.updateSettings(s);
          },
        ),
        _buildSubSettingRow(
          title: AppTranslations.getText('hud_sub_gear'),
          subtitle: AppTranslations.getText('hud_sub_gear_desc'),
          value: s.hudShowGear,
          color: catColor,
          icon: Icons.looks_one,
          txt: txt,
          sub: sub,
          div: div,
          onChanged: (v) {
            s.hudShowGear = v;
            prov.updateSettings(s);
          },
        ),
        _buildSubSettingRow(
          title: AppTranslations.getText('hud_sub_drs_ers'),
          subtitle: AppTranslations.getText('hud_sub_drs_ers_desc'),
          value: s.hudShowDrsErs,
          color: catColor,
          icon: Icons.battery_charging_full,
          txt: txt,
          sub: sub,
          div: div,
          onChanged: (v) {
            s.hudShowDrsErs = v;
            prov.updateSettings(s);
          },
        ),
        _buildSubSettingRow(
          title: AppTranslations.getText('hud_sub_pedal_bars'),
          subtitle: AppTranslations.getText('hud_sub_pedal_bars_desc'),
          value: s.hudShowPedalBars,
          color: catColor,
          icon: Icons.compare_arrows,
          txt: txt,
          sub: sub,
          div: div,
          onChanged: (v) {
            s.hudShowPedalBars = v;
            prov.updateSettings(s);
          },
        ),
        _buildSubSettingRow(
          title: AppTranslations.getText('hud_sub_tyres'),
          subtitle: AppTranslations.getText('hud_sub_tyres_desc'),
          value: s.hudShowTyres,
          color: catColor,
          icon: Icons.thermostat,
          txt: txt,
          sub: sub,
          div: div,
          onChanged: (v) {
            s.hudShowTyres = v;
            prov.updateSettings(s);
          },
        ),
        _buildSubSettingRow(
          title: AppTranslations.getText('hud_sub_rpm_box'),
          subtitle: AppTranslations.getText('hud_sub_rpm_box_desc'),
          value: s.hudShowRpmBox,
          color: catColor,
          icon: Icons.crop_square,
          txt: txt,
          sub: sub,
          div: div,
          onChanged: (v) {
            s.hudShowRpmBox = v;
            prov.updateSettings(s);
          },
        ),
        _buildSubSettingRow(
          title: AppTranslations.getText('hud_sub_status_flags'),
          subtitle: AppTranslations.getText('hud_sub_status_flags_desc'),
          value: s.hudShowStatusFlags,
          color: catColor,
          icon: Icons.flag,
          txt: txt,
          sub: sub,
          div: div,
          onChanged: (v) {
            s.hudShowStatusFlags = v;
            prov.updateSettings(s);
          },
        ),
        const SizedBox(height: 6),
        _buildInlineResetButton(
          sub: sub,
          div: div,
          onReset: () {
            s.hudShowRpm = true;
            s.hudShowSpeed = true;
            s.hudShowGear = true;
            s.hudShowDrsErs = true;
            s.hudShowPedalBars = true;
            s.hudShowTyres = true;
            s.hudShowRpmBox = true;
            s.hudShowStatusFlags = true;
            prov.updateSettings(s);
          },
        ),
      ];
    }

    return const [];
  }

  Widget _buildSubSettingRow({
    required String title,
    required String subtitle,
    required bool value,
    required Color color,
    required IconData icon,
    required Color txt,
    required Color sub,
    required Color div,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      decoration: BoxDecoration(
        color: txt.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: value ? color.withValues(alpha: 0.3) : div,
        ),
      ),
      child: SwitchListTile(
        dense: true,
        value: value,
        onChanged: onChanged,
        activeThumbColor: color,
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
        secondary: Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: 16),
        ),
        title: Text(
          title,
          style: TextStyle(
            color: txt,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: TextStyle(color: sub, fontSize: 10.5),
        ),
      ),
    );
  }

  Widget _buildInlineResetButton({
    required Color sub,
    required Color div,
    required VoidCallback onReset,
  }) {
    return Align(
      alignment: Alignment.centerLeft,
      child: OutlinedButton.icon(
        onPressed: onReset,
        icon: Icon(Icons.refresh, size: 15, color: sub),
        label: Text(
          AppTranslations.getText('reset_to_defaults'),
          style: TextStyle(color: sub, fontSize: 11.5),
        ),
        style: OutlinedButton.styleFrom(
          visualDensity: VisualDensity.compact,
          side: BorderSide(color: div),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
    );
  }
}
