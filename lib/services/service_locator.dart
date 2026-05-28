import 'package:audio_service/audio_service.dart';
import 'package:get_it/get_it.dart';
import 'audio_handler.dart';
import 'audio_cache_service.dart';

final getIt = GetIt.instance;

Future<void> setupServiceLocator() async {
  // Initialize and register AudioCacheService
  final cacheService = AudioCacheService();
  await cacheService.initialize();
  getIt.registerSingleton<AudioCacheService>(cacheService);

  // Register the AudioHandler as a singleton
  getIt.registerSingleton<AudioHandler>(
    await AudioService.init(
      builder: () => AudioPlayerHandler(),
      config: const AudioServiceConfig(
        androidNotificationChannelId: 'com.homeapplications.audio',
        androidNotificationChannelName: 'Home Applications Audio',
        androidNotificationOngoing: true,
        androidStopForegroundOnPause: true,
      ),
    ),
  );
}
