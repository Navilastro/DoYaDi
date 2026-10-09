import 'package:flutter/material.dart';

/// Taktik Anahtar Widget'ı.
///
/// Güvenlik kapaklı (Master Arm), kademeli (Flap), basit toggle (Gear, Airbrake)
/// türlerinde kokpit anahtarları.
class TacticalSwitchWidget extends StatelessWidget {
  /// Anahtar etiketi
  final String label;

  /// Aktif durumu
  final bool isActive;

  /// Basıldığında çağrılır
  final VoidCallback onTap;

  /// İkon
  final IconData icon;

  /// Aktif renk
  final Color activeColor;

  /// Güvenlik kapaklı mı (iki kez basma gerektirir)
  final bool hasSafetyGuard;

  /// Compact mod
  final bool compact;

  const TacticalSwitchWidget({
    super.key,
    required this.label,
    required this.isActive,
    required this.onTap,
    required this.icon,
    this.activeColor = const Color(0xFF00E676),
    this.hasSafetyGuard = false,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final size = compact ? 48.0 : 60.0;
    final fontSize = compact ? 8.0 : 10.0;
    final iconSize = compact ? 20.0 : 26.0;

    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: isActive
                  ? activeColor.withValues(alpha: 0.15)
                  : const Color(0xFF0D0D1A),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isActive
                    ? activeColor
                    : const Color(0xFF333344),
                width: isActive ? 2 : 1,
              ),
              boxShadow: isActive
                  ? [
                      BoxShadow(
                        color: activeColor.withValues(alpha: 0.2),
                        blurRadius: 12,
                      ),
                    ]
                  : null,
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Icon(
                  icon,
                  size: iconSize,
                  color: isActive
                      ? activeColor
                      : const Color(0xFF555577),
                ),
                // Güvenlik kapağı göstergesi
                if (hasSafetyGuard)
                  Positioned(
                    top: 2,
                    right: 2,
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isActive
                            ? const Color(0xFFFF1744)
                            : const Color(0xFF333344),
                        border: Border.all(
                          color: const Color(0xFFFF1744).withValues(alpha: 0.5),
                          width: 1,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              color: isActive
                  ? activeColor.withValues(alpha: 0.8)
                  : const Color(0xFF666688),
              fontSize: fontSize,
              letterSpacing: 1,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
