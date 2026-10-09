import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import '../models/telemetry_data.dart';
import '../core/network/network_manager.dart';

/// Genişletilmiş telemetri dinleme servisi.
///
/// Mod 7-10 için bağımsız bir UDP dinleyicisi (port 8892) çalıştırır.
/// Girdi hattı (port 8888, 60Hz) ile **tamamen bağımsızdır** ve onu
/// asla bloke etmez.
///
/// Gelen 32-byte veriler [ExtendedTelemetryData] olarak parse edilip
/// [telemetryNotifier] üzerinden yalnızca ilgili widget'lara dağıtılır.
/// setState ile tüm ekran yeniden çizilmez.
class TelemetryListenerService {
  static final TelemetryListenerService _instance =
      TelemetryListenerService._internal();
  factory TelemetryListenerService() => _instance;
  TelemetryListenerService._internal();

  // ── Genel Durum ───────────────────────────────────────────────────────────

  /// Widget'ların dinleyeceği ana telemetri verisi.
  /// ValueListenableBuilder ile kullanılır — setState gerektirmez.
  final ValueNotifier<ExtendedTelemetryData> telemetryNotifier =
      ValueNotifier<ExtendedTelemetryData>(const ExtendedTelemetryData());

  /// Servis aktif mi
  bool _listening = false;
  bool get isListening => _listening;

  /// Son paket alım zamanı (canlılık kontrolü)
  DateTime? _lastRxTime;

  /// Son 3 saniyede paket alındı mı
  bool get isLive {
    if (!_listening || _lastRxTime == null) return false;
    return DateTime.now().difference(_lastRxTime!).inSeconds < 3;
  }

  // ── İç Kaynaklar ──────────────────────────────────────────────────────────

  RawDatagramSocket? _socket;
  StreamSubscription? _btSub;

  // ── Filtre (Low-Pass) ─────────────────────────────────────────────────────

  /// Telemetri verilerine uygulanacak düşük geçiş filtresi alfa değeri.
  /// 1.0 = filtre yok (ham veri), 0.0'a yakın = çok yumuşak.
  double filterAlpha = 1.0;

  // Filtrelenmiş intermediate değerler
  double _filteredRpm = 0;
  double _filteredSpeed = 0;
  double _filteredThrottle = 0;
  double _filteredBrake = 0;

  // ── Yaşam Döngüsü ────────────────────────────────────────────────────────

  /// Telemetri dinlemeyi başlat.
  /// Bağlantı türüne göre UDP veya BT/Serial üzerinden dinler.
  void start() {
    if (_listening) return;
    _listening = true;

    final nm = NetworkManager();
    if (nm.isBluetoothConnected) {
      _startBtListener(nm);
    } else {
      _startUdpListener();
    }

    debugPrint('[EXT_TELEMETRY] Dinleme başlatıldı.');
  }

  /// Telemetri dinlemeyi durdur ve kaynakları serbest bırak.
  void stop() {
    _listening = false;
    _socket?.close();
    _socket = null;
    _btSub?.cancel();
    _btSub = null;
    _lastRxTime = null;

    // Filtreleme state'ini sıfırla
    _filteredRpm = 0;
    _filteredSpeed = 0;
    _filteredThrottle = 0;
    _filteredBrake = 0;

    debugPrint('[EXT_TELEMETRY] Dinleme durduruldu.');
  }

  // ── UDP Dinleyici (Port 8892) ─────────────────────────────────────────────

  Future<void> _startUdpListener() async {
    try {
      _socket?.close();
      _socket = await RawDatagramSocket.bind(
        InternetAddress.anyIPv4,
        8892,
        reuseAddress: true,
      );

      _socket!.listen(
        (RawSocketEvent event) {
          if (event == RawSocketEvent.read) {
            final dg = _socket?.receive();
            if (dg != null && dg.data.length >= 32 && dg.data[0] == 0xFE) {
              _lastRxTime = DateTime.now();
              _processPacket(dg.data);
            }
          }
        },
        onError: (e) => debugPrint('[EXT_TELEMETRY] UDP error: $e'),
        onDone: () => debugPrint('[EXT_TELEMETRY] UDP done'),
      );
    } catch (e) {
      debugPrint('[EXT_TELEMETRY] UDP bind error: $e');
    }
  }

  // ── BT/Serial Dinleyici ───────────────────────────────────────────────────

  void _startBtListener(NetworkManager nm) {
    final btStream = nm.btInputStream;
    if (btStream == null) return;

    final buffer = <int>[];

    _btSub = btStream.listen((Uint8List data) {
      buffer.addAll(data);

      // 0xFE imzalı 32-byte paketleri ara
      while (buffer.length >= 32) {
        final feIndex = buffer.indexOf(0xFE);
        if (feIndex == -1) {
          buffer.clear();
          break;
        }
        if (feIndex + 32 <= buffer.length) {
          final packet = buffer.sublist(feIndex, feIndex + 32);
          buffer.removeRange(0, feIndex + 32);

          _lastRxTime = DateTime.now();
          _processPacket(packet);
        } else {
          if (feIndex > 0) buffer.removeRange(0, feIndex);
          break;
        }
      }

      // Tampon aşırı büyürse sıfırla (güvenlik)
      if (buffer.length > 512) buffer.clear();
    });
  }

  // ── Paket İşleme ─────────────────────────────────────────────────────────

  void _processPacket(List<int> bytes) {
    final raw = ExtendedTelemetryData.fromBytes(bytes);

    if (filterAlpha >= 0.99) {
      // Filtre kapalı — ham veriyi doğrudan yayınla
      telemetryNotifier.value = raw;
    } else {
      // Düşük geçiş filtresi uygula (yalnızca hızlı değişen değerlere)
      final a = filterAlpha;
      _filteredRpm = _filteredRpm + a * (raw.rpmPct - _filteredRpm);
      _filteredSpeed = _filteredSpeed + a * (raw.speedRaw - _filteredSpeed);
      _filteredThrottle =
          _filteredThrottle + a * (raw.throttlePct - _filteredThrottle);
      _filteredBrake = _filteredBrake + a * (raw.brakePct - _filteredBrake);

      telemetryNotifier.value = ExtendedTelemetryData(
        rpmPct: _filteredRpm.round(),
        speedRaw: _filteredSpeed.round(),
        gear: raw.gear,
        throttlePct: _filteredThrottle.round(),
        brakePct: _filteredBrake.round(),
        drsStatus: raw.drsStatus,
        ersDeployPct: raw.ersDeployPct,
        tyreTemps: raw.tyreTemps,
        tyreWears: raw.tyreWears,
        leftSlip: raw.leftSlip,
        rightSlip: raw.rightSlip,
        gearImpact: raw.gearImpact,
        altitudeFt: raw.altitudeFt,
        airspeedKnots: raw.airspeedKnots,
        pitchDeg: raw.pitchDeg,
        rollDeg: raw.rollDeg,
        n1Pct: raw.n1Pct,
        n2Pct: raw.n2Pct,
        egtRaw: raw.egtRaw,
        deltaTimeMs: raw.deltaTimeMs,
        flags: raw.flags,
      );
    }
  }
}
