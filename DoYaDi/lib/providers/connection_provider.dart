import 'package:flutter/material.dart';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';

enum ConnectionStatus { disconnected, connecting, connected }
enum ConnectionType { none, wifi, bluetooth }

class ConnectionProvider with ChangeNotifier {
  ConnectionStatus _status = ConnectionStatus.disconnected;
  ConnectionType _type = ConnectionType.none;
  
  String _wifiIp = '';
  BluetoothDevice? _selectedDevice;

  ConnectionStatus get status => _status;
  ConnectionType get type => _type;
  String get wifiIp => _wifiIp;
  BluetoothDevice? get selectedDevice => _selectedDevice;

  void setWifiIp(String ip) {
    _wifiIp = ip;
    notifyListeners();
  }

  void setBluetoothDevice(BluetoothDevice device) {
    _selectedDevice = device;
    notifyListeners();
  }

  void connect() {
    // Basic stub for connection logic
    // Normally we'd attempt Bluetooth first if _selectedDevice != null,
    // otherwise fallback to UDP with _wifiIp.
    _status = ConnectionStatus.connecting;
    notifyListeners();

    Future.delayed(const Duration(milliseconds: 500), () {
      _status = ConnectionStatus.connected;
      _type = _selectedDevice != null ? ConnectionType.bluetooth : ConnectionType.wifi;
      notifyListeners();
    });
  }

  void disconnect() {
    _status = ConnectionStatus.disconnected;
    _type = ConnectionType.none;
    notifyListeners();
  }
}
