// ignore_for_file: unused_import

import 'package:collection/collection.dart';
import 'package:recase/recase.dart';

import '../meta/serverpod_entity.dart';
import '../utils/file_generator.dart';
import '../utils/parsed_field.dart';
import '../utils_function.dart';

class AdminUtilsGenerator extends FileGenerator {
  final String serverPath;
  final String serverPackageName;
  final List<ServerpodEntity> entities;
  final List<String> serverpodModuleImports;

  AdminUtilsGenerator({
    required this.serverPath,
    required this.entities,
    required this.serverPackageName,
    required this.serverpodModuleImports,
  });

  @override
  String get path => '$serverPath/lib/src/web/utils/admin/admin_utils.dart';

  String? includeValueForResource(ServerpodClass modelClass, List<ServerpodClass> allClasses) {
    final relatedFields = modelClass.fields.where((field) => field.relation != null && field.relation?.parent == null).toList();

    // if there is no relations then there is no ClassInclude value needed either
    if (relatedFields.isEmpty) {
      return null;
    }

    final buffer = StringBuffer();
    buffer.writeln('${modelClass.name.pascalCase}.include(');
    for (var relatedField in relatedFields) {
      final nonNullableType = relatedField.type.replaceAll('?', '');
      if (nonNullableType.startsWith('List<')) {
        // extracting T out of List<T>
        final extractedTypeName = nonNullableType.substring(5, nonNullableType.length - 1);
        buffer.writeln('  ${relatedField.name}: ${extractedTypeName.pascalCase}.includeList(),');
      } else {
        buffer.writeln('  ${relatedField.name}: ${nonNullableType.pascalCase}.include(),');
      }
    }
    buffer.writeln(')');

    return buffer.toString();
  }

  @override
  Future<String> fileContent() async {
    final buffer = StringBuffer();

    buffer.writeln('// ignore_for_file: depend_on_referenced_packages, unused_import, duplicate_import'); // ignored lint rule
    buffer.writeln("import 'package:$serverPackageName/src/generated/protocol.dart';"); // import
    buffer.writeln('import "package:$serverPackageName/src/web/routes/admin/admin_route.dart";');
    buffer.writeln('import "package:$serverPackageName/src/web/routes/admin/object_route.dart";');
    buffer.writeln('import "package:$serverPackageName/src/web/routes/admin/table_route.dart";');
    buffer.writeln('import "package:$serverPackageName/src/web/routes/admin/upload_route.dart";');
    buffer.writeln("import 'package:uuid/v7.dart';"); // import
    buffer.writeln("import 'package:uuid/v4.dart';"); // import
    buffer.writeln("import 'package:serverpod/serverpod.dart';"); // import
    buffer.writeln("import 'package:serverpod/protocol.dart';"); // import

    for (var import in serverpodModuleImports) {
      buffer.writeln(import);
    }

    buffer.writeln('final modelsMap = <String, dynamic>{'); // map of models start
    final classes = entities.whereClassWithTables();
    final classNames = classes.map((e) => e.name).toList();

    for (var entity in classes) {
      if (entity.fields.firstWhereOrNull((field) => field.name == 'id') == null) {
        entity.fields.insert(0, ParsedField(name: 'id', type: 'int?', meta: ['defaultPersist=serial'], relation: null));
      }

      final schema =
          '''
            {${entity.fields.toList().map((parsedField) {
            var typeMapping = ' "${parsedField.name}": "${parsedField.type}" ';

            final nonNullableFieldType = parsedField.type.replaceAll('?', '');
            if (classNames.contains(nonNullableFieldType) && parsedField.relation?.field == null) {
              final foreignKeyFieldName = '${parsedField.name.camelCase}Id';

              final relatedClassEntity = classes.firstWhereOrNull((e) => e.name == parsedField.type.replaceAll('?', ''));
              final idTypeOfRelatedClass = relatedClassEntity?.fields.firstWhereOrNull((field) => field.name == 'id')?.type.replaceAll('?', '') ?? 'int';

              final foreignKeyFieldType = parsedField.relation?.isOptional == true ? "$idTypeOfRelatedClass?" : idTypeOfRelatedClass;

              return '$typeMapping, "$foreignKeyFieldName": "$foreignKeyFieldType"';
            }

            return typeMapping;
          }).join(',')}}
          ''';

      // in the schema section below there is a relation defined on the class type. it is required to add a the field for
      // foreign id to the schema as well.
      buffer.writeln('''
        "${entity.name.toLowerCase()}": {
          "table": "${entity.table != null ? "${entity.table}" : "null"}", 
          "class": "${entity.name}",
          "columns": [${entity.fields.map((e) => e.name).toList().map((e) => '"$e"').join(',')}],
          "schema": $schema,
          "related_fields": <String, dynamic>{${entity.fields.where((e) => e.relation != null && e.relation?.parent == null).map((e) => '"${e.name}": "${e.type}"').join(',')}},
        },
      ''');
    }
    buffer.writeln('};'); // map of models end

    buffer.writeln('\n\n'); // adding empty space;

    buffer.writeln(
      'Future<Map<String, dynamic>?> findResourceById(Session session, String resource, dynamic id) async{',
    ); // findResourceById() start
    buffer.writeln('final isIdInteger = int.tryParse(id.toString()) != null;');

    buffer.writeln('if(isIdInteger) {');
    buffer.writeln('  id = int.tryParse(id.toString());');
    buffer.writeln('} else {');
    buffer.writeln('  id = UuidValue.fromString(id);');
    buffer.writeln('}');

    for (final entity in classes) {
      buffer.writeln('if(resource.toLowerCase() == "${entity.name.toLowerCase()}"){');
      final includeParameterValue = includeValueForResource(entity, classes);
      final includeParameter = includeParameterValue != null ? ', include: $includeParameterValue' : '';

      buffer.writeln('  return (await ${entity.name.pascalCase}.db.findById(session, id $includeParameter))?.toJson();');
      buffer.writeln('}\n');
    }

    buffer.writeln("throw Exception('Could not find any resource called \$resource');");
    buffer.writeln('}'); // findResourceById() end

    buffer.writeln(
      'Future<Iterable<Map<String, dynamic>>> listResources(Session session, String resource) async {',
    ); // listResources() start
    for (final entity in classes) {
      buffer.writeln('if(resource.toLowerCase() == "${entity.name.toLowerCase()}"){');
      final includeParameterValue = includeValueForResource(entity, classes);
      final includeParameter = includeParameterValue != null ? ', include: $includeParameterValue' : '';

      buffer.writeln(
        '  return (await ${entity.name.pascalCase}.db.find(session $includeParameter)).map((e)=> e.toJson()).toList().reversed;',
      );
      buffer.writeln('}\n');
    }
    buffer.writeln("throw Exception('Could not find any resource called \$resource');");
    buffer.writeln('}'); // listResources() end

    buffer.writeln(
      'Future<Map<String, dynamic>> insertOrUpdateResource(Session session, String resource, Map<String, dynamic> json, dynamic id,) async {',
    ); // insertOrUpdateResource() start

    buffer.writeln('// parsing id to the correct id type, integer or uuid');
    buffer.writeln('final isIdInteger = int.tryParse(id?.toString() ?? "") != null;');
    buffer.writeln('if (isIdInteger) {');
    buffer.writeln('  id = int.tryParse(id.toString());');
    buffer.writeln('} else if(id != null) {');
    buffer.writeln('  id = UuidValue.fromString(id);');
    buffer.writeln('}');

    buffer.writeln('''
  // Pre-process related fields to support id-only payloads
  final Map<String, dynamic> relatedFieldsMap =
      (modelsMap[resource.toLowerCase()]['related_fields'] as Map<String, dynamic>);
  // Keep ids for list relations to attach after row is saved
  final Map<String, List<dynamic>> relatedListIds = {};

  for (final entry in relatedFieldsMap.entries) {
    final fieldName = entry.key;
    final type = entry.value.toString();
    final isList = type.trim().startsWith('List<');
    final dynamic fieldValue = json[fieldName];

    if (isList) {
      if (fieldValue is List) {
        final ids = fieldValue.whereType<Map>().map((m) => m['id']).where((v) => v != null).toList();
        if (ids.isNotEmpty) {
          relatedListIds[fieldName] = ids;
          // prevent fromJson from requiring full objects
          json[fieldName] = null;
        }
      } else if (fieldValue == null) {
        // Explicitly send empty to indicate clearing the relation list
        relatedListIds[fieldName] = <dynamic>[];
        json[fieldName] = null;
      }
    } else {
      final foreignKeyName = '\${fieldName}Id';
      if (fieldValue is Map && fieldValue['id'] != null) {
        final schema = (modelsMap[resource.toLowerCase()]['schema'] as Map<String, dynamic>);
        if (schema.containsKey(foreignKeyName)) {
          json[foreignKeyName] = fieldValue['id'].toString();
          // prevent fromJson from requiring full object
          json[fieldName] = null;
        }
      } else if (fieldValue == null) {
        // Null selection for single relation -> clear FK if present in schema
        final schema = (modelsMap[resource.toLowerCase()]['schema'] as Map<String, dynamic>);
        if (schema.containsKey(foreignKeyName)) {
          json[foreignKeyName] = null;
        }
      }
    }
  }
''');

    for (final entity in classes) {
      buffer.writeln('if(resource.toLowerCase() == "${entity.name.toLowerCase()}"){');
      buffer.writeln('  if(json["id"] == null) {');
      buffer.writeln('    final newId = newUuidForResource(resource);');
      buffer.writeln('    if(newId != null){');
      buffer.writeln('      json["id"] = newId.toString();');
      buffer.writeln('    }');
      buffer.writeln('  }');
      buffer.writeln('  final row = ${entity.name.pascalCase}.fromJson(json);');
      buffer.writeln('  final isInDb = id != null && (await ${entity.name.pascalCase}.db.findById(session, id)) != null;');
      buffer.writeln('  final ${entity.name} updatedRow;\n');
      buffer.writeln('  if(isInDb) {');
      buffer.writeln('    updatedRow = (await ${entity.name.pascalCase}.db.updateRow(session, row));');
      buffer.writeln('  } else {');
      buffer.writeln('    updatedRow = (await ${entity.name.pascalCase}.db.insertRow(session, row));');
      buffer.writeln('  }');
      final relatedFields = entity.fields.where((field) => field.relation != null && field.relation?.parent == null).toList();

      // if there is no relations then there is no ClassInclude value needed either
      if (relatedFields.isNotEmpty) {
        for (var relatedField in relatedFields) {
          buffer.writeln('\n    // Updating relation field: ${relatedField.name} of type ${relatedField.type}');
          buffer.writeln('if(row.${relatedField.name} != null) {');
          final nonNullableType = relatedField.type.replaceAll('?', '');
          if (relatedField.type.startsWith('List')) {
            final extractedTypeName = nonNullableType.substring(5, nonNullableType.length - 1);
            buffer.writeln('''
              // insert or update all objects inside the list

              final updated${relatedField.name.pascalCase} = (await Future.wait(
                row.${relatedField.name}?.map((e) {
                  final ${extractedTypeName.camelCase}Json = e.toJson();
                  final id = ${extractedTypeName.camelCase}Json["id"];
                  return insertOrUpdateResource(session, "${extractedTypeName.toLowerCase()}", ${extractedTypeName.camelCase}Json, id.toString());
              }) ?? <Future<Map<String, dynamic>>>[])).map((e) => $extractedTypeName.fromJson(e)).toList();

              // if there is any, detach old relations between one(${entity.name}) to many(${relatedField.name}: ${relatedField.type})
              final current = await ${entity.name}.db.findById(session, updatedRow.id!, include: ${includeValueForResource(entity, classes)},);
              if(current?.${relatedField.name} case var ${relatedField.name}?){
                await ${entity.name}.db.detach.${relatedField.name}(session, ${relatedField.name});
              }

              // attach a new relation between one(${entity.name}) to many(${relatedField.name}: ${relatedField.type})
              await ${entity.name}.db.attach.${relatedField.name}(session, updatedRow, updated${relatedField.name.pascalCase});
            ''');
          } else {
            buffer.writeln('''
              final updated = await insertOrUpdateResource(session, "$nonNullableType", row.${relatedField.name}!.toJson(), row.${relatedField.name}!.id.toString());
              await ${entity.name}.db.attachRow.${relatedField.name}(session, updatedRow, $nonNullableType.fromJson(updated));

            ''');
          }
          if (relatedField.type.startsWith('List')) {
            buffer.writeln('''
            } else if(relatedListIds['${relatedField.name}'] != null){
              final ids = relatedListIds['${relatedField.name}'] ?? [];

              // Detach all existing relations first
              final current = await ${entity.name}.db.findById(session, updatedRow.id!, include: ${includeValueForResource(entity, classes)},);

              if(current?.${relatedField.name} case var ${relatedField.name}?){
                await ${entity.name}.db.detach.${relatedField.name}(session, ${relatedField.name});
              }

              if(ids.isNotEmpty){
                final $nonNullableType updated${relatedField.name.pascalCase} = [];

                for (var id in ids) {
                  id = id.toString();
                  final relatedObject = await findResourceById(session, '${relatedField.relation?.relatedResourceType?.toLowerCase()}', id);
                  if (relatedObject != null) {
                    updated${relatedField.name.pascalCase}.add(${relatedField.relation?.relatedResourceType?.pascalCase}.fromJson(relatedObject));
                  }
                }

                await Person.db.attach.simples(session, updatedRow, updated${relatedField.name.pascalCase});
              }
            }
          ''');
          } else {
            buffer.writeln('}');
          }
        }
      }

      buffer.writeln('\nreturn (await findResourceById(session, "${entity.name.toLowerCase()}", updatedRow.id.toString()))!;');
      buffer.writeln('}\n');
    }

    buffer.writeln("throw Exception('Could not find any resource called \$resource');");
    buffer.writeln('}'); // insertOrUpdateResource() end

    buffer.writeln(
      'Future<Map<String, dynamic>> deleteResource(Session session, String resource, dynamic id) async {',
    ); // deleteResource() start

    buffer.writeln('final isIdInteger = int.tryParse(id.toString()) != null;');
    buffer.writeln('if(isIdInteger) {');
    buffer.writeln('  id = int.tryParse(id.toString());');
    buffer.writeln('} else {');
    buffer.writeln('  id = UuidValue.fromString(id);');
    buffer.writeln('}');

    for (final entity in classes) {
      buffer.writeln('if(resource.toLowerCase() == "${entity.name.toLowerCase()}"){');
      buffer.writeln('  return (await ${entity.name.pascalCase}.db.deleteWhere(session, where: (t) => t.id.equals(id))).first.toJson();');
      buffer.writeln('}\n');
    }
    buffer.writeln("throw Exception('Could not find any resource called \$resource');");
    buffer.writeln('}'); // deleteResource() end

    buffer.writeln('Future<int> resourceCount(Session session, String resource) async {'); // resourceCount start
    for (var entity in classes) {
      buffer.writeln('if(resource.toLowerCase() == "${entity.name.toLowerCase()}") {');
      buffer.writeln('  return await ${entity.name.pascalCase}.db.count(session);');
      buffer.writeln('}\n');
    }
    buffer.writeln("throw Exception('Could not find any resource called \$resource to count its rows');");
    buffer.writeln('}'); // resourceCount end

    buffer.writeln('/// Will create a new UuidValue for resource if the id type is uuid. If type of id is int it will return null.');
    buffer.writeln('dynamic newUuidForResource(String resource) {'); // newUuidForResource start
    buffer.writeln('  final idType = modelsMap[resource]["schema"]["id"].toString();');
    buffer.writeln('  if(idType.startsWith("UuidValue")){');
    buffer.writeln('    return UuidV7().generate();');
    buffer.writeln('  } else {');
    buffer.writeln('    // if id type is int it should fall on database to assign the integer id');
    buffer.writeln('    return null;');
    buffer.writeln('  }');
    buffer.writeln('}'); // newUuidForResource end

    buffer.writeln('void appendAdminRoutes(Serverpod pod){'); // appendAdminRoutes() start
    buffer.writeln('''
      pod.webServer.addRoute(AdminRoute(), '/admin');
      pod.webServer.addRoute(AdminRoute(), '/admin/');

      pod.webServer.addRoute(TableRoute(), '/admin/list/*');
      pod.webServer.addRoute(TableRoute(), '/admin/bulk-add/*');
      pod.webServer.addRoute(TableRoute(), '/admin/bulk-save/*');

      pod.webServer.addRoute(ObjectRoute(), '/admin/view/*');
      pod.webServer.addRoute(ObjectRoute(), '/admin/edit/*');
      pod.webServer.addRoute(ObjectRoute(), '/admin/save/*');
      pod.webServer.addRoute(ObjectRoute(), '/admin/delete/*');
      pod.webServer.addRoute(ObjectRoute(), '/admin/add/*');
      
      pod.webServer.addRoute(UploadRoute(), '/admin/upload-file');
    ''');
    buffer.writeln('}'); // appendAdminRoutes() end

    return buffer.toString();
  }
}
