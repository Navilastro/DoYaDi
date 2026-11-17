import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:sensors_plus/sensors_plus.dart';

import '../providers/settings_provider.dart';
import '../providers/connection_provider.dart';
import '../providers/monetization_provider.dart';
import '../services/ad_service.dart';
import '../models/app_settings.dart';
import '../core/utils/result.dart';
import 'settings_screen.dart';
import 'driving_screen.dart';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';
import 'package:permission_handler/permission_handler.dart';
import '../core/utils/app_translations.dart';
import '../widgets/looping_media_widget.dart';

// ═══════════════════════════════════════════════════════════════════════════
// PC İSTEMCİ WEB SİTESİ BAĞLANTISI (Daha sonra buradan güncelleyebilirsiniz)
// ═══════════════════════════════════════════════════════════════════════════
const String kClientWebsiteUrl = 'https://doyadi.com';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _isConnectionOptionsExpanded = false;

  @override
  void initState() {
    super.initState();
    _requestPermissions();
  }

  String _rememberedConnectionLabel(ConnectionProvider connection) {
    final method = connection.lastConnectionMethod;
    if (method == 'bluetooth') {
      final devName = connection.selectedDevice?.name ??
          connection.selectedDevice?.address ??
          '';
      final base = AppTranslations.getText('last_conn_bt');
      return devName.isNotEmpty ? '$base ($devName)' : base;
    } else if (method == 'usb') {
      final ip = connection.wifiIp;
      final base = AppTranslations.getText('last_conn_usb');
      return ip.isNotEmpty ? '$base ($ip)' : base;
    } else if (method == 'wifi') {
      final ip = connection.wifiIp;
      final base = AppTranslations.getText('last_conn_wifi');
      return ip.isNotEmpty ? '$base ($ip)' : base;
    }
    return AppTranslations.getText('change_conn_type');
  }

  IconData _rememberedConnectionIcon(ConnectionProvider connection) {
    final method = connection.lastConnectionMethod;
    if (method == 'bluetooth') return Icons.bluetooth_connected;
    if (method == 'usb') return Icons.cable;
    return Icons.wifi;
  }

  Future<void> _requestPermissions() async {
    try {
      final List<Permission> permissions = [
        Permission.location,
        Permission.bluetooth,
        Permission.bluetoothScan,
        Permission.bluetoothConnect,
        Permission.bluetoothAdvertise,
      ];
      for (final p in permissions) {
        try {
          if (await p.status.isDenied) {
            await p.request();
          }
        } catch (_) {}
      }
    } catch (e) {
      debugPrint("Permission request error: $e");
    }
  }

  void _showConnectionDialog(BuildContext context) {
    final connectionProvider = Provider.of<ConnectionProvider>(context, listen: false);
    final ipController = TextEditingController(text: connectionProvider.wifiIp);

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(AppTranslations.getText('connection_settings')),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: ipController,
                        decoration: InputDecoration(
                          labelText: AppTranslations.getText('pc_local_ip'),
                          border: const OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.number,
                        onChanged: (val) {
                          connectionProvider.setWifiIp(val, isUsb: false);
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: () async {
                        // Yükleniyor göstergesi
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(AppTranslations.getText('scanning_network')), duration: const Duration(seconds: 1)),
                        );
                        final result = await connectionProvider.discoverServer();
                        switch (result) {
                          case Success(:final value):
                            ipController.text = value;
                            connectionProvider.setWifiIp(value, isUsb: false);
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text(AppTranslations.getText('pc_found_ready')), backgroundColor: Colors.green),
                              );
                            }
                          case Failure(:final message):
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text(message), backgroundColor: Colors.red),
                              );
                            }
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 18),
                      ),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(AppTranslations.getText('auto_find')),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                ElevatedButton.icon(
                  onPressed: () {
                    _showBluetoothDevicesDialog(context, connectionProvider);
                  },
                  icon: const Icon(Icons.bluetooth),
                  label: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(AppTranslations.getText('select_bt_device')),
                  ),
                  style: ElevatedButton.styleFrom(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(AppTranslations.getText('close')),
            ),
          ],
        );
      },
    );
  }

  void _showBluetoothDevicesDialog(BuildContext context, ConnectionProvider connectionProvider) async {
    // Her cihaz için bağlanma işlemi yapılırken UI'ı kilitlememek için
    // dialog içinde state yönetimi StatefulBuilder ile sağlanıyor.

    // Tarama stream'i ve cihaz listesi dialog kapanana kadar tutulacak
    StreamSubscription<BluetoothDiscoveryResult>? discoverySubscription;
    final List<BluetoothDevice> devices = [];
    bool isScanning = true;

    /// Tekrarsız cihaz ekleme yardımcısı
    void addDeviceIfNew(BluetoothDevice device, StateSetter setState) {
      final exists = devices.any((d) => d.address == device.address);
      if (!exists) {
        setState(() => devices.add(device));
      } else {
        // İsim veya bond durumu güncellenmiş olabilir, yerinde güncelle
        final idx = devices.indexWhere((d) => d.address == device.address);
        setState(() => devices[idx] = device);
      }
    }

    // ① Önce kayıtlı (bonded) cihazları getir — eşzamanlı taramaya başlamadan önce
    List<BluetoothDevice> bonded = [];
    try {
      bonded = await FlutterBluetoothSerial.instance.getBondedDevices();
    } catch (_) {}

    if (!context.mounted) return;

    await showDialog(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (statefulContext, setState) {
            // Dialog ilk oluşturulduğunda taramayı başlat
            if (isScanning && discoverySubscription == null) {
              // Bonded cihazları listeye ekle
              for (final d in bonded) {
                addDeviceIfNew(d, setState);
              }

              // ② Eş zamanlı Discovery başlat
              try {
                discoverySubscription = FlutterBluetoothSerial.instance
                    .startDiscovery()
                    .listen(
                  (result) {
                    addDeviceIfNew(result.device, setState);
                  },
                  onDone: () {
                    setState(() => isScanning = false);
                    discoverySubscription = null;
                  },
                  onError: (Object e) {
                    setState(() => isScanning = false);
                    discoverySubscription = null;
                  },
                  cancelOnError: true,
                );
              } catch (e) {
                setState(() => isScanning = false);
              }
            }

            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: Row(
                children: [
                  const Icon(Icons.bluetooth_searching, color: Colors.blueAccent),
                  const SizedBox(width: 8),
                  Expanded(child: Text(AppTranslations.getText('bt_devices'))),
                  if (isScanning)
                    const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                ],
              ),
              content: SizedBox(
                width: double.maxFinite,
                height: math.min(320.0, MediaQuery.of(context).size.height * 0.55),
                child: devices.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const CircularProgressIndicator(),
                            const SizedBox(height: 16),
                            Text(AppTranslations.getText('searching_devices')),
                          ],
                        ),
                      )
                    : ListView.separated(
                        itemCount: devices.length,
                        separatorBuilder: (BuildContext c, int i) => const Divider(height: 1),
                        itemBuilder: (BuildContext c, int index) {
                          final device = devices[index];
                          final isBonded = device.isBonded;

                          return ListTile(
                            leading: Icon(
                              isBonded ? Icons.bluetooth_connected : Icons.bluetooth,
                              color: isBonded ? Colors.blueAccent : Colors.grey,
                            ),
                            title: Text(
                              device.name ?? AppTranslations.getText('unknown_device'),
                              style: const TextStyle(fontWeight: FontWeight.w600),
                            ),
                            subtitle: Text(
                              '${device.address}  •  ${isBonded ? AppTranslations.getText('paired') : AppTranslations.getText('new_device')}',
                              style: TextStyle(
                                fontSize: 12,
                                color: isBonded ? Colors.blueAccent : Colors.orange,
                              ),
                            ),
                            onTap: () async {
                              // ③ Taramayı durdur ve dialog'u kapat
                              await discoverySubscription?.cancel();
                              discoverySubscription = null;

                              if (dialogContext.mounted) Navigator.pop(dialogContext);
                              if (context.mounted) Navigator.pop(context); // Ana bağlantı dialog'unu kapat

                              // ④ Eşleşmemişse önce bond işlemini başlat
                              bool bonded = isBonded;
                              if (!bonded) {
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('${device.name ?? device.address}${AppTranslations.getText('pairing_with')}'),
                                      duration: const Duration(seconds: 5),
                                    ),
                                  );
                                }
                                try {
                                  bonded = await FlutterBluetoothSerial.instance
                                          .bondDeviceAtAddress(device.address) ??
                                      false;
                                } catch (_) {
                                  bonded = false;
                                }
                                if (!bonded) {
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text('${device.name ?? device.address}${AppTranslations.getText('pairing_failed')}'),
                                        backgroundColor: Colors.red,
                                      ),
                                    );
                                  }
                                  return;
                                }
                              }

                              // ⑤ Eşleşme tamam → soketi aç
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('${device.name ?? device.address}${AppTranslations.getText('connecting')}'),
                                  ),
                                );
                              }

                              final btResult = await connectionProvider.connectBluetooth(
                                device: device,
                              );

                              switch (btResult) {
                                case Success():
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                       SnackBar(
                                        content: Text(AppTranslations.getText('bt_connection_success')),
                                        backgroundColor: Colors.green,
                                      ),
                                    );
                                  }
                                case Failure(:final message):
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                       SnackBar(
                                        content: Text(message),
                                        backgroundColor: Colors.red,
                                      ),
                                    );
                                  }
                              }
                            },
                          );
                        },
                      ),
              ),
              actions: [
                TextButton(
                  onPressed: () async {
                    await discoverySubscription?.cancel();
                    discoverySubscription = null;
                    if (dialogContext.mounted) Navigator.pop(dialogContext);
                  },
                  child: Text(isScanning ? AppTranslations.getText('stop_scan') : AppTranslations.getText('close')),
                ),
              ],
            );
          },
        );
      },
    );

    // Dialog kapanırken stream mutlaka iptal edilsin
    await discoverySubscription?.cancel();
  }

  void _showUsbTetheringDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          backgroundColor: const Color(0xFF0A0A20),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          title: Row(
            children: [
              const Icon(Icons.cable, color: Colors.cyan, size: 28),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  AppTranslations.getText('usb_zero_delay'),
                  style: const TextStyle(color: Colors.white, fontSize: 18),
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ListTile(
                  leading: const Icon(Icons.looks_one, color: Colors.cyan),
                  title: Text(AppTranslations.getText('usb_step_1'), style: const TextStyle(color: Colors.white70)),
                  contentPadding: EdgeInsets.zero,
                ),
                ListTile(
                  leading: const Icon(Icons.looks_two, color: Colors.cyan),
                  title: Text(AppTranslations.getText('usb_step_2'), style: const TextStyle(color: Colors.white70)),
                  contentPadding: EdgeInsets.zero,
                ),
                ListTile(
                  leading: const Icon(Icons.looks_3, color: Colors.cyan),
                  title: Text(AppTranslations.getText('usb_step_3'), style: const TextStyle(color: Colors.white70)),
                  contentPadding: EdgeInsets.zero,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(AppTranslations.getText('cancel'), style: const TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(dialogContext);
                
                final connectionProvider = Provider.of<ConnectionProvider>(context, listen: false);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(AppTranslations.getText('scanning_network')), duration: const Duration(seconds: 1)),
                );
                final usbResult = await connectionProvider.discoverServer();
                switch (usbResult) {
                  case Success(:final value):
                    connectionProvider.setWifiIp(value, isUsb: true);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(AppTranslations.getText('pc_found_ready')), backgroundColor: Colors.green),
                      );
                    }
                  case Failure(:final message):
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(message), backgroundColor: Colors.red),
                      );
                    }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.cyan,
              ),
              child: Text(AppTranslations.getText('ok_start_connect'), style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<SettingsProvider>(context).settings;
    final hasBgMedia = AppMediaHelper.hasMedia(settings.bgMediaPath);
    final fgColor = hasBgMedia ? Colors.white : settings.textColor;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        flexibleSpace: ClipRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              color: settings.surfaceColor.withValues(alpha: hasBgMedia ? 0.35 : 0.0),
            ),
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.info_outline, color: fgColor),
            tooltip: AppTranslations.getText('client_website_title'),
            onPressed: () => _showClientWebsiteDialog(context, settings),
          ),
          PopupMenuButton<String>(
            icon: Icon(Icons.more_vert, color: fgColor),
            color: settings.surfaceColor,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            onSelected: (value) async {
              if (value == 'calibrate') {
                // Tek bir akselerometre değeri oku ve offset olarak kaydet
                final settingsProv = Provider.of<SettingsProvider>(context, listen: false);
                try {
                  final event = await accelerometerEventStream().first;
                  final rawPitch = math.atan2(event.x.abs(), event.z) * (180 / math.pi);
                  final s = settingsProv.settings;
                  s.calibPitchOffset = rawPitch;
                  settingsProv.updateSettings(s);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(AppTranslations.getText('calib_success')),
                        backgroundColor: const Color(0xFF00C853),
                        duration: const Duration(seconds: 3),
                      ),
                    );
                  }
                } catch (_) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(AppTranslations.getText('sensor_error')), backgroundColor: settings.warningColor),
                    );
                  }
                }
              } else if (value == 'settings') {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const SettingsScreen()),
                );
              }
            },
            itemBuilder: (_) => [
              PopupMenuItem<String>(
                value: 'calibrate',
                child: Row(children: [
                  Icon(Icons.tune, color: settings.detailColor, size: 20),
                  const SizedBox(width: 10),
                  Text(AppTranslations.getText('calibrate_accel'),
                      style: TextStyle(color: settings.contrastTextFor(settings.surfaceColor), fontSize: 14)),
                ]),
              ),
              PopupMenuItem<String>(
                value: 'settings',
                child: Row(children: [
                  Icon(Icons.settings, color: settings.detailColor, size: 20),
                  const SizedBox(width: 10),
                  Text(AppTranslations.getText('settings'),
                      style: TextStyle(color: settings.contrastTextFor(settings.surfaceColor), fontSize: 14)),
                ]),
              ),
            ],
          ),
        ],
      ),
      backgroundColor: settings.backgroundColor,
      body: Stack(
        children: [
          if (hasBgMedia)
            Positioned.fill(
              child: LoopingMediaWidget(
                mediaPath: settings.bgMediaPath,
                fit: BoxFit.cover,
              ),
            ),
          SafeArea(
            child: Center(
              child: Consumer<ConnectionProvider>(
                builder: (context, connection, _) {
                  final bool hasRecentLogin = connection.hasRecentLogin;
                  final bool showExpandedOptions =
                      !hasRecentLogin || _isConnectionOptionsExpanded;
                  final String welcomePrefix = AppTranslations.getText('welcome_prefix');
                  final String defaultDriver = AppTranslations.getText('default_driver_name');
                  final String driverName = settings.customDriverName.trim().isNotEmpty
                      ? settings.customDriverName.trim()
                      : defaultDriver;

                  return SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        BlurredTextChip(
                          enabled: hasBgMedia,
                          borderRadius: BorderRadius.circular(18),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          child: _DriverSketchWelcomeBanner(
                            prefix: welcomePrefix,
                            driverName: driverName,
                            accentColor: settings.detailColor,
                          ),
                        ),
                        const SizedBox(height: 18),
                        AnimatedSize(
                          duration: const Duration(milliseconds: 240),
                          curve: Curves.easeInOut,
                          child: showExpandedOptions
                              ? Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (hasRecentLogin) ...[
                                      Tooltip(
                                        message: AppTranslations.getText('hide_conn_types'),
                                        child: InkWell(
                                          borderRadius: BorderRadius.circular(24),
                                          onTap: () {
                                            setState(() {
                                              _isConnectionOptionsExpanded = false;
                                            });
                                          },
                                          child: GlassContainer(
                                            isGlassActive: hasBgMedia,
                                            solidBackgroundColor: settings.detailColor.withValues(alpha: 0.12),
                                            borderRadius: BorderRadius.circular(24),
                                            border: Border.all(
                                              color: settings.detailColor.withValues(alpha: 0.45),
                                              width: 1.2,
                                            ),
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 18,
                                              vertical: 4,
                                            ),
                                            child: Icon(
                                              Icons.keyboard_arrow_up_rounded,
                                              color: settings.detailColor,
                                              size: 28,
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 12),
                                    ],
                                    GlassContainer(
                                      isGlassActive: hasBgMedia,
                                      solidBackgroundColor: Colors.transparent,
                                      borderRadius: BorderRadius.circular(30),
                                      border: Border.all(color: settings.detailColor, width: 2),
                                      child: ElevatedButton(
                                        onPressed: () => _showConnectionDialog(context),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: settings.detailColor.withValues(alpha: hasBgMedia ? 0.15 : 0.2),
                                          foregroundColor: hasBgMedia ? Colors.white : settings.detailColor,
                                          shadowColor: Colors.transparent,
                                          padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(30),
                                          ),
                                        ),
                                        child: FittedBox(
                                          fit: BoxFit.scaleDown,
                                          child: Text(
                                            AppTranslations.getText('select_device_to_connect'),
                                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 15),
                                    GlassContainer(
                                      isGlassActive: hasBgMedia,
                                      solidBackgroundColor: Colors.transparent,
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(color: settings.detailColor.withValues(alpha: 0.5), width: 1.5),
                                      child: ElevatedButton.icon(
                                        onPressed: () => _showUsbTetheringDialog(context),
                                        icon: Icon(Icons.cable, color: fgColor),
                                        label: FittedBox(
                                          fit: BoxFit.scaleDown,
                                          child: Text(
                                            AppTranslations.getText('wired_connect_usb'),
                                            style: TextStyle(color: fgColor, fontSize: 16),
                                          ),
                                        ),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: settings.detailColor.withValues(alpha: 0.15),
                                          shadowColor: Colors.transparent,
                                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(20),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                )
                              : GlassContainer(
                                  isGlassActive: hasBgMedia,
                                  solidBackgroundColor: Colors.transparent,
                                  borderRadius: BorderRadius.circular(26),
                                  border: Border.all(
                                    color: settings.detailColor.withValues(alpha: 0.7),
                                    width: 1.5,
                                  ),
                                  child: ElevatedButton(
                                    onPressed: () {
                                      setState(() {
                                        _isConnectionOptionsExpanded = true;
                                      });
                                    },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: settings.detailColor.withValues(alpha: 0.16),
                                      foregroundColor: hasBgMedia ? Colors.white : settings.detailColor,
                                      shadowColor: Colors.transparent,
                                      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(26),
                                      ),
                                    ),
                                    child: FittedBox(
                                      fit: BoxFit.scaleDown,
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            _rememberedConnectionIcon(connection),
                                            color: hasBgMedia ? Colors.white : settings.detailColor,
                                            size: 20,
                                          ),
                                          const SizedBox(width: 10),
                                          Text(
                                            _rememberedConnectionLabel(connection),
                                            style: const TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Icon(
                                            Icons.keyboard_arrow_down_rounded,
                                            color: hasBgMedia ? Colors.white : settings.detailColor,
                                            size: 24,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                        ),
                        const SizedBox(height: 24),
                        Builder(
                          builder: (context) {
                            final hasStartMedia = AppMediaHelper.hasMedia(settings.homeStartBtnMediaPath);
                            final startBgColor = settings.homeStartBtnColor;
                            final startBtnFgColor = hasStartMedia
                                ? Colors.white
                                : startBgColor.contrastingTextColor;

                            Future<void> handleStart() async {
                              final conn = Provider.of<ConnectionProvider>(context, listen: false);
                              final connResult = await conn.ensureConnectedForDriving();
                              if (connResult.isFailure) {
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        conn.wifiIp.isEmpty && conn.selectedDevice == null
                                            ? AppTranslations.getText('please_select_device_first')
                                            : (connResult.errorMessage ??
                                                AppTranslations.getText('please_select_device_first')),
                                      ),
                                      backgroundColor: settings.warningColor,
                                      duration: const Duration(seconds: 3),
                                    ),
                                  );
                                }
                                return;
                              }

                              if (mounted) {
                                setState(() {
                                  _isConnectionOptionsExpanded = false;
                                });
                              }

                              if (!context.mounted) return;
                              final monetization =
                                  Provider.of<MonetizationProvider>(
                                    context,
                                    listen: false,
                                  );
                              AdService().showInterstitial(
                                isAdFree: monetization.isAdFree,
                                onComplete: () {
                                  if (!context.mounted) return;
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) =>
                                          const DrivingScreen(),
                                    ),
                                  );
                                },
                              );
                            }

                            if (hasStartMedia) {
                              return Container(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(30),
                                  boxShadow: [
                                    BoxShadow(
                                      color: startBgColor.withValues(alpha: 0.5),
                                      blurRadius: 12,
                                      spreadRadius: 2,
                                    ),
                                  ],
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(30),
                                  child: Material(
                                    color: Colors.transparent,
                                    child: InkWell(
                                      onTap: handleStart,
                                      child: Stack(
                                        alignment: Alignment.center,
                                        children: [
                                          Positioned.fill(
                                            child: LoopingMediaWidget(
                                              mediaPath: settings.homeStartBtnMediaPath,
                                              fit: BoxFit.cover,
                                            ),
                                          ),
                                          Padding(
                                            padding: EdgeInsets.symmetric(
                                              horizontal: math.min(60.0, MediaQuery.of(context).size.width * 0.12),
                                              vertical: 25,
                                            ),
                                            child: BlurredTextChip(
                                              enabled: true,
                                              borderRadius: BorderRadius.circular(18),
                                              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
                                              child: FittedBox(
                                                fit: BoxFit.scaleDown,
                                                child: Text(
                                                  AppTranslations.getText('start_button'),
                                                  style: const TextStyle(
                                                    fontSize: 22,
                                                    fontWeight: FontWeight.bold,
                                                    color: Colors.white,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            }

                            return ElevatedButton(
                              onPressed: handleStart,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: startBgColor,
                                foregroundColor: startBtnFgColor,
                                padding: EdgeInsets.symmetric(
                                  horizontal: math.min(60.0, MediaQuery.of(context).size.width * 0.12),
                                  vertical: 25,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(30),
                                ),
                                elevation: 10,
                                shadowColor: startBgColor.withValues(alpha: 0.5),
                              ),
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(
                                  AppTranslations.getText('start_button'),
                                  style: TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                    color: startBtnFgColor,
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showClientWebsiteDialog(BuildContext context, AppSettings settings) {
    final Color surface = settings.surfaceColor;
    final Color txt = settings.contrastTextFor(surface);
    final Color sub = settings.textSecondaryColor;
    final Color accent = settings.detailColor;

    showDialog(
      context: context,
      builder: (dctx) => AlertDialog(
        backgroundColor: surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Row(
          children: [
            Icon(Icons.info_outline, color: accent),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                AppTranslations.getText('client_website_title'),
                style: TextStyle(color: txt, fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              AppTranslations.getText('client_website_desc'),
              style: TextStyle(color: sub, fontSize: 13, height: 1.4),
            ),
            const SizedBox(height: 14),
            InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () async {
                try {
                  final ok = await const MethodChannel('Navilastro.DoYaDi/volume_keys')
                      .invokeMethod<bool>('open_url', {'url': kClientWebsiteUrl});
                  if (ok != true) {
                    await Clipboard.setData(const ClipboardData(text: kClientWebsiteUrl));
                  }
                } catch (_) {
                  await Clipboard.setData(const ClipboardData(text: kClientWebsiteUrl));
                }
              },
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: accent.withValues(alpha: 0.6)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        kClientWebsiteUrl,
                        style: TextStyle(
                          color: accent,
                          fontWeight: FontWeight.w600,
                          decoration: TextDecoration.underline,
                          decorationColor: accent,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(Icons.open_in_new_rounded, color: accent, size: 18),
                  ],
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dctx),
            child: Text(
              AppTranslations.getText('ok'),
              style: TextStyle(color: accent, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}

/// El yazısı / imza (signature) stilinde ikonsuz karşılama başlığı
class _DriverSketchWelcomeBanner extends StatelessWidget {
  final String prefix;
  final String driverName;
  final Color accentColor;

  const _DriverSketchWelcomeBanner({
    required this.prefix,
    required this.driverName,
    required this.accentColor,
  });

  static const List<String> _signatureFontFallback = [
    'Dancing Script',
    'Segoe Script',
    'Brush Script MT',
    'Snell Roundhand',
    'Lucida Handwriting',
    'cursive',
  ];

  @override
  Widget build(BuildContext context) {
    final String fullGreeting = '$prefix $driverName';

    return CustomPaint(
      painter: _SignatureSwashPainter(accentColor: accentColor),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Transform(
            alignment: Alignment.center,
            transform: Matrix4.skewX(-0.14)..rotateZ(-0.035),
            child: Stack(
              alignment: Alignment.center,
              children: [
                // 1. Katman: Yumuşak kalem mürekkebi derinlik gölgesi
                Transform.translate(
                  offset: const Offset(2.0, 2.5),
                  child: Text(
                    fullGreeting,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: 'cursive',
                      fontFamilyFallback: _signatureFontFallback,
                      fontSize: 38,
                      fontWeight: FontWeight.w600,
                      fontStyle: FontStyle.italic,
                      letterSpacing: 1.2,
                      foreground: Paint()
                        ..style = PaintingStyle.stroke
                        ..strokeWidth = 3.2
                        ..strokeCap = StrokeCap.round
                        ..strokeJoin = StrokeJoin.round
                        ..color = Colors.black.withValues(alpha: 0.75),
                    ),
                  ),
                ),
                // 2. Katman: İnce kalem ucu dış konturu (Pen Nib Stroke)
                Text(
                  fullGreeting,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'cursive',
                    fontFamilyFallback: _signatureFontFallback,
                    fontSize: 38,
                    fontWeight: FontWeight.w600,
                    fontStyle: FontStyle.italic,
                    letterSpacing: 1.2,
                    foreground: Paint()
                      ..style = PaintingStyle.stroke
                      ..strokeWidth = 1.6
                      ..strokeCap = StrokeCap.round
                      ..strokeJoin = StrokeJoin.round
                      ..color = accentColor.withValues(alpha: 0.9),
                  ),
                ),
                // 3. Katman: Akıcı imza mürekkebi dolgusu
                ShaderMask(
                  shaderCallback: (bounds) {
                    return LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Colors.white,
                        Colors.white.withValues(alpha: 0.95),
                        accentColor,
                        Colors.white,
                      ],
                      stops: const [0.0, 0.45, 0.80, 1.0],
                    ).createShader(bounds);
                  },
                  child: Text(
                    fullGreeting,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: 'cursive',
                      fontFamilyFallback: _signatureFontFallback,
                      fontSize: 38,
                      fontWeight: FontWeight.w600,
                      fontStyle: FontStyle.italic,
                      letterSpacing: 1.2,
                      color: Colors.white,
                      shadows: [
                        Shadow(
                          color: accentColor.withValues(alpha: 0.5),
                          blurRadius: 12,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// İkonsuz, sadece el yazısı imzanın altındaki zarif kalem kuyruğu (signature flourish)
class _SignatureSwashPainter extends CustomPainter {
  final Color accentColor;

  _SignatureSwashPainter({required this.accentColor});

  @override
  void paint(Canvas canvas, Size size) {
    final double w = size.width;
    final double h = size.height;

    final Paint mainPen = Paint()
      ..color = accentColor.withValues(alpha: 0.78)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final Paint featherPen = Paint()
      ..color = accentColor.withValues(alpha: 0.32)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.9
      ..strokeCap = StrokeCap.round;

    // İmza alt kuyruk darbesi (sağdan sola doğru kıvrılıp tekrar sağa uzanan gerçek imza çizgisi)
    final Path swash = Path()
      ..moveTo(w * 0.14, h - 4)
      ..cubicTo(
        w * 0.38,
        h - 11,
        w * 0.68,
        h - 9,
        w * 0.88,
        h - 5,
      )
      ..quadraticBezierTo(
        w * 0.72,
        h - 1,
        w * 0.44,
        h + 1,
      );

    final Path echoSwash = Path()
      ..moveTo(w * 0.22, h - 2)
      ..quadraticBezierTo(w * 0.56, h - 6, w * 0.84, h - 3);

    canvas.drawPath(swash, mainPen);
    canvas.drawPath(echoSwash, featherPen);
  }

  @override
  bool shouldRepaint(covariant _SignatureSwashPainter oldDelegate) {
    return oldDelegate.accentColor != accentColor;
  }
}
