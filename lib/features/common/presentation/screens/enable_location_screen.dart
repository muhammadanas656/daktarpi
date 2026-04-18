import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';

class EnableLocationScreen extends StatefulWidget {
  const EnableLocationScreen({super.key});

  @override
  State<EnableLocationScreen> createState() => _EnableLocationScreenState();
}

class _EnableLocationScreenState extends State<EnableLocationScreen>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    // Listen to app lifecycle to detect when user comes back from Settings
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // If user returns to the app, check if they enabled location
    if (state == AppLifecycleState.resumed) {
      _checkLocationStatus();
    }
  }

  Future<void> _checkLocationStatus() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (serviceEnabled && mounted) {
      // Automatically close screen if location is now enabled
      // Passing 'true' indicates success
      if (context.canPop()) {
        context.pop(true);
      }
    }
  }

  Future<void> _openSettings() async {
    await Geolocator.openLocationSettings();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    // Ensure status bar icons contrast with active background
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: InkWell(
            onTap: () {
              if (context.canPop()) {
                context.pop(false); // Return false if user cancelled
              }
            },
            borderRadius: BorderRadius.circular(12),
            child: Container(
              margin: EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: isDark ? Colors.white12 : Colors.grey.shade200),
              ),
              child: Icon(
                Icons.arrow_back_ios_new,
                size: 18,
                color: context.colorTextDark,
              ),
            ),
          ),
          title: Text(
            "Enable Location Services",
            style: TextStyle(
              color: context.colorTextDark,
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
          centerTitle: true,
        ),
        body: SafeArea(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Spacer(flex: 1),
                // --- ILLUSTRATION ---
                Container(
                  width: 200,
                  height: 200,
                  decoration: BoxDecoration(
                    color: AppColors.primaryGreen.withAlpha(isDark ? 30 : 25), // Smooth tinted circle
                    shape: BoxShape.circle,
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Dotted Path illustration
                      Positioned(
                        top: 100,
                        child: SizedBox(
                          width: 120,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: List.generate(
                              6,
                              (index) => Container(
                                width: 8,
                                height: 4,
                                decoration: BoxDecoration(
                                  color: isDark ? Colors.white24 : Colors.black26,
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      // Pin 1 (Start)
                      Positioned(
                        left: 40,
                        top: 60,
                        child: Icon(
                          Icons.location_on,
                          size: 60,
                          color: Colors.redAccent,
                        ),
                      ),
                      // Pin 2 (End)
                      Positioned(
                        right: 40,
                        top: 40,
                        child: Icon(
                          Icons.location_on,
                          size: 50,
                          color: Colors.redAccent,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 40),

                // --- TITLE & DESCRIPTION ---
                Text(
                  "Location",
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: context.colorTextDark,
                  ),
                ),
                SizedBox(height: 12),
                Text(
                  "Your location services are switched off. Please enable location to find relevant doctors and hospitals near you.",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: isDark ? Colors.white70 : Colors.grey[600],
                    height: 1.5,
                  ),
                ),
                Spacer(flex: 2),

                // --- BUTTON ---
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _openSettings,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryGreen,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 2,
                    ),
                    child: Text(
                      "Enable Location",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                SizedBox(height: 16),
                // Fallback Button
                TextButton(
                  onPressed: () {
                    if (context.canPop()) {
                      context.pop(false);
                    }
                  },
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: Text(
                    "Skip for now",
                    style: TextStyle(
                      color: isDark ? Colors.white60 : Colors.grey[600],
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                SizedBox(height: 12), // Bottom padding
              ],
            ),
          ),
        ),
      ),
    );
  }
}
