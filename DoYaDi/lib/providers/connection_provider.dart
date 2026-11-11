import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';
import 'package:shared_preferences/shared_preferences.dart';
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
  static const Duration longInactivityThreshold = Duration(days: 7);

  ConnectionStatus _status = ConnectionStatus.disconnected;
  ConnectionType _type = ConnectionType.none;

  String _wifiIp = '';
  BluetoothDevice? _selectedDevice;
  bool _isUsbMethod = false;

  /// En son başarılı giriş yapılan bağlantı yöntemi: 'wifi', 'usb', 'bluetooth' veya ''
  String _lastConnectionMethod = '';
  bool _hasRecentLogin = false;
  bool _isLoaded = false;

  /// Son bağlantı hata mesajı (UI'da göstermek için)
  String? _lastError;

  ConnectionStatus get status => _status;
  ConnectionType get type => _type;
  String get wifiIp => _wifiIp;
  BluetoothDevice? get selectedDevice => _selectedDevice;
  String? get lastError => _lastError;
  bool get isUsbMethod => _isUsbMethod;
  String get lastConnectionMethod => _lastConnectionMethod;
  bool get hasRecentLogin => _hasRecentLogin;
  bool get isLoaded => _isLoaded;

  /// Bağlı sunucunun IP adresi (DLC servisleri için).
  /// Wi-Fi/USB: IP doluysa bağlı kabul edilir.
  String? get connectedIp => _wifiIp.isNotEmpty ? _wifiIp : null;

  /// Herhangi bir bağlantı aktif mi (Wi-Fi, USB veya Bluetooth).
  /// Gerçek NetworkManager durumunu yansıtır.
  bool get isConnected =>
      _status == ConnectionStatus.connected &&
      (_wifiIp.isNotEmpty || NetworkManager().isBluetoothConnected);

  /// Uygulama açılışında son bağlantı türünü ve son giriş zamanını yükler.
  /// Uzun süre (7 gün) girilmemişse ilk giriş görünümüne döner.
  Future<void> loadSavedConnection() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final method = prefs.getString('last_conn_method') ?? '';
      final savedIp = (prefs.getString('last_pc_ip') ?? '').trim();
      final btAddress = (prefs.getString('last_bt_address') ?? '').trim();
      final btName = prefs.getString('last_bt_name');
      final lastLoginMs = prefs.getInt('last_conn_timestamp');

      bool recent = false;
      if (lastLoginMs != null && method.isNotEmpty) {
        final lastTime = DateTime.fromMillisecondsSinceEpoch(lastLoginMs);
        final diff = DateTime.now().difference(lastTime);
        if (!diff.isNegative && diff <= longInactivityThreshold) {
          recent = true;
        }
      }

      _lastConnectionMethod = method;
      _hasRecentLogin = recent;

      if (method == 'wifi' || method == 'usb') {
        _isUsbMethod = (method == 'usb');
        if (savedIp.isNotEmpty && _wifiIp.isEmpty) {
          _wifiIp = savedIp;
        }
      } else if (method == 'bluetooth') {
        if (btAddress.isNotEmpty && _selectedDevice == null) {
          _selectedDevice = BluetoothDevice(
            address: btAddress,
            name: btName,
          );
        }
      } else if (savedIp.isNotEmpty && _wifiIp.isEmpty) {
        _wifiIp = savedIp;
      }
    } catch (e) {
      debugPrint('Saved connection load error: $e');
    } finally {
      _isLoaded = true;
      notifyListeners();
    }
  }

  Future<void> _persistConnectionMethod(String method) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final nowMs = DateTime.now().millisecondsSinceEpoch;
      await prefs.setString('last_conn_method', method);
      await prefs.setInt('last_conn_timestamp', nowMs);
      if ((method == 'wifi' || method == 'usb') && _wifiIp.isNotEmpty) {
        await prefs.setString('last_pc_ip', _wifiIp);
      } else if (method == 'bluetooth' && _selectedDevice != null) {
        await prefs.setString('last_bt_address', _selectedDevice!.address);
        if (_selectedDevice!.name != null) {
          await prefs.setString('last_bt_name', _selectedDevice!.name!);
        }
      }
      _lastConnectionMethod = method;
      _hasRecentLogin = true;
      notifyListeners();
    } catch (e) {
      debugPrint('Persist connection method error: $e');
    }
  }

  // ── Manuel IP Girişi ───────────────────────────────────────────────────────

  /// Kullanıcı IP adresini manuel girer veya discovery sonucu set eder.
  /// Bağlantı durumunu **değiştirmez** — sadece adresi kaydeder.
  void setWifiIp(String ip, {bool isUsb = false}) {
    _wifiIp = ip.trim();
    _isUsbMethod = isUsb;
    if (_wifiIp.isNotEmpty) {
      _lastConnectionMethod = isUsb ? 'usb' : 'wifi';
      if (NetworkManager().isBluetoothConnected) {
        NetworkManager().disconnectBluetooth();
      }
    }
    _lastError = null;
    notifyListeners();
  }

  /// Kullanıcı Bluetooth cihazını seçer (henüz bağlanmaz).
  void setBluetoothDevice(BluetoothDevice device) {
    _selectedDevice = device;
    _lastConnectionMethod = 'bluetooth';
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
      await _persistConnectionMethod(_isUsbMethod ? 'usb' : 'wifi');
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
        await _persistConnectionMethod('bluetooth');
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

  /// Sürücü ekranına girilirken veya geri dönüldüğünde bağlantıyı otomatik tazeler/kurar.
  /// Wi-Fi/USB modunda her zaman UDP soketini yeniden bağlar (ayarlar ekranında
  /// geçen sürede düşen/uyuyan soketi ve sunucu slotunu anında uyandırır).
  Future<Result<void>> ensureConnectedForDriving() async {
    if (!_isLoaded) {
      await loadSavedConnection();
    }

    // 1. Bluetooth aktifse veya son yöntem Bluetooth ise
    if (NetworkManager().isBluetoothConnected) {
      _status = ConnectionStatus.connected;
      _type = ConnectionType.bluetooth;
      await _persistConnectionMethod('bluetooth');
      return const Success(null);
    }

    if ((_type == ConnectionType.bluetooth ||
            (_lastConnectionMethod == 'bluetooth' && _wifiIp.isEmpty)) &&
        _selectedDevice != null) {
      return connectBluetooth(device: _selectedDevice);
    }

    // 2. Wi-Fi veya USB IP mevcutsa (veya NetworkManager'da kayıtlıysa) UDP soketini tazele
    final targetIp = _wifiIp.isNotEmpty ? _wifiIp : NetworkManager().serverIp;
    if (targetIp.isNotEmpty) {
      return connectWifi(ip: targetIp);
    }

    return const Failure('Lütfen önce bağlanılacak cihazı seçin.');
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
