import 'package:homeApplications/models/credentials.dart';
import 'package:homeApplications/services/audio_cache_service.dart';

// Fake AudioCacheService for use in tests.
// Provides controlled cached song titles without requiring file system access.
class FakeAudioCacheService extends AudioCacheService {
  List<String> _fakeCachedTitles = [];

  void setFakeCachedTitles(List<String> titles) {
    _fakeCachedTitles = titles;
  }

  @override
  List<String> getCachedSongTitles() {
    return List.from(_fakeCachedTitles);
  }

  @override
  Future<void> initialize() async {}

  @override
  void setCredentials(Credentials credentials) {}

  @override
  int getCachedFileCount() => _fakeCachedTitles.length;

  @override
  String getFormattedCacheSize() => '0 B';

  @override
  DownloadState getDownloadState(String title) => DownloadState.notDownloaded;

  @override
  Stream<Map<String, DownloadProgress>> get progressStream =>
      const Stream.empty();
}
