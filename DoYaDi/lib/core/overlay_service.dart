import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

@pragma("vm:entry-point")
void overlayMain() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: OverlayWidget(),
    ),
  );
}

class OverlayWidget extends StatefulWidget {
  const OverlayWidget({super.key});

  @override
  State<OverlayWidget> createState() => _OverlayWidgetState();
}

class _OverlayWidgetState extends State<OverlayWidget> {
  RawDatagramSocket? _udpSocket;
  InternetAddress? _targetAddress;
  StreamSubscription? _accelSub;
  Timer? _timer;

  double _steering = 0.0;
  double _gas = 0.0;
  double _brake = 0.0;

  double _lastRawPitch = 45.0;
  double _lastRawRoll = 0.0;
  double _basePitch = 45.0;
  double _baseRoll = 0.0;
  bool _calibrated = false;

  double _steerSens = 1.0;
  double _gasBrakeSens = 1.0;
  double _steeringAngleDeg = 180.0;
  bool _showGearButtons = true;

  bool _gearDownPressed = false;
  bool _gearUpPressed = false;
  bool _isOverlayActive = false;
  StreamSubscription? _overlayMsgSub;

  @override
  void initState() {
    super.initState();
    _initBackgroundTask();
  }

  Future<void> _initBackgroundTask() async {
    _isOverlayActive = await FlutterOverlayWindow.isActive();
    _overlayMsgSub = FlutterOverlayWindow.overlayListener.listen((msg) async {
      if (msg == 'START') {
        final prefs = await SharedPreferences.getInstance();
        await prefs.reload();
        final ip = prefs.getString('last_pc_ip');
        _steerSens = (prefs.getDouble('chillSteeringSensitivity') ?? 1.0).clamp(0.2, 3.0);
        _gasBrakeSens = (prefs.getDouble('chillGasBrakeSensitivity') ?? 1.0).clamp(0.2, 3.0);
        _steeringAngleDeg = (prefs.getDouble('steeringAngle') ?? 180.0).clamp(15.0, 1080.0);
        _showGearButtons = prefs.getBool('chillOverlayGearButtons') ?? true;
        if (ip != null && ip.isNotEmpty) {
          _targetAddress = InternetAddress(ip.trim());
          _udpSocket ??= await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
        }
        _calibrated = false;
        _isOverlayActive = true;
      } else if (msg == 'STOP') {
        _isOverlayActive = false;
      }
    });

    final prefs = await SharedPreferences.getInstance();
    final ip = prefs.getString('last_pc_ip');
    _steerSens = (prefs.getDouble('chillSteeringSensitivity') ?? 1.0).clamp(0.2, 3.0);
    _gasBrakeSens = (prefs.getDouble('chillGasBrakeSensitivity') ?? 1.0).clamp(0.2, 3.0);
    _steeringAngleDeg = (prefs.getDouble('steeringAngle') ?? 180.0).clamp(15.0, 1080.0);
    _showGearButtons = prefs.getBool('chillOverlayGearButtons') ?? true;

    if (ip != null && ip.isNotEmpty) {
      _targetAddress = InternetAddress(ip.trim());
      _udpSocket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
    }

    _accelSub = accelerometerEventStream().listen((event) {
      if (!_isOverlayActive) return;
      final double yzMag = math.sqrt(event.y * event.y + event.z * event.z);
      final double rawRoll = math.atan2(-event.x, math.max(0.1, yzMag)) * (180.0 / math.pi);
      final double rawPitch = math.atan2(event.z, event.y) * (180.0 / math.pi);

      _lastRawRoll = rawRoll;
      _lastRawPitch = rawPitch;

      if (!_calibrated) {
        _basePitch = rawPitch;
        _baseRoll = rawRoll;
        _calibrated = true;
      }

      final double deltaRoll = rawRoll - _baseRoll;
      final double deltaPitch = rawPitch - _basePitch;

      final double maxRoll = (_steeringAngleDeg / 4.0).clamp(15.0, 65.0);
      if (deltaRoll.abs() <= 2.0) {
        _steering = 0.0;
      } else {
        final double effRoll = (deltaRoll.abs() - 2.0) * deltaRoll.sign;
        _steering = ((effRoll / maxRoll) * _steerSens).clamp(-1.0, 1.0);
      }

      if (deltaPitch > 4.0) {
        _gas = (((deltaPitch - 4.0) / 24.0) * _gasBrakeSens).clamp(0.0, 1.0);
        _brake = 0.0;
      } else if (deltaPitch < -4.0) {
        _brake = (((-deltaPitch - 4.0) / 24.0) * _gasBrakeSens).clamp(0.0, 1.0);
        _gas = 0.0;
      } else {
        _gas = 0.0;
        _brake = 0.0;
      }

      if (mounted) setState(() {});
    });

    _timer = Timer.periodic(const Duration(milliseconds: 16), (_) {
      _sendPayload();
    });
  }

  void _recalibrate() {
    setState(() {
      _basePitch = _lastRawPitch;
      _baseRoll = _lastRawRoll;
      _steering = 0.0;
      _gas = 0.0;
      _brake = 0.0;
    });
  }

  void _sendPayload() {
    if (!_isOverlayActive || _udpSocket == null || _targetAddress == null) return;

    final int steerByte = ((_steering + 1.0) / 2.0 * 255).clamp(0, 255).toInt();
    final int gasByte = (_gas * 255).clamp(0, 255).toInt();
    final int brakeByte = (_brake * 255).clamp(0, 255).toInt();

    int buttons = 0;
    if (_gearDownPressed) buttons |= 0x0100; // LB (Vites Küçült)
    if (_gearUpPressed) buttons |= 0x0200; // RB (Vites Büyüt)

    final int buttonsHigh = (buttons >> 8) & 0xFF;
    final int buttonsLow = buttons & 0xFF;

    final payload = [
      steerByte,
      gasByte,
      brakeByte,
      buttonsHigh,
      buttonsLow,
      221, // Standart 5 bayt + 221 sonlandırıcı
    ];

    _udpSocket?.send(payload, _targetAddress!, 8888);
  }

  @override
  void dispose() {
    _isOverlayActive = false;
    _overlayMsgSub?.cancel();
    _accelSub?.cancel();
    _timer?.cancel();
    _udpSocket?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Center(
        child: Container(
          width: 220,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0xFF0A0A18).withValues(alpha: 0.92),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: const Color(0xFF40E0D0).withValues(alpha: 0.8), width: 1.8),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF40E0D0).withValues(alpha: 0.25),
                blurRadius: 16,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Üst Satır: Kapsül Başlık + Merkezle + Kapat
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.drive_eta, color: Color(0xFF40E0D0), size: 15),
                      SizedBox(width: 5),
                      Text(
                        'CHILL DRIVE',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.5,
                        ),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      GestureDetector(
                        onTap: _recalibrate,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFF40E0D0).withValues(alpha: 0.16),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xFF40E0D0).withValues(alpha: 0.5)),
                          ),
                          child: const Row(
                            children: [
                              Icon(Icons.my_location, color: Color(0xFF40E0D0), size: 11),
                              SizedBox(width: 3),
                              Text(
                                'SIFIRLA',
                                style: TextStyle(
                                  color: Color(0xFF40E0D0),
                                  fontSize: 8,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      GestureDetector(
                        onTap: () {
                          _isOverlayActive = false;
                          FlutterOverlayWindow.closeOverlay();
                        },
                        child: Container(
                          padding: const EdgeInsets.all(3),
                          decoration: BoxDecoration(
                            color: Colors.redAccent.withValues(alpha: 0.2),
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.redAccent),
                          ),
                          child: const Icon(Icons.close, color: Colors.redAccent, size: 12),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Direksiyon Mini Çubuğu
              SizedBox(
                height: 8,
                child: LayoutBuilder(
                  builder: (ctx, c) {
                    final w = c.maxWidth;
                    final center = w / 2;
                    final ind = center + (_steering * center);
                    return Stack(
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            color: const Color(0xFF1A1A2E),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                        Positioned(
                          left: _steering >= 0 ? center : ind,
                          width: (_steering.abs() * center).clamp(0.0, center),
                          top: 0,
                          bottom: 0,
                          child: Container(
                            decoration: BoxDecoration(
                              color: const Color(0xFF40E0D0),
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
              const SizedBox(height: 6),

              // Gaz ve Fren Yüzde Satırı
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'FREN ${(100 * _brake).toInt()}%',
                    style: const TextStyle(
                      color: Color(0xFFFF2A6D),
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'monospace',
                    ),
                  ),
                  Text(
                    'DİR ${(_steering * 100).toInt()}%',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 9,
                      fontFamily: 'monospace',
                    ),
                  ),
                  Text(
                    'GAZ ${(100 * _gas).toInt()}%',
                    style: const TextStyle(
                      color: Color(0xFF00E676),
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'monospace',
                    ),
                  ),
                ],
              ),

              if (_showGearButtons) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: Listener(
                        onPointerDown: (_) => setState(() => _gearDownPressed = true),
                        onPointerUp: (_) => setState(() => _gearDownPressed = false),
                        onPointerCancel: (_) => setState(() => _gearDownPressed = false),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          decoration: BoxDecoration(
                            color: _gearDownPressed
                                ? const Color(0xFFFF2A6D).withValues(alpha: 0.35)
                                : const Color(0xFF16162B),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: _gearDownPressed
                                  ? const Color(0xFFFF2A6D)
                                  : Colors.white24,
                            ),
                          ),
                          alignment: Alignment.center,
                          child: const Text(
                            'VİTES -',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Listener(
                        onPointerDown: (_) => setState(() => _gearUpPressed = true),
                        onPointerUp: (_) => setState(() => _gearUpPressed = false),
                        onPointerCancel: (_) => setState(() => _gearUpPressed = false),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          decoration: BoxDecoration(
                            color: _gearUpPressed
                                ? const Color(0xFF40E0D0).withValues(alpha: 0.35)
                                : const Color(0xFF16162B),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: _gearUpPressed
                                  ? const Color(0xFF40E0D0)
                                  : Colors.white24,
                            ),
                          ),
                          alignment: Alignment.center,
                          child: const Text(
                            'VİTES +',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
