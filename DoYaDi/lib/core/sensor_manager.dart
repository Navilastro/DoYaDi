import 'dart:async';
import 'dart:math' as math;
import 'package:sensors_plus/sensors_plus.dart';
import '../models/app_settings.dart';

/// Sensör verilerini işler ve direksiyon açısını hesaplar.
/// Normal mod: accelerometer (pitch-bazlı).
/// Kümülatif mod: gyroscope entegrasyonu (180° eşiğinden sonra).
class SensorManager {
  static final SensorManager _instance = SensorManager._internal();
  factory SensorManager() => _instance;
  SensorManager._internal();

  // ── Çıktılar ──────────────────────────────────────────────────────────────
  /// -1.0 .. 1.0 normalize edilmiş direksiyon açısı
  double steeringAngle = 0.0;

  /// Ham pitch açısı (derece). SteeringPainter'a iletilir.
  double pitchDeg = 0.0;

  /// Kümülatif toplam açı (derece) — Mod 6 gösterimi için
  double cumulativeDegrees = 0.0;

  /// Şu an kümülatif modda mı
  bool isCumulativeActive = false;

  /// Tam tur sayısı (floor(cumulativeDegrees / 360))
  int fullTurns = 0;

  // ── İç değişkenler ─────────────────────────────────────────────────────────
  StreamSubscription? _accelerometerSub;
  StreamSubscription? _gyroscopeSub;
  DateTime? _lastGyroTimestamp;
  double _accelSteeringAngle = 0.0; // Accelerometer'den hesaplanan açı

  // ── Başlat ─────────────────────────────────────────────────────────────────
  void init(AppSettings settings) {
    dispose(); // Önceki dinleyicileri temizle

    _accelerometerSub = accelerometerEventStream().listen((event) {
      _processAccelerometer(event, settings);
    });

    if (settings.useGyroscope || settings.isCumulativeSteering) {
      _lastGyroTimestamp = null;
      _gyroscopeSub = gyroscopeEventStream().listen((event) {
        _processGyroscope(event, settings);
      });
    }
  }

  // ── Accelerometer işleme ──────────────────────────────────────────────────
  void _processAccelerometer(AccelerometerEvent event, AppSettings settings) {
    // 1. Gerçek Pitch (Eğim) Açısını Bulma
    double rawPitch;
    if (settings.zeroOrientation == 2) {
      rawPitch = math.atan2(event.x.abs(), -event.z) * (180 / math.pi);
    } else {
      rawPitch = math.atan2(event.x.abs(), event.z) * (180 / math.pi);
    }
    rawPitch -= settings.calibPitchOffset;
    double pitch = rawPitch.abs();
    pitchDeg = pitch;

    // 2. Dinamik Hassasiyet Çarpanı (Multiplier) Hesaplama
    double multiplier = 1.0;
    double minMultiplier = 0.4;
    double maxMultiplier = 2.5;

    if (pitch >= 50.0 && pitch <= 70.0) {
      double t = (pitch - 50.0) / (70.0 - 50.0);
      multiplier = minMultiplier + (t * (1.0 - minMultiplier));
    } else if (pitch >= 110.0 && pitch <= 130.0) {
      double t = (pitch - 110.0) / (130.0 - 110.0);
      multiplier = 1.0 + (t * (maxMultiplier - 1.0));
    } else if (pitch < 50.0) {
      multiplier = minMultiplier;
    } else if (pitch > 130.0) {
      multiplier = maxMultiplier;
    }

    // 3. Nihai Direksiyon Verisini Hesaplama
    double maxG = (settings.steeringAngle / 180.0) * 9.8;
    double normalized = ((event.y / maxG) * multiplier).clamp(-1.0, 1.0);
    _accelSteeringAngle = normalized;

    // Kümülatif modda değilse doğrudan ata
    if (!isCumulativeActive) {
      steeringAngle = normalized;
    }

    // Kümülatif mod geçiş kontrolü (180° eşiği)
    if (settings.isCumulativeSteering) {
      final accelAngleDeg = normalized.abs() * settings.steeringAngle;
      if (!isCumulativeActive && accelAngleDeg >= 175.0) {
        // Kümülatif moda geç
        isCumulativeActive = true;
        cumulativeDegrees = normalized * settings.steeringAngle;
        _lastGyroTimestamp = null;
      } else if (isCumulativeActive && cumulativeDegrees.abs() < 170.0) {
        // Normal moda geri dön
        isCumulativeActive = false;
        cumulativeDegrees = 0.0;
        fullTurns = 0;
        steeringAngle = _accelSteeringAngle;
      }
    }
  }

  // ── Gyroscope işleme (Kümülatif Mod) ──────────────────────────────────────
  void _processGyroscope(GyroscopeEvent event, AppSettings settings) {
    if (!settings.isCumulativeSteering || !isCumulativeActive) return;

    final now = DateTime.now();
    if (_lastGyroTimestamp != null) {
      final dt = now.difference(_lastGyroTimestamp!).inMicroseconds / 1e6;
      if (dt > 0 && dt < 0.5) {
        // Z eksenindeki açısal hız (rad/s) → derece/s → açı farkı
        // İşaret tersine çevriliyor: gyro Z ekseni konvansiyonu
        // cihazın fiziksel dönüş yönüyle ters ürettiği için
        final deltaAngle = event.z * (180.0 / math.pi) * dt * -1.0;
        cumulativeDegrees += deltaAngle;

        // Tam tur sayısını güncelle
        fullTurns = cumulativeDegrees ~/ 360;

        // Kümülatif açıyı steeringAngle ayarına göre -1.0 .. 1.0'a normalize et
        final maxAngle = settings.steeringAngle;
        steeringAngle = (cumulativeDegrees / maxAngle).clamp(-1.0, 1.0);
      }
    }
    _lastGyroTimestamp = now;
  }

  // ── Temizle ────────────────────────────────────────────────────────────────
  void dispose() {
    _accelerometerSub?.cancel();
    _gyroscopeSub?.cancel();
    _accelerometerSub = null;
    _gyroscopeSub = null;
    _lastGyroTimestamp = null;
    isCumulativeActive = false;
    cumulativeDegrees = 0.0;
    fullTurns = 0;
  }
}
