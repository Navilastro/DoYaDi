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
          title: const Text('Bağlantı Ayarları'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: ipController,
                      decoration: const InputDecoration(
                        labelText: 'PC Yerel IP (Wi-Fi UDP)',
                        border: OutlineInputBorder(),
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
                        const SnackBar(content: Text('Ağ taranıyor...'), duration: Duration(seconds: 1)),
                      );
                      String? foundIp = await NetworkManager().discoverServer();
                      if (foundIp != null) {
                        ipController.text = foundIp;
                        connectionProvider.setWifiIp(foundIp);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('PC Bulundu! Bağlantı Hazır'), backgroundColor: Colors.green),
                          );
                        }
                      } else {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Ağda PC bulunamadı.'), backgroundColor: Colors.red),
                          );
                        }
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                    ),
                    child: const Text('Otomatik Bul'),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: () {
                  _showBluetoothDevicesDialog(context, connectionProvider);
                },
                icon: const Icon(Icons.bluetooth),
                label: const Text('Bluetooth Cihazı Seç'),
                style: ElevatedButton.styleFrom(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Kapat'),
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
                  const Expanded(child: Text('Bluetooth Cihazları')),
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
                    ? const Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CircularProgressIndicator(),
                            SizedBox(height: 16),
                            Text('Cihazlar aranıyor...'),
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
                              device.name ?? 'Bilinmeyen Cihaz',
                              style: const TextStyle(fontWeight: FontWeight.w600),
                            ),
                            subtitle: Text(
                              '${device.address}  •  ${isBonded ? "Eşleşmiş" : "Yeni Cihaz"}',
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
                                      content: Text('${device.name ?? device.address} ile eşleşiliyor...'),
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
                                        content: Text('${device.name ?? device.address} ile eşleşme başarısız.'),
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
                                    content: Text('${device.name ?? device.address} bağlanıyor...'),
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
                                    const SnackBar(
                                      content: Text('Bluetooth Bağlantısı Başarılı! 🎮'),
                                      backgroundColor: Colors.green,
                                    ),
                                  );
                                }
                              } else {
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Bluetooth Bağlantısı Başarısız!'),
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
                  child: Text(isScanning ? 'Taramayı Durdur' : 'Kapat'),
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
                      const SnackBar(
                        content: Text('Kalibrasyon başarılı!'),
                        backgroundColor: Color(0xFF00C853),
                        duration: Duration(seconds: 3),
                      ),
                    );
                  }
                } catch (_) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Sensör okunamadı.'), backgroundColor: Colors.red),
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
              const PopupMenuItem<String>(
                value: 'calibrate',
                child: Row(children: [
                  Icon(Icons.tune, color: Color(0xFF40E0D0), size: 20),
                  SizedBox(width: 10),
                  Text('İvmeölçeri Ayarla (Calibrate accelerometer)',
                      style: TextStyle(color: Colors.white, fontSize: 14)),
                ]),
              ),
              const PopupMenuItem<String>(
                value: 'settings',
                child: Row(children: [
                  Icon(Icons.settings, color: Color(0xFF40E0D0), size: 20),
                  SizedBox(width: 10),
                  Text('Ayarlar',
                      style: TextStyle(color: Colors.white, fontSize: 14)),
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
              child: const Text(
                'Bağlanılacak Cihazı Seç',
                style: TextStyle(fontSize: 18),
              ),
            ),
            const SizedBox(height: 30),
            ElevatedButton(
              onPressed: () async {
                final connection = Provider.of<ConnectionProvider>(context, listen: false);
                
                // 4. GÜVENLİK KONTROLÜ: Eğer ne IP girilmiş ne de Bluetooth bağlanmışsa engelle!
                if (connection.wifiIp.isEmpty && !NetworkManager().isBluetoothConnected) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Lütfen önce "Bağlanılacak Cihazı Seç" menüsünden PC\'nizi bulun veya IP adresini girin.'),
                      backgroundColor: Colors.red,
                      duration: Duration(seconds: 3),
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
              child: const Text(
                'Direksiyon Modunu Başlat',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
