import os

base_path = r"c:\skills development\daktarpi\lib\features\doctors\presentation\screens"

def fix_popular():
    path = os.path.join(base_path, "popular_doctors_screen.dart")
    with open(path, "r", encoding="utf-8") as f:
        content = f.read()

    # Fix imports
    if "import '../../../../core/widgets/background_sync_indicator.dart';" not in content:
        content = content.replace(
            "import '../../../../core/theme/app_styles.dart';",
            "import '../../../../core/theme/app_styles.dart';\nimport '../../../../core/widgets/premium_app_loader.dart';\nimport '../../../../core/widgets/background_sync_indicator.dart';"
        )

    # Fix getter
    content = content.replace("BackgroundSyncIndicator(isSyncing: _isLoading && _doctors.isNotEmpty)", "BackgroundSyncIndicator(isSyncing: _isLoading && sortedDisplayList.isNotEmpty)")

    # Fix the empty loader
    if "child: PremiumAppLoader()" not in content:
        content = content.replace(
            "    _isLoading\n                                  ? const SizedBox.shrink()\n                                  : const Center(",
            "    _isLoading\n                                  ? const Center(child: PremiumAppLoader())\n                                  : const Center("
        )

    with open(path, "w", encoding="utf-8") as f:
        f.write(content)

def fix_featured():
    path = os.path.join(base_path, "featured_doctors_screen.dart")
    with open(path, "r", encoding="utf-8") as f:
        content = f.read()

    # Fix imports
    if "import '../../../../core/widgets/background_sync_indicator.dart';" not in content:
        content = content.replace(
            "import '../../../../core/widgets/app_loader.dart';",
            "import '../../../../core/widgets/app_loader.dart';\nimport '../../../../core/widgets/premium_app_loader.dart';\nimport '../../../../core/widgets/background_sync_indicator.dart';"
        )
        
    s1 = """                if (_isLoading && doctors.isNotEmpty)
                  Positioned(
                    top: MediaQuery.paddingOf(context).top,
                    left: 0,
                    right: 0,
                    child: LinearProgressIndicator(
                      color: AppColors.primaryGreen,
                      backgroundColor: AppColors.primaryGreen.withOpacity(0.1),
                      minHeight: 2,
                    ),
                  ),"""
    s2 = """                Positioned(
                  top: MediaQuery.paddingOf(context).top,
                  left: 0,
                  right: 0,
                  child: BackgroundSyncIndicator(isSyncing: _isLoading && doctors.isNotEmpty),
                ),"""
    content = content.replace(s1, s2)
    
    # Fix the premium loader
    content = content.replace("AppLoader(color: AppColors.primaryGreen)", "PremiumAppLoader()")

    with open(path, "w", encoding="utf-8") as f:
        f.write(content)

fix_popular()
fix_featured()
print("Fixed screens!")
