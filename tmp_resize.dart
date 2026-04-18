import 'dart:io';
import 'package:image/image.dart';

void main() {
  final file = File('assets/images/logo.png');
  if (!file.existsSync()) {
    print('Error: logo.png not found');
    return;
  }
  
  final bytes = file.readAsBytesSync();
  final original = decodeImage(bytes);
  
  if (original == null) {
    print('Failed to decode image');
    return;
  }

  // Find the actual bounding box of the non-transparent pixels to trim any existing padding
  int minX = original.width;
  int minY = original.height;
  int maxX = 0;
  int maxY = 0;

  for (int y = 0; y < original.height; y++) {
    for (int x = 0; x < original.width; x++) {
      final pixel = original.getPixel(x, y);
      if (pixel.a > 0) {
        if (x < minX) minX = x;
        if (x > maxX) maxX = x;
        if (y < minY) minY = y;
        if (y > maxY) maxY = y;
      }
    }
  }

  // If empty, bail
  if (minX > maxX || minY > maxY) {
    print('Image is completely transparent');
    return;
  }

  final cropped = copyCrop(original, x: minX, y: minY, width: maxX - minX + 1, height: maxY - minY + 1);

  // Resize cropped to a standard "branding" size (e.g., max 240px wide or high)
  final double scale = 240.0 / (cropped.width > cropped.height ? cropped.width : cropped.height);
  final targetW = (cropped.width * scale).toInt();
  final targetH = (cropped.height * scale).toInt();
  
  final resizedLogo = copyResize(cropped, width: targetW, height: targetH, interpolation: Interpolation.linear);

  // Create a 1000x1000 transparent canvas (Youtube/Google standard 1:4 ratio approx)
  final canvasSize = 1000;
  final padded = Image(width: canvasSize, height: canvasSize, numChannels: 4);

  // Calculate center offsets
  final targetX = (canvasSize - targetW) ~/ 2;
  final targetY = (canvasSize - targetH) ~/ 2;

  // Composite the clean resized logo onto the perfectly sized canvas
  compositeImage(padded, resizedLogo, dstX: targetX, dstY: targetY);

  file.writeAsBytesSync(encodePng(padded));
  print('Successfully generated professional 1000px native boot logo mapping.');
}
