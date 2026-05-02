import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';
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
      
      // 3. Wi-Fi ağlarında tek UDP paketi kaybolabilir! 
      // Garanti olması için peş peşe 3 kez arama paketi gönderiyoruz.
      for (int i = 0; i < 3; i++) {
        socket.send(bytes, InternetAddress("255.255.255.255"), 8889);
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

  // Payload gönder (5 byte: temel, 9 byte: joystick dahil)
  void sendPayload5Bytes(List<int> bytes) {
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
