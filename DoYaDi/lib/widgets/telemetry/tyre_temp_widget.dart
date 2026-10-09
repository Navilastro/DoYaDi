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

  const TyreTempWidget({
    super.key,
    required this.tyreTemps,
    required this.tyreWears,
    this.compact = false,
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
    final health = 100 - wear;
    final healthFraction = health / 100.0;

    // Aşınma rengi: yeşil → sarı → kırmızı
    Color wearColor;
    if (health > 60) {
      wearColor = const Color(0xFF00E676); // Sağlıklı (Yeşil)
    } else if (health > 30) {
      wearColor = const Color(0xFFFFC107); // Orta (Sarı)
    } else {
      wearColor = const Color(0xFFFF1744); // Kritik (Kırmızı)
    }

    return Container(
      width: size,
      height: size + wearBarH + 4,
      decoration: BoxDecoration(
        color: tempColor, // Arka plan tamamen sıcaklık rengi
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: tempColor, width: 1),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            '${_tempToCelsius(temp)}°',
            style: TextStyle(
              color: const Color(0xFF101018), // Yazı rengi koyu yapıldı (okunabilirlik için)
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

  /// Sıcaklık değerini (0-255) °C'ye dönüştürür (50°-150° aralığı)
  int _tempToCelsius(int raw) => (raw * 100 ~/ 255) + 50;

  /// Sıcaklık değerine göre renk (soğuk:mavi → optimal:yeşil → sıcak:kırmızı)
  Color _tempToColor(int raw) {
    if (raw < 80) return const Color(0xFF42A5F5); // Soğuk — Mavi
    if (raw < 140) return const Color(0xFF66BB6A); // Optimal — Yeşil
    if (raw < 200) return const Color(0xFFFFC107); // Sıcak — Sarı
    return const Color(0xFFFF1744); // Aşırı — Kırmızı
  }
}
