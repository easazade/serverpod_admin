/// Represents a database relation with optional details.
class Relation {
  final String? name;
  final String? field;
  final String? parent;
  final bool isOptional;

  Relation({
    this.name,
    this.field,
    this.parent,
    required this.isOptional,
  });

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

/// A data class representing a parsed field with its name,
/// type, nullability, metadata list, and optional relation.
class ParsedField {
  final String name;
  final String type;
  final List<String> meta;
  final Relation? relation;

  ParsedField({
    required this.name,
    required this.type,
    required this.meta,
    this.relation,
  });

  @override
  String toString() => 'ParsedField(name: "$name", type: "$type", meta: $meta, relation: $relation)';

  /// Parses a definition string of the form:
  ///   name: type, meta1=value, flagMeta, relation(...)
  /// and returns a [ParsedField] with any relation extracted.
  static ParsedField from({
    required String name,
    required String typeAndProperties,
  }) {
    // Helper to split at top-level commas (ignoring commas inside <>, {}, ())
    List<String> splitTopLevel(String str) {
      final segments = <String>[];
      final buffer = StringBuffer();
      int angle = 0, brace = 0, paren = 0;
      for (var i = 0; i < str.length; i++) {
        final char = str[i];
        if (char == '<') angle++;
        if (char == '>') angle--;
        if (char == '{') brace++;
        if (char == '}') brace--;
        if (char == '(') paren++;
        if (char == ')') paren--;

        if (char == ',' && angle == 0 && brace == 0 && paren == 0) {
          segments.add(buffer.toString());
          buffer.clear();
        } else {
          buffer.write(char);
        }
      }
      if (buffer.isNotEmpty) segments.add(buffer.toString());
      return segments;
    }

    // Split remainder into segments: first is the type, rest are meta entries
    final parts = splitTopLevel(typeAndProperties).map((s) => s.trim()).toList();
    if (parts.isEmpty) {
      throw FormatException('No type found in "$typeAndProperties"');
    }

    // Determine nullability
    final rawType = parts.first;

    // Collect meta entries and detect relation
    final meta = <String>[];
    Relation? relation;
    for (var i = 1; i < parts.length; i++) {
      final part = parts[i];
      if (part.isEmpty) continue;
      meta.add(part);
      if (part.startsWith('relation')) {
        relation = Relation.parse(part);
      }
    }

    return ParsedField(name: name, type: rawType, meta: meta, relation: relation);
  }
}
