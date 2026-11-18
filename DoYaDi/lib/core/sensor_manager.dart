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

  /// Sağ analog X ve Y ekseni (Gyro-to-Right Analog için) (-1.0 .. 1.0)
  double rightAnalogX = 0.0;
  double rightAnalogY = 0.0;

  /// Fare Delta X ve Y (Gyro-to-Mouse için)
  double mouseDeltaX = 0.0;
  double mouseDeltaY = 0.0;
  double _lastTargetMx = 0.0;
  double _lastTargetMy = 0.0;

  // Pilot modu için biriken (accumulated) açılar
  double _accumulatedRaPitch = 0.0;
  double _accumulatedRaYaw = 0.0;
  double _accumulatedMousePitch = 0.0;
  double _accumulatedMouseYaw = 0.0;

  // ── Peak-Hold Anti-Drift (Tepe Tutma) ─────────────────────────────────────
  // Maksimum sınıra ulaşıldıktan sonra devam eden fiziksel dönüşü izler.
  // Geri dönüşte, bu fazla dönüş miktarı eritilene kadar çıktı sabitlenerek
  // merkez kaymasını (drift) önler.
  double _overflowRaYaw = 0.0;
  double _overflowRaPitch = 0.0;
  double _overflowMouseYaw = 0.0;
  double _overflowMousePitch = 0.0;

  /// 0: Kapalı, 1: Pilot (Mutlak/Direkt), 2: FPS (Yumuşatılmış/Sürüklenmeli)
  int rightAnalogMode = 0;
  double rightAnalogSensitivity = 1.0;
  double rightAnalogDeadzone = 7.0;

  /// Yarışçı modu: Sadece Yaw bakışı yapar, Pitch ekseni (yukarı/aşağı) sıfırlanır.
  bool rightAnalogOnlyYaw = false;
  
  /// 0: Kapalı, 1: Pilot, 2: FPS
  int mouseMode = 0;
  double mouseSensitivity = 1.0;
  double mouseDeadzone = 7.0;

  /// Kümülatif toplam açı (derece) — Mod 6 gösterimi için
  double cumulativeDegrees = 0.0;

  /// Şu an kümülatif modda mı
  bool isCumulativeActive = false;

  /// Tam tur sayısı (floor(cumulativeDegrees / 360))
  int fullTurns = 0;

  // ── Mod 8 (Rahat Sürüş / Chill Drive - Dikey Tutuş) İzole Çıktılar ─────────
  /// Mod 8 direksiyon açısı (-1.0 .. 1.0)
  double chillSteering = 0.0;

  /// Mod 8 kalibre edilmiş Pitch farkı (derece: + öne eğim/gaz, - geriye eğim/fren)
  double chillPitchDeg = 0.0;

  /// Mod 8 kalibre edilmiş Roll/Yaw farkı (derece: - sol, + sağ)
  double chillRollDeg = 0.0;

  /// Mod 8 sensör tabanlı Gaz (0.0 .. 1.0)
  double chillGas = 0.0;

  /// Mod 8 sensör tabanlı Fren (0.0 .. 1.0)
  double chillBrake = 0.0;

  double _lastRawChillPitch = 45.0;
  double _lastRawChillRoll = 0.0;
  double _chillBasePitch = 45.0;
  double _chillBaseRoll = 0.0;
  double _chillAccumYaw = 0.0;
  bool _chillInitialCalibrated = false;

  double get chillBasePitch => _chillBasePitch;
  double get chillBaseRoll => _chillBaseRoll;

  void setChillCalibration(double basePitch, double baseRoll) {
    _chillBasePitch = basePitch;
    _chillBaseRoll = baseRoll;
    _chillAccumYaw = 0.0;
    _chillInitialCalibrated = true;
    chillSteering = 0.0;
    chillPitchDeg = 0.0;
    chillRollDeg = 0.0;
    chillGas = 0.0;
    chillBrake = 0.0;
  }

  // ── Mod 9 (Arcade Flight / HOTAS - Yatay Uçuş Kontrolü) İzole Çıktılar ─────
  /// Sol Analog X: Roll / Aileron (-1.0 Sol Yatış .. +1.0 Sağ Yatış)
  double flightRoll = 0.0;

  /// Sol Analog Y: Pitch / Elevator (-1.0 Burun Yukarı/Aşağı .. +1.0)
  double flightPitch = 0.0;

  /// Sağ Analog X / Rudder: Yaw (-1.0 Sol Dümen .. +1.0 Sağ Dümen)
  double flightYaw = 0.0;

  double flightPitchDeg = 0.0;
  double flightRollDeg = 0.0;
  double flightYawDeg = 0.0;
  bool flightInvertPitch = false;

  double _lastRawFlightPitch = 0.0;
  double _lastRawFlightRoll = 0.0;
  double _flightBasePitch = 0.0;
  double _flightBaseRoll = 0.0;
  double _flightAccumYaw = 0.0;
  bool _flightInitialCalibrated = false;

  // ── İç değişkenler ─────────────────────────────────────────────────────────
  StreamSubscription? _accelerometerSub;
  StreamSubscription? _gyroscopeSub;
  DateTime? _lastGyroTimestamp;
  double _accelSteeringAngle = 0.0; // Accelerometer'den hesaplanan açı
  
  // Otomatik merkezleme için hareketsizlik takibi
  DateTime? _lastGyroMovementTimestamp;

  // ── Başlat ─────────────────────────────────────────────────────────────────
  void init(AppSettings settings) {
    dispose(); // Önceki dinleyicileri temizle

    _accelerometerSub = accelerometerEventStream().listen(
      (event) {
        _processAccelerometer(event, settings);
      },
      onError: (_) {},
    );

    // Jiroskop: Kümülatif direksiyon, Sensörle Bakış (Global) veya Mod 5 gyro özellikleri için her zaman hazır tut
    _startGyroscope(settings);
  }

  void _startGyroscope(AppSettings settings) {
    if (_gyroscopeSub != null) return;
    _lastGyroTimestamp = null;
    _gyroscopeSub = gyroscopeEventStream().listen(
      (event) {
        _processGyroscope(event, settings);
      },
      onError: (_) {},
    );
  }

  void ensureGyroscopeActive(AppSettings settings) {
    if (_gyroscopeSub == null) {
      _startGyroscope(settings);
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

    // Gyro-to-Right Analog and Mouse will be processed in _processGyroscope
    // Here we only keep _accelSteeringAngle and normal steering
    double maxG = (settings.steeringAngle / 180.0) * 9.8;
    double normalized = ((event.y / maxG) * multiplier).clamp(-1.0, 1.0);
    _accelSteeringAngle = normalized;

    if (!isCumulativeActive) {
      steeringAngle = normalized;
    }

    if (settings.isCumulativeSteering) {
      final accelAngleDeg = normalized.abs() * settings.steeringAngle;
      if (!isCumulativeActive && accelAngleDeg >= 175.0) {
        isCumulativeActive = true;
        cumulativeDegrees = normalized * settings.steeringAngle;
        _lastGyroTimestamp = null;
      } else if (isCumulativeActive && cumulativeDegrees.abs() < 170.0) {
        isCumulativeActive = false;
        cumulativeDegrees = 0.0;
        fullTurns = 0;
        steeringAngle = _accelSteeringAngle;
      }
    }

    // ── Mod 8 (Rahat Sürüş / Dikey Tek El Modu) İzole Hesaplama ──────────────
    // Temel sürüş modlarına (Mod 0-7) kesinlikle müdahale etmez.
    if (settings.defaultDrivingMode == 8) {
      // Dikey (Portrait) tutuşta:
      // - event.x: Sağa/sola yatırma (Sol +x, Sağ -x -> -event.x ile sağ pozitif)
      // - event.y ve event.z: Öne/arkaya eğim (Pitch)
      final double yzMag = math.sqrt(event.y * event.y + event.z * event.z);
      final double rawRoll = math.atan2(-event.x, math.max(0.1, yzMag)) * (180.0 / math.pi);
      // Telefon dikken y~9.8, z~0 (0°); ekran yukarı/masaya yatıkken y~0, z~9.8 (90°)
      // Öne yatırma -> rawPitch artar (Gaz), kendine çekme -> rawPitch azalır (Fren)
      final double rawPitchPort = math.atan2(event.z, event.y) * (180.0 / math.pi);

      _lastRawChillRoll = rawRoll;
      _lastRawChillPitch = rawPitchPort;

      if (!_chillInitialCalibrated) {
        _chillBasePitch = rawPitchPort;
        _chillBaseRoll = rawRoll;
        _chillInitialCalibrated = true;
      }

      final double deltaPitch = rawPitchPort - _chillBasePitch;
      final double deltaRoll = rawRoll - _chillBaseRoll;
      chillPitchDeg = deltaPitch;

      // Direksiyon (Eksen 0: Roll - Sağa/Sola Yatırma)
      if (settings.chillSteeringAxis == 0) {
        chillRollDeg = deltaRoll;
        final double maxRoll = (settings.steeringAngle / 4.0).clamp(15.0, 65.0);
        const double rollDeadzone = 2.0;
        if (deltaRoll.abs() <= rollDeadzone) {
          chillSteering = 0.0;
        } else {
          final double effRoll = (deltaRoll.abs() - rollDeadzone) * deltaRoll.sign;
          chillSteering = ((effRoll / maxRoll) * settings.chillSteeringSensitivity).clamp(-1.0, 1.0);
        }
      }

      // Pitch -> Gaz / Fren (Ölü alan: ±4.0°, Tam pedal menzili: 24°)
      const double pitchDeadzone = 4.0;
      const double fullPedalRangeDeg = 24.0;
      if (deltaPitch > pitchDeadzone) {
        chillGas = (((deltaPitch - pitchDeadzone) / fullPedalRangeDeg) *
                settings.chillGasBrakeSensitivity)
            .clamp(0.0, 1.0);
        chillBrake = 0.0;
      } else if (deltaPitch < -pitchDeadzone) {
        chillBrake = (((-deltaPitch - pitchDeadzone) / fullPedalRangeDeg) *
                settings.chillGasBrakeSensitivity)
            .clamp(0.0, 1.0);
        chillGas = 0.0;
      } else {
        chillGas = 0.0;
        chillBrake = 0.0;
      }
    }

    // ── Mod 9 & Mod 10 (Flight / HOTAS / MFD - WT, DCS, MSFS) İzole Hesaplama ──
    // Temel sürüş modlarına (Mod 0-7) kesinlikle müdahale etmez.
    if (settings.defaultDrivingMode == 9 || settings.defaultDrivingMode == 10) {
      // Yatay (Landscape) tutuşta:
      // Roll (Aileron): event.y (sağa/sola yatırma)
      // Pitch (Elevator): event.z ve event.x (öne/geriye eğme)
      final double xzMag = math.sqrt(event.x * event.x + event.z * event.z);
      final double rawFlightRoll =
          math.atan2(event.y, math.max(0.1, xzMag)) * (180.0 / math.pi);
      final double rawFlightPitch =
          math.atan2(event.z, math.max(0.1, event.x.abs())) * (180.0 / math.pi);

      _lastRawFlightRoll = rawFlightRoll;
      _lastRawFlightPitch = rawFlightPitch;

      if (!_flightInitialCalibrated) {
        _flightBaseRoll = rawFlightRoll;
        _flightBasePitch = rawFlightPitch;
        _flightInitialCalibrated = true;
      }

      final double deltaRoll = rawFlightRoll - _flightBaseRoll;
      final double deltaPitch = rawFlightPitch - _flightBasePitch;

      flightRollDeg = deltaRoll;
      flightPitchDeg = deltaPitch;

      // Roll: ±35° tam sapma (flightRollSensitivity ile ölçeklenir), derece cinsinden ayarlanabilir ölü bölge (varsayılan 0.0°)
      final double rollDeadzone = settings.flightRollDeadzone.clamp(0.0, 15.0);
      const double maxRollRange = 35.0;
      if (rollDeadzone > 0.0 && deltaRoll.abs() <= rollDeadzone) {
        flightRoll = 0.0;
      } else {
        final double effRoll = (deltaRoll.abs() - rollDeadzone) * deltaRoll.sign;
        flightRoll = ((effRoll / maxRollRange) * settings.flightRollSensitivity)
            .clamp(-1.0, 1.0);
      }

      // Pitch: ±28° tam sapma (flightPitchSensitivity ile ölçeklenir), derece cinsinden ayarlanabilir ölü bölge (varsayılan 0.0°)
      // Varsayılan uçuş mantığı: Telefonu kendine çekmek (deltaPitch < 0) -> Burun Yukarı (Pitch Up)
      final double pitchDeadzone = settings.flightPitchDeadzone.clamp(0.0, 15.0);
      const double maxPitchRange = 28.0;
      if (pitchDeadzone > 0.0 && deltaPitch.abs() <= pitchDeadzone) {
        flightPitch = 0.0;
      } else {
        final double effPitch = (deltaPitch.abs() - pitchDeadzone) * deltaPitch.sign;
        final double dir = flightInvertPitch ? -1.0 : 1.0;
        flightPitch = ((effPitch / maxPitchRange) * settings.flightPitchSensitivity * dir)
            .clamp(-1.0, 1.0);
      }
    }
  }

  // ── Gyroscope işleme (Kümülatif Mod & Right Analog / Mouse) ───────────────
  void _processGyroscope(GyroscopeEvent event, AppSettings settings) {
    final now = DateTime.now();
    if (_lastGyroTimestamp != null) {
      final dt = now.difference(_lastGyroTimestamp!).inMicroseconds / 1e6;
      if (dt > 0 && dt < 0.5) {
        
        // 1. Kümülatif Direksiyon Modu (Z ekseni - Roll)
        if (settings.isCumulativeSteering && isCumulativeActive) {
          // Z eksenindeki açısal hız (rad/s) → derece/s → açı farkı
          final deltaAngle = event.z * (180.0 / math.pi) * dt * -1.0;
          cumulativeDegrees += deltaAngle;
          fullTurns = cumulativeDegrees ~/ 360;
          final maxAngle = settings.steeringAngle;
          steeringAngle = (cumulativeDegrees / maxAngle).clamp(-1.0, 1.0);
        }

        // 1.b Mod 8 (Rahat Sürüş) Yaw Direksiyon Modu (chillSteeringAxis == 1)
        if (settings.defaultDrivingMode == 8 && settings.chillSteeringAxis == 1) {
          const double yawNoiseRad = 0.025;
          // Dikey (Portrait) tutuşta sağa/sola döndürme (-event.z ve -event.y bileşkesi)
          final double rawYawRate = (-event.z + event.y * 0.5);
          if (rawYawRate.abs() >= yawNoiseRad) {
            final double maxYaw = (settings.steeringAngle / 4.0).clamp(15.0, 65.0);
            _chillAccumYaw = (_chillAccumYaw + rawYawRate * (180.0 / math.pi) * dt)
                .clamp(-maxYaw * 1.5, maxYaw * 1.5);
            chillRollDeg = _chillAccumYaw;
            chillSteering =
                ((_chillAccumYaw / maxYaw) * settings.chillSteeringSensitivity)
                    .clamp(-1.0, 1.0);
          }
        }

        // 1.c Mod 9 & Mod 10 (Flight / MFD) Gyro Yaw / Rudder Desteği
        if (settings.defaultDrivingMode == 9 || settings.defaultDrivingMode == 10) {
          final double yawDeadzoneDeg = settings.flightYawDeadzone.clamp(0.0, 15.0);
          final double yawNoiseRad = yawDeadzoneDeg > 0.0 ? 0.025 : 0.005;
          final double yawRate = -event.x; // Landscape tutuşta sağa/sola döndürme
          if (yawRate.abs() >= yawNoiseRad && event.z.abs() < 0.7) {
            _flightAccumYaw = (_flightAccumYaw + yawRate * (180.0 / math.pi) * dt)
                .clamp(-30.0, 30.0);
          } else {
            // Arcade uçuşta dümen (rudder) bırakıldığında yumuşakça merkeze döner
            _flightAccumYaw *= math.max(0.0, 1.0 - 2.5 * dt);
            if (_flightAccumYaw.abs() < 0.02) _flightAccumYaw = 0.0;
          }
          flightYawDeg = _flightAccumYaw;
          if (yawDeadzoneDeg > 0.0 && _flightAccumYaw.abs() <= yawDeadzoneDeg) {
            flightYaw = 0.0;
          } else {
            final double effYaw =
                (_flightAccumYaw.abs() - yawDeadzoneDeg) * _flightAccumYaw.sign;
            flightYaw = ((effYaw / 25.0) * settings.flightYawSensitivity)
                .clamp(-1.0, 1.0);
          }
        }

        // 2. Gyro-to-Right Analog & Mouse İşleme
        // Landscape mod (yatay tutuş) için:
        // Cihazın kendi Y ekseni etrafında dönmesi (ileriye/geriye eğme) -> Pitch (Yukarı/Aşağı)
        // Cihazın kendi X ekseni etrafında dönmesi (sağa/sola döndürme) -> Yaw (Sağa/Sola)
        // Sensör taban gürültüsü (bias/drift) kaynaklı kendiliğinden kaymayı önlemek için
        // düşük açısal hız eşiği (noise gate) uygula.
        const double gyroNoiseThresholdRad = 0.025; // ~1.4°/sn altındaki sensör gürültüsünü yoksay
        final double cleanEventY = event.y.abs() < gyroNoiseThresholdRad ? 0.0 : event.y;
        final double cleanEventX = event.x.abs() < gyroNoiseThresholdRad ? 0.0 : event.x;

        // Direksiyon (Z ekseni / Roll) hızlı çevrilirken bilekten kaynaklanan
        // istemsiz X/Y ekseni sapmalarının bakış açısını kaydırmasını önle
        final bool isTurningWheelFast = event.z.abs() > 0.65 &&
            event.z.abs() > (event.x.abs() + event.y.abs());

        double gyroPitchDelta = isTurningWheelFast ? 0.0 : cleanEventY * (180.0 / math.pi) * dt; // yukarı/aşağı
        double gyroYawDelta = isTurningWheelFast ? 0.0 : -cleanEventX * (180.0 / math.pi) * dt; // sağa/sola

        double pDeadzone = settings.includePitchInDeadzone ? rightAnalogDeadzone : 0.0;
        double mpDeadzone = mouseDeadzone; // Sadece sağ analog için geçerli dendiği için fare pitch deadzone normal çalışır.

        // Sağ Analog
        if (rightAnalogMode != 0) {
          if (rightAnalogOnlyYaw) {
            _accumulatedRaPitch = 0.0;
          }
          if (rightAnalogMode == 1 || rightAnalogMode == 3) {
            // Sürücü modu (3) için ekstra ölü alan uygulayalım (direksiyon çevirirken kazara bakmayı önlemek için)
            double rYawDeadzone = rightAnalogMode == 3 ? math.max(rightAnalogDeadzone, 12.0) : rightAnalogDeadzone;
            double rPitchDeadzone = rightAnalogMode == 3 ? math.max(pDeadzone, 10.0) : pDeadzone;

            // Normal (Mutlak) veya Sürücü Modu — Peak-Hold Anti-Drift
            // Sınıra çarptıktan sonra devam eden fiziksel dönüşü overflow olarak
            // biriktirir. Geri dönüşte, overflow tamamen eritilene kadar birikimli
            // açı değişmez; böylece merkez kayması (drift) engellenir.
            final double yawLimit = rYawDeadzone * 2 + 45.0;
            final double pitchLimit = rPitchDeadzone * 2 + 45.0;

            if (!rightAnalogOnlyYaw) {
              _accumulatedRaPitch = _applyPeakHold(
                _accumulatedRaPitch, gyroPitchDelta, pitchLimit,
                _overflowRaPitch, (v) => _overflowRaPitch = v,
              );
            }
            _accumulatedRaYaw = _applyPeakHold(
              _accumulatedRaYaw, gyroYawDelta, yawLimit,
              _overflowRaYaw, (v) => _overflowRaYaw = v,
            );
            
            // Sürücü modu için çok daha kısa mesafe (15 derece), Normal için 45 derece
            double range = (rightAnalogMode == 3) ? 15.0 : 45.0;

            // Merkezden Deadzone çıkararak 0-1 arası normalize et
            double raTargetRx = 0.0;
            if (_accumulatedRaYaw.abs() > rYawDeadzone) {
              raTargetRx = ((_accumulatedRaYaw.abs() - rYawDeadzone) / range).clamp(0.0, 1.0);
              // Üst seviye hissiyat için Sürücü modunda ivmeli (exponential) hassasiyet
              if (rightAnalogMode == 3) raTargetRx = raTargetRx * raTargetRx; 
              raTargetRx *= _accumulatedRaYaw.sign;
            }
            double raTargetRy = 0.0;
            if (!rightAnalogOnlyYaw && _accumulatedRaPitch.abs() > rPitchDeadzone) {
              raTargetRy = ((_accumulatedRaPitch.abs() - rPitchDeadzone) / range).clamp(0.0, 1.0);
              if (rightAnalogMode == 3) raTargetRy = raTargetRy * raTargetRy;
              raTargetRy *= _accumulatedRaPitch.sign;
            }
            
            double finalX = (raTargetRx * rightAnalogSensitivity).clamp(-1.0, 1.0);
            double finalY = rightAnalogOnlyYaw ? 0.0 : (raTargetRy * rightAnalogSensitivity).clamp(-1.0, 1.0);

            if (rightAnalogMode == 3) {
              // Sürücü modu: Geçişler çok yumuşak ve akıcı
              rightAnalogX += (finalX - rightAnalogX) * 0.15;
              rightAnalogY = rightAnalogOnlyYaw ? 0.0 : (rightAnalogY + (finalY - rightAnalogY) * 0.15);
              if (rightAnalogX.abs() < 0.005) rightAnalogX = 0.0;
              if (rightAnalogY.abs() < 0.005) rightAnalogY = 0.0;
            } else {
              // Normal mod: Anlık tepki
              rightAnalogX = finalX;
              rightAnalogY = rightAnalogOnlyYaw ? 0.0 : finalY;
            }
          } else if (rightAnalogMode == 2) {
            // FPS Modu (Açısal hız - Sürekli hareket)
            double raX = 0.0;
            if (gyroYawDelta.abs() > (rightAnalogDeadzone * dt)) {
               raX = gyroYawDelta * rightAnalogSensitivity; // Sağa/sola hız
            }
            double raY = 0.0;
            if (!rightAnalogOnlyYaw && gyroPitchDelta.abs() > (pDeadzone * dt)) {
               raY = gyroPitchDelta * rightAnalogSensitivity; // Yukarı/aşağı hız
            }
            
            // FPS modu için anlık hızı stick sapması olarak veriyoruz
            // Drift olmaması için yumuşatmayı kaldırdık, anında sıfırlanır
            rightAnalogX = (raX / 10.0).clamp(-1.0, 1.0);
            rightAnalogY = rightAnalogOnlyYaw ? 0.0 : (raY / 10.0).clamp(-1.0, 1.0);
          }
        } else {
          _accumulatedRaPitch = 0.0;
          _accumulatedRaYaw = 0.0;
          _overflowRaPitch = 0.0;
          _overflowRaYaw = 0.0;
          rightAnalogX = 0.0;
          rightAnalogY = 0.0;
        }

        // Fare
        if (mouseMode != 0) {
          if (mouseMode == 1 || mouseMode == 3) {
            double mYawDeadzone = mouseMode == 3 ? math.max(mouseDeadzone, 12.0) : mouseDeadzone;
            double mPitchDeadzone = mouseMode == 3 ? math.max(mpDeadzone, 10.0) : mpDeadzone;

            // Normal (Mutlak) veya Sürücü Modu — Peak-Hold Anti-Drift (Fare)
            final double mYawLimit = mYawDeadzone * 2 + 45.0;
            final double mPitchLimit = mPitchDeadzone * 2 + 45.0;

            _accumulatedMousePitch = _applyPeakHold(
              _accumulatedMousePitch, gyroPitchDelta, mPitchLimit,
              _overflowMousePitch, (v) => _overflowMousePitch = v,
            );
            _accumulatedMouseYaw = _applyPeakHold(
              _accumulatedMouseYaw, gyroYawDelta, mYawLimit,
              _overflowMouseYaw, (v) => _overflowMouseYaw = v,
            );

            double range = (mouseMode == 3) ? 15.0 : 45.0;

            double mTargetRx = 0.0;
            if (_accumulatedMouseYaw.abs() > mYawDeadzone) {
              mTargetRx = ((_accumulatedMouseYaw.abs() - mYawDeadzone) / range).clamp(0.0, 1.0);
              if (mouseMode == 3) mTargetRx = mTargetRx * mTargetRx;
              mTargetRx *= _accumulatedMouseYaw.sign;
            }
            double mTargetRy = 0.0;
            if (_accumulatedMousePitch.abs() > mPitchDeadzone) {
              mTargetRy = ((_accumulatedMousePitch.abs() - mPitchDeadzone) / range).clamp(0.0, 1.0);
              if (mouseMode == 3) mTargetRy = mTargetRy * mTargetRy;
              mTargetRy *= _accumulatedMousePitch.sign;
            }

            double mX = mTargetRx * mouseSensitivity;
            double mY = mTargetRy * mouseSensitivity;
            
            if (mouseMode == 3) {
              // Yumuşak geçiş
              final nextMx = _lastTargetMx + (mX - _lastTargetMx) * 0.15;
              final nextMy = _lastTargetMy + (mY - _lastTargetMy) * 0.15;
              mouseDeltaX += (nextMx - _lastTargetMx) * 100.0;
              mouseDeltaY += (nextMy - _lastTargetMy) * 100.0;
              _lastTargetMx = nextMx;
              _lastTargetMy = nextMy;
            } else {
              mouseDeltaX += (mX - _lastTargetMx) * 100.0;
              mouseDeltaY += (mY - _lastTargetMy) * 100.0;
              _lastTargetMx = mX;
              _lastTargetMy = mY;
            }
          } else if (mouseMode == 2) {
            // FPS Modu farede asıl Flick/Gyro Aiming'dir (Açısal Hız delta olarak doğrudan gönderilir)
            double mx = 0.0;
            if (gyroYawDelta.abs() > (mouseDeadzone * dt)) mx = gyroYawDelta;
            double my = 0.0;
            if (gyroPitchDelta.abs() > (mpDeadzone * dt)) my = gyroPitchDelta;

            mouseDeltaX += mx * mouseSensitivity * 25.0; 
            mouseDeltaY += my * mouseSensitivity * 25.0;
          }
        } else {
          _accumulatedMousePitch = 0.0;
          _accumulatedMouseYaw = 0.0;
          _overflowMousePitch = 0.0;
          _overflowMouseYaw = 0.0;
          mouseDeltaX = 0.0;
          mouseDeltaY = 0.0;
          _lastTargetMx = 0.0;
          _lastTargetMy = 0.0;
        }

        // Hareketsizlik takibi ve Otomatik Merkezleme
        _lastGyroMovementTimestamp ??= now;
        double movementMagnitude = gyroPitchDelta.abs() + gyroYawDelta.abs();
        if (movementMagnitude > 0.12) {
          _lastGyroMovementTimestamp = now;
        }

        if (settings.gyroCenterMode == 0 && _lastGyroMovementTimestamp != null) {
          final stillDuration = now.difference(_lastGyroMovementTimestamp!).inMilliseconds / 1000.0;
          if (stillDuration >= settings.gyroAutoCenterDuration) {
            recenterGyro();
            _lastGyroMovementTimestamp = now; // Sürekli sıfırlamaması için
          }
        }
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
    rightAnalogX = 0.0;
    rightAnalogY = 0.0;
    _chillInitialCalibrated = false;
    _flightInitialCalibrated = false;
  }

  // ── Mod 8 (Rahat Sürüş) Kalibrasyonu ────────────────────────────────────────
  /// Telefonun o anki dikey/eğimli tutuş açısını sıfır (nötr) noktası olarak kaydeder.
  void calibrateChillDrive() {
    _chillBasePitch = _lastRawChillPitch;
    _chillBaseRoll = _lastRawChillRoll;
    _chillAccumYaw = 0.0;
    _chillInitialCalibrated = true;
    chillSteering = 0.0;
    chillPitchDeg = 0.0;
    chillRollDeg = 0.0;
    chillGas = 0.0;
    chillBrake = 0.0;
  }

  // ── Mod 9 (Arcade Flight / HOTAS) Trim & Ufuk Kalibrasyonu ──────────────────
  /// Telefonun o anki yatay tutuş açısını 0° düz uçuş (level flight) olarak sıfırlar.
  void calibrateFlightStick() {
    _flightBasePitch = _lastRawFlightPitch;
    _flightBaseRoll = _lastRawFlightRoll;
    _flightAccumYaw = 0.0;
    _flightInitialCalibrated = true;
    flightRoll = 0.0;
    flightPitch = 0.0;
    flightYaw = 0.0;
    flightPitchDeg = 0.0;
    flightRollDeg = 0.0;
    flightYawDeg = 0.0;
  }

  // ── Peak-Hold Anti-Drift Yardımcı Fonksiyonu ──────────────────────────────
  /// Birikimli açıya [delta] ekler. Sonuç ±[limit] sınırını aşarsa fazlalığı
  /// [overflow] tamponuna yazar ([setOverflow] ile). Geri dönüşte, overflow
  /// tamamen eritilene kadar birikimli açı değişmez; böylece fiziksel telefon
  /// pozisyonu ile yazılım açısı arasındaki fark kapanır ve merkez kayması
  /// (drift) engellenir.
  double _applyPeakHold(
    double accumulated,
    double delta,
    double limit,
    double overflow,
    void Function(double) setOverflow,
  ) {
    final double rawNext = accumulated + delta;
    final double clamped = rawNext.clamp(-limit, limit);
    final double excess = rawNext - clamped;

    if (excess.abs() > 0.001) {
      // Sınıra çarptı, fazlalığı overflow'a biriktir
      setOverflow(overflow + excess);
      return clamped;
    }

    if (overflow.abs() > 0.001) {
      // Sınırın altındayız ama hâlâ eritilecek overflow var
      if (delta != 0 && delta.sign != overflow.sign) {
        // Geri dönüş yönünde: önce overflow'u erit
        final double newOverflow = overflow + delta;
        // Overflow işaret değiştirdiyse tamamen eritildi demektir
        if (newOverflow.sign != overflow.sign || newOverflow.abs() < 0.001) {
          // Kalan farkı birikime uygula
          setOverflow(0.0);
          return (accumulated + newOverflow).clamp(-limit, limit);
        }
        setOverflow(newOverflow);
        return accumulated; // Birikimli açı sabit kalır
      } else {
        // Aynı yönde devam: overflow'a ekle (daha fazla aşım)
        setOverflow(overflow + delta);
        return accumulated;
      }
    }

    // Normal durum: overflow yok, sınır aşılmadı
    setOverflow(0.0);
    return clamped;
  }

  // ── Manuel Merkezleme ──────────────────────────────────────────────────────
  void recenterGyro() {
    _accumulatedRaPitch = 0.0;
    _accumulatedRaYaw = 0.0;
    _accumulatedMousePitch = 0.0;
    _accumulatedMouseYaw = 0.0;
    _overflowRaPitch = 0.0;
    _overflowRaYaw = 0.0;
    _overflowMousePitch = 0.0;
    _overflowMouseYaw = 0.0;
    rightAnalogX = 0.0;
    rightAnalogY = 0.0;
    mouseDeltaX = 0.0;
    mouseDeltaY = 0.0;
    _lastTargetMx = 0.0;
    _lastTargetMy = 0.0;
    calibrateChillDrive();
    calibrateFlightStick();
  }
}
