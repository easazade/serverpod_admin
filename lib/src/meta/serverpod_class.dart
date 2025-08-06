part of 'serverpod_entity.dart';

class ServerpodClass extends ServerpodEntity {
  final String? table;
  final bool serverOnly;
  final List<ParsedField> fields;

  ServerpodClass({
    required super.name,
    required this.table,
    required this.serverOnly,
    required this.fields,
  }) : super(type: 'class');

  static ServerpodClass fromJson(Map<String, dynamic> json) {
    final fieldsJson = json['fields'] != null ? json['fields'] as Map<String, dynamic> : null;
    
    return ServerpodClass(
      name: json['class'].toString(),
      table: json['table'],
      serverOnly: json['serverOnly'] ?? false,
      fields: fieldsJson?.entries.map((e) {
            return ParsedField.from(name: e.key, typeAndProperties: e.value.toString());
          }).toList() ??
          [],
    );
  }
}
