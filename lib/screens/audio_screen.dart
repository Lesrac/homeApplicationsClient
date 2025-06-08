import 'dart:convert';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
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
  String? _currentlyPlayingTitle;
  Duration _duration = Duration.zero;
  String _filter = '';
  bool _isLoading = true;
  bool _isPlayingAll = false;
  Duration _position = Duration.zero;
  int _playAllIndex = 0;
  List<String> _playAllQueue = [];
  List<String> _songs = [];

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
    player.onDurationChanged.listen((Duration d) {
      setState(() {
        _duration = d;
      });
    });
    player.positionUpdater = TimerPositionUpdater(
      interval: const Duration(milliseconds: 200),
      getPosition: player.getCurrentPosition,
    );
    player.onPositionChanged.listen((Duration p) {
      setState(() {
        _position = p;
      });
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
    final url = 'http://${widget.credentials.backendAddress}/audio/$title';
    setState(() {
      _currentlyPlayingTitle = title;
      _duration = Duration.zero;
      _position = Duration.zero;
      if (!fromPlayAll) {
        _isPlayingAll = false;
      }
    });
    await player.play(UrlSource(url));
  }

  Future<void> _stop() async {
    await player.release();
    setState(() {
      _currentlyPlayingTitle = null;
      _isPlayingAll = false;
      _duration = Duration.zero;
      _position = Duration.zero;
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
    final filteredSongs =
        _songs
            .where(
              (title) => title.toLowerCase().contains(_filter.toLowerCase()),
            )
            .toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Play music')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child:
            _isLoading
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
                    if (_currentlyPlayingTitle != null)
                      SongProgressBar(duration: _duration, position: _position),
                    Row(
                      children: [
                        ElevatedButton.icon(
                          icon: const Icon(Icons.queue_music),
                          label: const Text('Play All'),
                          onPressed:
                              (_isPlayingAll || filteredSongs.isEmpty)
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
                                fontWeight:
                                    isPlaying
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

class SongProgressBar extends StatelessWidget {
  final Duration duration;
  final Duration position;

  // no onSeek change as we work with streams and the native player doesn't support that on android
  // final ValueChanged<Duration> onSeek;

  const SongProgressBar({
    super.key,
    required this.duration,
    required this.position,
  });

  String _formatDuration(Duration d) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(d.inMinutes.remainder(60));
    final seconds = twoDigits(d.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    final max = duration.inMilliseconds.toDouble();
    final value =
        position.inMilliseconds.clamp(0, duration.inMilliseconds).toDouble();

    return Column(
      children: [
        Slider(
          min: 0,
          max: max,
          value: value,
          onChanged: null,
          /*   onChanged:
              duration.inMilliseconds > 0
                  ? (v) => onSeek(Duration(milliseconds: v.toInt()))
                  : null, */
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(_formatDuration(position)),
            Text(
              duration.inMilliseconds > 0 ? _formatDuration(duration) : "00:00",
            ),
          ],
        ),
        const SizedBox(height: 8),
      ],
    );
  }
}
