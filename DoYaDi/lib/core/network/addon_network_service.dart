import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'network_manager.dart';
import '../haptic_manager.dart';

/// Eklenti veri modeli (DLC)
class AddonInfo {
  final String id;
  final int numericId; // 0x00–0xFF arası sayısal ID
  final String name;
  final String category; // "haptic", "visual", "telemetry" vb.
  bool value; // aktif/pasif

  AddonInfo({
    required this.id,
    required this.numericId,
    required this.name,
    required this.category,
    this.value = false,
  });

  factory AddonInfo.fromJson(Map<String, dynamic> json) {
    return AddonInfo(
      id: json['id'] as String,
      numericId: json['numericId'] as int? ?? 0,
      name: json['name'] as String,
      category: json['category'] as String? ?? 'general',
      value: json['value'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'numericId': numericId,
        'name': name,
        'category': category,
        'value': value,
      };
}

// ─────────────────────────────────────────────────────────────────────────────
// Telemetri veri modeli (8 byte sunucudan gelen paket)
// [0xFF, RPM, Sol Kayma, Sağ Kayma, Vites Darbesi, Boş, Boş, Boş]
// ─────────────────────────────────────────────────────────────────────────────
class TelemetryData {
  final int rpm;          // 0-255
  final int leftSlip;     // 0-255
  final int rightSlip;    // 0-255
  final int gearImpact;   // 0-255
  final int reserved1;
  final int reserved2;
  final int reserved3;

  const TelemetryData({
    this.rpm = 0,
    this.leftSlip = 0,
    this.rightSlip = 0,
    this.gearImpact = 0,
    this.reserved1 = 0,
    this.reserved2 = 0,
    this.reserved3 = 0,
  });

  /// 8 byte'lık ham veriden parse et. İlk byte imza (0xFF) olmalı.
  factory TelemetryData.fromBytes(List<int> bytes) {
    if (bytes.length < 8 || bytes[0] != 0xFF) {
      return const TelemetryData();
    }
    return TelemetryData(
      rpm: bytes[1],
      leftSlip: bytes[2],
      rightSlip: bytes[3],
      gearImpact: bytes[4],
      reserved1: bytes[5],
      reserved2: bytes[6],
      reserved3: bytes[7],
    );
  }

  @override
  String toString() =>
      'Telemetry(RPM:$rpm, L:$leftSlip, R:$rightSlip, Gear:$gearImpact)';
}

/// DLC eklenti ağ servisi.
/// Port 8891: Addon keşif & komut gönderme (3 byte).
/// Port 8890: Şartlı telemetri dinleme (8 byte).
///
/// Ana sürüş verisi (port 8888) ile TAMAMEN BAĞIMSIZ çalışır.
/// Sürüş ekranından çıkıldığında bile DLC komutları gönderilebilir
/// ve telemetri dinleme devam eder.
class AddonNetworkService {
  static final AddonNetworkService _instance = AddonNetworkService._internal();
  factory AddonNetworkService() => _instance;
  AddonNetworkService._internal();

  Timer? _globalHeartbeatTimer;
  final List<AddonInfo> _activeAddons = [];
  DateTime? _lastTelemetryRxTime;

  /// Global Eklenti Paneli Anahtar Durumu
  bool isMasterSwitchActive = false;

  /// Global Önceden Getirilmiş Eklenti Listesi
  List<AddonInfo> cachedAddons = [];

  StreamSubscription<TelemetryData>? _globalHapticSubscription;

  void updateActiveAddonState(AddonInfo addon, String? serverIp) {
    _activeAddons.removeWhere((a) => a.id == addon.id);
    if (addon.value) {
      _activeAddons.add(addon);
      sendAddonCommand(serverIp, addon);
    } else {
      // Kapatma komutunu (0x00) anında sunucuya ilet ki DLL iş parçacığı sonlandırılsın
      sendAddonCommand(
        serverIp,
        AddonInfo(
          id: addon.id,
          numericId: addon.numericId,
          name: addon.name,
          category: addon.category,
          value: false,
        ),
      );
    }

    if (_activeAddons.isNotEmpty) {
      HapticManager().setDlcHapticActive(true);
      _startGlobalHeartbeat(serverIp);
      startTelemetryStream();
    } else {
      HapticManager().setDlcHapticActive(false);
      _stopGlobalHeartbeat();
      stopTelemetryStream();
      _lastTelemetryRxTime = null;
    }
  }

  void _startGlobalHeartbeat(String? serverIp) {
    if (_globalHeartbeatTimer != null) return;
    _globalHeartbeatTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      for (final addon in _activeAddons) {
        sendAddonCommand(serverIp, addon);
      }
    });
  }

  void _stopGlobalHeartbeat() {
    _globalHeartbeatTimer?.cancel();
    _globalHeartbeatTimer = null;
  }

  // ── Addon Keşif (Port 8891) ────────────────────────────────────────────────

  /// 8891 portundan veya BT üzerinden addon listesi getir.
  /// [serverIp] doluysa UDP, boşsa/null ise Bluetooth kullanılır.
  Future<List<AddonInfo>> fetchAddons(
    String? serverIp, {
    Duration timeout = const Duration(seconds: 5),
  }) async {
    final nm = _getNetworkManager();

    // ── Bluetooth yolu ──
    if ((serverIp == null || serverIp.isEmpty) &&
        nm != null && nm.isBluetoothConnected) {
      return _fetchAddonsViaBluetooth(nm, timeout);
    }

    // ── UDP yolu ──
    if (serverIp == null || serverIp.isEmpty) return [];
    return _fetchAddonsViaUdp(serverIp, timeout);
  }

  /// UDP: 8891 portuna DOYADI_ADDON_LIST gönder, JSON yanıt bekle
  Future<List<AddonInfo>> _fetchAddonsViaUdp(
    String serverIp, Duration timeout,
  ) async {
    RawDatagramSocket? socket;
    try {
      socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);

      // Sunucuya addon listesi talebi gönder (UDP paket kaybını önlemek için tekrar gönder)
      final request = utf8.encode('DOYADI_ADDON_LIST');
      final targetAddr = InternetAddress(serverIp.trim());
      socket.send(request, targetAddr, 8891);
      Future.delayed(const Duration(milliseconds: 250), () {
        if (socket != null) {
          try {
            socket.send(request, targetAddr, 8891);
          } catch (_) {}
        }
      });

      final completer = Completer<List<AddonInfo>>();

      socket.listen((RawSocketEvent event) {
        if (event == RawSocketEvent.read) {
          final dg = socket?.receive();
          if (dg != null && !completer.isCompleted) {
            try {
              final jsonStr = utf8.decode(dg.data);
              final list = jsonDecode(jsonStr) as List;
              final addons = list
                  .map((e) => AddonInfo.fromJson(e as Map<String, dynamic>))
                  .toList();
              completer.complete(addons);
            } catch (e) {
              debugPrint('Addon JSON parse error: $e');
              if (!completer.isCompleted) completer.complete([]);
            }
          }
        }
      });

      // Timeout
      Future.delayed(timeout, () {
        if (!completer.isCompleted) {
          completer.complete([]);
        }
      });

      final result = await completer.future;
      socket.close();
      return result;
    } catch (e) {
      debugPrint('Addon fetch error: $e');
      socket?.close();
      return [];
    }
  }

  /// Bluetooth: Seri port üzerinden DOYADI_ADDON_LIST gönder,
  /// [0xAA, lenHigh, lenLow, ...JSON_UTF8...] formatında yanıt bekle.
  Future<List<AddonInfo>> _fetchAddonsViaBluetooth(
    NetworkManager nm, Duration timeout,
  ) async {
    try {
      final btConn = nm.btConnection;
      final btStream = nm.btInputStream;
      if (btConn == null || btStream == null) return [];

      // Talebi gönder
      final request = utf8.encode('DOYADI_ADDON_LIST');
      btConn.output.add(Uint8List.fromList(request));

      final completer = Completer<List<AddonInfo>>();
      final buffer = <int>[];
      late final StreamSubscription sub;
      sub = btStream.listen((Uint8List data) {
        buffer.addAll(data);

        // 0xAA imzası ara
        final aaIndex = buffer.indexOf(0xAA);
        if (aaIndex == -1 || aaIndex + 3 > buffer.length) return;

        // Uzunluğu oku
        final lenHigh = buffer[aaIndex + 1];
        final lenLow = buffer[aaIndex + 2];
        final jsonLen = (lenHigh << 8) | lenLow;

        // Makul uzunluk kontrolü: JSON listesi 0 < len < 16384 olmalı.
        // Sürüş verisindeki rastlantısal 0xAA byte'larını (170 decimal)
        // yanlışlıkla imza olarak algılamayı önler.
        if (jsonLen <= 0 || jsonLen > 16384) {
          // Bu 0xAA rastlantısal bir sürüş verisi byte'ı — atla
          buffer.removeRange(0, aaIndex + 1);
          return;
        }

        if (aaIndex + 3 + jsonLen > buffer.length) return; // Tam veri bekleniyor

        // JSON parse
        try {
          final jsonBytes = buffer.sublist(aaIndex + 3, aaIndex + 3 + jsonLen);
          final jsonStr = utf8.decode(jsonBytes);
          final list = jsonDecode(jsonStr) as List;
          final addons = list
              .map((e) => AddonInfo.fromJson(e as Map<String, dynamic>))
              .toList();
          if (!completer.isCompleted) completer.complete(addons);
        } catch (e) {
          debugPrint('Addon BT JSON parse error: $e');
          if (!completer.isCompleted) completer.complete([]);
        }
      });

      // Timeout
      Future.delayed(timeout, () {
        sub.cancel();
        if (!completer.isCompleted) completer.complete([]);
      });

      final result = await completer.future;
      sub.cancel();
      return result;
    } catch (e) {
      debugPrint('Addon BT fetch error: $e');
      return [];
    }
  }

  // ── Addon Komut Gönderme — 3 Byte (Bağımsız Kanal) ────────────────────────
  //
  // Format: [0xEE, Eklenti_ID, Durum]
  //   [0] = 0xEE — DLC komut imzası
  //   [1] = Eklentinin sayısal ID'si (numericId, 0x00–0xFF)
  //   [2] = 0x01 (Aç) veya 0x00 (Kapat)
  //
  // UDP: Ephemeral soket → port 8891. Ana sürüş soketi (8888) ile ilişkisi yok.
  // BT/Serial: Mevcut açık BluetoothConnection üzerinden gönderilir.

  /// 3 byte'lık DLC komut paketi gönderir.
  /// Bağlantı türüne göre otomatik olarak UDP veya BT/Serial kullanır.
  /// Sürüş ekranı aktif olmasa bile çalışır (Watchdog bypass).
  void sendAddonCommand(String? serverIp, AddonInfo addon) {
    final targetIp = (serverIp != null && serverIp.isNotEmpty)
        ? serverIp
        : NetworkManager().serverIp;

    final packet = _buildCommandPacket(addon);
    final nm = _getNetworkManager();

    if (nm != null && nm.isBluetoothConnected) {
      // ── BT / Serial yolu ──
      _sendViaBluetooth(nm, packet);
    } else if (targetIp.isNotEmpty) {
      // ── UDP yolu (bağımsız ephemeral soket) ──
      _sendViaUdp(targetIp, packet);
    } else {
      debugPrint('DLC Command: Bağlantı yok (ne UDP ne BT).');
    }
  }

  /// Komut paketini oluşturur: [0xEE, numericId, durum] (3 Bayt)
  List<int> _buildCommandPacket(AddonInfo addon) {
    return [0xEE, addon.numericId & 0xFF, addon.value ? 0x01 : 0x00];
  }

  /// UDP ile bağımsız soket üzerinden gönderir.
  void _sendViaUdp(String serverIp, List<int> packet) {
    try {
      RawDatagramSocket.bind(InternetAddress.anyIPv4, 0).then((socket) {
        final target = InternetAddress(serverIp.trim());
        socket.send(packet, target, 8891);
        Future.delayed(const Duration(milliseconds: 40), () {
          try {
            socket.send(packet, target, 8891);
          } catch (_) {}
          Future.delayed(const Duration(milliseconds: 40), () {
            try {
              socket.send(packet, target, 8891);
            } catch (_) {}
            socket.close();
          });
        });
      });
    } catch (e) {
      debugPrint('DLC UDP send error: $e');
    }
  }

  /// Bluetooth/Serial üzerinden mevcut açık bağlantıdan gönderir.
  void _sendViaBluetooth(NetworkManager nm, List<int> packet) {
    try {
      nm.sendPayloadData(packet);
    } catch (e) {
      debugPrint('DLC BT send error: $e');
    }
  }

  /// NetworkManager singleton'ına erişim.
  NetworkManager? _getNetworkManager() {
    _nm ??= _resolveNetworkManager();
    return _nm;
  }
  NetworkManager? _nm;

  static NetworkManager? _resolveNetworkManager() {
    try {
      return NetworkManager();
    } catch (_) {
      return null;
    }
  }

  // ── Telemetri Dinleme — 8 Byte (Şartlı / Dinamik) ────────────────────────
  //
  // Format: [0xFF, RPM, Sol Kayma, Sağ Kayma, Vites Darbesi, Boş, Boş, Boş]
  //
  // DİNAMİK DİNLEME:
  //   - Sadece ek paket panelinden ilgili eklenti AKTİF edildiğinde başlar.
  //   - Eklenti kapatıldığında dinleme kesilir ve kaynaklar serbest bırakılır.
  //
  // UDP: Port 8890'dan dinler.
  // BT/Serial: Mevcut stream'den 0xFF imzalı 8-byte paketleri filtreler.

  RawDatagramSocket? _telemetrySocket;
  StreamController<TelemetryData>? _telemetryController;
  StreamSubscription? _btTelemetrySub;
  bool _telemetryListening = false;

  /// Telemetri dinleme aktif mi
  bool get isTelemetryActive => _telemetryListening;

  /// Gerçek zamanlı telemetri paketleri geliyor mu (son 3 saniyede paket alındı mı)
  bool get isTelemetryLive {
    if (!_telemetryListening || _lastTelemetryRxTime == null) return false;
    return DateTime.now().difference(_lastTelemetryRxTime!).inSeconds < 3;
  }

  /// Telemetri dinlemeyi başlat.
  /// Bağlantı türüne göre UDP veya BT/Serial üzerinden dinler.
  /// Gelen 8-byte veriler [TelemetryData] olarak yayınlanır.
  Stream<TelemetryData> startTelemetryStream() {
    if (_telemetryListening && _telemetryController != null) {
      return _telemetryController!.stream;
    }

    stopTelemetryStream();

    _telemetryController = StreamController<TelemetryData>.broadcast();
    _telemetryListening = true;
    HapticManager().setDlcHapticActive(true);

    // Global Haptic Dinleyicisi: Sürüş ekranında veya başka sekmelerde
    // eklenti paneli kapalı görünmeden telemetri titreşimlerini çalıştırmaya devam eder.
    _globalHapticSubscription?.cancel();
    _globalHapticSubscription = _telemetryController!.stream.listen((TelemetryData data) {
      HapticManager().processTelemetry(data);
    });

    final nm = _getNetworkManager();
    if (nm != null && nm.isBluetoothConnected) {
      _startBtTelemetry(nm);
    } else {
      _startUdpTelemetry();
    }

    return _telemetryController!.stream;
  }

  /// UDP: Port 8890'dan telemetri dinle
  Future<void> _startUdpTelemetry() async {
    try {
      _telemetrySocket?.close();
      _telemetrySocket = await RawDatagramSocket.bind(
        InternetAddress.anyIPv4,
        8890,
        reuseAddress: true,
      );

      debugPrint('[TELEMETRY] UDP 8890 dinleme başlatıldı.');

      _telemetrySocket!.listen(
        (RawSocketEvent event) {
          if (event == RawSocketEvent.read) {
            final dg = _telemetrySocket?.receive();
            if (dg != null &&
                dg.data.length >= 8 &&
                dg.data[0] == 0xFF &&
                _telemetryController != null) {
              _lastTelemetryRxTime = DateTime.now();
              final telemetry = TelemetryData.fromBytes(dg.data);
              _telemetryController!.add(telemetry);
            }
          }
        },
        onError: (e) => debugPrint('Telemetry UDP error: $e'),
        onDone: () => debugPrint('Telemetry UDP done'),
      );
    } catch (e) {
      debugPrint('Telemetry UDP bind error: $e');
      // Hatayı stream'e ilet ki UI katmanı bilgilendirilsin
      _telemetryController?.addError(e);
    }
  }

  /// BT/Serial: Mevcut stream'den 0xFF imzalı 8-byte paketleri filtrele.
  /// Sürüş verisi (5-11 byte, 0x00-0x80 başlangıçlı) ile karışmaz
  /// çünkü telemetri imzası 0xFF'dir.
  void _startBtTelemetry(NetworkManager nm) {
    try {
      final btStream = nm.btInputStream;
      if (btStream == null) return;

      // 8-byte tampon: seri portta veriler parçalı gelebilir
      final buffer = <int>[];

      _btTelemetrySub = btStream.listen((Uint8List data) {
        buffer.addAll(data);

        // Tampon içinde 0xFF imzası ara
        while (buffer.length >= 8) {
          final ffIndex = buffer.indexOf(0xFF);
          if (ffIndex == -1) {
            // İmza yok — tamponu temizle (sürüş verisi olabilir)
            buffer.clear();
            break;
          }
          if (ffIndex + 8 <= buffer.length) {
            // 8 byte'lık telemetri paketi bulundu
            final packet = buffer.sublist(ffIndex, ffIndex + 8);
            buffer.removeRange(0, ffIndex + 8);

            if (_telemetryController != null) {
              final telemetry = TelemetryData.fromBytes(packet);
              _telemetryController!.add(telemetry);
            }
          } else {
            // Tam paket için yeterli byte yok — bekle
            if (ffIndex > 0) buffer.removeRange(0, ffIndex);
            break;
          }
        }

        // Tampon aşırı büyürse sıfırla (güvenlik)
        if (buffer.length > 256) buffer.clear();
      });
    } catch (e) {
      debugPrint('Telemetry BT listen error: $e');
    }
  }

  /// Telemetri dinlemeyi durdur ve kaynakları serbest bırak.
  void stopTelemetryStream() {
    _globalHapticSubscription?.cancel();
    _globalHapticSubscription = null;
    _telemetryListening = false;
    _telemetrySocket?.close();
    _telemetrySocket = null;
    _btTelemetrySub?.cancel();
    _btTelemetrySub = null;
    _telemetryController?.close();
    _telemetryController = null;
  }

  /// Tüm bağlantıları kapat ve sunucudaki çalışan DLL iş parçacıklarını durdur
  void dispose() {
    for (final addon in _activeAddons) {
      sendAddonCommand(
        null,
        AddonInfo(
          id: addon.id,
          numericId: addon.numericId,
          name: addon.name,
          category: addon.category,
          value: false,
        ),
      );
    }
    _activeAddons.clear();
    _stopGlobalHeartbeat();
    stopTelemetryStream();
    _lastTelemetryRxTime = null;
  }
}
