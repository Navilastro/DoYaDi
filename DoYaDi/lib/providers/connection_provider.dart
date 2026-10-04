import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';
import '../core/network/network_manager.dart';
import '../core/utils/result.dart';

/// Bağlantı durumu.
enum ConnectionStatus { disconnected, connecting, connected }

/// Bağlantı türü.
enum ConnectionType { none, wifi, bluetooth }

/// Gerçek bağlantı yöneticisi.
///
/// Sahte (mock) `Future.delayed` yerine gerçek UDP discovery doğrulaması
/// ve Bluetooth soket sonuçlarını kullanır. Bağlantı ve sürüş ekranına
/// geçiş **ayrı olaylar** olarak ele alınır; `connect*()` başarılı olsa
/// bile otomatik ekran geçişi yapmaz.
class ConnectionProvider with ChangeNotifier {
  ConnectionStatus _status = ConnectionStatus.disconnected;
  ConnectionType _type = ConnectionType.none;

  String _wifiIp = '';
  BluetoothDevice? _selectedDevice;

  /// Son bağlantı hata mesajı (UI'da göstermek için)
  String? _lastError;

  ConnectionStatus get status => _status;
  ConnectionType get type => _type;
  String get wifiIp => _wifiIp;
  BluetoothDevice? get selectedDevice => _selectedDevice;
  String? get lastError => _lastError;

  /// Bağlı sunucunun IP adresi (DLC servisleri için).
  /// Wi-Fi/USB: IP doluysa bağlı kabul edilir.
  String? get connectedIp => _wifiIp.isNotEmpty ? _wifiIp : null;

  /// Herhangi bir bağlantı aktif mi (Wi-Fi, USB veya Bluetooth).
  /// Gerçek NetworkManager durumunu yansıtır.
  bool get isConnected =>
      _status == ConnectionStatus.connected &&
      (_wifiIp.isNotEmpty || NetworkManager().isBluetoothConnected);

  // ── Manuel IP Girişi ───────────────────────────────────────────────────────

  /// Kullanıcı IP adresini manuel girer veya discovery sonucu set eder.
  /// Bağlantı durumunu **değiştirmez** — sadece adresi kaydeder.
  void setWifiIp(String ip) {
    _wifiIp = ip.trim();
    _lastError = null;
    notifyListeners();
  }

  /// Kullanıcı Bluetooth cihazını seçer (henüz bağlanmaz).
  void setBluetoothDevice(BluetoothDevice device) {
    _selectedDevice = device;
    _lastError = null;
    notifyListeners();
  }

  // ── Wi-Fi / USB Bağlantısı ─────────────────────────────────────────────────

  /// Otomatik keşif: DOYADI_SEARCH → DOYADI_PC_OK doğrulaması yapar.
  ///
  /// Birden fazla sunucu açıksa ilk bulunan IP'yi döndürür.
  /// Kullanıcı sonucu görür, isterse farklı bir IP girebilir.
  Future<Result<String>> discoverServer({
    Duration timeout = const Duration(seconds: 5),
  }) async {
    _lastError = null;
    notifyListeners();
    try {
      final foundIp = await NetworkManager()
          .discoverServer()
          .timeout(timeout);
      if (foundIp != null) {
        return Success(foundIp);
      }
      return const Failure('Sunucu bulunamadı. Ağ bağlantısını kontrol edin.');
    } on TimeoutException {
      return const Failure('Sunucu arama zaman aşımına uğradı.');
    } catch (e) {
      return Failure('Keşif hatası', e);
    }
  }

  /// Wi-Fi/USB üzerinden bağlanır.
  ///
  /// [ip] boşsa ve daha önce `setWifiIp()` ile IP kaydedilmişse onu kullanır.
  /// UDP soketini başlatır ve durumu `connected` yapar.
  Future<Result<void>> connectWifi({
    String? ip,
    Duration timeout = const Duration(seconds: 5),
  }) async {
    final targetIp = (ip ?? _wifiIp).trim();
    if (targetIp.isEmpty) {
      return const Failure('IP adresi boş. Lütfen bir IP adresi girin.');
    }

    _status = ConnectionStatus.connecting;
    _type = ConnectionType.wifi;
    _lastError = null;
    notifyListeners();

    try {
      await NetworkManager()
          .initUdp(targetIp)
          .timeout(timeout);

      _wifiIp = targetIp;
      _status = ConnectionStatus.connected;
      _type = ConnectionType.wifi;
      _lastError = null;
      notifyListeners();
      return const Success(null);
    } on TimeoutException {
      _status = ConnectionStatus.disconnected;
      _type = ConnectionType.none;
      _lastError = 'Wi-Fi bağlantısı zaman aşımına uğradı.';
      notifyListeners();
      return Failure(_lastError!);
    } catch (e) {
      _status = ConnectionStatus.disconnected;
      _type = ConnectionType.none;
      _lastError = 'Wi-Fi bağlantı hatası: $e';
      notifyListeners();
      return Failure(_lastError!, e);
    }
  }

  // ── Bluetooth Bağlantısı ───────────────────────────────────────────────────

  /// Bluetooth üzerinden seçili cihaza bağlanır.
  ///
  /// [device] verilmezse daha önce `setBluetoothDevice()` ile kaydedilen
  /// cihazı kullanır. Soket açılır, gerçek bağlantı sonucu döner.
  Future<Result<void>> connectBluetooth({
    BluetoothDevice? device,
    Duration timeout = const Duration(seconds: 10),
  }) async {
    final targetDevice = device ?? _selectedDevice;
    if (targetDevice == null) {
      return const Failure('Bluetooth cihazı seçilmedi.');
    }

    _status = ConnectionStatus.connecting;
    _type = ConnectionType.bluetooth;
    _lastError = null;
    notifyListeners();

    try {
      final success = await NetworkManager()
          .initBluetooth(targetDevice.address)
          .timeout(timeout);

      if (success) {
        _selectedDevice = targetDevice;
        _wifiIp = ''; // Wi-Fi UDP'yi devre dışı bırak (çift kanal önlemi)
        _status = ConnectionStatus.connected;
        _type = ConnectionType.bluetooth;
        _lastError = null;
        notifyListeners();
        return const Success(null);
      } else {
        _status = ConnectionStatus.disconnected;
        _type = ConnectionType.none;
        _lastError = 'Bluetooth bağlantısı kurulamadı.';
        notifyListeners();
        return Failure(_lastError!);
      }
    } on TimeoutException {
      _status = ConnectionStatus.disconnected;
      _type = ConnectionType.none;
      _lastError = 'Bluetooth bağlantısı zaman aşımına uğradı.';
      notifyListeners();
      return Failure(_lastError!);
    } catch (e) {
      _status = ConnectionStatus.disconnected;
      _type = ConnectionType.none;
      _lastError = 'Bluetooth bağlantı hatası: $e';
      notifyListeners();
      return Failure(_lastError!, e);
    }
  }

  // ── Bağlantı Kesme ─────────────────────────────────────────────────────────

  /// Tüm aktif bağlantıları güvenle kapatır.
  ///
  /// UDP soketini kapatır, Bluetooth bağlantısını dispose eder,
  /// durumu sıfırlar. Sürüş ekranından çıkışta da çağrılmalıdır.
  Future<void> disconnect() async {
    try {
      NetworkManager().close();
    } catch (e) {
      debugPrint('Disconnect sırasında hata: $e');
    }
    _status = ConnectionStatus.disconnected;
    _type = ConnectionType.none;
    _wifiIp = '';
    _selectedDevice = null;
    _lastError = null;
    notifyListeners();
  }
}
