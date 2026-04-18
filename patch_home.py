import os

path = r"c:\skills development\daktarpi\lib\features\home\presentation\screens\home_screen.dart"

with open(path, "r", encoding="utf-8") as f:
    orig_content = f.read()

# Replace the initState block completely
old_init = """  @override
  void initState() {
    super.initState();
    _launchController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    );

    if (!widget.isBackgroundLayer) {
      // 🚀 SYNCED LAUNCH: Delay the internal stagger precisely by 400ms. 
      // This ensures it begins staggering exactly as the Router's 800ms FadeTransition becomes visible!
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted && !_launchController.isAnimating && !_launchController.isCompleted) {
          _launchController.forward(from: 0.0);
        }
      });

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        // THE FIX: Trigger the native RefreshIndicator which visually drops down the spinner
        // and safely executes `onRefresh: _refreshData` which hits `forceRefresh: true`.
        _refreshIndicatorKey.currentState?.show();
      });
    }
  }"""

new_init = """  @override
  void initState() {
    super.initState();
    _launchController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    );

    _docsNotifier.addListener(() {
      if (!mounted) return;
      if (!_docsNotifier.isLoading) {
        if (!_launchController.isAnimating && !_launchController.isCompleted) {
          _launchController.forward(from: 0.0);
        }
      } else {
        _launchController.reset();
      }
    });

    if (!widget.isBackgroundLayer) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _refreshIndicatorKey.currentState?.show();
      });
    }
  }"""


# Replace the build method array list sections
old_build_section = """                    _buildStaggered(start: 0.1, end: 0.6, slideDown: true, child: _buildHeader()),
                    ListenableBuilder(
                      listenable: _docsNotifier,
                      builder: (context, _) => BackgroundSyncIndicator(isSyncing: _docsNotifier.isLoading),
                    ),
                    _buildStaggered(start: 0.2, end: 0.7, child: HomeBanner(banners: _banners)),
                    _buildStaggered(start: 0.3, end: 0.8, child: _buildSpecialtiesSection()),
                    _buildStaggered(start: 0.4, end: 0.9, child: _buildPopularSection()),
                    _buildStaggered(start: 0.5, end: 1.0, child: _buildFeaturedSection()),"""

new_build_section = """                    _buildStaggered(start: 0.1, end: 0.6, slideDown: true, child: _buildHeader()),
                    _buildStaggered(start: 0.2, end: 0.7, child: HomeBanner(banners: _banners)),
                    ListenableBuilder(
                      listenable: _docsNotifier,
                      builder: (context, _) {
                        if (_docsNotifier.isLoading) {
                          return const Padding(
                            padding: EdgeInsets.only(top: 100),
                            child: Center(
                              child: CircularProgressIndicator(color: AppColors.primaryGreen),
                            ),
                          );
                        }
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildStaggered(start: 0.3, end: 0.8, child: _buildSpecialtiesSection()),
                            _buildStaggered(start: 0.4, end: 0.9, child: _buildPopularSection()),
                            _buildStaggered(start: 0.5, end: 1.0, child: _buildFeaturedSection()),
                          ],
                        );
                      },
                    ),"""

content = orig_content.replace(old_init, new_init)
content = content.replace(old_build_section, new_build_section)

# We also need to remove PremiumAppLoader handling in _buildPopularList and _buildFeaturedList
import re
popular_loader = re.compile(r"    if \(_docsNotifier\.isLoading && popular\.isEmpty\) \{.*?\}.*?else if", re.DOTALL)
content = popular_loader.sub("    if", content)

featured_loader = re.compile(r"    if \(_docsNotifier\.isLoading && featured\.isEmpty\) \{.*?\}.*?else if", re.DOTALL)
content = featured_loader.sub("    if", content)


with open(path, "w", encoding="utf-8") as f:
    f.write(content)

print("Home patched")
