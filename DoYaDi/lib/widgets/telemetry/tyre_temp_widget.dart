import 'package:flutter/material.dart';

/// Lastik sıcaklığı ve aşınma gösterge widget'ı.
///
/// 4 lastik için sıcaklık renk haritası + aşınma çubuğu gösterir.
/// Düzen: FL-FR üst satır, RL-RR alt satır.
class TyreTempWidget extends StatelessWidget {
  /// Lastik sıcaklıkları [FL, FR, RL, RR] (0-255 haritalanmış)
  final List<int> tyreTemps;

  /// Lastik aşınma yüzdeleri [FL, FR, RL, RR] (0-100)
  final List<int> tyreWears;

  /// Compact mod (daha küçük boyut)
  final bool compact;

  /// Özelleştirilebilir sıcaklık gradyan renkleri
  final Color coldColor;
  final Color optColor;
  final Color hotColor;
  final Color critColor;

  const TyreTempWidget({
    super.key,
    required this.tyreTemps,
    required this.tyreWears,
    this.compact = false,
    this.coldColor = const Color(0xFF42A5F5),
    this.optColor = const Color(0xFF66BB6A),
    this.hotColor = const Color(0xFFFFC107),
    this.critColor = const Color(0xFFFF1744),
  });

  @override
  Widget build(BuildContext context) {
    final cellSize = compact ? 36.0 : 48.0;
    final fontSize = compact ? 10.0 : 12.0;
    final gap = compact ? 4.0 : 8.0;
    final wearBarHeight = compact ? 3.0 : 5.0;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // FL - FR
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildTyreCell(0, cellSize, fontSize, wearBarHeight),
            SizedBox(width: gap),
            _buildTyreCell(1, cellSize, fontSize, wearBarHeight),
          ],
        ),
        SizedBox(height: gap),
        // RL - RR
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildTyreCell(2, cellSize, fontSize, wearBarHeight),
            SizedBox(width: gap),
            _buildTyreCell(3, cellSize, fontSize, wearBarHeight),
          ],
        ),
      ],
    );
  }

  Widget _buildTyreCell(int index, double size, double fontSize, double wearBarH) {
    final temp = tyreTemps[index];
    final wear = tyreWears[index].clamp(0, 100);
    final tempColor = _tempToColor(temp);
    final grad = _tempToGradient(temp, tempColor);
    final textCol = temp <= 0
        ? Colors.white54
        : (tempColor.computeLuminance() > 0.45
            ? const Color(0xFF101018)
            : Colors.white);
    // Assetto Corsa ve simülasyonlarda tyreWear kalan lastik sağlığıdır (%100 yeni, %0 bitmiş)
    // Henüz telemetri verisi yoksa varsayılan 100 kabul edilir
    final health = (wear == 0 && temp == 0) ? 100 : wear;
    final healthFraction = health / 100.0;

    // Aşınma rengi: yeşil → sarı → kırmızı
    Color wearColor;
    if (health > 60) {
      wearColor = optColor; // Sağlıklı
    } else if (health > 30) {
      wearColor = hotColor; // Orta
    } else {
      wearColor = critColor; // Kritik
    }

    return Container(
      width: size,
      height: size + wearBarH + 4,
      decoration: BoxDecoration(
        gradient: grad,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: tempColor, width: 1),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            temp <= 0 ? '--' : '$temp°',
            style: TextStyle(
              color: textCol,
              fontSize: fontSize,
              fontWeight: FontWeight.bold,
              fontFamily: 'monospace',
            ),
          ),
          const SizedBox(height: 2),
          // Aşınma çubuğu
          Container(
            width: size - 10,
            height: wearBarH,
            decoration: BoxDecoration(
              color: const Color(0xFF1A1A2E),
              borderRadius: BorderRadius.circular(2),
            ),
            alignment: Alignment.centerLeft,
            child: FractionallySizedBox(
              widthFactor: healthFraction,
              child: Container(
                decoration: BoxDecoration(
                  color: wearColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Sıcaklık değerine göre kesintisiz geçişli renk
  Color _tempToColor(int celsius) {
    if (celsius <= 0) return const Color(0xFF1E1E2E); // Veri yok / boş
    if (celsius < 65) {
      final t = ((celsius - 25) / 40.0).clamp(0.0, 1.0);
      return Color.lerp(coldColor, optColor, t * 0.45)!;
    }
    if (celsius <= 100) {
      final t = ((celsius - 65) / 35.0).clamp(0.0, 1.0);
      return Color.lerp(optColor, hotColor, t * 0.45)!;
    }
    if (celsius <= 118) {
      final t = ((celsius - 100) / 18.0).clamp(0.0, 1.0);
      return Color.lerp(hotColor, critColor, t)!;
    }
    return critColor;
  }

  LinearGradient _tempToGradient(int celsius, Color base) {
    if (celsius <= 0) {
      return LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          coldColor.withValues(alpha: 0.22),
          optColor.withValues(alpha: 0.12),
        ],
      );
    }
    Color nextStop;
    if (celsius < 65) {
      nextStop = Color.lerp(base, optColor, 0.35)!;
    } else if (celsius <= 100) {
      nextStop = Color.lerp(base, hotColor, 0.3)!;
    } else {
      nextStop = Color.lerp(base, critColor, 0.4)!;
    }
    return LinearGradient(
      begin: Alignment.bottomLeft,
      end: Alignment.topRight,
      colors: [base, nextStop],
    );
  }
}
