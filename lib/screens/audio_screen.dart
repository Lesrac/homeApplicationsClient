import 'package:audio_service/audio_service.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';

import '../models/credentials.dart';
import '../services/audio_cache_service.dart';
import '../services/audio_handler.dart';
import '../services/service_locator.dart';
import '../services/song_service.dart';
import '../widgets/audio/all_songs_list.dart';
import '../widgets/audio/audio_offline_banner.dart';
import '../widgets/audio/play_controls_row.dart';
import '../widgets/audio/playlist_reorderable_list.dart';
import '../widgets/audio/song_progress_bar.dart';

export '../widgets/audio/play_controls_row.dart';
export '../widgets/audio/song_progress_bar.dart';

class AudioScreen extends StatefulWidget {
  final Credentials credentials;
  final SongService? songService;

  const AudioScreen({
    super.key,
    required this.credentials,
    this.songService,
  });

  @override
  State<AudioScreen> createState() => _AudioScreenState();
}

class _AudioScreenState extends State<AudioScreen> {
  late final AudioPlayerHandler _audioHandler;
  late final AudioCacheService _cacheService;
  late final SongService _songService;

  String? _currentlyPlayingTitle;
  Duration _duration = Duration.zero;
  String _filter = '';
  bool _isLoading = true;
  bool _isOffline = false;
  bool _isPlayingAll = false;
  Duration _position = Duration.zero;
  List<String> _songs = [];
  List<MediaItem> _queue = [];
  Map<String, DownloadProgress> _downloadProgress = {};

  // Playlist state
  List<String> _playlist = [];
  bool _showPlaylist = false;

  @override
  void initState() {
    super.initState();
    _songService = widget.songService ?? SongService();
    _audioHandler = getIt<AudioHandler>() as AudioPlayerHandler;
    _cacheService = getIt<AudioCacheService>();

    // Set credentials in both services
    _audioHandler.setCredentials(widget.credentials);
    _cacheService.setCredentials(widget.credentials);

    _fetchSongs();
    _loadPlaylist();

    // Listen to download progress
    _cacheService.progressStream.listen((progress) {
      if (mounted) {
        setState(() {
          _downloadProgress = progress;
        });
      }
    });

    // Set up listeners
    _audioHandler.player.onPlayerComplete.listen((event) {
      if (_queue.isEmpty || _audioHandler.currentIndex >= _queue.length - 1) {
        if (mounted) {
          setState(() {
            _isPlayingAll = false;
          });
        }
      }
    });

    _audioHandler.player.onDurationChanged.listen((Duration d) {
      if (mounted) {
        setState(() {
          _duration = d;
        });
      }
    });

    _audioHandler.player.positionUpdater = TimerPositionUpdater(
      interval: const Duration(milliseconds: 200),
      getPosition: _audioHandler.player.getCurrentPosition,
    );

    _audioHandler.player.onPositionChanged.listen((Duration p) {
      if (mounted) {
        setState(() {
          _position = p;
        });
      }
    });

    // Listen to changes in currently playing item
    _audioHandler.mediaItem.listen((mediaItem) {
      if (mounted) {
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
      }
    });

    // Listen to queue changes
    _audioHandler.queue.listen((queue) {
      if (mounted) {
        setState(() {
          _queue = queue;
        });
      }
    });
  }

  Future<void> _fetchSongs() async {
    try {
      final songsList = await _songService.fetchSongs(widget.credentials);
      if (mounted) {
        setState(() {
          _songs = songsList;
          _isOffline = false;
          _isLoading = false;
        });
      }
    } catch (e) {
      _handleFetchFailure();
    }
  }

  void _handleFetchFailure() {
    final cachedTitles = _cacheService.getCachedSongTitles();
    if (mounted) {
      setState(() {
        _songs = cachedTitles;
        _isOffline = true;
        _isLoading = false;
      });
    }
  }

  Future<void> _play(String title) async {
    final url = 'http://${widget.credentials.backendAddress}/audio/$title';
    setState(() {
      _isPlayingAll = false;
    });
    await _audioHandler.playSingle(url, title);
  }

  Future<void> _stop() async {
    await _audioHandler.stop();
    setState(() {
      _isPlayingAll = false;
    });
  }

  Future<void> _playAll(List<String> songTitles) async {
    if (songTitles.isEmpty) return;

    setState(() {
      _isPlayingAll = true;
    });

    final songs = songTitles
        .map(
          (title) => SongItem(
            title: title,
            url: 'http://${widget.credentials.backendAddress}/audio/$title',
          ),
        )
        .toList();

    await _audioHandler.playAll(songs);
  }

  Future<void> _loadPlaylist() async {
    final loaded = await _songService.loadPlaylist();
    if (mounted) {
      setState(() {
        _playlist = loaded;
      });
    }
  }

  Future<void> _savePlaylist() async {
    await _songService.savePlaylist(_playlist);

    final songs = _playlist
        .map(
          (title) => SongItem(
            title: title,
            url: 'http://${widget.credentials.backendAddress}/audio/$title',
          ),
        )
        .toList();

    _audioHandler.setPlaylist(songs);
  }

  void _addToPlaylist(String title) {
    if (_isOffline) return;
    if (!_playlist.contains(title)) {
      setState(() {
        _playlist.add(title);
      });
      _savePlaylist();
    }
  }

  void _removeFromPlaylist(String title) {
    if (_isOffline) return;
    setState(() {
      _playlist.remove(title);
    });
    _savePlaylist();
  }

  void _togglePlaylist(String title) {
    if (_isOffline) return;
    if (_playlist.contains(title)) {
      _removeFromPlaylist(title);
    } else {
      _addToPlaylist(title);
    }
  }

  void _togglePlaylistView() {
    setState(() {
      _showPlaylist = !_showPlaylist;
    });
  }

  void _reorderPlaylist(int oldIndex, int newIndex) {
    if (_isOffline) return;
    setState(() {
      if (newIndex > oldIndex) newIndex -= 1;
      final item = _playlist.removeAt(oldIndex);
      _playlist.insert(newIndex, item);
    });
    _savePlaylist();
  }

  Future<void> _seekTo(Duration position) async {
    await _audioHandler.seek(position);
  }

  void _queueDownload(String title) {
    final url = 'http://${widget.credentials.backendAddress}/audio/$title';
    _cacheService.queueDownload(title, url);
  }

  Future<void> _deleteDownload(String title) async {
    if (_isOffline) return;
    await _cacheService.deleteDownload(title);
    setState(() {});
  }

  DownloadState _getDownloadState(String title) {
    return _cacheService.getDownloadState(title);
  }

  @override
  Widget build(BuildContext context) {
    final filteredSongs = _songs
        .where((title) => title.toLowerCase().contains(_filter.toLowerCase()))
        .toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Play music')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : Column(
                children: [
                  if (_isOffline)
                    AudioOfflineBanner(
                      isLoading: _isLoading,
                      onRetry: () {
                        setState(() {
                          _isLoading = true;
                        });
                        _fetchSongs();
                      },
                    ),
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
                  const SizedBox(height: 8),
                  Text(
                    'Cache: ${_cacheService.getCachedFileCount()} files, ${_cacheService.getFormattedCacheSize()}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: _showPlaylist
                        ? PlaylistReorderableList(
                            playlist: _playlist,
                            currentlyPlayingTitle: _currentlyPlayingTitle,
                            isOffline: _isOffline,
                            downloadProgress: _downloadProgress,
                            getDownloadState: _getDownloadState,
                            onPlay: _play,
                            onStop: _stop,
                            onRemoveFromPlaylist: _removeFromPlaylist,
                            onReorder: _reorderPlaylist,
                            onQueueDownload: _queueDownload,
                            onDeleteDownload: _deleteDownload,
                          )
                        : AllSongsList(
                            songs: filteredSongs,
                            playlist: _playlist,
                            currentlyPlayingTitle: _currentlyPlayingTitle,
                            isOffline: _isOffline,
                            downloadProgress: _downloadProgress,
                            getDownloadState: _getDownloadState,
                            onPlay: _play,
                            onStop: _stop,
                            onTogglePlaylist: _togglePlaylist,
                            onQueueDownload: _queueDownload,
                            onDeleteDownload: _deleteDownload,
                          ),
                  ),
                ],
              ),
      ),
    );
  }
}
