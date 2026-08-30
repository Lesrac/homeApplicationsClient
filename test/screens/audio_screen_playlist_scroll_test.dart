import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:homeApplications/models/credentials.dart';
import 'package:homeApplications/screens/audio_screen.dart';
import 'package:homeApplications/services/audio_cache_service.dart';
import 'package:homeApplications/services/audio_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/fake_audio_cache_service.dart';

class TestHttpOverrides extends HttpOverrides {
  final Map<String, dynamic> Function(Uri uri, String method, dynamic body)?
  handler;

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
    int statusCode = 200;
    String responseString = jsonEncode({'songs': []});

    if (handler != null) {
      final result = handler!(uri, method, null);
      statusCode = result['status'] as int? ?? 200;
      responseString = result['body'] is String
          ? result['body'] as String
          : jsonEncode(result['body']);
    } else {
      if (uri.path.contains('/songs')) {
        responseString = jsonEncode({
          'songs': List.generate(
            25,
            (i) => {'title': 'Track ${(i + 1).toString().padLeft(2, '0')}'},
          ),
        });
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

  final testCredentials = Credentials(
    username: 'user',
    password: 'pw',
    backendAddress: 'localhost:8080',
    admin: false,
    id: 1,
  );

  late FakeAudioCacheService fakeCacheService;

  setUp(() {
    GetIt.instance.reset();

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('xyz.luan/audioplayers.global'),
      (MethodCall methodCall) async => 1,
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('xyz.luan/audioplayers'),
      (MethodCall methodCall) async => 1,
    );

    fakeCacheService = FakeAudioCacheService();
    GetIt.instance.registerSingleton<AudioCacheService>(fakeCacheService);
    GetIt.instance.registerSingleton<AudioHandler>(AudioPlayerHandler());
  });

  tearDown(() {
    GetIt.instance.reset();
    HttpOverrides.global = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('xyz.luan/audioplayers.global'),
      null,
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('xyz.luan/audioplayers'),
      null,
    );
  });

  testWidgets(
    'Playlist view allows scrolling by dragging on track titles and reordering via drag handle',
    (WidgetTester tester) async {
      final initialPlaylist = List.generate(
        25,
        (i) => 'Track ${(i + 1).toString().padLeft(2, '0')}',
      );

      SharedPreferences.setMockInitialValues({
        'audio_playlist': jsonEncode(initialPlaylist),
      });

      HttpOverrides.global = TestHttpOverrides();

      // Render AudioScreen in a standard portrait viewport
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        MaterialApp(
          home: AudioScreen(credentials: testCredentials),
        ),
      );
      await tester.pumpAndSettle();

      // Switch to playlist view
      expect(find.text('Show Playlist'), findsOneWidget);
      await tester.tap(find.text('Show Playlist'));
      await tester.pumpAndSettle();

      // Verify that the playlist view is visible with initial tracks
      expect(find.text('Track 01'), findsOneWidget);
      expect(find.text('Track 02'), findsOneWidget);

      // Verify that each item has a dedicated drag handle icon
      expect(find.byIcon(Icons.drag_handle), findsWidgets);

      // Track 25 should be off-screen initially
      expect(find.text('Track 25'), findsNothing);

      // --- TEST 1: SCROLLING ---
      // Dragging vertically on the song title ('Track 02') must scroll the list
      await tester.drag(find.text('Track 02'), const Offset(0, -500));
      await tester.pumpAndSettle();

      // After scrolling down, Track 01 should have scrolled out of view and later tracks should be visible
      expect(find.text('Track 01'), findsNothing);
      expect(find.text('Track 15'), findsOneWidget);

      // Scroll back up to the top
      await tester.drag(find.text('Track 15'), const Offset(0, 500));
      await tester.pumpAndSettle();

      expect(find.text('Track 01'), findsOneWidget);

      // --- TEST 2: REORDERING VIA DRAG HANDLE ---
      // Find the drag handle for Track 01 (the first drag handle on screen)
      final firstDragHandle = find.byIcon(Icons.drag_handle).first;

      // Drag the drag handle of Track 01 downwards to reorder it past Track 02
      final handleLocation = tester.getCenter(firstDragHandle);
      final gesture = await tester.startGesture(handleLocation);
      await tester.pump(const Duration(milliseconds: 50));

      // Move down by about 120 pixels (past Track 02)
      await gesture.moveBy(const Offset(0, 120));
      await tester.pump(const Duration(milliseconds: 100));
      await gesture.up();
      await tester.pumpAndSettle();

      // Verify Track 01 moved and the new order is saved to SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      final savedJson = prefs.getString('audio_playlist');
      expect(savedJson, isNotNull);
      final List<dynamic> savedPlaylist = jsonDecode(savedJson!);

      // Track 01 is no longer at index 0 (it was moved down)
      expect(savedPlaylist.first, isNot('Track 01'));
      expect(savedPlaylist.contains('Track 01'), isTrue);
    },
  );

  testWidgets(
    'In offline mode, drag handle is disabled and does not permit reordering',
    (WidgetTester tester) async {
      final initialPlaylist = ['Track A', 'Track B', 'Track C'];

      SharedPreferences.setMockInitialValues({
        'audio_playlist': jsonEncode(initialPlaylist),
      });

      // HTTP failure will trigger offline mode
      HttpOverrides.global = TestHttpOverrides(
        handler: (uri, method, body) => {'status': 500, 'body': 'Server Error'},
      );

      await tester.pumpWidget(
        MaterialApp(
          home: AudioScreen(credentials: testCredentials),
        ),
      );
      await tester.pumpAndSettle();

      // Switch to playlist view
      await tester.tap(find.text('Show Playlist'));
      await tester.pumpAndSettle();

      // Drag handle exists
      final dragHandles = find.byIcon(Icons.drag_handle);
      expect(dragHandles, findsWidgets);

      // Check that the ReorderableDragStartListener is not enabled
      final dragStartListeners = tester.widgetList<ReorderableDragStartListener>(
        find.byType(ReorderableDragStartListener),
      );
      for (final listener in dragStartListeners) {
        expect(listener.enabled, isFalse);
      }

      // Dragging does not reorder in offline mode
      final handleLocation = tester.getCenter(dragHandles.first);
      final gesture = await tester.startGesture(handleLocation);
      await tester.pump(const Duration(milliseconds: 50));
      await gesture.moveBy(const Offset(0, 120));
      await tester.pump(const Duration(milliseconds: 100));
      await gesture.up();
      await tester.pumpAndSettle();

      final prefs = await SharedPreferences.getInstance();
      final savedJson = prefs.getString('audio_playlist');
      final List<dynamic> savedPlaylist = jsonDecode(savedJson!);
      expect(savedPlaylist, ['Track A', 'Track B', 'Track C']);
    },
  );
}
