import 'package:flutter/material.dart';

class AudioOfflineBanner extends StatelessWidget {
  final bool isLoading;
  final VoidCallback onRetry;

  const AudioOfflineBanner({
    super.key,
    required this.isLoading,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return MaterialBanner(
      content: const Text(
        'Server connection failed. Showing downloaded songs only. Playlist editing is disabled.',
      ),
      leading: const Icon(Icons.cloud_off, color: Colors.orange),
      backgroundColor: Colors.orange.shade50,
      actions: [
        TextButton(
          onPressed: isLoading ? null : onRetry,
          child: const Text('Retry'),
        ),
      ],
    );
  }
}
