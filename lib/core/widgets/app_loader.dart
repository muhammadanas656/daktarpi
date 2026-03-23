import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class AppLoader extends StatelessWidget {
  final Color? color;
  final double strokeWidth;
  final double? size;

  const AppLoader({
    super.key,
    this.color,
    this.strokeWidth = 4.0,
    this.size,
  });

  @override
  Widget build(BuildContext context) {
    Widget loader = CircularProgressIndicator(
      color: color ?? AppColors.primaryGreen,
      strokeWidth: strokeWidth,
    );

    if (size != null) {
      loader = SizedBox(width: size, height: size, child: loader);
    }

    return Center(child: loader);
  }
}
