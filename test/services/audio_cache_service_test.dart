import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:homeApplications/services/audio_cache_service.dart';

// Cached song titles are sorted case-insensitively
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late Directory cacheDir;
  late AudioCacheService service;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('audio_cache_test_');
    cacheDir = Directory('${tempDir.path}/audio_cache');
    cacheDir.createSync(recursive: true);

    // Mock path_provider to return our temp directory
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (MethodCall methodCall) async {
        if (methodCall.method == 'getApplicationSupportDirectory') {
          return tempDir.path;
        }
        return null;
      },
    );

    service = AudioCacheService();
  });

  tearDown(() {
    service.dispose();
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      null,
    );
  });

  // Helper to write metadata JSON to the expected cache directory location.
  void writeMetadata(Map<String, Map<String, dynamic>> metadata) {
    final metadataFile = File('${cacheDir.path}/audio_cache_metadata.json');
    metadataFile.writeAsStringSync(jsonEncode(metadata));
  }

  // Helper to build a metadata entry map for a given title.
  Map<String, dynamic> buildMetadataEntry(String title) {
    return {
      'title': title,
      'lastAccessed': DateTime.now().toIso8601String(),
      'downloadedAt': DateTime.now().toIso8601String(),
      'fileSize': 1024,
    };
  }

  group('getCachedSongTitles - Property 6: sorted case-insensitively', () {
    test('returns empty list when no metadata entries exist', () async {
      // No metadata file written — initialize with empty state
      await service.initialize();

      final titles = service.getCachedSongTitles();

      expect(titles, isEmpty);
      expect(titles, isA<List<String>>());
    });

    test('returns empty list when metadata file exists but is empty map',
        () async {
      writeMetadata({});
      await service.initialize();

      final titles = service.getCachedSongTitles();

      expect(titles, isEmpty);
    });

    test('returns single title when one metadata entry exists', () async {
      writeMetadata({
        '${Uri.encodeComponent("My Song")}.mp3': buildMetadataEntry('My Song'),
      });
      await service.initialize();

      final titles = service.getCachedSongTitles();

      expect(titles, ['My Song']);
    });

    test(
        'returns titles sorted case-insensitively with multiple mixed-case entries',
        () async {
      writeMetadata({
        '${Uri.encodeComponent("alpha")}.mp3': buildMetadataEntry('alpha'),
        '${Uri.encodeComponent("Beta")}.mp3': buildMetadataEntry('Beta'),
        '${Uri.encodeComponent("gamma")}.mp3': buildMetadataEntry('gamma'),
        '${Uri.encodeComponent("DELTA")}.mp3': buildMetadataEntry('DELTA'),
      });
      await service.initialize();

      final titles = service.getCachedSongTitles();

      // Case-insensitive sort: alpha, Beta, DELTA, gamma
      expect(titles, ['alpha', 'Beta', 'DELTA', 'gamma']);
    });

    test('sorting is stable and case-insensitive for similar names', () async {
      writeMetadata({
        '${Uri.encodeComponent("Zebra")}.mp3': buildMetadataEntry('Zebra'),
        '${Uri.encodeComponent("apple")}.mp3': buildMetadataEntry('apple'),
        '${Uri.encodeComponent("APPLE")}.mp3': buildMetadataEntry('APPLE'),
        '${Uri.encodeComponent("banana")}.mp3': buildMetadataEntry('banana'),
        '${Uri.encodeComponent("Cherry")}.mp3': buildMetadataEntry('Cherry'),
      });
      await service.initialize();

      final titles = service.getCachedSongTitles();

      // Case-insensitive sort: apple/APPLE (same lowercase), banana, Cherry, Zebra
      // Both 'apple' and 'APPLE' compare equally — order between them depends on
      // original map iteration order, but both must come before 'banana'
      expect(titles.length, 5);

      // Verify the list is sorted case-insensitively
      for (int i = 0; i < titles.length - 1; i++) {
        expect(
          titles[i].toLowerCase().compareTo(titles[i + 1].toLowerCase()) <= 0,
          isTrue,
          reason:
              'Expected "${titles[i]}" to sort before or equal to "${titles[i + 1]}" (case-insensitive)',
        );
      }

      // Verify specific ordering constraints
      expect(titles.indexOf('banana'),
          greaterThan(titles.indexOf('apple')));
      expect(titles.indexOf('banana'),
          greaterThan(titles.indexOf('APPLE')));
      expect(titles.indexOf('Cherry'),
          greaterThan(titles.indexOf('banana')));
      expect(titles.indexOf('Zebra'),
          greaterThan(titles.indexOf('Cherry')));
    });
  });
}
