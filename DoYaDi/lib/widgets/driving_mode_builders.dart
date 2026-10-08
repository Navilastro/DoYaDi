import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import '../models/app_settings.dart';
import '../models/layout5_item.dart';
import '../models/joystick_mode.dart';
import '../widgets/driving_painters.dart';
import '../widgets/dynamic_steering_painter.dart';
import '../widgets/driving_tap_zone.dart';
import '../widgets/joystick_widget.dart';
import '../widgets/joystick/joystick_spawn_layer.dart';
import '../screens/driving_screen_state.dart';
import '../core/utils/app_translations.dart';
import '../core/sensor_manager.dart';
import '../core/haptic_manager.dart';

part 'mode_builders/mode0_to_4_builder.dart';
part 'mode_builders/mode5_builder.dart';
part 'mode_builders/mode6_builder.dart';
part 'mode_builders/shared_builders.dart';
/// Tüm mod build metodlarını barındıran mixin.
/// DrivingInputMixin ile birlikte kullanılır.
mixin DrivingModeBuildMixin<T extends StatefulWidget>
    on State<T>, DrivingInputMixin<T> {
  Widget buildLayout(AppSettings settings, Size size) {
    switch (settings.defaultDrivingMode) {
      case 0:
        return buildMode0(settings, size);
      case 1:
        return buildMode1(settings, size);
      case 2:
        return buildMode2(settings, size);
      case 3:
        return buildMode3(settings, size);
      case 4:
        return buildMode4(settings, size);
      case 5:
        return buildMode5(settings, size);
      case 6:
        return buildMode6(settings, size);
      default:
        return buildMode0(settings, size);
    }
  }

}
