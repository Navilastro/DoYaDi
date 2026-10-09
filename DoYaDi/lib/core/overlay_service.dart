import 'dart:async';
import 'dart:io';
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
  double _pitch = 0.0;
  double _gas = 0.0;
  double _brake = 0.0;

  @override
  void initState() {
    super.initState();
    _initBackgroundTask();
  }

  Future<void> _initBackgroundTask() async {
    final prefs = await SharedPreferences.getInstance();
    final ip = prefs.getString('last_pc_ip');
    
    if (ip != null && ip.isNotEmpty) {
      _targetAddress = InternetAddress(ip);
      _udpSocket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
    }

    _accelSub = accelerometerEventStream().listen((event) {
      // Basic fallback calculation for background overlay
      // Pitch
      double rawPitch = (event.z != 0) ? (event.x.abs() / event.z) : 0.0; // Simplified
      _pitch = rawPitch * 50.0; // Just visual proxy

      // Steering
      double maxG = (180.0 / 180.0) * 9.8;
      _steering = (event.y / maxG).clamp(-1.0, 1.0);

      // Simple gas/brake based on pitch (for chill drive)
      if (_pitch > 30) {
         _gas = ((_pitch - 30) / 40).clamp(0.0, 1.0);
         _brake = 0.0;
      } else if (_pitch < 10) {
         _brake = ((10 - _pitch) / 40).clamp(0.0, 1.0);
         _gas = 0.0;
      } else {
         _gas = 0.0;
         _brake = 0.0;
      }
      
      if (mounted) setState(() {});
    });

    _timer = Timer.periodic(const Duration(milliseconds: 16), (timer) {
      _sendPayload();
    });
  }

  void _sendPayload() {
    if (_udpSocket == null || _targetAddress == null) return;
    
    int steerByte = ((_steering + 1.0) / 2.0 * 255).clamp(0, 255).toInt();
    int gasByte = (_gas * 255).clamp(0, 255).toInt();
    int brakeByte = (_brake * 255).clamp(0, 255).toInt();
    
    final payload = [
      steerByte,
      gasByte,
      brakeByte,
      0, // Buttons High
      0, // Buttons Low
      128, 128, 128, 128, // Joysticks
      128, 128, // Touchpad
      0, // Click
      0, 0, 0, 0, // KB
      221 // Terminator
    ];
    
    _udpSocket?.send(payload, _targetAddress!, 8888);
  }

  @override
  void dispose() {
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
          width: 160,
          height: 160,
          decoration: BoxDecoration(
            color: const Color(0xFF0D0D1A).withValues(alpha: 0.9),
            shape: BoxShape.circle,
            border: Border.all(color: const Color(0xFF40E0D0), width: 2),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF40E0D0).withValues(alpha: 0.3),
                blurRadius: 20,
              )
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.drive_eta, color: Color(0xFF40E0D0), size: 24),
              const SizedBox(height: 8),
              const Text(
                'Chill Drive',
                style: TextStyle(
                  color: Colors.white, 
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'S: ${(_steering * 100).toInt()}%',
                style: const TextStyle(color: Colors.white70, fontSize: 10),
              ),
              const SizedBox(height: 8),
              GestureDetector(
                onTap: () {
                  FlutterOverlayWindow.closeOverlay();
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.redAccent.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.redAccent),
                  ),
                  child: const Text(
                    'DURDUR',
                    style: TextStyle(color: Colors.redAccent, fontSize: 10, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

