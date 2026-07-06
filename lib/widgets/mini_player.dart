import 'package:flutter/material.dart';
import 'package:on_audio_query/on_audio_query.dart';
import 'sketchy_container.dart';
import 'artwork_widget.dart';
import 'animation_widgets.dart';

class MiniPlayer extends StatefulWidget {
  final SongModel currentSong;
  final bool isPlaying;
  final Duration currentPosition;
  final Duration totalDuration;
  final VoidCallback onPlayPause;
  final VoidCallback onNext;
  final VoidCallback onPrevious;
  final ValueChanged<double> onSeek;
  final VoidCallback onClose;
  final VoidCallback? onTapBody;

  const MiniPlayer({
    super.key,
    required this.currentSong,
    required this.isPlaying,
    required this.currentPosition,
    required this.totalDuration,
    required this.onPlayPause,
    required this.onNext,
    required this.onPrevious,
    required this.onSeek,
    required this.onClose,
    this.onTapBody,
  });

  @override
  State<MiniPlayer> createState() => _MiniPlayerState();
}

class _MiniPlayerState extends State<MiniPlayer> with SingleTickerProviderStateMixin {
  late AnimationController _floatController;
  late Animation<double> _floatAnimation;

  @override
  void initState() {
    super.initState();
    // 3-second cycle vertical float
    _floatController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    );
    _floatAnimation = Tween<double>(begin: -1.5, end: 1.5).animate(
      CurvedAnimation(parent: _floatController, curve: Curves.easeInOut),
    );
    _floatController.repeat(reverse: true);
  }

  @override
  void dispose() {
    _floatController.dispose();
    super.dispose();
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  Widget _buildSketchyButton({
    required IconData icon,
    required VoidCallback onTap,
    double size = 28,
    Color? backgroundColor,
    required Color iconColor,
  }) {
    return TactileButton(
      onTap: onTap,
      backgroundColor: backgroundColor,
      borderWidth: 1.8,
      borderRadius: BorderRadius.circular(8),
      padding: const EdgeInsets.all(6),
      shadowOffset: const Offset(2, 2),
      child: Icon(icon, color: iconColor, size: size),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? const Color(0xFFFAF6EE) : const Color(0xFF18181A);
    final subtitleColor = isDark ? Colors.white60 : Colors.black54;
    
    final activeTrackColor = isDark ? const Color(0xFFFAF6EE) : const Color(0xFF18181A);
    final inactiveTrackColor = isDark ? Colors.white24 : Colors.black12;

    return AnimatedBuilder(
      animation: _floatAnimation,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, _floatAnimation.value),
          child: child,
        );
      },
      child: Padding(
        padding: const EdgeInsets.only(left: 12.0, right: 12.0, bottom: 16.0),
        child: SketchyContainer(
          backgroundColor: isDark ? const Color(0xFF26262B) : const Color(0xFFFFFDF9),
          borderRadius: BorderRadius.circular(16),
          padding: const EdgeInsets.all(12.0),
          shadowOffset: const Offset(4, 4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Row(
                children: [
                  // Tappable Album Artwork & Metadata Area
                  Expanded(
                    child: GestureDetector(
                      onTap: widget.onTapBody,
                      behavior: HitTestBehavior.opaque,
                      child: Row(
                        children: [
                          Hero(
                            tag: 'artwork_vinyl',
                            child: CustomArtworkWidget(song: widget.currentSong, size: 46),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  widget.currentSong.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontFamily: 'monospace',
                                    fontWeight: FontWeight.bold,
                                    color: textColor,
                                    fontSize: 14.0,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  widget.currentSong.artist ?? '<Unknown Artist>',
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
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Controls Row
                  Row(
                    children: [
                      _buildSketchyButton(
                        icon: Icons.skip_previous,
                        onTap: widget.onPrevious,
                        iconColor: textColor,
                        backgroundColor: isDark ? const Color(0xFF333338) : Colors.white,
                      ),
                      const SizedBox(width: 8),
                      _buildSketchyButton(
                        icon: widget.isPlaying ? Icons.pause : Icons.play_arrow,
                        onTap: widget.onPlayPause,
                        size: 28,
                        backgroundColor: isDark ? const Color(0xFF5C5C3D) : const Color(0xFFFFF9C4), 
                        iconColor: isDark ? const Color(0xFFFFF9C4) : const Color(0xFF18181A),
                      ),
                      const SizedBox(width: 8),
                      _buildSketchyButton(
                        icon: Icons.skip_next,
                        onTap: widget.onNext,
                        iconColor: textColor,
                        backgroundColor: isDark ? const Color(0xFF333338) : Colors.white,
                      ),
                      const SizedBox(width: 8),
                      _buildSketchyButton(
                        icon: Icons.close,
                        onTap: widget.onClose,
                        iconColor: textColor,
                        backgroundColor: isDark ? const Color(0xFF333338) : Colors.white,
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Text(
                    _formatDuration(widget.currentPosition),
                    style: TextStyle(
                      fontFamily: 'monospace',
                      color: textColor,
                      fontSize: 11.5,
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4.0),
                      child: SmoothSlider(
                        value: widget.currentPosition.inSeconds.toDouble(),
                        max: widget.totalDuration.inSeconds.toDouble(),
                        activeColor: activeTrackColor,
                        inactiveColor: inactiveTrackColor,
                        onChanged: widget.onSeek,
                      ),
                    ),
                  ),
                  Text(
                    _formatDuration(widget.totalDuration),
                    style: TextStyle(
                      fontFamily: 'monospace',
                      color: textColor,
                      fontSize: 11.5,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
