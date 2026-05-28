import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import '../models/audio_cache_metadata.dart';
import '../models/credentials.dart';
import '../helper/headers.dart';

enum DownloadState {
  notDownloaded,
  queued,
  downloading,
  downloaded,
  error,
}

class DownloadProgress {
  final String title;
  final DownloadState state;
  final double progress;
  final String? errorMessage;

  DownloadProgress({
    required this.title,
    required this.state,
    this.progress = 0.0,
    this.errorMessage,
  });
}

class AudioCacheService {
  static const String _cacheFolder = 'audio_cache';
  static const String _metadataFile = 'audio_cache_metadata.json';
  static const int _maxCacheSizeBytes = 500 * 1024 * 1024; // 500MB
  static const int _maxAgeDays = 14;
  static const int _maxConcurrentDownloads = 2;

  Directory? _cacheDir;
  Map<String, AudioCacheMetadata> _metadata = {};
  final Map<String, DownloadProgress> _downloadProgress = {};
  final List<_DownloadTask> _downloadQueue = [];
  int _activeDownloads = 0;
  Credentials? _credentials;

  final _progressController = StreamController<Map<String, DownloadProgress>>.broadcast();
  Stream<Map<String, DownloadProgress>> get progressStream => _progressController.stream;

  Future<void> initialize() async {
    final appSupportDir = await getApplicationSupportDirectory();
    _cacheDir = Directory('${appSupportDir.path}/$_cacheFolder');

    if (!await _cacheDir!.exists()) {
      await _cacheDir!.create(recursive: true);
    }

    await _loadMetadata();
  }

  void setCredentials(Credentials credentials) {
    _credentials = credentials;
  }

  Future<void> _loadMetadata() async {
    final metadataFile = File('${_cacheDir!.path}/$_metadataFile');
    if (await metadataFile.exists()) {
      try {
        final content = await metadataFile.readAsString();
        final Map<String, dynamic> json = jsonDecode(content);
        _metadata = json.map(
          (key, value) => MapEntry(key, AudioCacheMetadata.fromJson(value)),
        );
      } catch (e) {
        // Failed to load metadata, start fresh
        _metadata = {};
      }
    }
  }

  Future<void> _saveMetadata() async {
    final metadataFile = File('${_cacheDir!.path}/$_metadataFile');
    final json = _metadata.map((key, value) => MapEntry(key, value.toJson()));
    await metadataFile.writeAsString(jsonEncode(json));
  }

  String _sanitizeFilename(String title) {
    return '${Uri.encodeComponent(title)}.mp3';
  }

  String _getFilePath(String title) {
    return '${_cacheDir!.path}/${_sanitizeFilename(title)}';
  }

  bool isDownloaded(String title) {
    final filename = _sanitizeFilename(title);
    return _metadata.containsKey(filename) && File(_getFilePath(title)).existsSync();
  }

  DownloadState getDownloadState(String title) {
    if (_downloadProgress.containsKey(title)) {
      return _downloadProgress[title]!.state;
    }

    if (isDownloaded(title)) {
      return DownloadState.downloaded;
    }

    return DownloadState.notDownloaded;
  }

  double getDownloadProgress(String title) {
    return _downloadProgress[title]?.progress ?? 0.0;
  }

  /// Get local file path if downloaded, otherwise return null
  Future<String?> getLocalPath(String title) async {
    if (isDownloaded(title)) {
      final path = _getFilePath(title);
      // Update last accessed time
      final filename = _sanitizeFilename(title);
      if (_metadata.containsKey(filename)) {
        _metadata[filename] = _metadata[filename]!.copyWith(
          lastAccessed: DateTime.now(),
        );
        await _saveMetadata();
      }
      return path;
    }
    return null;
  }

  /// Download file or return local path if already exists
  Future<String> getOrDownload(String title, String url) async {
    if (_credentials == null) {
      throw Exception('Credentials not set');
    }

    // Check if already downloaded
    final localPath = await getLocalPath(title);
    if (localPath != null) {
      return localPath;
    }

    // Download the file
    return await _downloadFile(title, url);
  }

  Future<String> _downloadFile(String title, String url) async {
    if (_credentials == null) {
      throw Exception('Credentials not set');
    }

    final filePath = _getFilePath(title);
    final filename = _sanitizeFilename(title);

    _updateProgress(title, DownloadState.downloading, 0.0);

    try {
      // Check storage limit before downloading
      await enforceStorageLimit();

      final request = http.Request('GET', Uri.parse(url));
      request.headers.addAll(HeadersHelper.getHeaders(_credentials!));

      final response = await request.send();

      if (response.statusCode == 200) {
        final contentLength = response.contentLength ?? 0;
        final file = File(filePath);
        final sink = file.openWrite();

        int downloadedBytes = 0;

        await response.stream.listen(
          (chunk) {
            sink.add(chunk);
            downloadedBytes += chunk.length;

            // Update progress
            if (contentLength > 0) {
              final progress = downloadedBytes / contentLength;
              _updateProgress(title, DownloadState.downloading, progress);
            }
          },
          onDone: () async {
            await sink.close();
          },
          onError: (error) async {
            await sink.close();
            throw error;
          },
          cancelOnError: true,
        ).asFuture();

        // Get actual file size after download
        final fileSize = await file.length();

        // Save metadata
        _metadata[filename] = AudioCacheMetadata(
          title: title,
          lastAccessed: DateTime.now(),
          downloadedAt: DateTime.now(),
          fileSize: fileSize,
        );
        await _saveMetadata();

        _updateProgress(title, DownloadState.downloaded, 1.0);
        return filePath;
      } else {
        throw Exception('Download failed with status: ${response.statusCode}');
      }
    } catch (e) {
      _updateProgress(title, DownloadState.error, 0.0, e.toString());
      // Clean up partial download
      final file = File(filePath);
      if (await file.exists()) {
        await file.delete();
      }
      rethrow;
    }
  }

  void queueDownload(String title, String url) {
    final state = getDownloadState(title);
    if (state == DownloadState.downloaded || state == DownloadState.downloading || state == DownloadState.queued) {
      return;
    }

    _downloadQueue.add(_DownloadTask(title: title, url: url));
    _updateProgress(title, DownloadState.queued, 0.0);
    _processQueue();
  }

  void _processQueue() {
    while (_activeDownloads < _maxConcurrentDownloads && _downloadQueue.isNotEmpty) {
      final task = _downloadQueue.removeAt(0);
      _activeDownloads++;

      _downloadFile(task.title, task.url).then((_) {
        _activeDownloads--;
        _processQueue();
      }).catchError((e) {
        // Download error handled in _downloadFile, just continue processing
        _activeDownloads--;
        _processQueue();
      });
    }
  }

  void _updateProgress(String title, DownloadState state, double progress, [String? errorMessage]) {
    _downloadProgress[title] = DownloadProgress(
      title: title,
      state: state,
      progress: progress,
      errorMessage: errorMessage,
    );
    _progressController.add(Map.from(_downloadProgress));
  }

  Future<void> deleteDownload(String title) async {
    final filePath = _getFilePath(title);
    final file = File(filePath);

    if (await file.exists()) {
      await file.delete();
    }

    final filename = _sanitizeFilename(title);
    _metadata.remove(filename);
    await _saveMetadata();

    _downloadProgress.remove(title);
    _progressController.add(Map.from(_downloadProgress));
  }

  Future<void> cleanupOldFiles() async {
    final now = DateTime.now();
    final cutoffDate = now.subtract(Duration(days: _maxAgeDays));

    final filesToDelete = <String>[];

    _metadata.forEach((filename, metadata) {
      if (metadata.lastAccessed.isBefore(cutoffDate)) {
        filesToDelete.add(filename);
      }
    });

    for (final filename in filesToDelete) {
      final filePath = '${_cacheDir!.path}/$filename';
      final file = File(filePath);
      if (await file.exists()) {
        await file.delete();
      }
      _metadata.remove(filename);
    }

    if (filesToDelete.isNotEmpty) {
      await _saveMetadata();
    }
  }

  Future<void> enforceStorageLimit() async {
    int totalSize = 0;
    _metadata.forEach((_, metadata) {
      totalSize += metadata.fileSize;
    });

    if (totalSize <= _maxCacheSizeBytes) {
      return;
    }

    // Sort by last accessed (oldest first)
    final sortedEntries = _metadata.entries.toList()
      ..sort((a, b) => a.value.lastAccessed.compareTo(b.value.lastAccessed));

    // Delete oldest files until under limit
    for (final entry in sortedEntries) {
      if (totalSize <= _maxCacheSizeBytes) {
        break;
      }

      final filePath = '${_cacheDir!.path}/${entry.key}';
      final file = File(filePath);
      if (await file.exists()) {
        await file.delete();
      }

      totalSize -= entry.value.fileSize;
      _metadata.remove(entry.key);
    }

    await _saveMetadata();
  }

  int getTotalCacheSize() {
    int totalSize = 0;
    _metadata.forEach((_, metadata) {
      totalSize += metadata.fileSize;
    });
    return totalSize;
  }

  String getFormattedCacheSize() {
    final sizeBytes = getTotalCacheSize();
    if (sizeBytes < 1024) {
      return '$sizeBytes B';
    } else if (sizeBytes < 1024 * 1024) {
      return '${(sizeBytes / 1024).toStringAsFixed(1)} KB';
    } else {
      return '${(sizeBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
  }

  int getCachedFileCount() {
    return _metadata.length;
  }

  void dispose() {
    _progressController.close();
  }
}

class _DownloadTask {
  final String title;
  final String url;

  _DownloadTask({required this.title, required this.url});
}
