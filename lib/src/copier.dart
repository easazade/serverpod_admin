import 'dart:io';
import 'dart:isolate';

class Copier {
  Future<void> copy() async {
    final uri = Uri.parse('package:serverpod_admin/src/scanner.dart');
    final fileUri = await Isolate.resolvePackageUri(uri);
    if (fileUri != null) {
      print('resolved file uri');
      // 3. Read the bytes (or .readAsString() if it's text)
      final file = File.fromUri(fileUri);
      final bytes = await File.fromUri(fileUri).readAsBytes();
      print(await file.readAsString());
      print('✅ Loaded ${bytes.length} bytes from $fileUri');
    } else {
      print('could not resolve $uri');
    }
  }
}
