import 'package:audio_service/audio_service.dart';
import 'package:audioplayers/audioplayers.dart';
import 'dart:async';
import '../models/credentials.dart';
import 'audio_cache_service.dart';
import 'service_locator.dart';

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
  int _currentIndex = -1;
  Credentials? _credentials;
  late final AudioCacheService _cacheService;

  // Public getters for UI to read state
  AudioPlayer get player => _player;
  bool get hasNext => _currentIndex < _queue.length - 1;
  bool get hasPrevious => _currentIndex > 0;
  int get currentIndex => _currentIndex;

  AudioPlayerHandler() {
    _cacheService = getIt<AudioCacheService>();
    _init();
  }

  void setCredentials(Credentials credentials) {
    _credentials = credentials;
    _cacheService.setCredentials(credentials);
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

    // Start new playback, passing the index to verify it hasn't changed
    await _loadAndPlay(_queue[index].id, index);
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

  Future<void> playFromUrl(String url, String title) async {
    final item = MediaItem(
      id: url,
      title: title,
      displayTitle: title,
    );
    await playMediaItem(item);
  }

  Future<void> _loadAndPlay(String url, int expectedIndex) async {
    // Update state to loading
    playbackState.add(playbackState.value.copyWith(
      playing: true,
      processingState: AudioProcessingState.loading,
    ));

    try {
      // Extract title from the expected queue item
      String? title;
      if (expectedIndex >= 0 && expectedIndex < _queue.length) {
        title = _queue[expectedIndex].title;
      }

      // Validate we have required data
      if (title == null) {
        throw Exception('Cannot play: song title is missing');
      }

      if (_credentials == null) {
        throw Exception('Cannot play: credentials not set');
      }

      // Use cache service to get or download the file
      final localPath = await _cacheService.getOrDownload(title, url);

      // Check if user hasn't moved to a different song during download
      if (_currentIndex != expectedIndex) {
        // User moved on, don't play this song
        return;
      }

      await _player.play(DeviceFileSource(localPath));

      // Update state to ready
      playbackState.add(playbackState.value.copyWith(
        playing: true,
        processingState: AudioProcessingState.ready,
      ));
    } catch (e) {
      // Update state to error
      playbackState.add(playbackState.value.copyWith(
        playing: false,
        processingState: AudioProcessingState.error,
      ));
    }
  }

  Future<void> playAll(List<SongItem> songs) async {
    final mediaItems = songs.map((song) => song.toMediaItem()).toList();
    await updateQueue(mediaItems);
    if (mediaItems.isNotEmpty) {
      await skipToQueueItem(0);
    }
  }

  void setPlaylist(List<SongItem> songs) {
    final mediaItems = songs.map((song) => song.toMediaItem()).toList();
    updateQueue(mediaItems);
  }
}
