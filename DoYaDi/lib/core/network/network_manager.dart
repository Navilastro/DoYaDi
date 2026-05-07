import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';

class NetworkManager {
  static final NetworkManager _instance = NetworkManager._internal();
  factory NetworkManager() => _instance;
  NetworkManager._internal();

  RawDatagramSocket? _udpSocket;
  InternetAddress? _targetAddress;
  BluetoothConnection? _btConnection;

  bool get isBluetoothConnected => _btConnection != null && _btConnection!.isConnected;

  Future<void> initUdp(String ip) async {
    if (ip.isEmpty) return;
    try {
      // 1. Önceki açık soket varsa MUTLAKA kapat (Port çakışmasını önler)
      _udpSocket?.close(); 
      
      // 2. Boşluk tuzağını çöz: .trim() ile IP'nin sağındaki/solundaki görünmez boşlukları temizle
      _targetAddress = InternetAddress(ip.trim());
      
      _udpSocket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
    } catch (e) {
      debugPrint("UDP Init Error: $e");
    }
  }

  Future<String?> discoverServer() async {
    RawDatagramSocket? socket;
    try {
      socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
      socket.broadcastEnabled = true;

      String? foundIp;
      socket.listen((RawSocketEvent event) {
        if (event == RawSocketEvent.read) {
          Datagram? dg = socket?.receive();
          if (dg != null) {
            String message = utf8.decode(dg.data);
            if (message == "DOYADI_PC_OK") {
              foundIp = dg.address.address;
            }
          }
        }
      });

      List<int> bytes = utf8.encode("DOYADI_SEARCH");
      
      // 1. Cihazdaki aktif ağ arabirimlerini (Wi-Fi, USB Tethering vb.) al
      final interfaces = await NetworkInterface.list(
        type: InternetAddressType.IPv4,
        includeLinkLocal: true,
      );

      // Sadece wifi (wlan) ve tethering (rndis, usb) arabirimlerini filtrele
      final targetInterfaces = interfaces.where((i) {
        final name = i.name.toLowerCase();
        return name.contains('wlan') || name.contains('rndis') || name.contains('usb');
      }).toList();

      // Eğer cihaz özel bir isim verdiyse kaçırmamak adına boş gelirse hepsini al
      final interfacesToUse = targetInterfaces.isNotEmpty ? targetInterfaces : interfaces;

      // 2. Garanti olması için peş peşe 3 kez arama paketi gönder
      for (int i = 0; i < 3; i++) {
        for (var interface in interfacesToUse) {
          for (var addr in interface.addresses) {
            List<String> parts = addr.address.split('.');
            if (parts.length == 4) {
               // 2. ALT AĞ YAYIN ADRESİ: 255.255.255.255 yerine o ağın .255'i
               parts[3] = '255';
               String broadcastIp = parts.join('.');
               socket.send(bytes, InternetAddress(broadcastIp), 8889);

               // 3. MULTI-CAST SİGORTASI: USB Tethering'de PC genellikle .1 veya .2 alır
               parts[3] = '1';
               String gateway1 = parts.join('.');
               socket.send(bytes, InternetAddress(gateway1), 8889);

               parts[3] = '2';
               String gateway2 = parts.join('.');
               socket.send(bytes, InternetAddress(gateway2), 8889);
            }
          }
        }
        await Future.delayed(const Duration(milliseconds: 100));
      }

      // Yanıt için 3 saniye bekle
      for (int i = 0; i < 30; i++) {
        await Future.delayed(const Duration(milliseconds: 100));
        if (foundIp != null) {
          socket.close();
          return foundIp;
        }
      }

      socket.close();
      return null;
    } catch (e) {
      debugPrint("Discovery Error: $e");
      socket?.close();
      return null;
    }
  }

  // Payload gönder (11 byte: temel, joystick, touchpad dahil)
  void sendPayloadData(List<int> bytes) {
    if (bytes.isEmpty) return;

    if (isBluetoothConnected) {
      _btConnection!.output.add(Uint8List.fromList(bytes));
    } else if (_udpSocket != null && _targetAddress != null) {
      _udpSocket!.send(bytes, _targetAddress!, 8888);
    }
  }

  Future<bool> initBluetooth(String address) async {
    try {
      _btConnection = await BluetoothConnection.toAddress(address);
      return true;
    } catch (e) {
      debugPrint("Bluetooth Connection Error: \$e");
      return false;
    }
  }

  void disconnectBluetooth() {
    _btConnection?.dispose();
    _btConnection = null;
  }

  // Geriye dönük uyumluluk veya debug için (JSON payload)
  void sendPayload(Map<String, dynamic> data) {
    if (_udpSocket != null && _targetAddress != null) {
      String jsonStr = jsonEncode(data);
      List<int> bytes = utf8.encode(jsonStr);
      _udpSocket!.send(bytes, _targetAddress!, 9999);
    }
  }

  void close() {
    _udpSocket?.close();
    disconnectBluetooth();
  }
}
