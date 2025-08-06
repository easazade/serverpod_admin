import 'package:recase/recase.dart';

import '../meta/serverpod_entity.dart';
import '../utils/file_generator.dart';

class AdminEndpointGenerator extends FileGenerator {
  final String serverPath;
  final String serverPackageName;
  final List<ServerpodEntity> entities;

  AdminEndpointGenerator({
    required this.serverPath,
    required this.entities,
    required this.serverPackageName,
  });

  @override
  String get path => '$serverPath/lib/src/admin/generated/admin_endpoint.dart';

  @override
  Future<String> fileContent() async {
    final buffer = StringBuffer();

    // imports
    buffer.writeln("import 'package:$serverPackageName/src/generated/protocol.dart';");
    buffer.writeln("import 'package:serverpod/serverpod.dart';");

    buffer.writeln('class AdminEndpoint extends Endpoint{'); //open AdminEndpoint class

    // creating endpoint methods for each entity
    for (final entity in entities) {
      if (entity is ServerpodClass && entity.table != null) {
        buffer.writeln(_crudMethodsFor(entity));
      }
    }

    buffer.writeln('}'); //end AdminEndpoint class

    return buffer.toString();
  }

  String _crudMethodsFor(ServerpodEntity entity) {
    final className = entity.name.pascalCase;
    return '''
  Future<List<$className>> getAll${className}s(Session session) async {
    if (session.serverpod.runMode != 'production') {
      return await $className.db.find(session);
    } else {
      return throw GeneralException(message: 'Resource does not exist', code: '404', statusCode: 404);
    }  
  }

  Future<List<$className>> delete${className}s(Session session, List<$className> rows) async {
    if (session.serverpod.runMode != 'production') {
      return await $className.db.delete(session, rows);
    } else {
      return throw GeneralException(message: 'Resource does not exist', code: '404', statusCode: 404);
    }  
  }

  Future<$className> update$className(Session session, $className row) async {
    if (session.serverpod.runMode != 'production') {
      return await $className.db.updateRow(session, row);
    } else {
      return throw GeneralException(message: 'Resource does not exist', code: '404', statusCode: 404);
    }  
  }

  Future<$className> create$className(Session session, $className row) async {
    if (session.serverpod.runMode != 'production') {
      final created${className}s = await $className.db.insert(session, [row]);
      return created${className}s.first;
    } else {
      return throw GeneralException(message: 'Resource does not exist', code: '404', statusCode: 404);
    }  
  }

''';
  }
}
