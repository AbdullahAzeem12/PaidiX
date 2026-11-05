/// Defines app motion in the application theme system.

import 'package:flutter/material.dart';

class AppMotion {
  AppMotion._();

  static const Duration fast = Duration(milliseconds: 120);
  static const Duration normal = Duration(milliseconds: 220);
  static const Duration medium = Duration(milliseconds: 320);
  static const Duration slow = Duration(milliseconds: 450);

  static const Curve easeOutSpring = Curves.easeOutBack;
  static const Curve easeIn = Curves.easeIn;
  static const Curve easeOut = Curves.easeOutCubic;
  static const Curve standard = Curves.easeInOutCubic;

  static const double buttonPressScale = 0.96;
}

