part of 'serverpod_entity.dart';

class ServerpodException extends ServerpodEntity {
  final List<ParsedField> fields;

  ServerpodException({required super.name, required this.fields}) : super(type: 'exception');

  static ServerpodException fromJson(Map<String, dynamic> json) {
    final fieldsJson = json['fields'] != null ? json['fields'] as Map<String, dynamic> : null;

    return ServerpodException(
      name: json['exception'].toString(),
      fields: fieldsJson?.entries.map((e) {
            return ParsedField.from(name: e.key, typeAndProperties: e.value.toString());
          }).toList() ??
          [],
    );
  }
}
