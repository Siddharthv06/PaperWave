import 'package:flutter/material.dart';
import 'package:on_audio_query/on_audio_query.dart';

class CustomArtworkWidget extends StatelessWidget {
  final SongModel song;
  final double size;

  const CustomArtworkWidget({
    super.key,
    required this.song,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final nullBgColor = isDark ? const Color(0xFF333338) : const Color(0xFFEAE7E0);
    final nullIconColor = isDark ? const Color(0xFFFAF6EE).withValues(alpha: 0.6) : const Color(0xFF18181A).withValues(alpha: 0.6);
    final borderColor = isDark ? const Color(0xFFFAF6EE) : const Color(0xFF18181A);

    Widget artworkChild;

    if (song.id >= 999900) {
      Color color;
      IconData icon;
      switch (song.id) {
        case 999901:
          color = const Color(0xFFF3C6F3); // pastel pink/purple
          icon = Icons.waves;
          break;
        case 999902:
          color = const Color(0xFFC4E8E8); // pastel teal
          icon = Icons.blur_on;
          break;
        case 999903:
          color = const Color(0xFFFFF0C2); // pastel yellow
          icon = Icons.library_music;
          break;
        case 999904:
          color = const Color(0xFFFFD1C2); // pastel orange
          icon = Icons.wb_sunny;
          break;
        default:
          color = const Color(0xFFE2E2E6);
          icon = Icons.music_note;
      }

      artworkChild = Container(
        color: color,
        width: size,
        height: size,
        child: Icon(
          icon,
          color: const Color(0xFF18181A),
          size: size * 0.5,
        ),
      );
    } else {
      artworkChild = QueryArtworkWidget(
        id: song.id,
        type: ArtworkType.AUDIO,
        nullArtworkWidget: Container(
          width: size,
          height: size,
          color: nullBgColor,
          child: Icon(
            Icons.music_note,
            color: nullIconColor,
            size: size * 0.5,
          ),
        ),
      );
    }

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        border: Border.all(
          color: borderColor,
          width: 1.8,
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: artworkChild,
      ),
    );
  }
}
