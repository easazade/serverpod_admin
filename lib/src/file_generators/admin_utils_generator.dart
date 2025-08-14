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
          "related_fields": <String, dynamic>{${entity.fields.where((e) => e.relation != null).map((e) => '"${e.name}": "${e.type}"').join(',')}},
        },
      ''');
    }
    buffer.writeln('};'); // map of models end

    buffer.writeln('\n\n'); // adding empty space;

    buffer.writeln(
      'Future<Map<String, dynamic>?> findResourceById(Session session, String resource, dynamic id,) async{',
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

    buffer.writeln('Future<List<Map<String, dynamic>>> listResources(Session session, String resource) async {'); // listResources() start
    for (final entity in classes) {
      buffer.writeln('if(resource.toLowerCase() == "${entity.name.toLowerCase()}"){');
      final includeParameterValue = includeValueForResource(entity, classes);
      final includeParameter = includeParameterValue != null ? ', include: $includeParameterValue' : '';

      buffer.writeln('  return (await ${entity.name.pascalCase}.db.find(session $includeParameter)).map((e)=> e.toJson()).toList();');
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
            buffer.writeln('    // insert or update all objects inside the list');
            buffer.writeln('final updated${relatedField.name.pascalCase} = (await Future.wait(');
            buffer.writeln('  row.${relatedField.name}?.map((e) {');
            buffer.writeln('final ${extractedTypeName.camelCase}Json = e.toJson();');
            buffer.writeln('final id = ${extractedTypeName.camelCase}Json["id"];');
            buffer.writeln(
              'return insertOrUpdateResource(session, "${extractedTypeName.toLowerCase()}", ${extractedTypeName.camelCase}Json, id.toString());',
            );
            buffer.writeln('}) ?? <Future<Map<String, dynamic>>>[])).map((e) => $extractedTypeName.fromJson(e)).toList();');

            buffer.writeln('    // attach relation between one(${entity.name}) to many(${relatedField.name}: ${relatedField.type})');
            buffer.writeln(
              'await ${entity.name}.db.attach.${relatedField.name}(session, updatedRow, updated${relatedField.name.pascalCase});',
            );
          } else {
            buffer.writeln(
              'final updated = await insertOrUpdateResource(session, "$nonNullableType", row.${relatedField.name}!.toJson(), row.${relatedField.name}!.id.toString());',
            );

            buffer.writeln(
              'await ${entity.name}.db.attachRow.${relatedField.name}(session, updatedRow, $nonNullableType.fromJson(updated));',
            );
          }
          buffer.writeln('}');
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
    ''');
    buffer.writeln('}'); // appendAdminRoutes() end

    return buffer.toString();
  }
}
