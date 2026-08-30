import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:homeApplications/models/credentials.dart';
import 'package:homeApplications/services/pocket_money_service.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  final credentials = Credentials(
    username: 'admin',
    password: 'pw',
    backendAddress: 'localhost:8080',
    admin: true,
    id: 1,
  );

  group('PocketMoneyService', () {
    test('fetchUsers filters out admin and prepends Select User option',
        () async {
      final mockClient = MockClient((request) async {
        expect(request.url.path, '/users');
        return http.Response(
          jsonEncode([
            {'ID': 1, 'Name': 'AdminUser', 'Access': 'admin', 'Password': ''},
            {'ID': 2, 'Name': 'Child1', 'Access': 'user', 'Password': ''},
            {'ID': 3, 'Name': 'Child2', 'Access': 'user', 'Password': ''},
          ]),
          200,
        );
      });

      final service = PocketMoneyService(client: mockClient);
      final users = await service.fetchUsers(credentials);

      expect(users.length, 3);
      expect(users[0].name, 'Select User');
      expect(users[0].id, -1);
      expect(users[1].name, 'Child1');
      expect(users[1].id, 2);
      expect(users[2].name, 'Child2');
      expect(users[2].id, 3);
    });

    test('fetchEntries returns parsed PocketMoneyEntry list', () async {
      final mockClient = MockClient((request) async {
        expect(request.url.path, '/pocketMoney/2');
        return http.Response(
          jsonEncode([
            {
              'id': 101,
              'amount': 50,
              'date': '2026-08-30T10:00:00.000',
              'confirmed': true,
              'user_id': 2,
            },
          ]),
          200,
        );
      });

      final service = PocketMoneyService(client: mockClient);
      final entries = await service.fetchEntries(credentials, 2);

      expect(entries.length, 1);
      expect(entries.first.id, 101);
      expect(entries.first.amount, 50);
      expect(entries.first.confirmed, true);
      expect(entries.first.userId, 2);
    });

    test('addEntry posts correct JSON body', () async {
      Map<String, dynamic>? postedBody;
      final testDate = DateTime(2026, 8, 30);

      final mockClient = MockClient((request) async {
        expect(request.url.path, '/pocketMoney/addAction');
        postedBody = jsonDecode(request.body) as Map<String, dynamic>;
        return http.Response('success', 200);
      });

      final service = PocketMoneyService(client: mockClient);
      await service.addEntry(
        credentials: credentials,
        userId: 2,
        amount: 75,
        date: testDate,
      );

      expect(postedBody, isNotNull);
      expect(postedBody!['userId'], 2);
      expect(postedBody!['amount'], 75);
      expect(postedBody!['date'], testDate.toIso8601String());
    });

    test('confirmEntry posts correct JSON body for confirmation', () async {
      Map<String, dynamic>? postedBody;

      final mockClient = MockClient((request) async {
        expect(request.url.path, '/pocketMoney/acknowledgeAction');
        postedBody = jsonDecode(request.body) as Map<String, dynamic>;
        return http.Response('success', 200);
      });

      final service = PocketMoneyService(client: mockClient);
      await service.confirmEntry(
        credentials: credentials,
        id: 101,
        confirm: true,
      );

      expect(postedBody, isNotNull);
      expect(postedBody!['id'], 101);
      expect(postedBody!['action'], 'confirm');
    });

    test('confirmEntry posts correct JSON body for refute', () async {
      Map<String, dynamic>? postedBody;

      final mockClient = MockClient((request) async {
        expect(request.url.path, '/pocketMoney/acknowledgeAction');
        postedBody = jsonDecode(request.body) as Map<String, dynamic>;
        return http.Response('success', 200);
      });

      final service = PocketMoneyService(client: mockClient);
      await service.confirmEntry(
        credentials: credentials,
        id: 101,
        confirm: false,
      );

      expect(postedBody, isNotNull);
      expect(postedBody!['id'], 101);
      expect(postedBody!['action'], 'refute');
    });
  });
}
