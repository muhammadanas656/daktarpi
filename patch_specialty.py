import re
import os

base_path = r"c:\skills development\daktarpi\lib\features\doctors\presentation\screens"

files_to_patch = [
    "popular_doctors_screen.dart",
    "featured_doctors_screen.dart"
]

def patch_file(filename):
    path = os.path.join(base_path, filename)
    with open(path, "r", encoding="utf-8") as f:
        content = f.read()

    # 1. Add Imports
    if "import '../../../../core/widgets/background_sync_indicator.dart';" not in content:
        import_pattern = re.compile(r"(import '../../../../presentation/widgets/app_network_image\.dart';)")
        content = import_pattern.sub(r"\1\nimport '../../../../core/widgets/premium_app_loader.dart';\nimport '../../../../core/widgets/background_sync_indicator.dart';", content)

    # 2. Replace LinearProgressIndicator
    overlay_pattern = re.compile(r"          if \(_isLoading\)\s+Positioned\(\s+top: MediaQuery\.paddingOf\(context\)\.top \+ kToolbarHeight \+ 112\.0,\s+left: 0,\s+right: 0,\s+child: const LinearProgressIndicator\(\s+color: AppColors\.primaryGreen,\s+backgroundColor: Colors\.transparent,\s+minHeight: 1\.5,\s+\),\s+\),")
    
    # 2.1 Fallback string pattern if the spacing differs slightly. This one is more liberal.
    overlay_pattern2 = re.compile(r"[\s]*if\s*\(_isLoading\)\s*Positioned\(.*?child:\s*const\s*LinearProgressIndicator\(.*?minHeight:\s*1\.5,\s*\),\s*\),", re.DOTALL)
    
    new_snippet = """          Positioned(
            top: MediaQuery.paddingOf(context).top + kToolbarHeight + 112.0,
            left: 0,
            right: 0,
            child: BackgroundSyncIndicator(isSyncing: _isLoading && _doctors.isNotEmpty),
          ),"""
          
    content = overlay_pattern.sub(new_snippet, content)
    content = overlay_pattern2.sub(new_snippet, content)
    
    # 3. Add PremiumAppLoader placeholder
    empty_pattern = re.compile(r"(\s+)(if \(_doctors\.isEmpty && !_isLoading\)\s+SliverToBoxAdapter\(\s+child:)")
    new_empty = r"""\1if (_isLoading && _doctors.isEmpty)
\1  const SliverToBoxAdapter(
\1    child: Padding(
\1      padding: EdgeInsets.only(top: 100),
\1      child: Center(child: PremiumAppLoader()),
\1    ),
\1  )
\1else \2"""
    content = empty_pattern.sub(new_empty, content)

    with open(path, "w", encoding="utf-8") as f:
        f.write(content)
        
    print(f"Patched {filename}")

for f in files_to_patch:
    patch_file(f)

# Also patch specialty empty state which missed earlier
def patch_specialty_empty():
    path = os.path.join(base_path, "specialty_doctors_screen.dart")
    with open(path, "r", encoding="utf-8") as f:
        content = f.read()
    empty_pattern = re.compile(r"(\s+)(if \(_doctors\.isEmpty && !_isLoading\)\s+SliverToBoxAdapter\(\s+child:)")
    new_empty = r"""\1if (_isLoading && _doctors.isEmpty)
\1  const SliverToBoxAdapter(
\1    child: Padding(
\1      padding: EdgeInsets.only(top: 100),
\1      child: Center(child: PremiumAppLoader()),
\1    ),
\1  )
\1else \2"""
    # Replace only if not already there
    if "Center(child: PremiumAppLoader())" not in content:
        content = empty_pattern.sub(new_empty, content)
        with open(path, "w", encoding="utf-8") as f:
            f.write(content)
        print("Patched specialty empty state")

patch_specialty_empty()
