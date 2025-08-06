// ignore_for_file: depend_on_referenced_packages

import 'dart:io';

import 'package:path/path.dart' as p;

import 'meta/serverpod_entity.dart';
import 'utils_function.dart';

class ReadResult {
  final List<ServerpodEntity> entities;
  final List<String> moduleImports;

  ReadResult({required this.entities, required this.moduleImports});
}

class ModuleInfo {
  final Directory directory;
  final String import;

  ModuleInfo({required this.directory, required this.import});
}

class ServerpodScanner {
  final String serverPath;

  ServerpodScanner({required this.serverPath});

  Future<ReadResult> scan() async {
    final entities = <ServerpodEntity>[];
    final spyFiles = <File>[];

    final serverDirectory = Directory(serverPath);

    final moduleInfos = await getServerpodModulesDirectories(serverPath);

    final allDirectories = [serverDirectory, ...moduleInfos.map((e) => e.directory)];

    for (var directory in allDirectories) {
      // read .spy.yaml files created in server project
      final files = directory
          .listSync(recursive: true)
          .map((systemFile) => File(systemFile.path))
          .where((file) => file.path.endsWith('.spy.yaml') || file.path.endsWith('.spy.yml'))
          .toList();

      spyFiles.addAll(files);
    }

    for (var spyFile in spyFiles) {
      print(spyFile.path);
    }

    final jsonEntities = await Future.wait(spyFiles.map((file) => readJsonOrYamlFile(file)).toList());

    for (var json in jsonEntities) {
      print(json["class"]);
      if (json.containsKey('enum')) {
        entities.add(ServerpodEnum.fromJson(json));
      } else if (json.containsKey('class')) {
        entities.add(ServerpodClass.fromJson(json));
      } else if (json.containsKey('exception')) {
        entities.add(ServerpodException.fromJson(json));
      }
    }

    return ReadResult(entities: entities, moduleImports: moduleInfos.map((e) => e.import).toList());
  }
}

Future<List<ModuleInfo>> getServerpodModulesDirectories(String serverPath) async {
  final pubspecLock = await readJsonOrYamlFile(File('$serverPath/pubspec.lock'));
  final serverpodPackages = (pubspecLock['packages'] as Map<String, dynamic>).entries.where((entry) {
    final packageName = entry.key;
    return packageName.contains('serverpod');
  }).toList();

  serverpodPackages.removeWhere((entry) {
    final packageName = entry.key;
    return packageName == 'serverpod_test' ||
        packageName == 'serverpod_lints' ||
        packageName == 'serverpod_serialization' ||
        packageName == 'serverpod_admin';
  });

  List<ModuleInfo> moduleInfos = [];

  for (var package in serverpodPackages) {
    print(package.key);
    final name = package.key;
    final source = package.value["source"];
    final version = package.value["version"];
    final url = package.value["description"]["url"].replaceAll("https://", "");
    final packagePath = '${getPubCachePath()}/$source/$url/$name-$version';
    moduleInfos.add(ModuleInfo(directory: Directory(packagePath), import: 'import "package:$name/$name.dart";'));
  }

  return moduleInfos;
}

String getPubCachePath() {
  final env = Platform.environment;

  // 1. If PUB_CACHE is explicitly set, use it
  if (env.containsKey('PUB_CACHE') && env['PUB_CACHE']!.isNotEmpty) {
    return env['PUB_CACHE']!;
  }

  // 2. Otherwise, pick the OS default
  if (Platform.isWindows) {
    final appData = env['APPDATA'];
    if (appData != null && appData.isNotEmpty) {
      return p.join(appData, 'Pub', 'Cache');
    }
  } else {
    final home = env['HOME'];
    if (home != null && home.isNotEmpty) {
      return p.join(home, '.pub-cache');
    }
  }

  // 3. If all else fails, throw or return a sensible fallback
  throw StateError('Cannot determine pub cache path on this system.');
}
