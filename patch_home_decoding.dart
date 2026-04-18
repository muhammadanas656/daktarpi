import 'dart:io';

void main() {
  final file = File('lib/features/home/data/home_repository.dart');
  var content = file.readAsStringSync();

  if (!content.contains("import 'package:flutter/foundation.dart';")) {
    content = content.replaceFirst("import 'dart:convert';", "import 'dart:convert';\nimport 'package:flutter/foundation.dart';");
  }

  if (!content.contains('_isolateDecodeHomeList')) {
    content += '\n\nList<dynamic> _isolateDecodeHomeList(String encoded) => jsonDecode(encoded) as List<dynamic>;\n';
  }

  content = content.replaceAll(
    'final decoded = jsonDecode(cachedData) as List<dynamic>;',
    'final decoded = await compute(_isolateDecodeHomeList, cachedData);'
  );

  file.writeAsStringSync(content);
}
