part of '../custom_layout5_editor_screen.dart';
extension _EditorCanvasExt on _CustomLayout5EditorScreenState {
  Widget _buildItem(Layout5Item item, Size size) {
    final double l = item.left * size.width;
    final double t = item.top * size.height;
    final double w = item.width * size.width;
    final double h = item.height * size.height;
    final bool isSelected = _selectedId == item.id;

    Widget content = _buildItemContent(item, w, h);

    if (_removeMode) {
      content = Stack(
        children: [
          content,
          Positioned.fill(child: Container(color: Colors.black45)),
          Positioned(
            top: 4,
            right: 4,
            child: GestureDetector(
              onTap: () => _removeItem(item.id),
              child: Container(
                width: 28,
                height: 28,
                decoration: const BoxDecoration(
                  color: Colors.red,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.close, color: Colors.white, size: 18),
              ),
            ),
          ),
        ],
      );
    }

    return Positioned(
      left: l,
      top: t,
      width: w,
      height: h,
      child: GestureDetector(
        onTap: _editMode ? () {
          setState(() {
            _selectedId = item.id;
            _items.remove(item);
            _items.add(item);
          });
        } : null,
        onScaleStart: _editMode
            ? (details) {
                setState(() {
                  _isDragging = true;
                  _selectedId = item.id;
                  final idx = _items.indexWhere((e) => e.id == item.id);
                  if (idx >= 0) {
                    _initialScaleW = _items[idx].width;
                    _initialScaleH = _items[idx].height;
                    _initialRotation = _items[idx].rotation;
                  }
                });
              }
            : null,
        onScaleUpdate: _editMode
            ? (details) {
                setState(() {
                  final idx = _items.indexWhere((e) => e.id == item.id);
                  if (idx < 0) return;

                  // Hareket (Pan)
                  double newLeft =
                      (_items[idx].left +
                              details.focalPointDelta.dx / size.width)
                          .clamp(0.0, 0.95);
                  double newTop =
                      (_items[idx].top +
                              details.focalPointDelta.dy / size.height)
                          .clamp(0.0, 0.95);

                  // Sınırları belirle (Pedallar ekranın yarısına ve tam boyuna kadar çıkabilir)
                  bool isPedal =
                      _items[idx].type == Layout5ItemType.gasBar ||
                      _items[idx].type == Layout5ItemType.brakeBar;
                  double maxW = isPedal ? 0.5 : 0.95;
                  double maxH = isPedal ? 1.0 : 0.95;

                  // Boyutlandırma (Aspect Ratio korunarak)
                  double newW = (_initialScaleW * details.scale).clamp(
                    0.05,
                    maxW,
                  );
                  double newH = (_initialScaleH * details.scale).clamp(
                    0.05,
                    maxH,
                  );

                  // Joystickler döndürülemesin (yön eksenleri bozulur)
                  final isJoystick =
                      _items[idx].type == Layout5ItemType.leftJoystick ||
                      _items[idx].type == Layout5ItemType.rightJoystick;
                  double newRot = isJoystick
                      ? _initialRotation // sabit tut
                      : _initialRotation + details.rotation;

                  _items[idx] = _items[idx].copyWith(
                    left: newLeft,
                    top: newTop,
                    width: newW,
                    height: newH,
                    rotation: newRot,
                  );
                });
              }
            : null,
        onScaleEnd: _editMode
            ? (details) {
                setState(() {
                  _isDragging = false;
                });
              }
            : null,
        child: Transform.rotate(
          angle: item.rotation,
          child: Container(
            decoration: isSelected && _editMode
                ? BoxDecoration(
                    border: Border.all(color: Colors.cyan, width: 2),
                  )
                : null,
            child: content,
          ),
        ),
      ),
    );
  }

  Widget _buildItemContent(Layout5Item item, double w, double h) {
    switch (item.type) {
      case Layout5ItemType.leftJoystick:
      case Layout5ItemType.rightJoystick:
        return JoystickWidget(
          radius: min(w, h) / 2,
          baseColor: item.bgColor,
          thumbColor: item.textColor,
          onChanged: (_, __) {},
        );
      case Layout5ItemType.gasBar:
        return CustomPaint(
          painter: PedalPainter(
            fillPercentage: 0.4,
            baseColor: const Color(0xFF00C853),
            bgColor: item.bgColor,
            yetsoreColor: const Color(0xFFFFD600),
          ),
        );
      case Layout5ItemType.brakeBar:
        return CustomPaint(
          painter: PedalPainter(
            fillPercentage: 0.4,
            baseColor: const Color(0xFFD50000),
            bgColor: item.bgColor,
            yetsoreColor: const Color(0xFFFFD600),
          ),
        );
      case Layout5ItemType.gasPedalIcon:
        return CustomPaint(
          painter: PedalIconPainter(
            fillPercentage: 0.4,
            baseColor: const Color(0xFF00C853),
            isGas: true,
          ),
        );
      case Layout5ItemType.brakePedalIcon:
        return CustomPaint(
          painter: PedalIconPainter(
            fillPercentage: 0.4,
            baseColor: const Color(0xFFD50000),
            isGas: false,
          ),
        );
      case Layout5ItemType.clutchBar:
        return CustomPaint(
          painter: PedalPainter(
            fillPercentage: 0.4,
            baseColor: Colors.blueAccent,
            bgColor: item.bgColor,
            yetsoreColor: const Color(0xFFFFD600),
          ),
        );
      case Layout5ItemType.clutchIcon:
        return CustomPaint(
          painter: PedalIconPainter(
            fillPercentage: 0.4,
            baseColor: Colors.blueAccent,
            isGas: false,
          ),
        );
      case Layout5ItemType.steeringWheelIcon:
        final s = Provider.of<SettingsProvider>(context, listen: false).settings;
        Widget steeringWidget;
        if (s.mod6SteeringStyle == 1) {
          steeringWidget = RepaintBoundary(
            child: CustomPaint(
              painter: DynamicSteeringWheelPainter(
                steeringRatio: 0.0,
                totalAngleDegrees: 0.0,
                turnRightColor: item.textColor,
                turnLeftColor: item.textColor,
                baseColor: item.textColor.withOpacity(0.3),
              ),
              child: const SizedBox.expand(),
            ),
          );
        } else {
          steeringWidget = RepaintBoundary(
            child: CustomPaint(
              painter: SteeringWheelPainter(
                angle: 0.0,
                fullTurns: 1,
                rimColor: item.textColor,
              ),
              child: const SizedBox.expand(),
            ),
          );
        }
        return Opacity(
          opacity: 0.85,
          child: steeringWidget,
        );
      case Layout5ItemType.handbrakeButton:
        return Container(
          decoration: BoxDecoration(
            color: const Color(0xFF381E1E),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.redAccent),
          ),
          child: const Center(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.sports_motorsports, color: Colors.redAccent, size: 16),
                SizedBox(width: 4),
                Text('EL FRENİ', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        );
      case Layout5ItemType.steeringBar:
        return RepaintBoundary(
          child: CustomPaint(
            painter: SteeringPainter(
              angle: 0.0,
              pitch: 90.0,
              indicatorColor: item.textColor,
              bgColor: item.bgColor,
            ),
          ),
        );
      case Layout5ItemType.touchpad:
        return Container(
          decoration: BoxDecoration(
            color: item.bgColor,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: item.textColor.withValues(alpha: 0.3)),
          ),
          child: Center(
            child: Icon(
              Icons.mouse,
              color: item.textColor.withValues(alpha: 0.4),
              size: min(w, h) * 0.35,
            ),
          ),
        );
      default:
        return _buildButtonContent(item, w, h);
    }
  }

  Widget _buildButtonContent(Layout5Item item, double w, double h) {
    final label =
        item.label ??
        '${_items.indexOf(item) + 1} ${AppTranslations.getText('btn_label_default')}';
    BorderRadius radius;
    switch (item.type) {
      case Layout5ItemType.buttonSoft:
        radius = BorderRadius.circular(16);
        break;
      case Layout5ItemType.buttonCircle:
        radius = BorderRadius.circular(min(w, h) / 2);
        break;
      default:
        radius = BorderRadius.circular(4);
    }
    return Container(
      decoration: BoxDecoration(
        color: item.bgColor,
        borderRadius: radius,
        border: Border.all(color: item.textColor.withValues(alpha: 0.3)),
      ),
      child: Center(
        child: Text(
          label,
          style: TextStyle(
            color: item.textColor,
            fontSize: min(w, h) * 0.18,
            fontWeight: FontWeight.w600,
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  Widget _addMenuButton() {
    return PopupMenuButton<Layout5ItemType>(
      color: const Color(0xFF1A1A3E),
      itemBuilder: (_) => [
        if (!_hasLeftJoystick) ...[
          PopupMenuItem(
            value: Layout5ItemType.leftJoystick,
            child: Text(
              AppTranslations.getText('add_left_joystick'),
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ],
        if (!_hasRightJoystick) ...[
          PopupMenuItem(
            value: Layout5ItemType.rightJoystick,
            child: Text(
              AppTranslations.getText('add_right_joystick'),
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ],
        if (!_hasGasController) ...[
          PopupMenuItem(
            value: Layout5ItemType.gasBar,
            child: Text(
              AppTranslations.getText('add_gas_bar'),
              style: const TextStyle(color: Colors.white),
            ),
          ),
          PopupMenuItem(
            value: Layout5ItemType.gasPedalIcon,
            child: Text(
              AppTranslations.getText('add_gas_pedal_icon'),
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ],
        if (!_hasBrakeController) ...[
          PopupMenuItem(
            value: Layout5ItemType.brakeBar,
            child: Text(
              AppTranslations.getText('add_brake_bar'),
              style: const TextStyle(color: Colors.white),
            ),
          ),
          PopupMenuItem(
            value: Layout5ItemType.brakePedalIcon,
            child: Text(
              AppTranslations.getText('add_brake_pedal_icon'),
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ],
        if (!_hasClutchController) ...[
          PopupMenuItem(
            value: Layout5ItemType.clutchBar,
            child: Text(
              AppTranslations.getText('type_clutch_bar') != 'type_clutch_bar' 
                ? AppTranslations.getText('type_clutch_bar') 
                : 'Debriyaj Barı Ekle',
              style: const TextStyle(color: Colors.cyanAccent),
            ),
          ),
          PopupMenuItem(
            value: Layout5ItemType.clutchIcon,
            child: Text(
              AppTranslations.getText('type_clutch_icon') != 'type_clutch_icon'
                ? AppTranslations.getText('type_clutch_icon')
                : 'Debriyaj İkonu Ekle',
              style: const TextStyle(color: Colors.cyanAccent),
            ),
          ),
        ],
        if (!_hasHandbrakeController) ...[
          PopupMenuItem(
            value: Layout5ItemType.handbrakeBar,
            child: Text(
              AppTranslations.getText('type_handbrake_bar'),
              style: const TextStyle(color: Colors.redAccent),
            ),
          ),
          PopupMenuItem(
            value: Layout5ItemType.handbrakeIcon,
            child: Text(
              AppTranslations.getText('type_handbrake_icon'),
              style: const TextStyle(color: Colors.redAccent),
            ),
          ),
        ],
        if (!_hasSteeringWheelIcon)
          PopupMenuItem(
            value: Layout5ItemType.steeringWheelIcon,
            child: Text(
              AppTranslations.getText('type_steering_wheel'),
              style: const TextStyle(color: Colors.greenAccent),
            ),
          ),
        if (!_hasSteeringBar)
          PopupMenuItem(
            value: Layout5ItemType.steeringBar,
            child: Text(
              'Direksiyon Barı Ekle',
              style: const TextStyle(color: Colors.greenAccent),
            ),
          ),
        PopupMenuItem(
          value: Layout5ItemType.buttonSquare,
          child: Text(
            AppTranslations.getText('add_square_button'),
            style: const TextStyle(color: Colors.white),
          ),
        ),
        PopupMenuItem(
          value: Layout5ItemType.buttonSoft,
          child: Text(
            AppTranslations.getText('add_soft_button'),
            style: const TextStyle(color: Colors.white),
          ),
        ),
        PopupMenuItem(
          value: Layout5ItemType.buttonCircle,
          child: Text(
            AppTranslations.getText('add_circle_button'),
            style: const TextStyle(color: Colors.white),
          ),
        ),
        PopupMenuItem(
          value: Layout5ItemType.touchpad,
          child: Text(
            AppTranslations.getText('add_touchpad'),
            style: const TextStyle(color: Colors.white),
          ),
        ),
      ],
      onSelected: _addItem,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFF40E0D0).withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFF40E0D0)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.add, color: Color(0xFF40E0D0), size: 18),
            const SizedBox(width: 4),
            Text(
              AppTranslations.getText('add'),
              style: const TextStyle(color: Color(0xFF40E0D0), fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }

  Widget _topBtn(
    String label,
    IconData icon,
    bool active,
    VoidCallback onTap, {
    Color color = const Color(0xFF40E0D0),
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: active
              ? color.withValues(alpha: 0.25)
              : Colors.white.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: active ? color : Colors.white24),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: active ? color : Colors.white70, size: 16),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                color: active ? color : Colors.white70,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
}
}
