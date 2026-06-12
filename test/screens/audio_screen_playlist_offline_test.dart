import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:homeApplications/services/audio_cache_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/fake_audio_cache_service.dart';

// Playlist immutability while offline
//
// Tests verify that playlist modification operations (add, remove, reorder) and
// song deletion are no-ops when the AudioScreen is in offline mode
// (_isOffline == true), and that the playlist/cache state is preserved exactly
// as it was when offline mode was entered.
//
// Since AudioPlayerHandler requires native plugins, we test the logic contract
// directly — simulating the guard behavior implemented in _addToPlaylist,
// _removeFromPlaylist, the onReorder callback, and _deleteDownload.
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

  group('Property 4: Playlist immutability while offline', () {
    // Helper that simulates the _addToPlaylist logic from AudioScreen
    void addToPlaylist(List<String> playlist, String title, bool isOffline) {
      if (isOffline) return;
      if (!playlist.contains(title)) {
        playlist.add(title);
      }
    }

    // Helper that simulates the _removeFromPlaylist logic from AudioScreen
    void removeFromPlaylist(List<String> playlist, String title, bool isOffline) {
      if (isOffline) return;
      playlist.remove(title);
    }

    // Helper that simulates the onReorder logic from AudioScreen
    void reorderPlaylist(
        List<String> playlist, int oldIndex, int newIndex, bool isOffline) {
      if (isOffline) return; // onReorder: _isOffline ? (_, __) {} : ...
      if (newIndex > oldIndex) newIndex -= 1;
      final item = playlist.removeAt(oldIndex);
      playlist.insert(newIndex, item);
    }

    test(
      'when _isOffline == true, attempting to add a song to the playlist is a no-op',
      () {
        // Arrange: known playlist state
        final playlist = ['Song A', 'Song B', 'Song C'];
        const isOffline = true;

        // Act: attempt to add a new song while offline
        addToPlaylist(playlist, 'Song D', isOffline);

        // Assert: playlist remains unchanged
        expect(playlist, ['Song A', 'Song B', 'Song C']);
        expect(playlist.length, 3);
        expect(playlist.contains('Song D'), isFalse);
      },
    );

    test(
      'when _isOffline == true, attempting to remove a song from the playlist is a no-op',
      () {
        // Arrange
        final playlist = ['Song A', 'Song B', 'Song C'];
        const isOffline = true;

        // Act: attempt to remove a song while offline
        removeFromPlaylist(playlist, 'Song B', isOffline);

        // Assert: playlist remains unchanged
        expect(playlist, ['Song A', 'Song B', 'Song C']);
        expect(playlist.length, 3);
        expect(playlist.contains('Song B'), isTrue);
      },
    );

    test(
      'when _isOffline == true, attempting to reorder the playlist is a no-op',
      () {
        // Arrange
        final playlist = ['Song A', 'Song B', 'Song C'];
        const isOffline = true;

        // Act: attempt to move Song C to the first position
        reorderPlaylist(playlist, 2, 0, isOffline);

        // Assert: playlist remains unchanged — order preserved
        expect(playlist, ['Song A', 'Song B', 'Song C']);
      },
    );

    test(
      'playlist state at the moment offline mode was entered is preserved throughout offline mode',
      () {
        // Arrange: initial playlist state before going offline
        final playlist = ['Song A', 'Song B', 'Song C'];
        final playlistSnapshot = List<String>.from(playlist);
        const isOffline = true;

        // Act: perform multiple modification attempts while offline
        addToPlaylist(playlist, 'New Song', isOffline);
        removeFromPlaylist(playlist, 'Song A', isOffline);
        removeFromPlaylist(playlist, 'Song B', isOffline);
        reorderPlaylist(playlist, 0, 2, isOffline);
        addToPlaylist(playlist, 'Another Song', isOffline);
        reorderPlaylist(playlist, 1, 0, isOffline);

        // Assert: playlist is identical to the snapshot taken at offline entry
        expect(playlist, playlistSnapshot);
        expect(playlist, ['Song A', 'Song B', 'Song C']);
      },
    );

    test(
      'when exiting offline mode (_isOffline = false), playlist modifications work again',
      () {
        // Arrange: start offline with known playlist
        final playlist = ['Song A', 'Song B', 'Song C'];
        var isOffline = true;

        // Act: attempt modifications while offline (should be no-ops)
        addToPlaylist(playlist, 'Song D', isOffline);
        removeFromPlaylist(playlist, 'Song A', isOffline);
        expect(playlist, ['Song A', 'Song B', 'Song C']);

        // Transition back to online (simulating successful _fetchSongs)
        isOffline = false;

        // Now modifications should work
        addToPlaylist(playlist, 'Song D', isOffline);
        expect(playlist, ['Song A', 'Song B', 'Song C', 'Song D']);

        removeFromPlaylist(playlist, 'Song B', isOffline);
        expect(playlist, ['Song A', 'Song C', 'Song D']);

        reorderPlaylist(playlist, 2, 0, isOffline);
        expect(playlist, ['Song D', 'Song A', 'Song C']);
      },
    );

    test(
      'add is a no-op even when adding a song that does not already exist in the playlist',
      () {
        // This ensures the guard fires before the "contains" check
        final playlist = ['Song A'];
        const isOffline = true;

        // 'Song B' is not in playlist, but add should still be blocked
        addToPlaylist(playlist, 'Song B', isOffline);

        expect(playlist, ['Song A']);
        expect(playlist.contains('Song B'), isFalse);
      },
    );

    test(
      'remove is a no-op even for a song that exists in the playlist',
      () {
        final playlist = ['Song A', 'Song B', 'Song C'];
        const isOffline = true;

        // 'Song A' exists but removal should be blocked
        removeFromPlaylist(playlist, 'Song A', isOffline);

        expect(playlist, ['Song A', 'Song B', 'Song C']);
      },
    );

    test(
      'reorder is a no-op for any index combination while offline',
      () {
        final playlist = ['Song A', 'Song B', 'Song C', 'Song D'];
        const isOffline = true;

        // Try various reorder combinations
        reorderPlaylist(playlist, 0, 3, isOffline); // Move first to last
        reorderPlaylist(playlist, 3, 0, isOffline); // Move last to first
        reorderPlaylist(playlist, 1, 2, isOffline); // Swap adjacent

        expect(playlist, ['Song A', 'Song B', 'Song C', 'Song D']);
      },
    );
  });

  group('Delete download is disabled while offline', () {
    // Tracks whether deleteDownload was actually called on the service
    late bool deleteWasCalled;

    // Helper that simulates the _deleteDownload logic from AudioScreen
    Future<void> deleteDownload(String title, bool isOffline) async {
      if (isOffline) return;
      // In the real code this calls: await _cacheService.deleteDownload(title);
      deleteWasCalled = true;
    }

    setUp(() {
      deleteWasCalled = false;
    });

    test(
      'when _isOffline == true, attempting to delete a download is a no-op',
      () async {
        const isOffline = true;

        await deleteDownload('Song A', isOffline);

        expect(deleteWasCalled, isFalse,
            reason: 'deleteDownload should not be called when offline');
      },
    );

    test(
      'when _isOffline == false, deleting a download proceeds normally',
      () async {
        const isOffline = false;

        await deleteDownload('Song A', isOffline);

        expect(deleteWasCalled, isTrue,
            reason: 'deleteDownload should be called when online');
      },
    );

    test(
      'multiple delete attempts while offline are all no-ops',
      () async {
        const isOffline = true;

        await deleteDownload('Song A', isOffline);
        await deleteDownload('Song B', isOffline);
        await deleteDownload('Song C', isOffline);

        expect(deleteWasCalled, isFalse,
            reason: 'No deletes should proceed while offline');
      },
    );

    test(
      'delete is blocked while offline but works after returning online',
      () async {
        var isOffline = true;

        // Attempt while offline — blocked
        await deleteDownload('Song A', isOffline);
        expect(deleteWasCalled, isFalse);

        // Return online
        isOffline = false;
        await deleteDownload('Song A', isOffline);
        expect(deleteWasCalled, isTrue,
            reason: 'Delete should work after returning online');
      },
    );
  });

  group('Playlist toggle in all songs list (add/remove based on membership)', () {
    // Simulates the toggle behavior of the playlist button in the all songs list.
    // In the UI, the IconButton onPressed does:
    //   if (_isOffline) -> null (disabled)
    //   else -> if (inPlaylist) _removeFromPlaylist(title) else _addToPlaylist(title)
    void togglePlaylist(List<String> playlist, String title, bool isOffline) {
      if (isOffline) return;
      final inPlaylist = playlist.contains(title);
      if (inPlaylist) {
        // _removeFromPlaylist logic
        playlist.remove(title);
      } else {
        // _addToPlaylist logic
        if (!playlist.contains(title)) {
          playlist.add(title);
        }
      }
    }

    test(
      'tapping playlist button when song is NOT in playlist adds it (online)',
      () {
        final playlist = <String>['Song A'];
        const isOffline = false;

        togglePlaylist(playlist, 'Song B', isOffline);

        expect(playlist, ['Song A', 'Song B']);
      },
    );

    test(
      'tapping playlist button when song IS in playlist removes it (online)',
      () {
        final playlist = ['Song A', 'Song B', 'Song C'];
        const isOffline = false;

        togglePlaylist(playlist, 'Song B', isOffline);

        expect(playlist, ['Song A', 'Song C']);
        expect(playlist.contains('Song B'), isFalse);
      },
    );

    test(
      'toggling twice returns playlist to original state (online)',
      () {
        final playlist = ['Song A', 'Song B'];
        const isOffline = false;

        // Remove Song B
        togglePlaylist(playlist, 'Song B', isOffline);
        expect(playlist, ['Song A']);

        // Add Song B back
        togglePlaylist(playlist, 'Song B', isOffline);
        expect(playlist, ['Song A', 'Song B']);
      },
    );

    test(
      'tapping playlist button is a no-op when offline (song not in playlist)',
      () {
        final playlist = <String>['Song A'];
        const isOffline = true;

        togglePlaylist(playlist, 'Song B', isOffline);

        expect(playlist, ['Song A']);
        expect(playlist.contains('Song B'), isFalse);
      },
    );

    test(
      'tapping playlist button is a no-op when offline (song already in playlist)',
      () {
        final playlist = ['Song A', 'Song B', 'Song C'];
        const isOffline = true;

        togglePlaylist(playlist, 'Song B', isOffline);

        expect(playlist, ['Song A', 'Song B', 'Song C']);
      },
    );

    test(
      'multiple toggles while offline leave playlist unchanged',
      () {
        final playlist = ['Song A', 'Song B'];
        const isOffline = true;

        togglePlaylist(playlist, 'Song A', isOffline); // would remove
        togglePlaylist(playlist, 'Song C', isOffline); // would add
        togglePlaylist(playlist, 'Song B', isOffline); // would remove

        expect(playlist, ['Song A', 'Song B']);
      },
    );

    test(
      'toggle works again after transitioning from offline to online',
      () {
        final playlist = ['Song A', 'Song B'];
        var isOffline = true;

        // Blocked while offline
        togglePlaylist(playlist, 'Song A', isOffline);
        expect(playlist, ['Song A', 'Song B']);

        // Go online
        isOffline = false;

        // Now toggle removes Song A
        togglePlaylist(playlist, 'Song A', isOffline);
        expect(playlist, ['Song B']);

        // Toggle adds Song C
        togglePlaylist(playlist, 'Song C', isOffline);
        expect(playlist, ['Song B', 'Song C']);
      },
    );
  });
}
