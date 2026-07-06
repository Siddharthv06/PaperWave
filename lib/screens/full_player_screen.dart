import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';

import '../widgets/ambient_background.dart';
import '../widgets/sketchy_container.dart';
import '../widgets/animation_widgets.dart';
import 'home_screen.dart'; // For ScribbledBackButton

class FullPlayerScreen extends StatefulWidget {
  final AudioPlayer audioPlayer;
  final String paperStyle;
  final Color highlightColor;
  final bool Function(int songId) isLiked;
  final Function(Map<String, dynamic> track) onLikeToggle;

  const FullPlayerScreen({
    super.key,
    required this.audioPlayer,
    required this.paperStyle,
    required this.highlightColor,
    required this.isLiked,
    required this.onLikeToggle,
  });

  @override
  State<FullPlayerScreen> createState() => _FullPlayerScreenState();
}

class _FullPlayerScreenState extends State<FullPlayerScreen> {
  String _formatDuration(Duration d) {
    final min = d.inMinutes;
    final sec = d.inSeconds % 60;
    return '$min:${sec.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark
        ? const Color(0xFFFAF6EE)
        : const Color(0xFF18181A);
    final subtitleColor = isDark ? Colors.white60 : Colors.black54;

    return StreamBuilder<SequenceState?>(
      stream: widget.audioPlayer.sequenceStateStream,
      builder: (context, seqSnapshot) {
        final seq = seqSnapshot.data;
        final mediaItem = (seq != null && seq.currentSource != null)
            ? seq.currentSource!.tag as MediaItem?
            : null;

        // Fallback info if stream is empty
        final title = mediaItem?.title ?? 'Unknown Track';
        final artist = mediaItem?.artist ?? 'Unknown Artist';
        final songId = mediaItem != null
            ? (int.tryParse(mediaItem.id) ?? -1)
            : -1;
        final isLiked = songId != -1 && widget.isLiked(songId);

        return StreamBuilder<bool>(
          stream: widget.audioPlayer.playingStream,
          builder: (context, playingSnapshot) {
            final isPlaying = playingSnapshot.data ?? false;

            return Scaffold(
              backgroundColor: isDark
                  ? const Color(0xFF1B1C1E)
                  : const Color(0xFFFAF6EE),
              body: Stack(
                children: [
                  AmbientBackground(style: widget.paperStyle),
                  FloatingNotesOverlay(
                    isPlaying: isPlaying,
                    child: SafeArea(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20.0,
                          vertical: 16.0,
                        ),
                        child: Column(
                          children: [
                            // Header Row
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                ScribbledBackButton(
                                  color: textColor,
                                  onTap: () {
                                    HapticFeedback.lightImpact();
                                    Navigator.pop(context);
                                  },
                                ),
                                Text(
                                  'NOW PLAYING',
                                  style: TextStyle(
                                    fontFamily: 'monospace',
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: textColor,
                                    letterSpacing: 1.5,
                                  ),
                                ),
                                const SizedBox(
                                  width: 32,
                                ), // Spacer to balance back button
                              ],
                            ),
                            const Spacer(),

                            // Vinyl Record Hero Area
                            Hero(
                              tag: 'artwork_vinyl',
                              child: RotatingVinyl(
                                isPlaying: isPlaying,
                                size: 240,
                                child: Container(
                                  width: 240,
                                  height: 240,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF0F0F10),
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: textColor,
                                      width: 3.5,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: textColor.withValues(
                                          alpha: 0.18,
                                        ),
                                        offset: const Offset(4, 4),
                                        blurRadius: 0,
                                      ),
                                    ],
                                  ),
                                  child: Stack(
                                    alignment: Alignment.center,
                                    children: [
                                      CustomPaint(
                                        size: const Size(240, 240),
                                        painter: VinylGroovesPainter(
                                          lineColor: isDark
                                              ? Colors.white30
                                              : Colors.grey.withValues(
                                                  alpha: 0.4,
                                                ),
                                        ),
                                      ),
                                      // Album Art in center with scale/fade transition
                                      AnimatedSwitcher(
                                        duration: const Duration(
                                          milliseconds: 300,
                                        ),
                                        transitionBuilder: (child, animation) {
                                          final scaleAnimation =
                                              Tween<double>(
                                                begin: 0.95,
                                                end: 1.0,
                                              ).animate(
                                                CurvedAnimation(
                                                  parent: animation,
                                                  curve: Curves.easeOutCubic,
                                                ),
                                              );
                                          return FadeTransition(
                                            opacity: animation,
                                            child: ScaleTransition(
                                              scale: scaleAnimation,
                                              child: child,
                                            ),
                                          );
                                        },
                                        child: ClipOval(
                                          key: ValueKey<int>(songId),
                                          child: SizedBox(
                                            width: 240 * 0.4,
                                            height: 240 * 0.4,
                                            child: (mediaItem?.artUri != null)
                                                ? Image.network(
                                                    mediaItem!.artUri
                                                        .toString(),
                                                    fit: BoxFit.cover,
                                                    errorBuilder: (c, e, s) =>
                                                        Container(
                                                          color: isDark
                                                              ? const Color(
                                                                  0xFF333338,
                                                                )
                                                              : const Color(
                                                                  0xFFEAE7E0,
                                                                ),
                                                          child: Icon(
                                                            Icons.music_note,
                                                            color: textColor
                                                                .withValues(
                                                                  alpha: 0.6,
                                                                ),
                                                            size: 32,
                                                          ),
                                                        ),
                                                  )
                                                : Container(
                                                    color: isDark
                                                        ? const Color(
                                                            0xFF333338,
                                                          )
                                                        : const Color(
                                                            0xFFEAE7E0,
                                                          ),
                                                    child: Icon(
                                                      Icons.music_note,
                                                      color: textColor
                                                          .withValues(
                                                            alpha: 0.6,
                                                          ),
                                                      size: 32,
                                                    ),
                                                  ),
                                          ),
                                        ),
                                      ),
                                      // Vinyl Center Hole
                                      Container(
                                        width: 240 * 0.07,
                                        height: 240 * 0.07,
                                        decoration: BoxDecoration(
                                          color: isDark
                                              ? const Color(0xFF1B1C1E)
                                              : const Color(0xFFFAF6EE),
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                            color: textColor,
                                            width: 2,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            const Spacer(),

                            // Song Metadata Card
                            SketchyContainer(
                              backgroundColor: isDark
                                  ? const Color(0xFF26262B)
                                  : Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 16,
                              ),
                              shadowOffset: const Offset(3, 3),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontFamily: 'monospace',
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                      color: textColor,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    artist,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontFamily: 'monospace',
                                      fontSize: 14,
                                      color: subtitleColor,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const Spacer(),

                            // Progress Slider
                            StreamBuilder<Duration>(
                              stream: widget.audioPlayer.positionStream,
                              builder: (context, posSnapshot) {
                                final position =
                                    posSnapshot.data ?? Duration.zero;
                                return StreamBuilder<Duration?>(
                                  stream: widget.audioPlayer.durationStream,
                                  builder: (context, durSnapshot) {
                                    final duration =
                                        durSnapshot.data ?? Duration.zero;
                                    return Column(
                                      children: [
                                        SmoothSlider(
                                          value: position.inSeconds.toDouble(),
                                          max: duration.inSeconds.toDouble(),
                                          activeColor: widget.highlightColor,
                                          inactiveColor: isDark
                                              ? Colors.white24
                                              : Colors.black12,
                                          onChanged: (val) {
                                            widget.audioPlayer.seek(
                                              Duration(seconds: val.toInt()),
                                            );
                                          },
                                        ),
                                        Padding(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 16.0,
                                          ),
                                          child: Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.spaceBetween,
                                            children: [
                                              Text(
                                                _formatDuration(position),
                                                style: TextStyle(
                                                  fontFamily: 'monospace',
                                                  fontSize: 12,
                                                  color: subtitleColor,
                                                ),
                                              ),
                                              Text(
                                                _formatDuration(duration),
                                                style: TextStyle(
                                                  fontFamily: 'monospace',
                                                  fontSize: 12,
                                                  color: subtitleColor,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    );
                                  },
                                );
                              },
                            ),
                            const Spacer(),

                            // Playback Controls Row
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [
                                TactileButton(
                                  borderRadius: BorderRadius.circular(12),
                                  backgroundColor: isDark
                                      ? const Color(0xFF333338)
                                      : Colors.white,
                                  borderWidth: 1.8,
                                  padding: const EdgeInsets.all(12),
                                  onTap: () =>
                                      widget.audioPlayer.seekToPrevious(),
                                  child: Icon(
                                    Icons.skip_previous,
                                    color: textColor,
                                    size: 28,
                                  ),
                                ),
                                TactileButton(
                                  borderRadius: BorderRadius.circular(16),
                                  backgroundColor: widget.highlightColor,
                                  borderWidth: 1.8,
                                  padding: const EdgeInsets.all(16),
                                  pressedScale: 0.90,
                                  onTap: () {
                                    if (isPlaying) {
                                      widget.audioPlayer.pause();
                                    } else {
                                      widget.audioPlayer.play();
                                    }
                                  },
                                  child: Icon(
                                    isPlaying ? Icons.pause : Icons.play_arrow,
                                    color: const Color(0xFF18181A),
                                    size: 32,
                                  ),
                                ),
                                TactileButton(
                                  borderRadius: BorderRadius.circular(12),
                                  backgroundColor: isDark
                                      ? const Color(0xFF333338)
                                      : Colors.white,
                                  borderWidth: 1.8,
                                  padding: const EdgeInsets.all(12),
                                  onTap: () => widget.audioPlayer.seekToNext(),
                                  child: Icon(
                                    Icons.skip_next,
                                    color: textColor,
                                    size: 28,
                                  ),
                                ),
                                TactileButton(
                                  borderRadius: BorderRadius.circular(12),
                                  backgroundColor: isDark
                                      ? const Color(0xFF333338)
                                      : Colors.white,
                                  borderWidth: 1.8,
                                  padding: const EdgeInsets.all(12),
                                  onTap:
                                      () {}, // Handled by inner HeartLikeButton
                                  child: HeartLikeButton(
                                    isLiked: isLiked,
                                    onTap: () {
                                      widget.onLikeToggle({
                                        'id': songId,
                                        'title': title,
                                        'artist': artist,
                                        'album':
                                            mediaItem?.album ?? 'Unknown Album',
                                        'previewUrl':
                                            mediaItem?.artUri?.toString() ?? '',
                                      });
                                    },
                                    iconColor: textColor,
                                    activeColor: Colors.redAccent,
                                    size: 28,
                                  ),
                                ),
                              ],
                            ),
                            const Spacer(),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
