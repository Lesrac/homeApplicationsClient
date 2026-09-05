import 'package:flutter/material.dart';

class SongProgressBar extends StatelessWidget {
  final Duration duration;
  final Duration position;
  final Function(Duration) onSeek;

  const SongProgressBar({
    super.key,
    required this.duration,
    required this.position,
    required this.onSeek,
  });

  String _formatDuration(Duration d) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(d.inMinutes.remainder(60));
    final seconds = twoDigits(d.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    final max = duration.inMilliseconds > 0
        ? duration.inMilliseconds.toDouble()
        : 1.0;
    final value = position.inMilliseconds.clamp(0, max.toInt()).toDouble();

    return Column(
      children: [
        Slider(
          min: 0,
          max: max,
          value: value,
          onChanged: duration.inMilliseconds > 0
              ? (v) => onSeek(Duration(milliseconds: v.toInt()))
              : null,
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(_formatDuration(position)),
            Text(
              duration.inMilliseconds > 0 ? _formatDuration(duration) : '00:00',
            ),
          ],
        ),
        const SizedBox(height: 8),
      ],
    );
  }
}
