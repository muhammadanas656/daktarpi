import 'dart:io';

void main() {
  final file = File('lib/features/splash/presentation/screens/splash_screen.dart');
  var content = file.readAsStringSync();

  content = content.replaceAll('filterQuality: FilterQuality.high,', '// filterQuality removed for massive GPU reduction');
  content = content.replaceAll('renderCache:\n                          RenderCache\n                              .drawingCommands, // Fixes Impeller path-dropping bugs', 'renderCache: null, // Avoid Impeller cache-thrashing on dynamic paths');
  content = content.replaceAll('renderCache: RenderCache.drawingCommands,', 'renderCache: null,');

  file.writeAsStringSync(content);
}
