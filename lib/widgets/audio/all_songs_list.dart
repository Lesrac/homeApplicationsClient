import 'package:flutter/material.dart';
import '../../services/audio_cache_service.dart';
import 'song_download_button.dart';

class AllSongsList extends StatelessWidget {
  final List<String> songs;
  final List<String> playlist;
  final String? currentlyPlayingTitle;
  final bool isOffline;
  final Map<String, DownloadProgress> downloadProgress;
  final DownloadState Function(String) getDownloadState;
  final void Function(String) onPlay;
  final VoidCallback onStop;
  final void Function(String) onTogglePlaylist;
  final void Function(String) onQueueDownload;
  final void Function(String) onDeleteDownload;

  const AllSongsList({
    super.key,
    required this.songs,
    required this.playlist,
    required this.currentlyPlayingTitle,
    required this.isOffline,
    required this.downloadProgress,
    required this.getDownloadState,
    required this.onPlay,
    required this.onStop,
    required this.onTogglePlaylist,
    required this.onQueueDownload,
    required this.onDeleteDownload,
  });

  @override
  Widget build(BuildContext context) {
    if (songs.isEmpty) {
      return const Center(child: Text('No songs found'));
    }

    return ListView.builder(
      itemCount: songs.length,
      itemBuilder: (context, index) {
        final title = songs[index];
        final isPlaying = currentlyPlayingTitle == title;
        final inPlaylist = playlist.contains(title);
        return ListTile(
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
                icon: Icon(
                  inPlaylist
                      ? Icons.playlist_add_check
                      : Icons.playlist_add,
                  color: inPlaylist ? Colors.green : null,
                ),
                tooltip: isOffline
                    ? 'Playlist editing disabled (offline)'
                    : (inPlaylist
                        ? 'Remove from playlist'
                        : 'Add to playlist'),
                onPressed: isOffline
                    ? null
                    : () => onTogglePlaylist(title),
              ),
            ],
          ),
        );
      },
    );
  }
}
