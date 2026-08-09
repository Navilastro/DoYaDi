import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/network/addon_network_service.dart';
import '../core/haptic_manager.dart';
import '../providers/connection_provider.dart';
import '../providers/settings_provider.dart';
import '../core/utils/app_translations.dart';

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

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── EKLENTİ PANELİ ANAHTARI (MASTER SWITCH) ──
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFF1E1E38),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: _isMasterSwitchActive
                    ? Colors.cyanAccent.withValues(alpha: 0.5)
                    : Colors.white12,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.extension,
                  color: _isMasterSwitchActive
                      ? Colors.cyanAccent
                      : Colors.white38,
                  size: 26,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        AppTranslations.getText('master_addon_switch'),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        AppTranslations.getText('master_addon_switch_desc'),
                        style: const TextStyle(
                          color: Colors.white38,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: _isMasterSwitchActive,
                  onChanged: _onMasterSwitchChanged,
                  activeThumbColor: Colors.cyanAccent,
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Panelin Durumuna Göre İçerik
          if (!_isMasterSwitchActive) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.02),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white10),
              ),
              child: Column(
                children: [
                  const Icon(Icons.power_settings_new,
                      color: Colors.white24, size: 40),
                  const SizedBox(height: 12),
                  Text(
                    AppTranslations.getText('addon_desc'),
                    style: const TextStyle(
                      color: Colors.white54,
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

  Widget _buildAddonTile(AddonInfo addon) {
    final catColor = _categoryColor(addon.category);
    final catIcon = _categoryIcon(addon.category);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: addon.value
              ? catColor.withValues(alpha: 0.4)
              : Colors.white12,
        ),
      ),
      child: SwitchListTile(
        value: addon.value,
        onChanged: (v) => _toggleAddon(addon, v),
        activeThumbColor: catColor,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        title: Row(
          children: [
            Icon(catIcon, color: catColor, size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                addon.name,
                style: const TextStyle(color: Colors.white, fontSize: 14),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: catColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                addon.category,
                style: TextStyle(
                  color: catColor,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        subtitle: Text(
          addon.id,
          style: const TextStyle(color: Colors.white24, fontSize: 10),
        ),
      ),
    );
  }
}
