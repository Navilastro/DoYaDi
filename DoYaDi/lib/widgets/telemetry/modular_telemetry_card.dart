import 'package:flutter/material.dart';

/// Modüler telemetri kart widget'ı.
///
/// Üzerinde ayar butonu ve açılır popover menüsü bulunan genel telemetri bileşeni.
/// Her kart bağımsız olarak gösterilebilir/gizlenebilir ve kendi ayarlarına sahiptir.
/// ValueListenableBuilder ile kullanılarak yalnızca ilgili kart güncellenir.
class ModularTelemetryCard extends StatefulWidget {
  /// Kart başlığı
  final String title;

  /// Kart içeriği
  final Widget child;

  /// Ayarlar menüsü oluşturucu (boşsa ayar ikonu gösterilmez)
  final List<Widget> Function(BuildContext context)? settingsBuilder;

  /// Kart görünür mü
  final bool visible;

  /// Kart arka plan rengi
  final Color? backgroundColor;

  /// Kart sınır rengi
  final Color? borderColor;

  const ModularTelemetryCard({
    super.key,
    required this.title,
    required this.child,
    this.settingsBuilder,
    this.visible = true,
    this.backgroundColor,
    this.borderColor,
  });

  @override
  State<ModularTelemetryCard> createState() => _ModularTelemetryCardState();
}

class _ModularTelemetryCardState extends State<ModularTelemetryCard>
    with SingleTickerProviderStateMixin {
  bool _settingsOpen = false;
  late AnimationController _animController;
  late Animation<double> _expandAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      duration: const Duration(milliseconds: 250),
      vsync: this,
    );
    _expandAnim = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOutCubic,
    );
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  void _toggleSettings() {
    setState(() {
      _settingsOpen = !_settingsOpen;
      if (_settingsOpen) {
        _animController.forward();
      } else {
        _animController.reverse();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.visible) return const SizedBox.shrink();

    final bgColor = widget.backgroundColor ?? const Color(0xFF0D0D1A);
    final borderClr = widget.borderColor ?? const Color(0xFF1E1E3A);

    return Container(
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderClr, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Başlık satırı
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 4, 0),
            child: Row(
              children: [
                Text(
                  widget.title,
                  style: const TextStyle(
                    color: Color(0xFF8888AA),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.2,
                  ),
                ),
                const Spacer(),
                if (widget.settingsBuilder != null)
                  GestureDetector(
                    onTap: _toggleSettings,
                    child: Padding(
                      padding: const EdgeInsets.all(4),
                      child: AnimatedRotation(
                        turns: _settingsOpen ? 0.25 : 0.0,
                        duration: const Duration(milliseconds: 250),
                        child: Icon(
                          Icons.settings,
                          size: 16,
                          color: _settingsOpen
                              ? const Color(0xFF40E0D0)
                              : const Color(0xFF555577),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // Ayarlar menüsü (AnimatedContainer)
          if (widget.settingsBuilder != null)
            SizeTransition(
              sizeFactor: _expandAnim,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: const BoxDecoration(
                  border: Border(
                    bottom: BorderSide(color: Color(0xFF1E1E3A), width: 1),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: widget.settingsBuilder!(context),
                ),
              ),
            ),

          // İçerik
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 6, 12, 10),
            child: widget.child,
          ),
        ],
      ),
    );
  }
}
