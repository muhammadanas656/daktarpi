import 'dart:io';

void main() {
  // 1. Doctor Repository
  final docFile = File('lib/features/doctors/data/doctor_repository.dart');
  var docContent = docFile.readAsStringSync();

  if (!docContent.contains('_isolateEncodeList')) {
    docContent += '\n\nString _isolateEncodeList(dynamic data) => jsonEncode(data);\n';
  }

  docContent = docContent.replaceAll('final freshStr = jsonEncode(fresh);', 
    'final freshStr = await compute(_isolateEncodeList, fresh);');
  
  docContent = docContent.replaceAll('await box.put(cacheKey, jsonEncode(data));', 
    'await box.put(cacheKey, await compute(_isolateEncodeList, data));');

  docFile.writeAsStringSync(docContent);

  // 2. Home Repository
  final homeFile = File('lib/features/home/data/home_repository.dart');
  var homeContent = homeFile.readAsStringSync();

  if (!homeContent.contains('_isolateEncodeHomeList')) {
    homeContent += '\n\nString _isolateEncodeHomeList(dynamic data) => jsonEncode(data);\n';
  }

  homeContent = homeContent.replaceAll('final freshStr = jsonEncode(data);', 
    'final freshStr = await compute(_isolateEncodeHomeList, data);');

  homeFile.writeAsStringSync(homeContent);
}
