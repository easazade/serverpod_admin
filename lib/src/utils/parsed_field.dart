import 'package:serverpod_admin/src/utils/relation.dart';

/// A data class representing a parsed field with its name,
/// type, nullability, metadata list, and optional relation.
class ParsedField {
  final String name;
  final String type;
  final List<String> meta;
  final Relation? relation;

  ParsedField({required this.name, required this.type, required this.meta, this.relation});

  @override
  String toString() => 'ParsedField(name: "$name", type: "$type", meta: $meta, relation: $relation)';

  /// Parses a definition string of the form:
  ///   name: type, meta1=value, flagMeta, relation(...)
  /// and returns a [ParsedField] with any relation extracted.
  static ParsedField from({required String name, required String typeAndProperties}) {
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
        print(part);

        final regex = RegExp(
          r'(?:List|Set)<\s*([^>]+?)\s*>\s*\??|\bMap<\s*String\s*,\s*([^>]+?)\s*>\s*\??|^\s*([A-Za-z_]\w*(?:\.[A-Za-z_]\w*)*\??)\s*$',
        );

        final match = regex.firstMatch(rawType);
        final captured = (match?.group(1) ?? match?.group(2) ?? match?.group(3))?.trim();
        String? relatedObjectType;
        if (captured != null && !captured.startsWith('int') && !captured.startsWith('UuidValue')) {
          relatedObjectType = captured;
        }

        relation = Relation.parse(raw: part, relatedResourceType: relatedObjectType);
      }
    }

    return ParsedField(name: name, type: rawType, meta: meta, relation: relation);
  }
}
