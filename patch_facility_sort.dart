import 'dart:io';

void main() {
  final repoFile = File('lib/features/doctors/data/doctor_repository.dart');
  if (repoFile.existsSync()) {
    var content = repoFile.readAsStringSync();
    
    // Add default alphabetical arrangement to hospitals/clinics
    content = content.replaceFirst(
      'if (isSearch) dbQuery = dbQuery.ilike(\'name\', \'%_query%\');\n        final response = await dbQuery;',
      'if (isSearch) dbQuery = dbQuery.ilike(\'name\', \'%_query%\');\n        dbQuery = dbQuery.order(\'name\', ascending: true);\n        final response = await dbQuery;'
    );
    // Since %query is literal the var in string is $query
    content = content.replaceFirst(
      'if (isSearch) dbQuery = dbQuery.ilike(\'name\', \'%\$query%\');\n        final response = await dbQuery;',
      'if (isSearch) dbQuery = dbQuery.ilike(\'name\', \'%\$query%\');\n        dbQuery = dbQuery.order(\'name\', ascending: true);\n        final response = await dbQuery;'
    );

    repoFile.writeAsStringSync(content);
    print('Updated doctor_repository.dart arrangement');
  }
}
