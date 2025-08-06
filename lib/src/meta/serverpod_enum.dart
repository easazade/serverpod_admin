part of 'serverpod_entity.dart';

class ServerpodEnum extends ServerpodEntity {
  final String serialized;
  final List<String> values;

  ServerpodEnum({
    required super.name,
    required this.serialized,
    required this.values,
  }) : super(type: 'enum');

  static ServerpodEnum fromJson(Map<String, dynamic> json) {
    return ServerpodEnum(
      name: json['enum'].toString(),
      serialized: json['serialized'].toString(),
      values: (json['values'] as List).map((e)=> e.toString()).toList(),
    );
  }
}
