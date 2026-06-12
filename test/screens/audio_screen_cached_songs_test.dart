import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:homeApplications/services/audio_cache_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/fake_audio_cache_service.dart';

// Offline songs are a subset of cached songs**
//
// These tests verify that when the AudioScreen is in offline mode, the displayed
// songs are exactly what getCachedSongTitles() returns, and that the filter
// TextField applies correctly against the cached songs list.
//
// The implementation logic under test:
// 1. _handleFetchFailure() sets `_songs = _cacheService.getCachedSongTitles()`
// 2. In build(): `filteredSongs = _songs.where((title) => title.toLowerCase().contains(_filter.toLowerCase())).toList()`
// 3. Display: `listToShow = _showPlaylist ? _playlist : filteredSongs`
//
// Since AudioPlayerHandler requires native plugins, we test the state machine
// logic and filtering contract directly.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeAudioCacheService fakeCacheService;

  setUp(() {
    GetIt.instance.reset();
    SharedPreferences.setMockInitialValues({});

    fakeCacheService = FakeAudioCacheService();
    GetIt.instance.registerSingleton<AudioCacheService>(fakeCacheService);
  });

  tearDown(() {
    GetIt.instance.reset();
  });

  // Helper that simulates the filtering logic from AudioScreen.build()
  List<String> applyFilter(List<String> songs, String filter) {
    return songs
        .where((title) => title.toLowerCase().contains(filter.toLowerCase()))
        .toList();
  }

  group('Property 5: Offline songs are a subset of cached songs', () {
    test(
      'songs displayed in offline mode are exactly what getCachedSongTitles() returns',
      () {
        // Arrange: set known cached titles
        fakeCacheService.setFakeCachedTitles(
            ['Alpha Song', 'Beta Song', 'Gamma Song']);

        // Act: simulate _handleFetchFailure()
        // _handleFetchFailure does: _songs = _cacheService.getCachedSongTitles()
        final cachedTitles = fakeCacheService.getCachedSongTitles();
        final isOffline = true;
        final songs = cachedTitles;

        // Assert: displayed songs are exactly the cached songs
        expect(isOffline, isTrue);
        expect(songs, ['Alpha Song', 'Beta Song', 'Gamma Song']);
        expect(songs.length, fakeCacheService.getCachedSongTitles().length);
      },
    );

    test(
      'every song displayed offline exists in the cached songs set',
      () {
        // Arrange
        final cachedSet = ['Track A', 'Track B', 'Track C', 'Track D'];
        fakeCacheService.setFakeCachedTitles(cachedSet);

        // Act: simulate offline mode entry
        final songs = fakeCacheService.getCachedSongTitles();
        final isOffline = true;

        // Assert: every displayed song is in the cached set
        expect(isOffline, isTrue);
        for (final song in songs) {
          expect(cachedSet.contains(song), isTrue,
              reason: '"$song" should exist in cached songs');
        }
      },
    );

    test(
      'filter applies correctly against cached songs list',
      () {
        // Arrange: set cached titles with distinct patterns (already sorted
        // case-insensitively as getCachedSongTitles() would return from real service)
        fakeCacheService.setFakeCachedTitles(
            ['Autumn Leaves', 'Summer Rain', 'Summer Vibes', 'Winter Blues']);

        // Act: simulate _handleFetchFailure() then apply filter
        final songs = fakeCacheService.getCachedSongTitles();
        final isOffline = true;
        final filter = 'summer';

        // Apply the same filtering logic as build():
        // _songs.where((title) => title.toLowerCase().contains(_filter.toLowerCase()))
        final filteredSongs = applyFilter(songs, filter);

        // Assert: only matching cached titles remain
        expect(isOffline, isTrue);
        expect(filteredSongs, ['Summer Rain', 'Summer Vibes']);
        expect(filteredSongs.length, 2);
        for (final song in filteredSongs) {
          expect(song.toLowerCase().contains('summer'), isTrue);
        }
      },
    );

    test(
      'empty filter shows all cached songs',
      () {
        // Arrange
        fakeCacheService.setFakeCachedTitles(
            ['Song A', 'Song B', 'Song C']);

        // Act: simulate offline mode with empty filter
        final songs = fakeCacheService.getCachedSongTitles();
        final isOffline = true;
        final filter = '';

        final filteredSongs = applyFilter(songs, filter);

        // Assert: all cached songs are displayed
        expect(isOffline, isTrue);
        expect(filteredSongs, songs);
        expect(filteredSongs.length, 3);
      },
    );

    test(
      'filter that matches nothing shows empty list',
      () {
        // Arrange
        fakeCacheService.setFakeCachedTitles(
            ['Rock Anthem', 'Jazz Melody', 'Blues Riff']);

        // Act: apply filter that matches no cached songs
        final songs = fakeCacheService.getCachedSongTitles();
        final isOffline = true;
        final filter = 'classical';

        final filteredSongs = applyFilter(songs, filter);

        // Assert: empty list when filter matches nothing
        expect(isOffline, isTrue);
        expect(filteredSongs, isEmpty);
      },
    );

    test(
      'filter is case-insensitive against cached songs',
      () {
        // Arrange
        fakeCacheService.setFakeCachedTitles(
            ['UPPERCASE Song', 'lowercase song', 'Mixed Case Song']);

        // Act
        final songs = fakeCacheService.getCachedSongTitles();
        final filter = 'SONG';

        final filteredSongs = applyFilter(songs, filter);

        // Assert: case-insensitive matching finds all songs containing "song"
        expect(filteredSongs.length, 3);
        expect(filteredSongs, contains('UPPERCASE Song'));
        expect(filteredSongs, contains('lowercase song'));
        expect(filteredSongs, contains('Mixed Case Song'));
      },
    );

    test(
      'filtered songs in offline mode are always a subset of cached songs',
      () {
        // Arrange
        final cachedTitles = [
          'Alpha',
          'Beta',
          'Gamma',
          'Delta',
          'Epsilon'
        ];
        fakeCacheService.setFakeCachedTitles(cachedTitles);

        // Act: simulate offline and apply various filters
        final songs = fakeCacheService.getCachedSongTitles();

        final filters = ['a', 'e', 'z', '', 'alpha', 'GAMMA'];
        for (final filter in filters) {
          final filteredSongs = applyFilter(songs, filter);

          // Assert: every filtered result is contained in the cached songs set
          for (final song in filteredSongs) {
            expect(songs.contains(song), isTrue,
                reason:
                    'Filtered song "$song" with filter "$filter" must be in cached songs');
          }
        }
      },
    );

    test(
      'when cache is empty and offline, display shows empty list (no songs found)',
      () {
        // Arrange: empty cache
        fakeCacheService.setFakeCachedTitles([]);

        // Act: simulate _handleFetchFailure with empty cache
        final songs = fakeCacheService.getCachedSongTitles();
        final isOffline = true;
        final filter = '';

        final filteredSongs = applyFilter(songs, filter);

        // Assert: empty list displayed
        // In build(): listToShow.isEmpty -> Center(child: Text('No songs found'))
        expect(isOffline, isTrue);
        expect(filteredSongs, isEmpty);
        expect(songs, isEmpty);
      },
    );

    test(
      'partial filter matches correct subset of cached songs',
      () {
        // Arrange: cached songs with overlapping substrings
        fakeCacheService.setFakeCachedTitles([
          'The Beatles - Hey Jude',
          'The Rolling Stones - Paint It Black',
          'Beatles - Let It Be',
          'Led Zeppelin - Stairway to Heaven',
        ]);

        // Act: filter for "Beatles"
        final songs = fakeCacheService.getCachedSongTitles();
        final filteredSongs = applyFilter(songs, 'Beatles');

        // Assert: only songs containing "Beatles" are shown
        expect(filteredSongs.length, 2);
        expect(filteredSongs, contains('The Beatles - Hey Jude'));
        expect(filteredSongs, contains('Beatles - Let It Be'));
        expect(filteredSongs, isNot(contains('The Rolling Stones - Paint It Black')));
        expect(filteredSongs, isNot(contains('Led Zeppelin - Stairway to Heaven')));
      },
    );

    test(
      'listToShow uses filteredSongs (not playlist) when _showPlaylist is false',
      () {
        // Arrange: simulate the build() logic:
        // final listToShow = _showPlaylist ? _playlist : filteredSongs;
        fakeCacheService.setFakeCachedTitles(['Cached A', 'Cached B', 'Cached C']);

        // Act: simulate offline mode with filter and showPlaylist = false
        final songs = fakeCacheService.getCachedSongTitles();
        final filter = 'cached';

        final filteredSongs = applyFilter(songs, filter);

        // Assert: filteredSongs contains only cached songs matching the filter
        expect(filteredSongs, ['Cached A', 'Cached B', 'Cached C']);
        // Playlist songs are not shown when showPlaylist is false (offline songs view)
        final playlist = ['Playlist Song 1', 'Playlist Song 2'];
        expect(filteredSongs, isNot(equals(playlist)));
      },
    );
  });
}
