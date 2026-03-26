import 'package:flutter/material.dart';

class AppScrollBehavior extends MaterialScrollBehavior {
  const AppScrollBehavior();

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) {
    // Completely replaces strict Math bounds with iOS fluid elasticity natively across the app.
    return const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics());
  }
}
