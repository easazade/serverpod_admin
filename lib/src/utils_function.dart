import 'dart:convert';
import 'dart:io';

import 'package:yaml/yaml.dart';

import 'meta/serverpod_entity.dart';

Future<Map<String, dynamic>> readJsonOrYamlFile(File file) async {
  try {
    var fileContent = await file.readAsString();
    return _readJsonOrYaml(fileContent);
  } catch (e, _) {
    print(e);
    throw Exception('Unsupported File: make sure the file content is in correct json or yaml format');
  }
}

Map<String, dynamic> _readJsonOrYaml(String content) {
  if (content.startsWith('{')) {
    var json = jsonDecode(content);
    return json;
  } else {
    YamlMap yaml = loadYaml(content);
    var map = jsonDecode(jsonEncode(yaml)) as Map<String, dynamic>;
    return map;
  }
}

extension ServerpodEntityX on Iterable<ServerpodEntity> {
  /// returns ServerpodEntity of type ServerpodClass if that class also has a table in database
  List<ServerpodClass> whereClassWithTables() => whereType<ServerpodClass>().where((e) => e.table != null).toList();
}
