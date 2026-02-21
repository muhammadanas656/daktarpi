import 'package:flutter/material.dart';

class AppShapes {
  AppShapes._();

  static const double radiusXs = 6;
  static const double radiusSm = 10;
  static const double radiusMd = 12;
  static const double radiusLg = 16;
  static const double radiusXl = 20;
  static const double radiusDialog = 24;
  static const double radiusPill = 50;

  static BorderRadius get xs => BorderRadius.circular(radiusXs);
  static BorderRadius get sm => BorderRadius.circular(radiusSm);
  static BorderRadius get md => BorderRadius.circular(radiusMd);
  static BorderRadius get lg => BorderRadius.circular(radiusLg);
  static BorderRadius get xl => BorderRadius.circular(radiusXl);
  static BorderRadius get dialog => BorderRadius.circular(radiusDialog);
  static BorderRadius get pill => BorderRadius.circular(radiusPill);
}
