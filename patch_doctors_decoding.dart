import 'dart:io';

void main() {
  final file = File('lib/features/doctors/data/doctor_repository.dart');
  var content = file.readAsStringSync();

  // Add the isolate function at the end of the file
  if (!content.contains('_isolateDecodeList')) {
    content += '\n\nList<dynamic> _isolateDecodeList(String encoded) => jsonDecode(encoded) as List<dynamic>;\n';
  }

  content = content.replaceAll(
    'final List<dynamic> decoded = jsonDecode(cachedData);',
    'final List<dynamic> decoded = await compute(_isolateDecodeList, cachedData);'
  );

  file.writeAsStringSync(content);
}
