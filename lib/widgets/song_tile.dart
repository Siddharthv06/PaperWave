import 'package:flutter/material.dart';
import 'package:on_audio_query/on_audio_query.dart';
import 'sketchy_container.dart';
import 'artwork_widget.dart';

class SongTile extends StatelessWidget {
  final SongModel song;
  final bool isCurrent;
  final VoidCallback onTap;
  final bool showRemoveOption;
  final VoidCallback? onAddToPlaylist;
  final VoidCallback? onRemoveFromPlaylist;
  final Color? highlightColor;

  const SongTile({
    super.key,
    required this.song,
    required this.isCurrent,
    required this.onTap,
    this.showRemoveOption = false,
    this.onAddToPlaylist,
    this.onRemoveFromPlaylist,
    this.highlightColor,
  });

  String _formatMilliseconds(int milliseconds) {
    final duration = Duration(milliseconds: milliseconds);
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final defaultBg = isDark ? const Color(0xFF26262B) : Colors.white;
    final backgroundColor = isCurrent ? (highlightColor ?? const Color(0xFFFFF9C4)) : defaultBg;
    
    final textColor = isCurrent ? const Color(0xFF18181A) : (isDark ? const Color(0xFFFAF6EE) : const Color(0xFF18181A));
    final subtitleColor = isCurrent ? Colors.black54 : (isDark ? Colors.white60 : Colors.black54);
    final timeColor = isCurrent ? Colors.black54 : (isDark ? Colors.white54 : Colors.black54);
    final iconColor = isCurrent ? const Color(0xFF18181A) : (isDark ? const Color(0xFFFAF6EE) : const Color(0xFF18181A));

    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: SketchyContainer(
        backgroundColor: backgroundColor,
        borderRadius: BorderRadius.circular(12),
        shadowOffset: isCurrent ? const Offset(2, 2) : const Offset(4, 4),
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 10.0),
            child: Row(
              children: [
                CustomArtworkWidget(song: song, size: 48),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        song.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: 'monospace',
                          fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                          color: textColor,
                          fontSize: 14.0,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        song.artist ?? '<Unknown Artist>',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: 'monospace',
                          color: subtitleColor,
                          fontSize: 11.5,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  _formatMilliseconds(song.duration ?? 0),
                  style: TextStyle(
                    fontFamily: 'monospace',
                    color: timeColor,
                    fontSize: 11.0,
                  ),
                ),
                const SizedBox(width: 4),
                Theme(
                  data: Theme.of(context).copyWith(
                    cardColor: isDark ? const Color(0xFF26262B) : Colors.white,
                  ),
                  child: PopupMenuButton<String>(
                    icon: Icon(Icons.more_vert, color: iconColor, size: 20),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onSelected: (value) {
                      if (value == 'add') {
                        onAddToPlaylist?.call();
                      } else if (value == 'remove') {
                        onRemoveFromPlaylist?.call();
                      }
                    },
                    itemBuilder: (context) => [
                      if (onAddToPlaylist != null)
                        PopupMenuItem(
                          value: 'add',
                          child: Text(
                            'Add to Playlist',
                            style: TextStyle(
                              fontFamily: 'monospace', 
                              fontSize: 13,
                              color: isDark ? const Color(0xFFFAF6EE) : const Color(0xFF18181A),
                            ),
                          ),
                        ),
                      if (showRemoveOption && onRemoveFromPlaylist != null)
                        PopupMenuItem(
                          value: 'remove',
                          child: Text(
                            'Remove from Playlist',
                            style: TextStyle(
                              fontFamily: 'monospace', 
                              fontSize: 13,
                              color: isDark ? const Color(0xFFFAF6EE) : const Color(0xFF18181A),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
