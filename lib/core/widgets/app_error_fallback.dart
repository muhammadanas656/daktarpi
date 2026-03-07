import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class AppErrorFallback extends StatelessWidget {
  final VoidCallback onGoHome;
  final FlutterErrorDetails? errorDetails; // <-- NEW: Accepts the raw error

  const AppErrorFallback({
    super.key,
    required this.onGoHome,
    this.errorDetails, // <-- NEW
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: context.colorBg,
      child: SafeArea(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: AppColors.primaryGreen.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.health_and_safety_rounded,
                  color: AppColors.primaryGreen,
                  size: 36,
                ),
              ),
              SizedBox(height: 20),
              Text(
                'Something went wrong',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: context.colorTextDark,
                ),
              ),
              SizedBox(height: 10),
              Text(
                'A temporary issue occurred while rendering this screen.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  height: 1.4,
                  color: context.colorTextLight,
                ),
              ),

              // --- NEW: THE ERROR UNMASKER UI ---
              if (errorDetails != null) ...[
                SizedBox(height: 24),
                Flexible(
                  child: Container(
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.red.withValues(alpha: 0.3),
                      ),
                    ),
                    child: SingleChildScrollView(
                      child: Text(
                        '${errorDetails!.exceptionAsString()}\n\n${errorDetails!.stack}',
                        style: TextStyle(
                          color: Colors.red,
                          fontSize: 12,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ),
                  ),
                ),
              ],

              // -----------------------------------
              SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: onGoHome,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryGreen,
                    foregroundColor: Colors.white,
                    minimumSize: Size.fromHeight(48),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    'Go to Home',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
