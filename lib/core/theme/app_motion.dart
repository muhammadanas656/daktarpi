import 'package:flutter/material.dart';

/// Centralized motion tokens for consistent interaction timing.
abstract final class AppMotion {
  static const Duration fast = Duration(milliseconds: 200);
  static const Duration standard = Duration(milliseconds: 300);
  static const Duration slow = Duration(milliseconds: 400);
  static const Duration defaultDuration = standard;

  static const Duration snackbarVisible = Duration(seconds: 4);

  static const Curve emphasized = Curves.easeOutBack;
  static const Curve standardCurve = Curves.easeInOut;
}
