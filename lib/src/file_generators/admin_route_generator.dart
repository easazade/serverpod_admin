// ignore_for_file: unused_import

import 'package:recase/recase.dart';

import '../meta/serverpod_entity.dart';
import '../utils/file_generator.dart';
import '../utils_function.dart';

class AdminRouteGenerator extends FileGenerator {
  final String serverPath;
  final String serverPackageName;
  final List<ServerpodEntity> entities;

  AdminRouteGenerator({required this.serverPath, required this.entities, required this.serverPackageName});

  @override
  String get path => '$serverPath/lib/src/web/routes/admin/admin_route.dart';

  @override
  Future<String> fileContent() async {
    final buffer = StringBuffer();

    // Adding imports
    buffer.writeln("import 'dart:io';");
    buffer.writeln("import 'package:$serverPackageName/src/web/widgets/admin/admin_page.dart';");
    buffer.writeln("import 'package:serverpod/serverpod.dart';");
    buffer.writeln("import 'package:$serverPackageName/src/web/utils/admin/admin_utils.dart';");

    buffer.writeln('class AdminRoute extends WidgetRoute {'); // AdminRoute class start

    // setHeaders method override
    buffer.writeln('''
      @override
      void setHeaders(HttpHeaders headers) {
        super.setHeaders(headers);
        headers.set('Cache-Control', 'no-store, no-cache, must-revalidate, max-age=0');
      }
    ''');

    // build method override
    buffer.writeln('''
      @override
      Future<AbstractWidget> build(Session session, HttpRequest request) async {
        final classNames = modelsMap.values.map((e) => e["class"].toString()).toList();

        Map<String, int> objectCount = {};
        for (var className in classNames) {
          objectCount[className] = await resourceCount(session, className);
        }

        return AdminPage(classNames: classNames, objectCount: objectCount);
      }
    ''');

    buffer.writeln('}'); // AdminRoute class end

    return buffer.toString();
  }
}
