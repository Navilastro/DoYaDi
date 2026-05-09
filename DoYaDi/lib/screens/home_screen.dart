import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sensors_plus/sensors_plus.dart';

import '../providers/settings_provider.dart';
import '../providers/connection_provider.dart';
import '../core/network/network_manager.dart';
import 'settings_screen.dart';
import 'driving_screen.dart';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';
import 'package:permission_handler/permission_handler.dart';
import '../core/utils/app_translations.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    _requestPermissions();
  }

  Future<void> _requestPermissions() async {
    await [
      Permission.bluetooth,
      Permission.bluetoothAdvertise,
      Permission.bluetoothConnect,
      Permission.bluetoothScan,
      Permission.location,
    ].request();
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
          content: Column(
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
                        connectionProvider.setWifiIp(val);
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
                      String? foundIp = await NetworkManager().discoverServer();
                      if (foundIp != null) {
                        ipController.text = foundIp;
                        connectionProvider.setWifiIp(foundIp);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(AppTranslations.getText('pc_found_ready')), backgroundColor: Colors.green),
                          );
                        }
                      } else {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(AppTranslations.getText('pc_not_found')), backgroundColor: Colors.red),
                          );
                        }
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                    ),
                    child: Text(AppTranslations.getText('auto_find')),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: () {
                  _showBluetoothDevicesDialog(context, connectionProvider);
                },
                icon: const Icon(Icons.bluetooth),
                label: Text(AppTranslations.getText('select_bt_device')),
                style: ElevatedButton.styleFrom(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                ),
              ),
            ],
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
                height: 320,
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

                              final bool success =
                                  await NetworkManager().initBluetooth(device.address);

                              if (success) {
                                connectionProvider.setBluetoothDevice(device);
                                connectionProvider.setWifiIp(''); // Wi-Fi UDP'yi devre dışı bırak
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                     SnackBar(
                                      content: Text(AppTranslations.getText('bt_connection_success')),
                                      backgroundColor: Colors.green,
                                    ),
                                  );
                                }
                              } else {
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                     SnackBar(
                                      content: Text(AppTranslations.getText('bt_connection_failed')),
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
              Text(
                AppTranslations.getText('usb_zero_delay'),
                style: const TextStyle(color: Colors.white, fontSize: 18),
              ),
            ],
          ),
          content: Column(
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
                String? foundIp = await NetworkManager().discoverServer();
                if (foundIp != null) {
                  connectionProvider.setWifiIp(foundIp);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(AppTranslations.getText('pc_found_ready')), backgroundColor: Colors.green),
                    );
                  }
                } else {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(AppTranslations.getText('pc_not_found_usb')), backgroundColor: Colors.red),
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
    
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: Colors.white),
            color: const Color(0xFF12122A),
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
                      SnackBar(content: Text(AppTranslations.getText('sensor_error')), backgroundColor: Colors.red),
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
                  const Icon(Icons.tune, color: Color(0xFF40E0D0), size: 20),
                  const SizedBox(width: 10),
                  Text(AppTranslations.getText('calibrate_accel'),
                      style: const TextStyle(color: Colors.white, fontSize: 14)),
                ]),
              ),
              PopupMenuItem<String>(
                value: 'settings',
                child: Row(children: [
                  const Icon(Icons.settings, color: Color(0xFF40E0D0), size: 20),
                  const SizedBox(width: 10),
                  Text(AppTranslations.getText('settings'),
                      style: const TextStyle(color: Colors.white, fontSize: 14)),
                ]),
              ),
            ],
          ),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton(
              onPressed: () => _showConnectionDialog(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: settings.detailColor.withValues(alpha: 0.2),
                foregroundColor: settings.detailColor,
                padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                  side: BorderSide(color: settings.detailColor, width: 2),
                ),
              ),
              child: Text(
                AppTranslations.getText('select_device_to_connect'),
                style: const TextStyle(fontSize: 18),
              ),
            ),
            const SizedBox(height: 15),
            ElevatedButton.icon(
              onPressed: () => _showUsbTetheringDialog(context),
              icon: const Icon(Icons.cable, color: Colors.white),
              label: Text(
                AppTranslations.getText('wired_connect_usb'),
                style: const TextStyle(color: Colors.white, fontSize: 16),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: settings.detailColor.withValues(alpha: 0.15),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                  side: BorderSide(color: settings.detailColor.withValues(alpha: 0.5), width: 1.5),
                ),
              ),
            ),
            const SizedBox(height: 30),
            ElevatedButton(
              onPressed: () async {
                final connection = Provider.of<ConnectionProvider>(context, listen: false);
                
                // 4. GÜVENLİK KONTROLÜ: Eğer ne IP girilmiş ne de Bluetooth bağlanmışsa engelle!
                if (connection.wifiIp.isEmpty && !NetworkManager().isBluetoothConnected) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(AppTranslations.getText('please_select_device_first')),
                      backgroundColor: Colors.red,
                      duration: const Duration(seconds: 3),
                    ),
                  );
                  return; // Uygulamanın sürüş ekranına geçmesini durdur
                }

                // IP varsa soketi güvenle başlat
                if (connection.wifiIp.isNotEmpty) {
                  await NetworkManager().initUdp(connection.wifiIp);
                }
                
                if (!context.mounted) return;
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const DrivingScreen()),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: settings.detailColor,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(horizontal: 60, vertical: 25),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
                elevation: 10,
                shadowColor: settings.detailColor.withValues(alpha: 0.5),
              ),
              child: Text(
                AppTranslations.getText('start_steering_mode'),
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
