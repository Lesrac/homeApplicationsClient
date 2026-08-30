import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:homeApplications/models/credentials.dart';
import 'package:homeApplications/screens/pocket_money_screen.dart';

class TestHttpOverrides extends HttpOverrides {
  final Map<String, dynamic> Function(Uri uri, String method, dynamic body)? handler;

  TestHttpOverrides({this.handler});

  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return _FakeHttpClient(handler: handler);
  }
}

class _FakeHttpClient implements HttpClient {
  final Map<String, dynamic> Function(Uri uri, String method, dynamic body)?
  handler;

  _FakeHttpClient({this.handler});

  @override
  void close({bool force = false}) {}

  @override
  Future<HttpClientRequest> openUrl(String method, Uri url) async {
    return _FakeHttpClientRequest(url, method, handler);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

  @override
  Future<HttpClientRequest> getUrl(Uri url) async {
    return _FakeHttpClientRequest(url, 'GET', handler);
  }

  @override
  Future<HttpClientRequest> postUrl(Uri url) async {
    return _FakeHttpClientRequest(url, 'POST', handler);
  }
}

class _FakeHttpClientRequest implements HttpClientRequest {
  @override
  final Uri uri;

  @override
  final String method;

  final Map<String, dynamic> Function(Uri uri, String method, dynamic body)?
  handler;

  @override
  final HttpHeaders headers = _FakeHttpHeaders();
  final List<int> _bodyBytes = [];

  @override
  bool followRedirects = true;

  @override
  int maxRedirects = 5;

  @override
  bool persistentConnection = true;

  @override
  int contentLength = -1;

  @override
  bool bufferOutput = true;

  _FakeHttpClientRequest(this.uri, this.method, this.handler);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

  @override
  void write(Object? obj) {
    if (obj != null) {
      _bodyBytes.addAll(utf8.encode(obj.toString()));
    }
  }

  @override
  Future<dynamic> addStream(Stream<List<int>> stream) async {
    await for (final chunk in stream) {
      _bodyBytes.addAll(chunk);
    }
  }

  @override
  void add(List<int> data) {
    _bodyBytes.addAll(data);
  }

  @override
  Future<HttpClientResponse> close() async {
    final bodyString = utf8.decode(_bodyBytes);
    final dynamic parsedBody =
        bodyString.isNotEmpty ? jsonDecode(bodyString) : null;

    int statusCode = 200;
    String responseString = '[]';

    if (handler != null) {
      final result = handler!(uri, method, parsedBody);
      statusCode = result['status'] as int? ?? 200;
      responseString = result['body'] is String
          ? result['body'] as String
          : jsonEncode(result['body']);
    } else {
      if (uri.path.contains('/users')) {
        responseString = jsonEncode([
          {'ID': 2, 'Name': 'Child1', 'Access': 'user', 'Password': ''}
        ]);
      } else if (uri.path.contains('/pocketMoney/addAction')) {
        responseString = jsonEncode({'status': 'ok'});
      } else if (uri.path.contains('/pocketMoney/acknowledgeAction')) {
        responseString = jsonEncode({'status': 'ok'});
      } else if (uri.path.contains('/pocketMoney/')) {
        responseString = jsonEncode([
          {
            'id': 101,
            'date': DateTime.now().toIso8601String(),
            'confirmed': false,
            'amount': 25,
            'user_id': 2
          }
        ]);
      }
    }

    return _FakeHttpClientResponse(statusCode, responseString);
  }
}

class _FakeHttpHeaders implements HttpHeaders {
  final Map<String, List<String>> _headers = {};

  @override
  void forEach(void Function(String name, List<String> values) action) {
    _headers.forEach(action);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

  @override
  void set(String name, Object value, {bool preserveHeaderCase = false}) {
    _headers[name] = [value.toString()];
  }

  @override
  void add(String name, Object value, {bool preserveHeaderCase = false}) {
    _headers.putIfAbsent(name, () => []).add(value.toString());
  }

  @override
  List<String>? operator [](String name) => _headers[name];

  @override
  String? value(String name) => _headers[name]?.first;
}

class _FakeHttpClientResponse extends Stream<List<int>>
    implements HttpClientResponse {
  @override
  final int statusCode;
  final String body;

  _FakeHttpClientResponse(this.statusCode, this.body);

  @override
  String get reasonPhrase => 'OK';

  @override
  bool get isRedirect => false;

  @override
  bool get persistentConnection => true;

  @override
  List<RedirectInfo> get redirects => [];

  @override
  List<Cookie> get cookies => [];

  @override
  X509Certificate? get certificate => null;

  @override
  HttpConnectionInfo? get connectionInfo => null;

  @override
  StreamSubscription<List<int>> listen(
    void Function(List<int> event)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) {
    return Stream.value(utf8.encode(body)).listen(
      onData,
      onError: onError,
      onDone: onDone,
      cancelOnError: cancelOnError,
    );
  }

  @override
  int get contentLength => utf8.encode(body).length;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

  @override
  HttpHeaders get headers => _FakeHttpHeaders();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final adminCredentials = Credentials(
    username: 'admin',
    password: 'pw',
    backendAddress: 'localhost:8080',
    admin: true,
    id: 1,
  );

  final userCredentials = Credentials(
    username: 'user1',
    password: 'pw',
    backendAddress: 'localhost:8080',
    admin: false,
    id: 2,
  );

  tearDown(() {
    HttpOverrides.global = null;
  });

  testWidgets(
      'Admin can select user, open date view bottom sheet, enter value, and save',
      (WidgetTester tester) async {
    Map<String, dynamic>? lastPostedBody;
    final testDate = DateTime(DateTime.now().year, DateTime.now().month, 15);

    HttpOverrides.global = TestHttpOverrides(
      handler: (uri, method, body) {
        if (uri.path == '/users') {
          return {
            'status': 200,
            'body': [
              {'ID': 2, 'Name': 'Child1', 'Access': 'user', 'Password': ''}
            ],
          };
        } else if (uri.path == '/pocketMoney/addAction') {
          lastPostedBody = body as Map<String, dynamic>?;
          return {'status': 200, 'body': 'success'};
        } else if (uri.path.startsWith('/pocketMoney/')) {
          return {
            'status': 200,
            'body': [
              {
                'id': 10,
                'amount': 20,
                'date': testDate.toIso8601String(),
                'confirmed': false,
                'user_id': 2,
              }
            ],
          };
        }
        return {'status': 200, 'body': '[]'};
      },
    );

    await tester.pumpWidget(
      MaterialApp(
        home: PocketMoneyScreen(credentials: adminCredentials),
      ),
    );
    await tester.pumpAndSettle();

    // Verify Dropdown exists
    expect(find.byType(DropdownButton<String>), findsOneWidget);

    // Select user Child1
    await tester.tap(find.byType(DropdownButton<String>));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Child1').last);
    await tester.pumpAndSettle();

    // Find day cell 15 in the TableCalendar
    final dayWidget = find.text('15').first;
    await tester.tap(dayWidget);
    await tester.pumpAndSettle();

    // Verify bottom sheet opened with TextField and Save button
    expect(find.byType(TextField), findsOneWidget);
    expect(find.text('Save'), findsOneWidget);
    expect(find.text('Cancel'), findsOneWidget);

    // Existing amount was 20, verify prefilled in TextField
    expect(find.widgetWithText(TextField, '20'), findsOneWidget);

    // Enter a new amount in the TextField
    await tester.enterText(find.byType(TextField), '450');
    await tester.pumpAndSettle();

    // Verify text persists
    expect(find.widgetWithText(TextField, '450'), findsOneWidget);

    // Tap Save
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    // Bottom sheet should be closed
    expect(find.byType(TextField), findsNothing);

    // Verify backend received the correct payload
    expect(lastPostedBody, isNotNull);
    expect(lastPostedBody!['userId'], 2);
    expect(lastPostedBody!['amount'], 450);
  });

  testWidgets(
      'Admin can open date view bottom sheet and cancel without saving',
      (WidgetTester tester) async {
    Map<String, dynamic>? lastPostedBody;
    final testDate = DateTime(DateTime.now().year, DateTime.now().month, 15);

    HttpOverrides.global = TestHttpOverrides(
      handler: (uri, method, body) {
        if (uri.path == '/users') {
          return {
            'status': 200,
            'body': [
              {'ID': 2, 'Name': 'Child1', 'Access': 'user', 'Password': ''}
            ],
          };
        } else if (uri.path == '/pocketMoney/addAction') {
          lastPostedBody = body as Map<String, dynamic>?;
          return {'status': 200, 'body': 'success'};
        } else if (uri.path.startsWith('/pocketMoney/')) {
          return {
            'status': 200,
            'body': [
              {
                'id': 10,
                'amount': 20,
                'date': testDate.toIso8601String(),
                'confirmed': false,
                'user_id': 2,
              }
            ],
          };
        }
        return {'status': 200, 'body': '[]'};
      },
    );

    await tester.pumpWidget(
      MaterialApp(
        home: PocketMoneyScreen(credentials: adminCredentials),
      ),
    );
    await tester.pumpAndSettle();

    // Select user Child1
    await tester.tap(find.byType(DropdownButton<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Child1').last);
    await tester.pumpAndSettle();

    // Tap day cell
    await tester.tap(find.text('15').first);
    await tester.pumpAndSettle();

    expect(find.byType(TextField), findsOneWidget);

    // Enter a new amount
    await tester.enterText(find.byType(TextField), '99');
    await tester.pumpAndSettle();

    // Tap Cancel
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    // Sheet should close and no request sent
    expect(find.byType(TextField), findsNothing);
    expect(lastPostedBody, isNull);
  });

  testWidgets(
      'Admin tapping date when no user selected shows select user state',
      (WidgetTester tester) async {
    HttpOverrides.global = TestHttpOverrides(
      handler: (uri, method, body) {
        if (uri.path == '/users') {
          return {
            'status': 200,
            'body': [
              {'ID': 2, 'Name': 'Child1', 'Access': 'user', 'Password': ''}
            ],
          };
        }
        return {'status': 200, 'body': '[]'};
      },
    );

    await tester.pumpWidget(
      MaterialApp(
        home: PocketMoneyScreen(credentials: adminCredentials),
      ),
    );
    await tester.pumpAndSettle();

    // When no user is selected, calendar is not shown
    expect(find.text('Select User'), findsOneWidget);
  });

  testWidgets('Non-admin user can view entry and mark as received',
      (WidgetTester tester) async {
    Map<String, dynamic>? lastAcknowledgeBody;
    final testDate = DateTime(DateTime.now().year, DateTime.now().month, 15);

    HttpOverrides.global = TestHttpOverrides(
      handler: (uri, method, body) {
        if (uri.path == '/pocketMoney/acknowledgeAction') {
          lastAcknowledgeBody = body as Map<String, dynamic>?;
          return {'status': 200, 'body': 'success'};
        } else if (uri.path.startsWith('/pocketMoney/')) {
          return {
            'status': 200,
            'body': [
              {
                'id': 10,
                'amount': 20,
                'date': testDate.toIso8601String(),
                'confirmed': false,
                'user_id': 2,
              }
            ],
          };
        }
        return {'status': 200, 'body': '[]'};
      },
    );

    await tester.pumpWidget(
      MaterialApp(
        home: PocketMoneyScreen(credentials: userCredentials),
      ),
    );
    await tester.pumpAndSettle();

    // Tap day 15 on calendar
    final dayWidget = find.text('15').first;
    await tester.tap(dayWidget);
    await tester.pumpAndSettle();

    // Verify non-admin bottom sheet has 'Mark as Received' button
    expect(find.text('Mark as Received'), findsOneWidget);
    expect(find.text('Amount: 20'), findsOneWidget);

    await tester.tap(find.text('Mark as Received'));
    await tester.pumpAndSettle();

    expect(lastAcknowledgeBody, isNotNull);
    expect(lastAcknowledgeBody!['id'], 10);
    expect(lastAcknowledgeBody!['action'], 'confirm');
  });
}
