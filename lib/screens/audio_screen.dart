import 'dart:convert';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:http/http.dart' as http;

import '../helper/headers.dart';
import '../models/credentials.dart';

class AudioScreen extends StatefulWidget {
  final Credentials credentials;

  const AudioScreen({super.key, required this.credentials});

  @override
  State<AudioScreen> createState() => _AudioScreenState();
}

class _AudioScreenState extends State<AudioScreen> {
  final player = AudioPlayer();
  List<String> _songs = [];
  String? _selectedTitle;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchSongs();
  }

  Future<void> _fetchSongs() async {
    final url = Uri.parse('http://${widget.credentials.backendAddress}/songs');
    try {
      final response = await http.get(
        url,
        headers: HeadersHelper.getHeaders(widget.credentials),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        final List<dynamic> songsJson = data['songs'] ?? [];
        setState(() {
          _songs =
              songsJson.map<String>((song) => song['title'] as String).toList();
          if (_songs.isNotEmpty) {
            _selectedTitle = _songs.first;
          }
          _isLoading = false;
        });
      } else {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _play() async {
    if (_selectedTitle == null) return;
    final url =
        'http://${widget.credentials.backendAddress}/audio/$_selectedTitle';
    await player.play(UrlSource(url));
  }

  Future<void> _stop() async {
    await player.release();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Play music')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child:
            _isLoading
                ? const Center(child: CircularProgressIndicator())
                : Column(
                  children: [
                    DropdownButton<String>(
                      value: _selectedTitle,
                      hint: const Text('Select a song'),
                      items:
                          _songs
                              .map(
                                (title) => DropdownMenuItem(
                                  value: title,
                                  child: Text(title),
                                ),
                              )
                              .toList(),
                      onChanged: (value) {
                        setState(() {
                          _selectedTitle = value;
                        });
                      },
                    ),
                    Row(
                      children: [
                        IconButton(
                          icon: Icon(Icons.play_arrow),
                          onPressed: _play,
                        ),
                        IconButton(icon: Icon(Icons.stop), onPressed: _stop),
                      ],
                    ),
                  ],
                ),
      ),
    );
  }
}
