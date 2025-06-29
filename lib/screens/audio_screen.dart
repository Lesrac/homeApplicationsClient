import 'dart:convert';

import 'package:audio_service/audio_service.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../helper/headers.dart';
import '../models/credentials.dart';
import '../services/audio_handler.dart';
import '../services/service_locator.dart';

class AudioScreen extends StatefulWidget {
  final Credentials credentials;

  const AudioScreen({super.key, required this.credentials});

  @override
  State<AudioScreen> createState() => _AudioScreenState();
}

class _AudioScreenState extends State<AudioScreen> {
  late final AudioPlayerHandler _audioHandler;
  String? _currentlyPlayingTitle;
  Duration _duration = Duration.zero;
  String _filter = '';
  bool _isLoading = true;
  bool _isPlayingAll = false;
  Duration _position = Duration.zero;
  List<String> _songs = [];
  List<MediaItem> _queue = []; // Store the current queue

  // Playlist state
  List<String> _playlist = [];
  bool _showPlaylist = false;

  static const String _playlistKey = 'audio_playlist';

  @override
  void initState() {
    super.initState();
    _audioHandler = getIt<AudioHandler>() as AudioPlayerHandler;
    _fetchSongs();
    _loadPlaylist();

    // Set up listeners
    _audioHandler.player.onPlayerComplete.listen((event) {
      // AudioService now handles progression in queue
      if (_queue.isEmpty || _audioHandler.currentIndex >= _queue.length - 1) {
        setState(() {
          _isPlayingAll = false;
        });
      }
    });

    _audioHandler.player.onDurationChanged.listen((Duration d) {
      setState(() {
        _duration = d;
      });
    });

    _audioHandler.player.positionUpdater = TimerPositionUpdater(
      interval: const Duration(milliseconds: 200),
      getPosition: _audioHandler.player.getCurrentPosition,
    );

    _audioHandler.player.onPositionChanged.listen((Duration p) {
      setState(() {
        _position = p;
      });
    });

    // Listen to changes in currently playing item
    _audioHandler.mediaItem.listen((mediaItem) {
      if (mediaItem != null) {
        setState(() {
          _currentlyPlayingTitle = mediaItem.title;
        });
      } else {
        setState(() {
          _currentlyPlayingTitle = null;
          _duration = Duration.zero;
          _position = Duration.zero;
        });
      }
    });

    // Listen to queue changes
    _audioHandler.queue.listen((queue) {
      setState(() {
        _queue = queue;
      });
    });

    // Listen to playback state changes
    _audioHandler.playbackState.listen((playbackState) {
      final isPlaying = playbackState.playing;
      setState(() {
        _isPlayingAll = isPlaying && _queue.length > 1;
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

  Future<void> _play(String title) async {
    final url = 'http://${widget.credentials.backendAddress}/audio/$title';
    setState(() {
      _isPlayingAll = false; // Ensure play all mode is off for single play
    });
    await _audioHandler.playFromUrl(url, title);
  }

  Future<void> _stop() async {
    await _audioHandler.stop();
  }

  Future<void> _playAll(List<String> songTitles) async {
    if (songTitles.isEmpty) return;

    setState(() {
      _isPlayingAll = true;
    });

    final songs = songTitles.map((title) => SongItem(
      title: title,
      url: 'http://${widget.credentials.backendAddress}/audio/$title',
    )).toList();

    await _audioHandler.playAll(songs);
  }

  Future<void> _loadPlaylist() async {
    final prefs = await SharedPreferences.getInstance();
    final playlistJson = prefs.getString(_playlistKey);
    if (playlistJson != null) {
      final List<dynamic> loaded = jsonDecode(playlistJson);
      setState(() {
        _playlist = loaded.cast<String>();
      });
    }
  }

  Future<void> _savePlaylist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_playlistKey, jsonEncode(_playlist));

    // Also update the AudioHandler's queue (doesn't start playing)
    final songs = _playlist.map((title) => SongItem(
      title: title,
      url: 'http://${widget.credentials.backendAddress}/audio/$title',
    )).toList();

    _audioHandler.setPlaylist(songs);
  }

  void _addToPlaylist(String title) {
    if (!_playlist.contains(title)) {
      setState(() {
        _playlist.add(title);
      });
      _savePlaylist();
    }
  }

  void _removeFromPlaylist(String title) {
    setState(() {
      _playlist.remove(title);
    });
    _savePlaylist();
  }

  void _togglePlaylistView() {
    setState(() {
      _showPlaylist = !_showPlaylist;
    });
  }

  Future<void> _seekTo(Duration position) async {
    await _audioHandler.seek(position);
  }

  @override
  Widget build(BuildContext context) {
    final filteredSongs =
        _songs
            .where(
              (title) => title.toLowerCase().contains(_filter.toLowerCase()),
            )
            .toList();

    final listToShow = _showPlaylist ? _playlist : filteredSongs;

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
                  if (_currentlyPlayingTitle != null)
                    SongProgressBar(
                      duration: _duration,
                      position: _position,
                      onSeek: _seekTo,
                    ),
                  PlayControlsRow(
                    showPlaylist: _showPlaylist,
                    isPlayingAll: _isPlayingAll,
                    filteredSongs: filteredSongs,
                    playlist: _playlist,
                    onPlayAll: () => _playAll(filteredSongs),
                    onPlayAllPlaylist: () => _playAll(_playlist),
                    onTogglePlaylistView: _togglePlaylistView,
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: listToShow.isEmpty
                        ? Center(
                            child: Text(_showPlaylist
                                ? 'Playlist is empty'
                                : 'No songs found'),
                          )
                        : _showPlaylist
                            ? ReorderableListView.builder(
                                buildDefaultDragHandles: false,
                                itemCount: _playlist.length,
                                onReorder: (oldIndex, newIndex) {
                                  setState(() {
                                    if (newIndex > oldIndex) newIndex -= 1;
                                    final item = _playlist.removeAt(oldIndex);
                                    _playlist.insert(newIndex, item);
                                  });
                                  _savePlaylist();
                                },
                                itemBuilder: (context, index) {
                                  final title = _playlist[index];
                                  final isPlaying = _currentlyPlayingTitle == title;
                                  return ReorderableDragStartListener(
                                    key: ValueKey('$title-$index'),
                                    index: index,
                                    child: ListTile(
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
                                      trailing: IconButton(
                                        icon: const Icon(Icons.remove_circle),
                                        tooltip: 'Remove from playlist',
                                        onPressed: () =>
                                            _removeFromPlaylist(title),
                                      ),
                                    ),
                                  );
                                },
                              )
                            : ListView.builder(
                                itemCount: listToShow.length,
                                itemBuilder: (context, index) {
                                  final title = listToShow[index];
                                  final isPlaying = _currentlyPlayingTitle == title;
                                  final inPlaylist = _playlist.contains(title);
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
                                    trailing: IconButton(
                                      icon: Icon(
                                        inPlaylist
                                            ? Icons.playlist_add_check
                                            : Icons.playlist_add,
                                        color: inPlaylist ? Colors.green : null,
                                      ),
                                      tooltip: inPlaylist
                                          ? 'Already in playlist'
                                          : 'Add to playlist',
                                      onPressed: inPlaylist
                                          ? null
                                          : () => _addToPlaylist(title),
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

class PlayControlsRow extends StatelessWidget {
  final bool showPlaylist;
  final bool isPlayingAll;
  final List<String> filteredSongs;
  final List<String> playlist;
  final VoidCallback onPlayAll;
  final VoidCallback onPlayAllPlaylist;
  final VoidCallback onTogglePlaylistView;

  const PlayControlsRow({
    super.key,
    required this.showPlaylist,
    required this.isPlayingAll,
    required this.filteredSongs,
    required this.playlist,
    required this.onPlayAll,
    required this.onPlayAllPlaylist,
    required this.onTogglePlaylistView,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          if (!showPlaylist)
            ElevatedButton.icon(
              icon: const Icon(Icons.queue_music),
              label: const Text('Play All'),
              onPressed:
                  (isPlayingAll || filteredSongs.isEmpty) ? null : onPlayAll,
            ),
          if (showPlaylist)
            ElevatedButton.icon(
              icon: const Icon(Icons.playlist_play),
              label: const Text('Play All (Playlist)'),
              onPressed: (isPlayingAll || playlist.isEmpty)
                  ? null
                  : onPlayAllPlaylist,
            ),
          const SizedBox(width: 8),
          OutlinedButton.icon(
            icon: Icon(showPlaylist
                ? Icons.library_music
                : Icons.playlist_add_check),
            label: Text(showPlaylist
                ? 'Show All Songs'
                : 'Show Playlist'),
            onPressed: onTogglePlaylistView,
          ),
          if (isPlayingAll)
            Padding(
              padding: const EdgeInsets.only(left: 12.0),
              child: Text(
                'Playing all...',
                style: TextStyle(color: Colors.green[700]),
              ),
            ),
        ],
      ),
    );
  }
}

class SongProgressBar extends StatelessWidget {
  final Duration duration;
  final Duration position;
  final Function(Duration) onSeek;

  const SongProgressBar({
    super.key,
    required this.duration,
    required this.position,
    required this.onSeek,
  });

  String _formatDuration(Duration d) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(d.inMinutes.remainder(60));
    final seconds = twoDigits(d.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    final max = duration.inMilliseconds > 0 ? duration.inMilliseconds.toDouble() : 1.0;
    final value = position.inMilliseconds.clamp(0, max.toInt()).toDouble();

    return Column(
      children: [
        Slider(
          min: 0,
          max: max,
          value: value,
          onChanged: duration.inMilliseconds > 0
              ? (v) => onSeek(Duration(milliseconds: v.toInt()))
              : null,
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
