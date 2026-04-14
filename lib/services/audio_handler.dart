import 'package:audio_service/audio_service.dart';
import 'package:audioplayers/audioplayers.dart';
import 'dart:async';

class SongItem {
  final String title;
  final String url;

  SongItem({required this.title, required this.url});

  MediaItem toMediaItem() {
    return MediaItem(
      id: url,
      title: title,
      displayTitle: title,
      playable: true,
    );
  }
}

class AudioPlayerHandler extends BaseAudioHandler with QueueHandler, SeekHandler {
  final AudioPlayer _player = AudioPlayer();
  final List<MediaItem> _queue = [];
  final Map<String, Map<String, String>?> _urlHeaders = {};
  int _currentIndex = -1;

  // Public getters for UI to read state
  AudioPlayer get player => _player;
  bool get hasNext => _currentIndex < _queue.length - 1;
  bool get hasPrevious => _currentIndex > 0;
  int get currentIndex => _currentIndex;

  AudioPlayerHandler() {
    _init();
  }

  Future<void> _init() async {
    // Connect listeners from AudioPlayer to AudioService
    _player.onPlayerComplete.listen((_) {
      if (hasNext) {
        skipToNext();
      } else {
        stop();
      }
    });

    _player.onDurationChanged.listen((duration) {
      if (_currentIndex >= 0 && _currentIndex < _queue.length) {
        final newMediaItem = _queue[_currentIndex].copyWith(duration: duration);
        _queue[_currentIndex] = newMediaItem;
        mediaItem.add(newMediaItem);
      }
    });

    _player.onPositionChanged.listen((position) {
      playbackState.add(playbackState.value.copyWith(
        updatePosition: position,
        processingState: AudioProcessingState.ready,
      ));
    });

    // Initialize with empty queue
    queue.add(_queue);
  }

  @override
  Future<void> play() async {
    if (_currentIndex < 0 || _currentIndex >= _queue.length) return;

    await _player.resume();
    playbackState.add(playbackState.value.copyWith(
      playing: true,
      processingState: AudioProcessingState.ready,
    ));
  }

  @override
  Future<void> pause() async {
    await _player.pause();
    playbackState.add(playbackState.value.copyWith(
      playing: false,
      processingState: AudioProcessingState.ready,
    ));
  }

  @override
  Future<void> stop() async {
    await _player.stop();
    playbackState.add(playbackState.value.copyWith(
      playing: false,
      processingState: AudioProcessingState.idle,
    ));
    mediaItem.add(null);
  }

  @override
  Future<void> seek(Duration position) async {
    await _player.seek(position);
  }

  @override
  Future<void> skipToQueueItem(int index) async {
    if (index < 0 || index >= _queue.length) return;

    // Stop current playback
    await _player.stop();

    // Update current index
    _currentIndex = index;

    // Update mediaItem
    mediaItem.add(_queue[index]);

    // Start new playback
    await _loadAndPlay(_queue[index].id);
  }

  @override
  Future<void> skipToNext() async {
    if (!hasNext) return;
    await skipToQueueItem(_currentIndex + 1);
  }

  @override
  Future<void> skipToPrevious() async {
    if (!hasPrevious) return;
    await skipToQueueItem(_currentIndex - 1);
  }

  @override
  Future<void> setRepeatMode(AudioServiceRepeatMode repeatMode) async {
    playbackState.add(playbackState.value.copyWith(repeatMode: repeatMode));
    super.setRepeatMode(repeatMode);
  }

  @override
  Future<void> updateQueue(List<MediaItem> newQueue) async {
    _queue.clear();
    _queue.addAll(newQueue);
    queue.add(_queue);
    // Prune any stored headers for URLs that are no longer in the queue
    final urlsInQueue = _queue.map((m) => m.id).toSet();
    _urlHeaders.removeWhere((k, _) => !urlsInQueue.contains(k));
  }

  @override
  Future<void> addQueueItem(MediaItem mediaItem) async {
    _queue.add(mediaItem);
    queue.add(_queue);
  }

  @override
  Future<void> removeQueueItem(MediaItem mediaItem) async {
    final index = _queue.indexOf(mediaItem);
    if (index != -1) {
      _queue.removeAt(index);
      if (_currentIndex > index) {
        _currentIndex--;
      } else if (_currentIndex == index && _currentIndex == _queue.length) {
        _currentIndex--;
      }
    }
    queue.add(_queue);
    // Remove any stored headers for the removed item's URL
    _urlHeaders.remove(mediaItem.id);
  }

  @override
  Future<void> setShuffleMode(AudioServiceShuffleMode shuffleMode) async {
    if (shuffleMode == AudioServiceShuffleMode.all) {
      _queue.shuffle();
      _currentIndex = _queue.isEmpty ? -1 : 0;
      queue.add(_queue);
    }
    playbackState.add(playbackState.value.copyWith(shuffleMode: shuffleMode));
    super.setShuffleMode(shuffleMode);
  }

  // Methods specific to our implementation
  @override
  Future<void> playMediaItem(MediaItem item) async {
    final index = _queue.indexWhere((element) => element.id == item.id);
    if (index != -1) {
      await skipToQueueItem(index);
    } else {
      await addQueueItem(item);
      await skipToQueueItem(_queue.length - 1);
    }
  }

  /// Play a single URL and optionally provide HTTP headers used when loading the URL.
  Future<void> playFromUrl(String url, String title, {Map<String, String>? headers}) async {
    // store headers for this URL so _loadAndPlay can pass them to UrlSource
    if (headers != null) {
      _urlHeaders[url] = headers;
    }

    final item = MediaItem(
      id: url,
      title: title,
      displayTitle: title,
    );
    await playMediaItem(item);
  }

  Future<void> _loadAndPlay(String url) async {
    // Update state to loading
    playbackState.add(playbackState.value.copyWith(
      playing: true,
      processingState: AudioProcessingState.loading,
    ));

    // Load and play the URL, passing through any stored headers for this URL
    final headers = _urlHeaders[url];
    if (headers != null) {
      await _player.play(UrlSource(url, headers: headers));
    } else {
      await _player.play(UrlSource(url));
    }

    // Update state to ready
    playbackState.add(playbackState.value.copyWith(
      playing: true,
      processingState: AudioProcessingState.ready,
    ));
  }

  /// Play a list of songs. You can optionally provide headers which will be used for every URL.
  Future<void> playAll(List<SongItem> songs, {Map<String, String>? headers}) async {
    final mediaItems = songs.map((song) => song.toMediaItem()).toList();
    // store headers for each song URL if provided
    if (headers != null) {
      for (final song in songs) {
        _urlHeaders[song.url] = headers;
      }
    }
    await updateQueue(mediaItems);
    if (mediaItems.isNotEmpty) {
      await skipToQueueItem(0);
    }
  }

  /// Set in-memory playlist; optional headers will be associated with each URL.
  void setPlaylist(List<SongItem> songs, {Map<String, String>? headers}) {
    final mediaItems = songs.map((song) => song.toMediaItem()).toList();
    if (headers != null) {
      for (final song in songs) {
        _urlHeaders[song.url] = headers;
      }
    }
    updateQueue(mediaItems);
  }
}
