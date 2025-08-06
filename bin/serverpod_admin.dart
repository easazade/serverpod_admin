import 'dart:io';

import 'package:serverpod_admin/src/file_generators/admin_route_generator.dart';
import 'package:serverpod_admin/src/file_generators/admin_utils_generator.dart';
import 'package:serverpod_admin/src/reader.dart';
import 'package:serverpod_admin/src/utils_function.dart';


void main(List<String> args) async {
  final pubspecJson = await readJsonOrYamlFile(File('pubspec.yaml'));
  final Map<String, dynamic> config = pubspecJson['serverpod_admin'];

  final serverPath = config['server-path'].toString();
  final serverPackageName = config['server-package-name'].toString();

  final reader = ServerpodYamlReader(serverPath: serverPath);

  final readResult = await reader.read();
  final serverpodEntities = readResult.entities;
  final serverpodModuleImports = readResult.moduleImports;

  for (var entity in serverpodEntities) {
    print('-> ${entity.name}: ${entity.type}');
  }

  final generatableFiles = [
    // AdminEndpointGenerator(
    //   serverPath: serverPath,
    //   entities: serverpodEntities,
    //   serverPackageName: serverPackageName,
    // ),
    AdminRouteGenerator(
      serverPath: serverPath,
      entities: serverpodEntities,
      serverPackageName: serverPackageName,
    ),
    AdminUtilsGenerator(
      serverPath: serverPath,
      entities: serverpodEntities,
      serverPackageName: serverPackageName,
      serverpodModuleImports: serverpodModuleImports,
    ),
  ];

  for (var file in generatableFiles) {
    await file.createFile();
  }
}
