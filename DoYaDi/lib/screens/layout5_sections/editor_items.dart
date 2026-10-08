part of '../custom_layout5_editor_screen.dart';
extension _EditorItemsExt on _CustomLayout5EditorScreenState {
  void _addItem(Layout5ItemType type) {
    // ── KATI YERLEŞİM KISITLAMALARI (VALIDATION RULES) ──
    if (type == Layout5ItemType.leftJoystick && _hasLeftJoystick) {
      _showConstraintWarning('Ekranda en fazla 1 adet Sol Joystick bulunabilir!');
      return;
    }
    if (type == Layout5ItemType.rightJoystick && _isRightAnalogSensorControlled) {
      _showConstraintWarning('Sağ analog sensör ile yönetildiği için eklenemez!');
      return;
    }
    if (type == Layout5ItemType.rightJoystick && _hasRightJoystick) {
      _showConstraintWarning('Ekranda en fazla 1 adet Sağ Joystick bulunabilir!');
      return;
    }
    if (type == Layout5ItemType.rightJoystick && (_hasHandbrakeController || _hasClutchController)) {
      _showConstraintWarning('El freni veya debriyaj varken sağ joystick eklenemez!');
      return;
    }
    if ((type == Layout5ItemType.gasBar || type == Layout5ItemType.gasPedalIcon) && _hasGasController) {
      _showConstraintWarning('Ekranda en fazla 1 adet Gaz kontrolcüsü bulunabilir (Gaz Barı ve Gaz İkonu aynı anda kullanılamaz)!');
      return;
    }
    if ((type == Layout5ItemType.brakeBar || type == Layout5ItemType.brakePedalIcon) && _hasBrakeController) {
      _showConstraintWarning('Ekranda en fazla 1 adet Fren kontrolcüsü bulunabilir (Fren Barı ve Fren İkonu aynı anda kullanılamaz)!');
      return;
    }
    if ((type == Layout5ItemType.clutchBar || type == Layout5ItemType.clutchIcon) && _isRightAnalogSensorControlled) {
      _showConstraintWarning('Sağ analog sensör ile yönetildiği için Debriyaj eklenemez!');
      return;
    }
    if ((type == Layout5ItemType.clutchBar || type == Layout5ItemType.clutchIcon) && _hasClutchController) {
      _showConstraintWarning('Ekranda en fazla 1 adet Debriyaj kontrolcüsü bulunabilir!');
      return;
    }
    if ((type == Layout5ItemType.handbrakeButton || type == Layout5ItemType.handbrakeBar || type == Layout5ItemType.handbrakeIcon) && _isRightAnalogSensorControlled) {
      _showConstraintWarning('Sağ analog sensör ile yönetildiği için El Freni eklenemez!');
      return;
    }
    if ((type == Layout5ItemType.handbrakeButton || type == Layout5ItemType.handbrakeBar || type == Layout5ItemType.handbrakeIcon) && _hasHandbrakeController) {
      _showConstraintWarning('Ekranda en fazla 1 adet El Freni bulunabilir!');
      return;
    }
    if (type == Layout5ItemType.steeringWheelIcon && _hasSteeringWheelIcon) {
      _showConstraintWarning('Ekranda en fazla 1 adet Direksiyon İkonu bulunabilir!');
      return;
    }
    if (type == Layout5ItemType.steeringBar && _hasSteeringBar) {
      _showConstraintWarning('Ekranda en fazla 1 adet Direksiyon Barı bulunabilir!');
      return;
    }
    
    // Eğer el freni veya debriyaj ekleniyorsa, varsa sağ joystick'i kaldır
    if (type == Layout5ItemType.clutchBar || type == Layout5ItemType.clutchIcon || type == Layout5ItemType.handbrakeBar || type == Layout5ItemType.handbrakeIcon) {
      _items.removeWhere((e) => e.type == Layout5ItemType.rightJoystick);
    }

    final id = '${type.name}_${DateTime.now().millisecondsSinceEpoch}';
    String? label;
    if (type == Layout5ItemType.buttonSquare ||
        type == Layout5ItemType.buttonSoft ||
        type == Layout5ItemType.buttonCircle) {
      label = null; // default: "$N Buton"
    }
    setState(() {
      _items.add(
        Layout5Item(
          id: id,
          type: type,
          left: 0.3,
          top: 0.3,
          width:
              (type == Layout5ItemType.leftJoystick ||
                  type == Layout5ItemType.rightJoystick)
              ? 0.22
              : (type == Layout5ItemType.gasPedalIcon ||
                  type == Layout5ItemType.brakePedalIcon ||
                  type == Layout5ItemType.clutchIcon)
              ? 0.12
              : 0.18,
          height:
              (type == Layout5ItemType.leftJoystick ||
                  type == Layout5ItemType.rightJoystick)
              ? 0.55
              : (type == Layout5ItemType.gasPedalIcon ||
                  type == Layout5ItemType.brakePedalIcon ||
                  type == Layout5ItemType.clutchIcon)
              ? 0.25
              : 0.22,
          label: label,
        ),
      );
      _selectedId = id;
    });
  }

  void _removeItem(String id) {
    setState(() {
      _items.removeWhere((e) => e.id == id);
      if (_selectedId == id) _selectedId = null;
    });
  }

  void _updateItem(Layout5Item updated) {
    setState(() {
      final idx = _items.indexWhere((e) => e.id == updated.id);
      if (idx >= 0) _items[idx] = updated;

      if (updated.type == Layout5ItemType.leftJoystick && updated.gyroToRightAnalogMode != 0) {
        _items.removeWhere((e) => 
          e.type == Layout5ItemType.rightJoystick ||
          e.type == Layout5ItemType.clutchBar ||
          e.type == Layout5ItemType.clutchIcon ||
          e.type == Layout5ItemType.handbrakeBar ||
          e.type == Layout5ItemType.handbrakeIcon ||
          e.type == Layout5ItemType.handbrakeButton
        );
      }
    });
  }

  Layout5Item? get _selected => _selectedId == null
      ? null
      : _items.cast<Layout5Item?>().firstWhere(
          (e) => e?.id == _selectedId,
          orElse: () => null,
        );

}
