/// Represents a database relation with optional details.
class Relation {
  final String? name;
  final String? field;
  final String? parent;
  final bool isOptional;

  Relation({this.name, this.field, this.parent, required this.isOptional});

  @override
  String toString() {
    return 'Relation(name: $name, field: $field, parent: $parent, isOptional: $isOptional)';
  }

  /// Parses a raw meta string starting with 'relation', e.g.
  /// 'relation', 'relation(optional)',
  /// 'relation(name=..., field=...)', etc.
  static Relation parse(String raw) {
    raw = raw.trim();
    String? name;
    String? field;
    String? parent;
    bool isOptional = false;

    final openParen = raw.indexOf('(');
    if (openParen >= 0 && raw.endsWith(')')) {
      final inner = raw.substring(openParen + 1, raw.length - 1);
      final parts = inner.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty);

      for (var part in parts) {
        if (!part.contains('=')) {
          if (part == 'optional') {
            isOptional = true;
          }
        } else {
          final kv = part.split('=');
          final key = kv[0].trim();
          final val = kv[1].trim();
          switch (key) {
            case 'name':
              name = val;
              break;
            case 'field':
              field = val;
              break;
            case 'parent':
              parent = val;
              break;
            case 'optional':
              isOptional = val.toLowerCase() == 'true';
              break;
          }
        }
      }
    }
    // If no parentheses and raw == 'relation', leave all fields null and isOptional false
    return Relation(name: name, field: field, parent: parent, isOptional: isOptional);
  }
}
