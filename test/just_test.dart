
import 'package:serverpod_admin/src/utils/parsed_field.dart';

void main() {
  // Example usages:
  final examples = [
    'id: UuidValue, defaultModel=random_v7',
    'createdAt: DateTime?, defaultPersist=now, important',
    'reservationDate: DateTime',
    'mySet: Set<String>',
    'address: List<Address>?, relation',
    'address: Address?, relation',
    'address: Address?, relation(optional)',
    'address: Address?, relation(name=user_address, field=addressId)',
    'address: Address?, relation(field=addressId)',
    'companyId: int, relation(name=company_employees, parent=company)',
  ];

  for (var ex in examples) {
    final [name, typeAndMeta] = ex.split(':');
    final parsed = ParsedField.from(name: name, typeAndProperties: typeAndMeta);
    print(parsed);
  }
}
