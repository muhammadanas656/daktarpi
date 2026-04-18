import 'dart:io';

void main() {
  final file = File('lib/main.dart');
  var content = file.readAsStringSync();

  final target = '''        await Future.wait([
          ProfileNotifier.instance.loadProfile(),
          FavoritesNotifier.instance.loadFavorites(),
        ]);
        await Future.wait([
          DoctorsNotifier.instance.fetchSpecialties(),
          DoctorsNotifier.instance.fetchPopularDoctors(limit: 5, isHomeFeed: true),
          DoctorsNotifier.instance.fetchFeaturedDoctors(limit: 5, isHomeFeed: true),
          HomeRepository().fetchBanners(ProfileNotifier.instance.profile?.countryIso),
        ]);''';

  final replacement = '''        // --- PRO FIX: SEQUENTIAL EVENT LOOP SPACING ---
        // Firing 6 simultaneous HTTP API calls blasts the underlying socket allocator
        // and chokes the Dart microtask queue, which randomly skips Lottie frames.
        // We delay the entire block until the heaviest part of the Lottie finishes (800ms)
        // and space requests by 150ms to ensure 60fps repaints slip through perfectly!
        
        await Future.delayed(const Duration(milliseconds: 800));
        
        await ProfileNotifier.instance.loadProfile();
        await Future.delayed(const Duration(milliseconds: 150));
        
        await FavoritesNotifier.instance.loadFavorites();
        await Future.delayed(const Duration(milliseconds: 150));
        
        await DoctorsNotifier.instance.fetchSpecialties();
        await Future.delayed(const Duration(milliseconds: 150));
        
        await DoctorsNotifier.instance.fetchPopularDoctors(limit: 5, isHomeFeed: true);
        await Future.delayed(const Duration(milliseconds: 150));
        
        await DoctorsNotifier.instance.fetchFeaturedDoctors(limit: 5, isHomeFeed: true);
        await Future.delayed(const Duration(milliseconds: 150));
        
        await HomeRepository().fetchBanners(ProfileNotifier.instance.profile?.countryIso);''';

  if (content.contains(target)) {
    content = content.replaceFirst(target, replacement);
  } else {
    print('Failed to find target in main.dart');
  }

  // Also remove the "Future.delayed(2000)" for texture precaching, since we already
  // organically pushed the timeline back using sequential delays spanning 1550ms!
  final textureTarget = '''        // We delay the HTTP streaming by precisely 2000ms. By this timestamp, the Lottie 
        // animation is either finished or completely settled, so the massive burst of 
        // network HTTP stacks will NOT choke out the 60fps UI thread!
        Future.delayed(const Duration(milliseconds: 2000), () {
          for (final url in imageUrls) {
            if (url.isNotEmpty) {
              final provider = CachedNetworkImageProvider(url);
              provider.resolve(const ImageConfiguration()).addListener(
                ImageStreamListener((info, call) {}),
              );
            }
          }
        });''';

  final textureReplacement = '''        // We stagger the image texture pre-caching loops safely 100ms apart from the network calls
        // so that the engine doesn't burst all operations on one frame!
        await Future.delayed(const Duration(milliseconds: 150));
        
        for (final url in imageUrls) {
          if (url.isNotEmpty) {
            final provider = CachedNetworkImageProvider(url);
            provider.resolve(const ImageConfiguration()).addListener(
              ImageStreamListener((info, call) {}),
            );
          }
        }''';

  if (content.contains(textureTarget)) {
    content = content.replaceFirst(textureTarget, textureReplacement);
  } else {
     print('Failed to find textureTarget in main.dart');
  }


  file.writeAsStringSync(content);
}
