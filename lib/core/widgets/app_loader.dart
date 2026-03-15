import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class AppLoader extends StatelessWidget {
  final Color? color;
  final double strokeWidth;

  const AppLoader({
    super.key,
    this.color,
    this.strokeWidth = 4.0,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: CircularProgressIndicator(
        color: color ?? AppColors.primaryGreen,
        strokeWidth: strokeWidth,
      ),
    );
  }
}
