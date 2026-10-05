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

  /// 0: Kapalı, 1: Pilot (Mutlak/Direkt), 2: FPS (Yumuşatılmış/Sürüklenmeli)
  int rightAnalogMode = 0;
  double rightAnalogSensitivity = 1.0;
  double rightAnalogDeadzone = 7.0;
  
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

        // 2. Gyro-to-Right Analog & Mouse İşleme
        // Landscape mod (yatay tutuş) için:
        // Cihazın kendi Y ekseni etrafında dönmesi (ileriye/geriye eğme) -> Pitch (Yukarı/Aşağı)
        // Cihazın kendi X ekseni etrafında dönmesi (sağa/sola döndürme) -> Yaw (Sağa/Sola)
        // Kullanıcının belirttiği gibi eksenlerin yönlerini düzeltiyoruz.
        double gyroPitchDelta = event.y * (180.0 / math.pi) * dt; // yukarı/aşağı
        double gyroYawDelta = -event.x * (180.0 / math.pi) * dt; // sağa/sola ters olduğu için - ekledik

        double pDeadzone = settings.includePitchInDeadzone ? rightAnalogDeadzone : 0.0;
        double mpDeadzone = mouseDeadzone; // Sadece sağ analog için geçerli dendiği için fare pitch deadzone normal çalışır.

        // Sağ Analog
        if (rightAnalogMode != 0) {
          if (rightAnalogMode == 1 || rightAnalogMode == 3) {
            // Sürücü modu (3) için ekstra ölü alan uygulayalım (direksiyon çevirirken kazara bakmayı önlemek için)
            double rYawDeadzone = rightAnalogMode == 3 ? math.max(rightAnalogDeadzone, 12.0) : rightAnalogDeadzone;
            double rPitchDeadzone = rightAnalogMode == 3 ? math.max(pDeadzone, 10.0) : pDeadzone;

            // Normal (Mutlak) veya Sürücü Modu
            _accumulatedRaPitch = (_accumulatedRaPitch + gyroPitchDelta).clamp(-rPitchDeadzone * 2 - 45.0, rPitchDeadzone * 2 + 45.0);
            _accumulatedRaYaw = (_accumulatedRaYaw + gyroYawDelta).clamp(-rYawDeadzone * 2 - 45.0, rYawDeadzone * 2 + 45.0);
            
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
            if (_accumulatedRaPitch.abs() > rPitchDeadzone) {
              raTargetRy = ((_accumulatedRaPitch.abs() - rPitchDeadzone) / range).clamp(0.0, 1.0);
              if (rightAnalogMode == 3) raTargetRy = raTargetRy * raTargetRy;
              raTargetRy *= _accumulatedRaPitch.sign;
            }
            
            double finalX = (raTargetRx * rightAnalogSensitivity).clamp(-1.0, 1.0);
            double finalY = (raTargetRy * rightAnalogSensitivity).clamp(-1.0, 1.0);

            if (rightAnalogMode == 3) {
              // Sürücü modu: Geçişler çok yumuşak ve akıcı
              rightAnalogX += (finalX - rightAnalogX) * 0.15; // Biraz daha hızlandırdık ama hala akıcı
              rightAnalogY += (finalY - rightAnalogY) * 0.15;
            } else {
              // Normal mod: Anlık tepki
              rightAnalogX = finalX;
              rightAnalogY = finalY;
            }
          } else if (rightAnalogMode == 2) {
            // FPS Modu (Açısal hız - Sürekli hareket)
            double raX = 0.0;
            if (gyroYawDelta.abs() > (rightAnalogDeadzone * dt)) {
               raX = gyroYawDelta * rightAnalogSensitivity; // Sağa/sola hız
            }
            double raY = 0.0;
            if (gyroPitchDelta.abs() > (pDeadzone * dt)) {
               raY = gyroPitchDelta * rightAnalogSensitivity; // Yukarı/aşağı hız
            }
            
            // FPS modu için anlık hızı stick sapması olarak veriyoruz
            // Drift olmaması için yumuşatmayı kaldırdık, anında sıfırlanır
            rightAnalogX = (raX / 10.0).clamp(-1.0, 1.0);
            rightAnalogY = (raY / 10.0).clamp(-1.0, 1.0);
          }
        } else {
          _accumulatedRaPitch = 0.0;
          _accumulatedRaYaw = 0.0;
        }

        // Fare
        if (mouseMode != 0) {
          if (mouseMode == 1 || mouseMode == 3) {
            double mYawDeadzone = mouseMode == 3 ? math.max(mouseDeadzone, 12.0) : mouseDeadzone;
            double mPitchDeadzone = mouseMode == 3 ? math.max(mpDeadzone, 10.0) : mpDeadzone;

            // Normal (Mutlak) veya Sürücü Modu
            _accumulatedMousePitch = (_accumulatedMousePitch + gyroPitchDelta).clamp(-mPitchDeadzone * 2 - 45.0, mPitchDeadzone * 2 + 45.0);
            _accumulatedMouseYaw = (_accumulatedMouseYaw + gyroYawDelta).clamp(-mYawDeadzone * 2 - 45.0, mYawDeadzone * 2 + 45.0);

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
              _lastTargetMx += (mX - _lastTargetMx) * 0.15;
              _lastTargetMy += (mY - _lastTargetMy) * 0.15;
              mouseDeltaX = (mX - _lastTargetMx) * 100.0;
              mouseDeltaY = (mY - _lastTargetMy) * 100.0;
              _lastTargetMx = mX;
              _lastTargetMy = mY;
            } else {
              mouseDeltaX = (mX - _lastTargetMx) * 100.0;
              mouseDeltaY = (mY - _lastTargetMy) * 100.0;
              _lastTargetMx = mX;
              _lastTargetMy = mY;
            }
          } else if (mouseMode == 2) {
            // FPS Modu farede asıl Flick/Gyro Aiming'dir (Açısal Hız delta olarak doğrudan gönderilir)
            double mx = 0.0;
            if (gyroYawDelta.abs() > (mouseDeadzone * dt)) mx = gyroYawDelta;
            double my = 0.0;
            if (gyroPitchDelta.abs() > (mpDeadzone * dt)) my = gyroPitchDelta;

            mouseDeltaX = mx * mouseSensitivity * 25.0; 
            mouseDeltaY = my * mouseSensitivity * 25.0;
          }
        } else {
          _accumulatedMousePitch = 0.0;
          _accumulatedMouseYaw = 0.0;
          mouseDeltaX = 0.0;
          mouseDeltaY = 0.0;
        }

        // Hareketsizlik takibi ve Otomatik Merkezleme
        double movementMagnitude = gyroPitchDelta.abs() + gyroYawDelta.abs();
        if (movementMagnitude > 0.05) {
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
  }

  // ── Manuel Merkezleme ──────────────────────────────────────────────────────
  void recenterGyro() {
    _accumulatedRaPitch = 0.0;
    _accumulatedRaYaw = 0.0;
    _accumulatedMousePitch = 0.0;
    _accumulatedMouseYaw = 0.0;
  }
}
