import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Arcade Uçuş & Savaş HUD Retikülü (War Thunder / DCS / MSFS tarzı).
///
/// - Sabit uçak referans sembolü (Waterline / Bore-sight)
/// - Sensör veya dokunmatik kol sapmasını gösteren Hareketli Nişangah (Gun Pipper / Mouse Aim Circle)
/// - Dinamik Yapay Ufuk (Pitch & Bank/Roll çizgisi)
/// - Üst Yatış Açısı (Bank Angle) yayı ve hedef kilit / ateşleme halkası
class CrosshairPainter extends CustomPainter {
  /// Ana HUD rengi
  final Color color;

  /// Roll sapması (-1.0 .. 1.0)
  final double offsetX;

  /// Pitch sapması (-1.0 .. 1.0)
  final double offsetY;

  /// Roll açısı (derece)
  final double rollDeg;

  /// Pitch açısı (derece)
  final double pitchDeg;

  /// Yaw / Rudder sapması (-1.0 .. 1.0)
  final double yawNorm;

  /// Ateş ediliyor mu (GUNS / MISSILE aktif)
  final bool isFiring;

  /// Hedef kilitli mi (TARGET LOCK)
  final bool isLocked;

  /// WEP / Afterburner aktif mi
  final bool isWep;

  const CrosshairPainter({
    this.color = const Color(0xFF40E0D0),
    this.offsetX = 0.0,
    this.offsetY = 0.0,
    this.rollDeg = 0.0,
    this.pitchDeg = 0.0,
    double yawNorm = 0.0,
    double? yawOffset,
    this.isFiring = false,
    bool isLocked = false,
    bool? isTargetLocked,
    this.isWep = false,
  })  : yawNorm = yawOffset ?? yawNorm,
        isLocked = isTargetLocked ?? isLocked;

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final radius = (size.width < size.height ? size.width / 2 : size.height / 2) * 0.92;

    final Color hudColor = isFiring
        ? const Color(0xFFFF3D00)
        : isLocked
            ? const Color(0xFF00E676)
            : color;

    // 1. Dış Taktik Çember & Bank (Yatış) Derece Çentikleri
    final ringPaint = Paint()
      ..color = hudColor.withValues(alpha: 0.22)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    canvas.drawCircle(Offset(cx, cy), radius, ringPaint);

    // İç ölü alan / hassas nişan halkası
    final midPaint = Paint()
      ..color = hudColor.withValues(alpha: 0.16)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    canvas.drawCircle(Offset(cx, cy), radius * 0.48, midPaint);

    // Üst yayda yatış (Bank Angle) çentikleri (-60°, -45°, -30°, -15°, 0°, +15°, +30°, +45°, +60°)
    final tickPaint = Paint()
      ..color = hudColor.withValues(alpha: 0.45)
      ..strokeWidth = 1.4;
    for (final deg in [-60, -45, -30, -15, 0, 15, 30, 45, 60]) {
      final rad = (deg - 90) * math.pi / 180.0;
      final bool isMajor = deg % 30 == 0;
      final rIn = radius * (isMajor ? 0.88 : 0.92);
      final rOut = radius * 0.98;
      canvas.drawLine(
        Offset(cx + math.cos(rad) * rIn, cy + math.sin(rad) * rIn),
        Offset(cx + math.cos(rad) * rOut, cy + math.sin(rad) * rOut),
        tickPaint,
      );
    }

    // 2. Dinamik Yapay Ufuk & Pitch Merdiveni (Horizon Line)
    canvas.save();
    canvas.clipPath(
      Path()..addOval(Rect.fromCircle(center: Offset(cx, cy), radius: radius * 0.86)),
    );
    canvas.translate(cx, cy);
    // Yatış açısı kadar döndür (Roll)
    canvas.rotate(-offsetX * 0.65);
    // Pitch sapması kadar kaydır
    final double pitchShift = offsetY * radius * 0.55;

    final horizonPaint = Paint()
      ..color = hudColor.withValues(alpha: 0.35)
      ..strokeWidth = 1.5;

    // Sol ve sağ ufuk kanat çizgileri
    canvas.drawLine(
      Offset(-radius * 0.7, pitchShift),
      Offset(-radius * 0.18, pitchShift),
      horizonPaint,
    );
    canvas.drawLine(
      Offset(radius * 0.18, pitchShift),
      Offset(radius * 0.7, pitchShift),
      horizonPaint,
    );

    // Pitch basamakları (+15° ve -15°)
    final ladderPaint = Paint()
      ..color = hudColor.withValues(alpha: 0.22)
      ..strokeWidth = 1.2;
    for (final step in [-1, 1]) {
      final double yPos = pitchShift + step * (radius * 0.28);
      canvas.drawLine(Offset(-radius * 0.32, yPos), Offset(-radius * 0.12, yPos), ladderPaint);
      canvas.drawLine(Offset(radius * 0.12, yPos), Offset(radius * 0.32, yPos), ladderPaint);
      // Uç dikmeler
      final double tipH = step < 0 ? 6.0 : -6.0;
      canvas.drawLine(Offset(-radius * 0.32, yPos), Offset(-radius * 0.32, yPos + tipH), ladderPaint);
      canvas.drawLine(Offset(radius * 0.32, yPos), Offset(radius * 0.32, yPos + tipH), ladderPaint);
    }
    canvas.restore();

    // 3. Sabit Merkez Uçak Sembolü (Waterline W-Wing)
    final centerWingPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.45)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8;
    final wingPath = Path()
      ..moveTo(cx - 24, cy)
      ..lineTo(cx - 9, cy)
      ..lineTo(cx - 5, cy + 5)
      ..moveTo(cx + 5, cy + 5)
      ..lineTo(cx + 9, cy)
      ..lineTo(cx + 24, cy);
    canvas.drawPath(wingPath, centerWingPaint);

    // 4. Alt Dümen (Yaw / Slip-Skid) Barı
    final double yawBarHalfW = radius * 0.42;
    final double yawBarY = cy + radius * 0.78;
    canvas.drawLine(
      Offset(cx - yawBarHalfW, yawBarY),
      Offset(cx + yawBarHalfW, yawBarY),
      Paint()
        ..color = Colors.white12
        ..strokeWidth = 2,
    );
    final double yawDotX = cx + yawNorm.clamp(-1.0, 1.0) * yawBarHalfW;
    canvas.drawCircle(
      Offset(yawDotX, yawBarY),
      4,
      Paint()..color = hudColor,
    );

    // 5. Hareketli Nişangah / Uçuş Vektörü (War Thunder Mouse-Aim / Gun Pipper)
    final double pipX = cx + offsetX.clamp(-1.0, 1.0) * radius * 0.78;
    final double pipY = cy + offsetY.clamp(-1.0, 1.0) * radius * 0.78;

    // Merkezden nişangaha ince kılavuz vektör çizgisi
    canvas.drawLine(
      Offset(cx, cy),
      Offset(pipX, pipY),
      Paint()
        ..color = hudColor.withValues(alpha: 0.25)
        ..strokeWidth = 1.0,
    );

    // Dış nişangah çemberi (Pipper Ring)
    final pipRingPaint = Paint()
      ..color = hudColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = isFiring ? 2.4 : 1.8;
    canvas.drawCircle(Offset(pipX, pipY), isFiring ? 16 : 13, pipRingPaint);

    // Hedef Kilitli (Target Lock) Elmas Köşeleri
    if (isLocked) {
      final lockPaint = Paint()
        ..color = const Color(0xFF00E676)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.8;
      canvas.drawRect(
        Rect.fromCenter(center: Offset(pipX, pipY), width: 32, height: 32),
        lockPaint,
      );
    }

    // Merkez nişan noktası
    canvas.drawCircle(
      Offset(pipX, pipY),
      3.5,
      Paint()..color = hudColor,
    );

    // Parlama (Glow)
    canvas.drawCircle(
      Offset(pipX, pipY),
      isFiring ? 14 : 8,
      Paint()
        ..color = hudColor.withValues(alpha: isFiring ? 0.45 : 0.28)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
    );
  }

  @override
  bool shouldRepaint(covariant CrosshairPainter old) =>
      old.offsetX != offsetX ||
      old.offsetY != offsetY ||
      old.rollDeg != rollDeg ||
      old.pitchDeg != pitchDeg ||
      old.yawNorm != yawNorm ||
      old.color != color ||
      old.isFiring != isFiring ||
      old.isLocked != isLocked ||
      old.isWep != isWep;
}
