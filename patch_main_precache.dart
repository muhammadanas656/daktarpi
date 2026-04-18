import 'dart:io';

void main() {
  final file = File('lib/main.dart');
  var content = file.readAsStringSync();

  if (!content.contains("import 'package:cached_network_image/cached_network_image.dart';")) {
    content = content.replaceFirst("import 'package:flutter/material.dart';", "import 'package:flutter/material.dart';\nimport 'package:cached_network_image/cached_network_image.dart';");
  }

  // Inject the precache logic right after the Future.wait block
  final target = '''        await Future.wait([
          DoctorsNotifier.instance.fetchSpecialties(),
          DoctorsNotifier.instance.fetchPopularDoctors(limit: 5, isHomeFeed: true),
          DoctorsNotifier.instance.fetchFeaturedDoctors(limit: 5, isHomeFeed: true),
          HomeRepository().fetchBanners(ProfileNotifier.instance.profile?.countryIso),
        ]);''';

  final replacement = '''        await Future.wait([
          DoctorsNotifier.instance.fetchSpecialties(),
          DoctorsNotifier.instance.fetchPopularDoctors(limit: 5, isHomeFeed: true),
          DoctorsNotifier.instance.fetchFeaturedDoctors(limit: 5, isHomeFeed: true),
          HomeRepository().fetchBanners(ProfileNotifier.instance.profile?.countryIso),
        ]);

        // --- PRO FIX: NATIVE TEXTURE AGGRESSIVE PRE-CACHE ---
        // Instantly force the Flutter engine to decode raw image textures into the GPU cache BEFORE the splash screen ends!
        final imageUrls = <String>{};

        for (var d in DoctorsNotifier.instance.homePopularDoctors) {
          if (d['profile_picture_url'] != null) imageUrls.add(d['profile_picture_url']);
        }
        for (var d in DoctorsNotifier.instance.homeFeaturedDoctors) {
          if (d['profile_picture_url'] != null) imageUrls.add(d['profile_picture_url']);
        }
        for (var s in DoctorsNotifier.instance.specialties) {
          if (s['icon_url'] != null) imageUrls.add(s['icon_url']);
        }
        
        // Use the raw home repository static cache we built in the previous fix!
        // We can access it directly by forcing an empty string ISO, but it's cleaner to just fetch what we can.
        final banners = await HomeRepository().fetchBanners(ProfileNotifier.instance.profile?.countryIso);
        for (var b in banners) {
          if (b['image_url'] != null) imageUrls.add(b['image_url']);
        }

        if (ProfileNotifier.instance.profile?.profilePictureUrl != null) {
          imageUrls.add(ProfileNotifier.instance.profile!.profilePictureUrl!);
        }

        // Fire parallel asynchronous decoders to VRAM
        for (final url in imageUrls) {
          if (url.isNotEmpty) {
            final provider = CachedNetworkImageProvider(url);
            provider.resolve(const ImageConfiguration()).addListener(
              ImageStreamListener((info, call) {
                // Instantly resolved and decoded to textures
              }),
            );
          }
        }''';

  if (!content.contains('NATIVE TEXTURE AGGRESSIVE PRE-CACHE')) {
    content = content.replaceFirst(target, replacement);
  }

  file.writeAsStringSync(content);
}
