import 'package:flutter/material.dart';
import '../../services/audio_cache_service.dart';

class SongDownloadButton extends StatelessWidget {
  final String title;
  final DownloadState state;
  final DownloadProgress? progress;
  final bool isOffline;
  final VoidCallback onDownload;
  final VoidCallback onDelete;

  const SongDownloadButton({
    super.key,
    required this.title,
    required this.state,
    required this.progress,
    required this.isOffline,
    required this.onDownload,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    switch (state) {
      case DownloadState.downloaded:
        return IconButton(
          icon: const Icon(Icons.download_done, color: Colors.green),
          tooltip: isOffline
              ? 'Downloaded (deletion disabled offline)'
              : 'Downloaded - tap to delete',
          onPressed: isOffline ? null : onDelete,
        );
      case DownloadState.downloading:
        return Stack(
          alignment: Alignment.center,
          children: [
            SizedBox(
              width: 32,
              height: 32,
              child: CircularProgressIndicator(
                value: progress?.progress,
                strokeWidth: 3,
                backgroundColor: Colors.grey[300],
              ),
            ),
            Text(
              '${((progress?.progress ?? 0) * 100).toInt()}%',
              style: const TextStyle(fontSize: 8, fontWeight: FontWeight.bold),
            ),
          ],
        );
      case DownloadState.queued:
        return const SizedBox(
          width: 32,
          height: 32,
          child: CircularProgressIndicator(
            strokeWidth: 3,
            backgroundColor: Colors.transparent,
          ),
        );
      case DownloadState.error:
        return IconButton(
          icon: const Icon(Icons.error, color: Colors.red),
          tooltip: progress?.errorMessage ?? 'Download failed',
          onPressed: onDownload,
        );
      case DownloadState.notDownloaded:
        return IconButton(
          icon: const Icon(Icons.download),
          tooltip: 'Download',
          onPressed: onDownload,
        );
    }
  }
}
