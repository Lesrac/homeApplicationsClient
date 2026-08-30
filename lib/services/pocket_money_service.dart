import 'dart:convert';
import 'package:http/http.dart' as http;
import '../helper/headers.dart';
import '../models/credentials.dart';
import '../models/pocket_money_entry.dart';
import '../models/user.dart';

class PocketMoneyService {
  final http.Client? _client;

  PocketMoneyService({http.Client? client}) : _client = client;

  Future<http.Response> _get(Uri url, {Map<String, String>? headers}) {
    if (_client != null) {
      return _client.get(url, headers: headers);
    }
    return http.get(url, headers: headers);
  }

  Future<http.Response> _post(
    Uri url, {
    Map<String, String>? headers,
    Object? body,
  }) {
    if (_client != null) {
      return _client.post(url, headers: headers, body: body);
    }
    return http.post(url, headers: headers, body: body);
  }

  Future<List<User>> fetchUsers(Credentials credentials) async {
    final url = Uri.parse('http://${credentials.backendAddress}/users');
    final response = await _get(
      url,
      headers: HeadersHelper.getHeaders(credentials),
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to load users.');
    }

    final decoded = jsonDecode(response.body) as List;
    final users = decoded
        .map((userJson) => User.fromJson(userJson as Map<String, dynamic>))
        .where((user) => !user.isAdmin)
        .toList();

    return [User(null, id: -1, name: 'Select User', access: 'user'), ...users];
  }

  Future<List<PocketMoneyEntry>> fetchEntries(
    Credentials credentials,
    int userId,
  ) async {
    final url = Uri.parse(
      'http://${credentials.backendAddress}/pocketMoney/$userId',
    );
    final response = await _get(
      url,
      headers: HeadersHelper.getHeaders(credentials),
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to load pocket money entries.');
    }

    final decoded = jsonDecode(response.body) as List;
    return decoded
        .map((json) => PocketMoneyEntry.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  Future<void> addEntry({
    required Credentials credentials,
    required int userId,
    required int amount,
    required DateTime date,
  }) async {
    final url = Uri.parse(
      'http://${credentials.backendAddress}/pocketMoney/addAction',
    );
    final response = await _post(
      url,
      headers: HeadersHelper.getHeaders(credentials),
      body: jsonEncode({
        'userId': userId,
        'amount': amount,
        'date': date.toIso8601String(),
      }),
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to add entry: ${response.body}');
    }
  }

  Future<void> confirmEntry({
    required Credentials credentials,
    required int? id,
    required bool confirm,
  }) async {
    final url = Uri.parse(
      'http://${credentials.backendAddress}/pocketMoney/acknowledgeAction',
    );
    final response = await _post(
      url,
      headers: HeadersHelper.getHeaders(credentials),
      body: jsonEncode({
        'id': id,
        'action': confirm ? 'confirm' : 'refute',
      }),
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to confirm entry: ${response.body}');
    }
  }
}
