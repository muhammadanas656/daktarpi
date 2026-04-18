import 'dart:io';

void main() {
  final file = File('lib/features/doctors/presentation/widgets/smart_filter_bar.dart');
  var content = file.readAsStringSync();
  content = content.replaceAll('AppRoutes.location', 'AppRoutes.locationPermission');
  file.writeAsStringSync(content);
}
