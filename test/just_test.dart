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

  final newPatterns = [
    'userInfo: module:auth:UserInfo?, relation',
    'purchasedItem: module:shopping:Product?, relation',
    'userImage: module:gallery:Photo?, relation',
  ];

  for (var ex in [...examples, ...newPatterns]) {
    final index = ex.indexOf(':');
    final name = ex.substring(0, index);
    final typeAndMeta = ex.substring(index + 1);
    final parsed = ParsedField.from(name: name, typeAndProperties: typeAndMeta);
    print(parsed);
  }
}
