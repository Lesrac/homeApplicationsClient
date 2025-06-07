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
  String? _currentlyPlayingTitle;
  bool _isLoading = true;
  String _filter = '';

  // Add play all state
  bool _isPlayingAll = false;
  List<String> _playAllQueue = [];
  int _playAllIndex = 0;

  @override
  void initState() {
    super.initState();
    _fetchSongs();
    player.onPlayerComplete.listen((event) {
      if (_isPlayingAll && _playAllIndex < _playAllQueue.length - 1) {
       setState(() {
          _playAllIndex++;
        });
       _play(_playAllQueue[_playAllIndex], fromPlayAll: true);
      } else {
        setState(() {
          _currentlyPlayingTitle = null;
          _isPlayingAll = false;
        });
      }
    });
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
        final songsList =
        songsJson.map<String>((song) => song['title'] as String).toList();
        songsList.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
        setState(() {
          _songs = songsList;
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

  Future<void> _play(String title, {bool fromPlayAll = false}) async {
    final url =
        'http://${widget.credentials.backendAddress}/audio/$title';
    await player.play(UrlSource(url));
    setState(() {
      _currentlyPlayingTitle = title;
      // Only set play all state if called from play all
      if (!fromPlayAll) {
        _isPlayingAll = false;
      }
    });
  }

  Future<void> _stop() async {
    await player.release();
    setState(() {
      _currentlyPlayingTitle = null;
      _isPlayingAll = false;
    });
  }

  Future<void> _playAll(List<String> songs) async {
    if (songs.isEmpty) return;
    setState(() {
      _isPlayingAll = true;
      _playAllQueue = List<String>.from(songs);
      _playAllIndex = 0;
    });
    await _play(_playAllQueue[_playAllIndex], fromPlayAll: true);
  }

  @override
  Widget build(BuildContext context) {
    final filteredSongs = _songs
        .where((title) => title.toLowerCase().contains(_filter.toLowerCase()),)
        .toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Play music')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : Column(
          children: [
            TextField(
              decoration: const InputDecoration(
                labelText: 'Filter songs',
              ),
              onChanged: (value) {
                setState(() {
                  _filter = value;
                });
              },
            ),
            const SizedBox(height: 16),
            // Add Play All button
            Row(
              children: [
                ElevatedButton.icon(
                  icon: const Icon(Icons.queue_music),
                  label: const Text('Play All'),
                  onPressed: (_isPlayingAll || filteredSongs.isEmpty)
                      ? null
                      : () => _playAll(filteredSongs),
                ),
                if (_isPlayingAll)
                  Padding(
                    padding: const EdgeInsets.only(left: 12.0),
                    child: Text(
                      'Playing all...',
                      style: TextStyle(color: Colors.green[700]),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: ListView.builder(
                itemCount: filteredSongs.length,
                itemBuilder: (context, index) {
                  final title = filteredSongs[index];
                  final isPlaying = _currentlyPlayingTitle == title;
                  return ListTile(
                    leading: IconButton(
                      icon: Icon(
                        isPlaying ? Icons.stop : Icons.play_arrow,
                      ),
                      onPressed: () {
                        if (isPlaying) {
                          _stop();
                        } else {
                          _play(title);
                        }
                      },
                    ),
                    title: Text(
                      title,
                      style: TextStyle(
                        fontWeight: isPlaying
                            ? FontWeight.bold
                            : FontWeight.normal,
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}