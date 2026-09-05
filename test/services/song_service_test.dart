import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:homeApplications/models/credentials.dart';
import 'package:homeApplications/services/song_service.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final testCredentials = Credentials(
    username: 'user',
    password: 'pw',
    backendAddress: 'localhost:8080',
    admin: false,
    id: 1,
  );

  group('SongService.fetchSongs', () {
    test('fetches and sorts songs case-insensitively on 200 OK', () async {
      final mockClient = MockClient((request) async {
        expect(request.url.path, '/songs');
        return http.Response(
          jsonEncode({
            'songs': [
              {'title': 'gamma'},
              {'title': 'Alpha'},
              {'title': 'beta'},
            ],
          }),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      });

      final service = SongService(client: mockClient);
      final songs = await service.fetchSongs(testCredentials);

      expect(songs, ['Alpha', 'beta', 'gamma']);
    });

    test('throws Exception when status code is not 200', () async {
      final mockClient = MockClient((request) async {
        return http.Response('Internal Server Error', 500);
      });

      final service = SongService(client: mockClient);

      expect(
        () => service.fetchSongs(testCredentials),
        throwsA(isA<Exception>()),
      );
    });
  });

  group('SongService playlist persistence', () {
    test('loadPlaylist returns empty list when no playlist is stored', () async {
      SharedPreferences.setMockInitialValues({});
      final service = SongService();

      final playlist = await service.loadPlaylist();
      expect(playlist, isEmpty);
    });

    test('loadPlaylist returns stored list', () async {
      SharedPreferences.setMockInitialValues({
        'audio_playlist': jsonEncode(['Song 1', 'Song 2']),
      });
      final service = SongService();

      final playlist = await service.loadPlaylist();
      expect(playlist, ['Song 1', 'Song 2']);
    });

    test('savePlaylist stores JSON list in SharedPreferences', () async {
      SharedPreferences.setMockInitialValues({});
      final service = SongService();

      await service.savePlaylist(['Track A', 'Track B']);

      final prefs = await SharedPreferences.getInstance();
      final stored = prefs.getString('audio_playlist');
      expect(stored, isNotNull);
      expect(jsonDecode(stored!), ['Track A', 'Track B']);
    });
  });
}
