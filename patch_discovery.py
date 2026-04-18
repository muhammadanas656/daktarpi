import os
import re

base_path = r"c:\skills development\daktarpi\lib\features\doctors\presentation\screens"

def patch_screen(filename):
    path = os.path.join(base_path, filename)
    with open(path, "r", encoding="utf-8") as f:
        content = f.read()

    # Common for Specialty, Popular, Featured
    # 1. Remove BackgroundSyncIndicator
    content = re.sub(r"Positioned\(\s*top: MediaQuery\.paddingOf\(context\)\.top.*?BackgroundSyncIndicator.*?\),", "", content, flags=re.DOTALL)
    
    # 2. Hide lists if _isLoading
    if filename == "specialty_doctors_screen.dart":
        # It has: `if (_isLoading && _doctors.isEmpty) ... else if (_doctors.isEmpty && !_isLoading)`
        # Change to `if (_isLoading) ... else if (_doctors.isEmpty)`
        content = re.sub(
            r"if \(_isLoading && _doctors\.isEmpty\).*?child: PremiumAppLoader\(\)\),.*?},\s*\)",
            """if (_isLoading)
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.only(top: 100),
                    child: Center(child: CircularProgressIndicator(color: AppColors.primaryGreen)),
                  ),
                )
              else if (_doctors.isEmpty)""",
            content, flags=re.DOTALL
        )
        content = content.replace("else if (_doctors.isEmpty && !_isLoading)", "else if (_doctors.isEmpty)")

    elif filename == "popular_doctors_screen.dart":
        content = re.sub(
            r"if \(_isLoading\)\s*\? const Center\(child: PremiumAppLoader\(\)\)\s*: const Center\(",
            """_isLoading
                                  ? const Center(child: CircularProgressIndicator(color: AppColors.primaryGreen))
                                  : const Center(""",
            content, flags=re.DOTALL
        )
        # Wait, if sortedDisplayList is NOT empty, it currently shows! We must hide it.
        # It currently says:
        # if (sortedDisplayList.isEmpty) SliverFillRemaining(child: _isLoading ? loader : texts) else SliverPadding(SliverList)
        # Change to: `if (_isLoading) SliverFillRemaining(loader) else if (sortedDisplayList.isEmpty) ...` 
        pattern = r"if \(sortedDisplayList\.isEmpty\).*?else\s*SliverPadding\("
        new_str = """if (_isLoading)
                        const SliverFillRemaining(
                          hasScrollBody: false,
                          child: Center(child: CircularProgressIndicator(color: AppColors.primaryGreen)),
                        )
                      else if (sortedDisplayList.isEmpty)
                        const SliverFillRemaining(
                          hasScrollBody: false,
                          child: Center(child: Text("No popular doctors found")),
                        )
                      else
                        SliverPadding("""
        content = re.sub(pattern, new_str, content, flags=re.DOTALL)

    elif filename == "featured_doctors_screen.dart":
        pattern = r"if \(_isLoading && doctors\.isEmpty\).*?PremiumAppLoader\(\)\),.*?else if \(doctors\.isEmpty\)"
        new_str = """if (_isLoading)
                        const SliverFillRemaining(
                          hasScrollBody: false,
                          child: Center(child: CircularProgressIndicator(color: AppColors.primaryGreen)),
                        )
                      else if (doctors.isEmpty)"""
        content = re.sub(pattern, new_str, content, flags=re.DOTALL)


    with open(path, "w", encoding="utf-8") as f:
        f.write(content)
    print(f"Patched {filename}")

for f in ["specialty_doctors_screen.dart", "popular_doctors_screen.dart", "featured_doctors_screen.dart"]:
    patch_screen(f)

# Doctor Details Screen
def patch_details():
    path = os.path.join(base_path, "doctor_details_screen.dart")
    with open(path, "r", encoding="utf-8") as f:
        content = f.read()

    # Remove BackgroundSyncIndicator
    content = re.sub(r"BackgroundSyncIndicator\(isSyncing: _isHeavyDataLoading\),", "", content)

    # Change AnimatedSwitcher logic to return CircularProgressIndicator if _isHeavyDataLoading (unconditionally, not just if clinics.isEmpty)
    # The switcher handles: `_isOfflineState ? ... : (_isHeavyDataLoading && _clinics.isEmpty) ? PremiumAppLoader : Column(...)`
    # Change to: `_isOfflineState ? ... : _isHeavyDataLoading ? CircularProgressIndicator : Column(...)`
    content = content.replace("(_isHeavyDataLoading && _clinics.isEmpty) ?", "_isHeavyDataLoading ?")
    content = content.replace("PremiumAppLoader()", "CircularProgressIndicator(color: AppColors.primaryGreen)")

    with open(path, "w", encoding="utf-8") as f:
        f.write(content)
    print("Patched doctor list details")

patch_details()
