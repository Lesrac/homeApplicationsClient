import 'package:flutter/material.dart';

class PlayControlsRow extends StatelessWidget {
  final bool showPlaylist;
  final bool isPlayingAll;
  final List<String> filteredSongs;
  final List<String> playlist;
  final VoidCallback onPlayAll;
  final VoidCallback onPlayAllPlaylist;
  final VoidCallback onTogglePlaylistView;

  const PlayControlsRow({
    super.key,
    required this.showPlaylist,
    required this.isPlayingAll,
    required this.filteredSongs,
    required this.playlist,
    required this.onPlayAll,
    required this.onPlayAllPlaylist,
    required this.onTogglePlaylistView,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          if (!showPlaylist) ...[
            ElevatedButton.icon(
              icon: const Icon(Icons.queue_music),
              label: const Text('Play All'),
              onPressed:
                  (isPlayingAll || filteredSongs.isEmpty) ? null : onPlayAll,
            ),
          ],
          if (showPlaylist) ...[
            ElevatedButton.icon(
              icon: const Icon(Icons.playlist_play),
              label: const Text('Play All (Playlist)'),
              onPressed: (isPlayingAll || playlist.isEmpty)
                  ? null
                  : onPlayAllPlaylist,
            ),
          ],
          const SizedBox(width: 8),
          OutlinedButton.icon(
            icon: Icon(
              showPlaylist ? Icons.library_music : Icons.playlist_add_check,
            ),
            label: Text(showPlaylist ? 'Show All Songs' : 'Show Playlist'),
            onPressed: onTogglePlaylistView,
          ),
          if (isPlayingAll)
            Padding(
              padding: const EdgeInsets.only(left: 12.0),
              child: Text(
                'Playing all...',
                style: TextStyle(color: Colors.green[700]),
              ),
            ),
        ],
      ),
    );
  }
}
