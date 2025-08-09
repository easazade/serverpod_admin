import 'dart:io';
import 'dart:isolate';

/// Copies all files from this package's `lib/src/copy/` directory into the
/// provided [serverPath], preserving the subdirectory structure. For example,
/// a source file `lib/src/copy/path/to/file.dart` will be copied to
/// `<serverPath>/path/to/file.dart`.
///
/// - Files whose name ends with `.copy` will have that suffix removed in the
///   destination (e.g. `file.yaml.copy` -> `file.yaml`).
/// - A generated header comment is prepended to common text file types.
/// - Each copied file's relative path (within [serverPath]) is printed.
class Copier {
  final String serverPath;

  Copier({required this.serverPath});

  Future<void> copy() async {
    final sourceDir = await _resolveCopyDirectory();
    if (sourceDir == null) {
      stdout.writeln('serverpod_admin: No copy directory found at lib/src/copy/. Nothing to do.');
      return;
    }

    if (!await sourceDir.exists()) {
      stdout.writeln('serverpod_admin: ${sourceDir.path} does not exist. Nothing to copy.');
      return;
    }

    final entities = await sourceDir.list(recursive: true, followLinks: false).toList();
    for (final entity in entities) {
      if (entity is! File) continue;

      final String relativePath = _relativePath(entity.path, sourceDir.path);
      final String destRelativePath = _withRemovedCopySuffix(relativePath);
      final String destinationPath = _joinPaths(serverPath, destRelativePath);

      await Directory(_dirname(destinationPath)).create(recursive: true);

      await _copyWithOptionalHeader(sourceFile: entity, destinationFile: File(destinationPath));

      // Print the path relative to serverPath for readability
      stdout.writeln('Copied: $destRelativePath');
    }
  }

  Future<Directory?> _resolveCopyDirectory() async {
    // Resolve the URI to this file, then derive lib/src/copy from it.
    final selfUri = await Isolate.resolvePackageUri(Uri.parse('package:serverpod_admin/src/copier.dart'));
    if (selfUri == null) return null;

    // This file resolves to .../lib/src/copier.dart
    final selfFile = File.fromUri(selfUri);
    final libSrcDir = Directory(_dirname(selfFile.path)); // .../lib/src
    final copyDir = Directory(_joinPaths(libSrcDir.path, 'copy'));
    return copyDir;
  }

  Future<void> _copyWithOptionalHeader({required File sourceFile, required File destinationFile}) async {
    final String destFileName = _basename(destinationFile.path);
    final String ext = _safeExtension(destFileName).toLowerCase();

    // For known text-based types, prepend a header; otherwise copy bytes as-is.
    final bool isText = _isTextualExtension(ext);
    final String header = _headerForExtension(ext);

    if (isText && header.isNotEmpty) {
      try {
        final String original = await sourceFile.readAsString();
        final String content = '$header\n\n$original';
        await destinationFile.writeAsString(content);
        return;
      } catch (_) {
        // Fall back to raw bytes if text read fails.
      }
    }

    // Default: copy bytes verbatim (no header)
    final bytes = await sourceFile.readAsBytes();
    await destinationFile.writeAsBytes(bytes);
  }

  String _withRemovedCopySuffix(String relativePath) {
    final int sep = relativePath.lastIndexOf(Platform.pathSeparator);
    final String dir = sep >= 0 ? relativePath.substring(0, sep) : '';
    String file = sep >= 0 ? relativePath.substring(sep + 1) : relativePath;
    if (file.endsWith('.copy')) {
      file = file.substring(0, file.length - '.copy'.length);
    }
    return dir.isEmpty ? file : _joinPaths(dir, file);
  }

  String _relativePath(String fullPath, String fromDir) {
    final String normalizedFrom = _ensureEndsWithSeparator(fromDir);
    if (fullPath.startsWith(normalizedFrom)) {
      return fullPath.substring(normalizedFrom.length);
    }
    // Fallback: attempt a platform-agnostic normalization using URIs
    final fromUri = Uri.file(fromDir.endsWith(Platform.pathSeparator) ? fromDir : fromDir + Platform.pathSeparator);
    final fileUri = Uri.file(fullPath);
    return fromUri.resolveUri(fileUri).path.replaceFirst(fromUri.path, '');
  }

  String _dirname(String path) {
    final int sep = path.lastIndexOf(Platform.pathSeparator);
    return sep < 0 ? '.' : path.substring(0, sep);
  }

  String _basename(String path) {
    final int sep = path.lastIndexOf(Platform.pathSeparator);
    return sep < 0 ? path : path.substring(sep + 1);
  }

  String _joinPaths(String a, String b) {
    if (a.endsWith(Platform.pathSeparator)) return a + b;
    return a + Platform.pathSeparator + b;
  }

  String _ensureEndsWithSeparator(String dir) {
    return dir.endsWith(Platform.pathSeparator) ? dir : dir + Platform.pathSeparator;
  }

  String _safeExtension(String filename) {
    final int dot = filename.lastIndexOf('.');
    if (dot <= 0 || dot == filename.length - 1) return '';
    return filename.substring(dot + 1);
  }

  bool _isTextualExtension(String ext) {
    const textExts = {
      'dart',
      'js',
      'ts',
      'java',
      'kt',
      'kts',
      'swift',
      'c',
      'cc',
      'cpp',
      'h',
      'cs',
      'yaml',
      'yml',
      'sh',
      'properties',
      'env',
      'toml',
      'ini',
      'css',
      'html',
      'xml',
      'md',
    };
    // JSON intentionally excluded to avoid breaking strict parsers
    return textExts.contains(ext);
  }

  String _headerForExtension(String ext) {
    const headerText =
        'Generated code — This file was created by the serverpod_admin library. '
        'Do not edit by hand.';

    switch (ext) {
      case 'dart':
      case 'js':
      case 'ts':
      case 'java':
      case 'kt':
      case 'kts':
      case 'swift':
      case 'c':
      case 'cc':
      case 'cpp':
      case 'h':
      case 'cs':
        return '// $headerText';
      case 'yaml':
      case 'yml':
      case 'sh':
      case 'properties':
      case 'env':
      case 'toml':
      case 'ini':
        return '# $headerText';
      case 'css':
        return '/* $headerText */';
      case 'html':
      case 'xml':
      case 'md':
        return '<!-- $headerText -->';
      // JSON and unknown types: no header to avoid breaking files
      default:
        return '';
    }
  }
}
