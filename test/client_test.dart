import 'package:flutter_test/flutter_test.dart';
import 'package:rosea_pos/features/clients/client.dart';

void main() {
  test('fromMap maps id / name / phone (phone optional)', () {
    final c = Client.fromMap(<String, dynamic>{'id': 'c1', 'name': 'Rania Abou Jaoude', 'phone': '+961 3 412 889'});
    expect(c.id, 'c1');
    expect(c.name, 'Rania Abou Jaoude');
    expect(c.phone, '+961 3 412 889');

    final walkin = Client.fromMap(<String, dynamic>{'id': 'c2', 'name': 'Walk-in', 'phone': null});
    expect(walkin.phone, isNull);
  });

  test('initials take first + last word, uppercased', () {
    expect(const Client(id: '1', name: 'Rania Abou Jaoude').initials, 'RA');
    expect(const Client(id: '2', name: 'maya').initials, 'M');
    expect(const Client(id: '3', name: '  ').initials, '?');
  });

  test('json round-trips losslessly (durable outbox / draft)', () {
    const c = Client(id: 'c1', name: 'Randa Khalil', phone: '+961 70 118 204');
    expect(Client.fromJson(c.toJson()), c); // equality is by id
    expect(Client.fromJson(c.toJson()).phone, '+961 70 118 204');

    const noPhone = Client(id: 'c2', name: 'New Walkin');
    expect(noPhone.toJson().containsKey('phone'), isFalse);
  });

  test('equality is by id', () {
    expect(const Client(id: 'x', name: 'A'), const Client(id: 'x', name: 'B', phone: '1'));
    expect(const Client(id: 'x', name: 'A') == const Client(id: 'y', name: 'A'), isFalse);
  });
}
