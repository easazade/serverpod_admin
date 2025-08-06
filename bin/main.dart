import 'dart:io';

import 'package:serverpod_admin/src/file_generators/admin_route_generator.dart';
import 'package:serverpod_admin/src/file_generators/admin_utils_generator.dart';
import 'package:serverpod_admin/src/scanner.dart';
import 'package:serverpod_admin/src/utils_function.dart';

void main(List<String> args) async {
  final serverDir = Directory.current;
  final pubspecJson = await readJsonOrYamlFile(File('pubspec.yaml'));
  final serverPackageName = pubspecJson['name'];

  final scanner = ServerpodScanner(serverPath: serverDir.path);

  final readResult = await scanner.scan();
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
    AdminRouteGenerator(serverPath: serverDir.path, entities: serverpodEntities, serverPackageName: serverPackageName),
    AdminUtilsGenerator(
      serverPath: serverDir.path,
      entities: serverpodEntities,
      serverPackageName: serverPackageName,
      serverpodModuleImports: serverpodModuleImports,
    ),
  ];

  for (var file in generatableFiles) {
    await file.createFile();
  }
}
