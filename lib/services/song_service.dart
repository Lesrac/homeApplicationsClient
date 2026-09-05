import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../helper/headers.dart';
import '../models/credentials.dart';

class SongService {
  final http.Client? _client;
  static const String _playlistKey = 'audio_playlist';

  SongService({http.Client? client}) : _client = client;

  Future<http.Response> _get(Uri url, {Map<String, String>? headers}) {
    if (_client != null) {
      return _client.get(url, headers: headers);
    }
    return http.get(url, headers: headers);
  }

  /// Fetches songs from the backend server, returning case-insensitively sorted titles.
  Future<List<String>> fetchSongs(Credentials credentials) async {
    final url = Uri.parse('http://${credentials.backendAddress}/songs');
    final response = await _get(
      url,
      headers: HeadersHelper.getHeaders(credentials),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(utf8.decode(response.bodyBytes));
      final List<dynamic> songsJson = data['songs'] ?? [];
      final songsList =
          songsJson.map<String>((song) => song['title'] as String).toList();
      songsList.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
      return songsList;
    } else {
      throw Exception('Failed to load songs: HTTP ${response.statusCode}');
    }
  }

  /// Loads the persisted playlist from SharedPreferences.
  Future<List<String>> loadPlaylist() async {
    final prefs = await SharedPreferences.getInstance();
    final playlistJson = prefs.getString(_playlistKey);
    if (playlistJson != null) {
      final List<dynamic> loaded = jsonDecode(playlistJson);
      return loaded.cast<String>();
    }
    return [];
  }

  /// Saves the playlist to SharedPreferences.
  Future<void> savePlaylist(List<String> playlist) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_playlistKey, jsonEncode(playlist));
  }
}
