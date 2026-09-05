import 'package:flutter/material.dart';
import '../../services/audio_cache_service.dart';
import 'song_download_button.dart';

class PlaylistReorderableList extends StatelessWidget {
  final List<String> playlist;
  final String? currentlyPlayingTitle;
  final bool isOffline;
  final Map<String, DownloadProgress> downloadProgress;
  final DownloadState Function(String) getDownloadState;
  final void Function(String) onPlay;
  final VoidCallback onStop;
  final void Function(String) onRemoveFromPlaylist;
  final void Function(int, int) onReorder;
  final void Function(String) onQueueDownload;
  final void Function(String) onDeleteDownload;

  const PlaylistReorderableList({
    super.key,
    required this.playlist,
    required this.currentlyPlayingTitle,
    required this.isOffline,
    required this.downloadProgress,
    required this.getDownloadState,
    required this.onPlay,
    required this.onStop,
    required this.onRemoveFromPlaylist,
    required this.onReorder,
    required this.onQueueDownload,
    required this.onDeleteDownload,
  });

  @override
  Widget build(BuildContext context) {
    if (playlist.isEmpty) {
      return const Center(child: Text('Playlist is empty'));
    }

    return ReorderableListView.builder(
      buildDefaultDragHandles: false,
      itemCount: playlist.length,
      onReorder: isOffline ? (_, _) {} : onReorder,
      itemBuilder: (context, index) {
        final title = playlist[index];
        final isPlaying = currentlyPlayingTitle == title;
        return ListTile(
          key: ValueKey('$title-$index'),
          leading: IconButton(
            icon: Icon(
              isPlaying ? Icons.stop : Icons.play_arrow,
            ),
            onPressed: () {
              if (isPlaying) {
                onStop();
              } else {
                onPlay(title);
              }
            },
          ),
          title: Text(
            title,
            style: TextStyle(
              fontWeight: isPlaying ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SongDownloadButton(
                title: title,
                state: getDownloadState(title),
                progress: downloadProgress[title],
                isOffline: isOffline,
                onDownload: () => onQueueDownload(title),
                onDelete: () => onDeleteDownload(title),
              ),
              IconButton(
                icon: const Icon(Icons.remove_circle),
                tooltip: isOffline
                    ? 'Playlist editing disabled (offline)'
                    : 'Remove from playlist',
                onPressed: isOffline
                    ? null
                    : () => onRemoveFromPlaylist(title),
              ),
              ReorderableDragStartListener(
                index: index,
                enabled: !isOffline,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4.0),
                  child: Icon(
                    Icons.drag_handle,
                    color: isOffline
                        ? Theme.of(context).disabledColor
                        : null,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
