import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class BackgroundSyncIndicator extends StatelessWidget {
  final bool isSyncing;

  const BackgroundSyncIndicator({
    super.key,
    required this.isSyncing,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedSize(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      child: isSyncing
          ? AnimatedOpacity(
              opacity: isSyncing ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 200),
              child: const LinearProgressIndicator(
                minHeight: 2,
                backgroundColor: Colors.transparent,
                color: AppColors.primaryGreen,
              ),
            )
          : const SizedBox(width: double.infinity, height: 0),
    );
  }
}
