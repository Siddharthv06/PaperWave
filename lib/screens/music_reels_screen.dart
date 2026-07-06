import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';

import '../widgets/sketchy_container.dart';
import '../widgets/animation_widgets.dart';

class MusicReelsView extends StatefulWidget {
  final AudioPlayer audioPlayer;
  final Color highlightColor;
  final Function(Map<String, dynamic> track) onLikeToggle;
  final bool Function(int trackId) isLiked;
  final String rotationSpeed;
  final String soundPreset;
  final ValueChanged<String> onSoundPresetChanged;

  final List<String> selectedGenres;
  final VoidCallback onChangeGenres;

  final List<Map<String, dynamic>> initialSongs;
  final int initialIndex;
  final ValueChanged<List<Map<String, dynamic>>> onSongsFetched;
  final ValueChanged<int> onIndexChanged;

  const MusicReelsView({
    super.key,
    required this.audioPlayer,
    required this.highlightColor,
    required this.onLikeToggle,
    required this.isLiked,
    required this.rotationSpeed,
    required this.soundPreset,
    required this.onSoundPresetChanged,
    required this.selectedGenres,
    required this.onChangeGenres,
    required this.initialSongs,
    required this.initialIndex,
    required this.onSongsFetched,
    required this.onIndexChanged,
  });

  @override
  State<MusicReelsView> createState() => _MusicReelsViewState();
}

class _MusicReelsViewState extends State<MusicReelsView>
    with TickerProviderStateMixin {
  List<Map<String, dynamic>> _reelsSongs = [];
  bool _isLoading = false;
  bool _isPlaying = false;
  bool _isMuted = false;
  // ponytail: false = iTunes 30s previews (correct metadata guaranteed)
  //           true  = Jamendo full tracks (correct metadata guaranteed)
  bool _preferFullTracks = false;

  late PageController _pageController;
  late AnimationController _rotationController;

  int _activePlayIndex = -1;

  // Stream Subscriptions to cancel on dispose
  StreamSubscription? _playerStateSub;
  StreamSubscription? _indexSub;

  final Map<String, List<String>> _genreQueryMap = {
    'Bollywood': [
      'Arijit Singh',
      'Pritam',
      'A.R. Rahman',
      'Shreya Ghoshal',
      'Vishal-Shekhar',
      'Amit Trivedi',
    ],
    'Hindi Indie': [
      'Anuv Jain',
      'Prateek Kuhad',
      'Osho Jain',
      'When Chai Met Toast',
      'The Local Train',
    ],
    'Punjabi': [
      'Diljit Dosanjh',
      'AP Dhillon',
      'Karan Aujla',
      'Sidhu Moose Wala',
      'Guru Randhawa',
      'Shubh',
    ],
    'English Pop': [
      'Taylor Swift',
      'Ed Sheeran',
      'Ariana Grande',
      'Justin Bieber',
      'Dua Lipa',
      'The Weeknd',
      'Billie Eilish',
      'Bruno Mars',
    ],
    'English Rock': [
      'Coldplay',
      'Imagine Dragons',
      'Queen',
      'Linkin Park',
      'Bon Jovi',
      'AC/DC',
      'Guns N\' Roses',
    ],
    'Hip-Hop / Rap': [
      'Eminem',
      'Drake',
      'Kendrick Lamar',
      'Post Malone',
      'Travis Scott',
      'Kanye West',
    ],
    'EDM / Dance': [
      'Avicii',
      'Martin Garrix',
      'David Guetta',
      'The Chainsmokers',
      'Calvin Harris',
      'Marshmello',
      'Alan Walker',
    ],
    'K-Pop': [
      'BTS',
      'BLACKPINK',
      'NewJeans',
      'TWICE',
      'Stray Kids',
      'FIFTY FIFTY',
    ],
    'Lo-Fi / Chill': [
      'Lofi Study Beats',
      'Lofi Chill Beats',
      'Lofi Girl',
      'Chillhop',
    ],
    'Latin': [
      'Bad Bunny',
      'Shakira',
      'Daddy Yankee',
      'J Balvin',
      'Karol G',
      'Maluma',
    ],
    'Jazz': [
      'Miles Davis',
      'John Coltrane',
      'Ella Fitzgerald',
      'Louis Armstrong',
      'Bill Evans',
    ],
    'Classical': [
      'Beethoven',
      'Mozart',
      'Bach',
      'Chopin',
      'Tchaikovsky',
      'Vivaldi',
    ],
  };

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: widget.initialIndex);

    _rotationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 12),
    );

    _setupAudioListeners();

    if (widget.initialSongs.isNotEmpty) {
      _reelsSongs = List.from(widget.initialSongs);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final sequenceState = widget.audioPlayer.sequenceState;
        final currentTag = sequenceState?.currentSource?.tag as MediaItem?;
        final targetSong = _reelsSongs[widget.initialIndex];
        if (currentTag == null ||
            currentTag.id != targetSong['id'].toString()) {
          _playSong(widget.initialIndex);
        }
      });
    } else {
      _fetchSongs();
    }
  }

  @override
  void dispose() {
    _playerStateSub?.cancel();
    _indexSub?.cancel();
    _pageController.dispose();
    _rotationController.dispose();
    super.dispose();
  }

  void _setupAudioListeners() {
    _playerStateSub = widget.audioPlayer.playerStateStream.listen((state) {
      if (!mounted) return;
      setState(() {
        _isPlaying = state.playing;
      });

      if (state.playing) {
        final sec = _getRotationDurationSeconds();
        if (sec > 0) {
          _rotationController.duration = Duration(seconds: sec);
          _rotationController.repeat();
        } else {
          _rotationController.stop();
        }
      } else {
        _rotationController.stop();
      }

      if (state.processingState == ProcessingState.completed) {
        final currentPage = _pageController.page?.round() ?? 0;
        final nextPage = currentPage + 1;
        if (nextPage < _reelsSongs.length) {
          _pageController.animateToPage(
            nextPage,
            duration: const Duration(milliseconds: 550),
            curve: Curves.easeInOut,
          );
        }
      }
    });

    _indexSub = widget.audioPlayer.currentIndexStream.listen((index) {
      if (!mounted) return;
      if (index != null &&
          index != _activePlayIndex &&
          index >= 0 &&
          index < _reelsSongs.length) {
        setState(() {
          _activePlayIndex = index;
        });
        widget.onIndexChanged(index);
        _pageController.animateToPage(
          index,
          duration: const Duration(milliseconds: 550),
          curve: Curves.easeInOut,
        );
      }
    });
  }

  Future<void> _fetchSongs() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _reelsSongs = [];
    });

    final activeGenres = widget.selectedGenres.isEmpty
        ? ['English Pop']
        : widget.selectedGenres;

    try {
      if (_preferFullTracks) {
        // Jamendo mode: full-length tracks with correct Jamendo metadata
        final randomGenre =
            activeGenres[DateTime.now().millisecond % activeGenres.length];
        final success = await _tryFetchJamendo(randomGenre, 'b688756f');
        if (!success && mounted) {
          setState(() => _isLoading = false);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Failed to load Jamendo tracks. Please try again!',
                style: TextStyle(fontFamily: 'monospace'),
              ),
            ),
          );
        }
      } else {
        // iTunes mode: 30s previews with correct iTunes metadata
        final List<Future<List<Map<String, dynamic>>>> futures = [];
        for (final genre in activeGenres) {
          final queries = _genreQueryMap[genre] ?? [genre];
          final query = queries[DateTime.now().millisecond % queries.length];
          futures.add(_fetchFromITunes(query, genre));
        }
        final results = await Future.wait(futures);
        final combined = results.expand((l) => l).toList();
        if (combined.isNotEmpty) {
          combined.shuffle();
          if (mounted) {
            setState(() {
              _reelsSongs = combined;
              _isLoading = false;
            });
            widget.onSongsFetched(combined);
            widget.onIndexChanged(0);
            _playSong(0);
          }
        } else if (mounted) {
          setState(() => _isLoading = false);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'No tracks found. Try changing genres or switching to Jamendo.',
                style: TextStyle(fontFamily: 'monospace'),
              ),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Error in _fetchSongs: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<List<Map<String, dynamic>>> _fetchFromITunes(
    String query,
    String genre,
  ) async {
    final url =
        'https://itunes.apple.com/search?term=${Uri.encodeComponent(query)}&media=music&entity=song&limit=30';
    try {
      final response = await http
          .get(Uri.parse(url))
          .timeout(const Duration(seconds: 6));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final results = data['results'] as List?;
        if (results != null) {
          return results.map((track) {
            final id = track['trackId'] as int? ?? DateTime.now().millisecond;
            String artworkUrl = track['artworkUrl100'] as String? ?? '';
            if (artworkUrl.contains('100x100bb.jpg')) {
              artworkUrl = artworkUrl.replaceAll(
                '100x100bb.jpg',
                '500x500bb.jpg',
              );
            } else if (artworkUrl.contains('100x100')) {
              artworkUrl = artworkUrl.replaceAll('100x100', '500x500');
            }
            return {
              'id': id,
              'title': track['trackName'] as String? ?? 'Unknown Title',
              'artist': track['artistName'] as String? ?? 'Unknown Artist',
              'album': track['collectionName'] as String? ?? 'Unknown Album',
              'artworkUrl': artworkUrl,
              'previewUrl': track['previewUrl'] as String? ?? '',
              'itunesPreviewUrl': track['previewUrl'] as String? ?? '',
              'duration': track['trackTimeMillis'] as int? ?? 30000,
              'isFull': false,
              'source': 'iTunes',
              'genre': genre,
            };
          }).toList();
        }
      }
      return [];
    } catch (e) {
      debugPrint('iTunes fetch failed for query $query: $e');
      return [];
    }
  }

  // ponytail: _resolveFullTrack deleted — it searched iTunes songs on Jamendo
  // (which doesn't have mainstream music), causing wrong audio with correct metadata.
  // Fix: source determines URL. iTunes → previewUrl. Jamendo → previewUrl (already full).

  Future<bool> _tryFetchJamendo(String genre, String clientId) async {
    final url =
        'https://api.jamendo.com/v3.0/tracks/?client_id=$clientId&format=json&fuzzytags=${Uri.encodeComponent(genre)}&limit=35&audioformat=mp32&vocalist=vocal';
    try {
      final response = await http
          .get(Uri.parse(url))
          .timeout(const Duration(seconds: 6));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final results = data['results'] as List?;
        if (results != null && results.isNotEmpty) {
          final mapped = results.where((track) => track['audio'] != null).map((
            track,
          ) {
            return {
              'id':
                  int.tryParse(track['id']?.toString() ?? '') ??
                  DateTime.now().millisecond,
              'title': track['name'] as String? ?? 'Unknown Title',
              'artist': track['artist_name'] as String? ?? 'Unknown Artist',
              'album': track['album_name'] as String? ?? 'Unknown Album',
              'artworkUrl': track['image'] as String? ?? '',
              'previewUrl': track['audio'] as String? ?? '',
              'duration': (track['duration'] as int? ?? 180) * 1000,
              'isFull': true,
              'source': 'Jamendo',
              'genre': genre,
            };
          }).toList();

          if (mapped.isNotEmpty) {
            mapped.shuffle();
            if (mounted) {
              setState(() {
                _reelsSongs = mapped;
                _isLoading = false;
              });
              widget.onSongsFetched(mapped);
              widget.onIndexChanged(0);
              _playSong(0);
            }
            return true;
          }
        }
      }
      return false;
    } catch (e) {
      debugPrint('Jamendo fetch failed (ID $clientId): $e');
      return false;
    }
  }

  Future<void> _playSong(int index) async {
    if (_reelsSongs.isEmpty || index < 0 || index >= _reelsSongs.length) return;

    _activePlayIndex = index;
    final myIndex = index;

    try {
      // Each song's previewUrl is the correct audio for that source.
      // iTunes songs: 30s preview URL (correct song, set at fetch time).
      // Jamendo songs: full track URL (correct song, set at fetch time).
      // No mid-play resolution needed — source is always honest.
      final needsRebuild =
          widget.audioPlayer.audioSource == null ||
          widget.audioPlayer.audioSource is! ConcatenatingAudioSource ||
          (widget.audioPlayer.audioSource as ConcatenatingAudioSource).length !=
              _reelsSongs.length ||
          _queueIsStale();

      if (needsRebuild) {
        final sources = _reelsSongs.map((s) {
          final url = s['previewUrl'] as String? ?? '';
          final tag = MediaItem(
            id: s['id'].toString(),
            title: s['title'] as String? ?? 'Unknown Title',
            artist: s['artist'] as String? ?? 'Unknown Artist',
            album: s['album'] as String? ?? '',
            artUri: (s['artworkUrl'] as String? ?? '').isNotEmpty
                ? Uri.parse(s['artworkUrl'] as String)
                : null,
          );
          return AudioSource.uri(Uri.parse(url), tag: tag);
        }).toList();

        await widget.audioPlayer.setAudioSource(
          ConcatenatingAudioSource(children: sources),
          initialIndex: myIndex,
        );
      } else if (widget.audioPlayer.currentIndex != myIndex) {
        await widget.audioPlayer.seek(Duration.zero, index: myIndex);
      }

      if (_activePlayIndex != myIndex) return;

      await widget.audioPlayer.setVolume(_isMuted ? 0.0 : 1.0);
      widget.audioPlayer.play();
    } catch (e) {
      debugPrint('Error playing Reels track: $e');
    }
  }

  bool _queueIsStale() {
    final seq = widget.audioPlayer.sequence;
    if (seq == null || seq.isEmpty || seq.length != _reelsSongs.length) {
      return true;
    }
    final firstTag = seq[0].tag;
    if (firstTag is MediaItem) {
      return firstTag.id != _reelsSongs[0]['id'].toString();
    }
    return true;
  }

  void _togglePlayPause() {
    if (_isPlaying) {
      widget.audioPlayer.pause();
    } else {
      widget.audioPlayer.play();
    }
  }

  void _toggleMute() {
    setState(() {
      _isMuted = !_isMuted;
    });
    widget.audioPlayer.setVolume(_isMuted ? 0.0 : 1.0);
  }

  void _showSoundPresetOptions() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark
        ? const Color(0xFFFAF6EE)
        : const Color(0xFF18181A);
    final presets = [
      'Cassette (Lo-Fi)',
      'Vinyl (Warm)',
      'Compact Disc (Hi-Fi)',
      'Studio (FLAC)',
    ];

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1B1C1E) : const Color(0xFFFAF8F3),
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(20),
              topRight: Radius.circular(20),
            ),
            border: Border(
              top: BorderSide(color: textColor, width: 2.0),
              left: BorderSide(color: textColor, width: 2.0),
              right: BorderSide(color: textColor, width: 2.0),
            ),
          ),
          padding: const EdgeInsets.all(24.0),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Acoustic Sound Profile',
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: textColor,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Select a preset reproduction profile:',
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 12,
                    color: isDark ? Colors.white60 : Colors.black54,
                  ),
                ),
                const SizedBox(height: 20),
                ...presets.map((preset) {
                  final isSelected = widget.soundPreset == preset;
                  return GestureDetector(
                    onTap: () {
                      widget.onSoundPresetChanged(preset);
                      Navigator.pop(context);
                    },
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 12.0),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? widget.highlightColor.withValues(
                                alpha: isDark ? 0.35 : 0.8,
                              )
                            : (isDark ? const Color(0xFF26262B) : Colors.white),
                        border: Border.all(
                          color: isSelected
                              ? textColor
                              : (isDark ? Colors.white24 : Colors.black26),
                          width: isSelected ? 2.0 : 1.5,
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            preset,
                            style: TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 14,
                              fontWeight: isSelected
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                              color: textColor,
                            ),
                          ),
                          if (isSelected)
                            Icon(Icons.check, color: textColor, size: 18),
                        ],
                      ),
                    ),
                  );
                }),
              ],
            ),
          ),
        );
      },
    );
  }

  String _formatDuration(Duration d) {
    final sec = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '${d.inMinutes}:$sec';
  }

  int _getRotationDurationSeconds() {
    switch (widget.rotationSpeed) {
      case 'Chill':
        return 20;
      case 'Vibe':
        return 12;
      case 'Hyper':
        return 6;
      case 'Off':
        return 0;
      default:
        return 12;
    }
  }

  Color _getDynamicMusicColor(bool isDark, int songId) {
    final int paletteIndex = songId.hashCode % 8;

    if (isDark) {
      switch (paletteIndex) {
        case 0:
          return const Color(0xFF262420); // Gold
        case 1:
          return const Color(0xFF20232A); // Blue
        case 2:
          return const Color(0xFF202822); // Green
        case 3:
          return const Color(0xFF282024); // Pink
        case 4:
          return const Color(0xFF2E2420); // Peach
        case 5:
          return const Color(0xFF202D2B); // Teal
        case 6:
          return const Color(0xFF25202D); // Violet
        case 7:
          return const Color(0xFF292C20); // Lime
        default:
          return const Color(0xFF26262B);
      }
    } else {
      switch (paletteIndex) {
        case 0:
          return const Color(0xFFFFFDF0); // Gold
        case 1:
          return const Color(0xFFF0F7FF); // Blue
        case 2:
          return const Color(0xFFF2FDF2); // Green
        case 3:
          return const Color(0xFFFAF0F3); // Pink
        case 4:
          return const Color(0xFFFFF0E6); // Peach
        case 5:
          return const Color(0xFFE6FAF8); // Teal
        case 6:
          return const Color(0xFFF3E6FF); // Violet
        case 7:
          return const Color(0xFFF9FFE6); // Lime
        default:
          return const Color(0xFFFFFDF9);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark
        ? const Color(0xFFFAF6EE)
        : const Color(0xFF18181A);
    final subtitleColor = isDark ? Colors.white60 : Colors.black54;

    return FloatingNotesOverlay(
      isPlaying: _isPlaying,
      child: Stack(
        children: [
          // Main content card takes up the entire area below the main header
          Positioned.fill(
            child: _buildMainContent(isDark, textColor, subtitleColor),
          ),



          // ponytail: resolving overlay deleted — no more async mid-play resolution
        ],
      ),
    );
  }

  Widget _buildMainContent(bool isDark, Color textColor, Color subtitleColor) {
    if (_isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const RotatingVinylLoader(size: 64),
            const SizedBox(height: 16),
            const Text(
              'Tuning to online channels...',
              style: TextStyle(
                fontFamily: 'monospace',
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      );
    }

    if (_reelsSongs.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'No online tracks loaded.',
              style: TextStyle(
                fontFamily: 'monospace',
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: isDark
                    ? const Color(0xFF26262B)
                    : Colors.white,
                foregroundColor: textColor,
                elevation: 0,
                side: BorderSide(color: textColor, width: 1.5),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onPressed: _fetchSongs,
              icon: const Icon(Icons.refresh),
              label: const Text(
                'Retry Connection',
                style: TextStyle(fontFamily: 'monospace'),
              ),
            ),
          ],
        ),
      );
    }

    return PageView.builder(
      scrollDirection: Axis.vertical,
      controller: _pageController,
      onPageChanged: (index) {
        widget.onIndexChanged(index);
        _playSong(index);
      },
      itemCount: _reelsSongs.length,
      itemBuilder: (context, index) {
        final song = _reelsSongs[index];
        final isLiked = widget.isLiked(song['id'] as int);

        return Padding(
          padding: const EdgeInsets.only(
            left: 12.0,
            right: 12.0,
            top: 96.0, // Space for top header (logo/offline toggle)
            bottom: 12.0,
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final double cardHeight = constraints.maxHeight;
              // Responsive size constraints for record disc (increased size!)
              final double discSize = cardHeight > 540.0
                  ? 240.0
                  : (cardHeight > 440.0 ? 190.0 : 130.0);

              return SketchyContainer(
                backgroundColor: _getDynamicMusicColor(
                  isDark,
                  song['id'] as int,
                ),
                borderRadius: BorderRadius.circular(20),
                padding: const EdgeInsets.all(16.0),
                shadowOffset: const Offset(3.5, 3.5),
                child: Stack(
                  children: [
                    Column(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Center(
                          child: _buildRecordDisc(
                            song['artworkUrl'] as String,
                            isDark,
                            discSize,
                          ),
                        ),

                        Padding(
                          padding: const EdgeInsets.only(right: 52.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: widget.highlightColor.withValues(
                                    alpha: 0.4,
                                  ),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  song['title'] as String,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontFamily: 'monospace',
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: textColor,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                song['artist'] as String,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontFamily: 'monospace',
                                  fontSize: 14,
                                  color: subtitleColor,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                song['album'] as String,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontFamily: 'monospace',
                                  fontSize: 11,
                                  color: subtitleColor.withValues(alpha: 0.6),
                                ),
                              ),
                              const SizedBox(height: 6),
                              Wrap(
                                spacing: 8.0,
                                runSpacing: 4.0,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: song['source'] == 'Jamendo'
                                          ? const Color(0xFFD1F3D1)
                                          : const Color(0xFFFFD1D1),
                                      borderRadius: BorderRadius.circular(4),
                                      border: Border.all(
                                        color: textColor,
                                        width: 1.2,
                                      ),
                                    ),
                                    child: Text(
                                      song['source'] == 'Jamendo'
                                          ? 'FULL TRACK'
                                          : '30S PREVIEW',
                                      style: const TextStyle(
                                        fontFamily: 'monospace',
                                        fontSize: 8.5,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF18181A),
                                      ),
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFE8D4FF),
                                      borderRadius: BorderRadius.circular(4),
                                      border: Border.all(
                                        color: textColor,
                                        width: 1.2,
                                      ),
                                    ),
                                    child: Text(
                                      song['source']
                                              ?.toString()
                                              .toUpperCase() ??
                                          'JAMENDO',
                                      style: const TextStyle(
                                        fontFamily: 'monospace',
                                        fontSize: 8.5,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF18181A),
                                      ),
                                    ),
                                  ),
                                  GestureDetector(
                                    onTap: widget.onChangeGenres,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 6,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: (isDark
                                            ? const Color(0xFF26262B)
                                            : Colors.white),
                                        borderRadius: BorderRadius.circular(4),
                                        border: Border.all(
                                          color: textColor,
                                          width: 1.2,
                                        ),
                                      ),
                                      child: Text(
                                        'GENRE: ${(song['genre'] as String? ?? "Unknown").toUpperCase()}',
                                        style: TextStyle(
                                          fontFamily: 'monospace',
                                          fontSize: 8.5,
                                          fontWeight: FontWeight.bold,
                                          color: textColor,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),

                        Padding(
                          padding: const EdgeInsets.only(right: 52.0),
                          child: _buildSeekBar(isDark, textColor),
                        ),

                        const Center(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.keyboard_double_arrow_up, size: 16),
                              SizedBox(width: 4),
                              Text(
                                'Swipe up for more tunes',
                                style: TextStyle(
                                  fontFamily: 'monospace',
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    Positioned(
                      right: 0,
                      bottom: 92,
                      child: Column(
                        children: [
                          _buildActionButton(
                            icon: _isMuted ? Icons.volume_off : Icons.volume_up,
                            color: _isMuted ? Colors.redAccent : textColor,
                            onTap: _toggleMute,
                          ),
                          const SizedBox(height: 16),
                          _buildActionButton(
                            onTap: () {},
                            color: Colors.transparent,
                            child: HeartLikeButton(
                              isLiked: isLiked,
                              onTap: () => widget.onLikeToggle(song),
                              iconColor: textColor,
                              activeColor: Colors.redAccent,
                              size: 24,
                            ),
                          ),
                          const SizedBox(height: 16),
                          _buildActionButton(
                            icon: _isPlaying ? Icons.pause : Icons.play_arrow,
                            color: textColor,
                            onTap: _togglePlayPause,
                          ),
                          const SizedBox(height: 16),
                          _buildActionButton(
                            child: Center(
                              child: Text(
                                _preferFullTracks ? 'JMD' : 'iTunes',
                                style: TextStyle(
                                  fontFamily: 'monospace',
                                  fontSize: 8.5,
                                  fontWeight: FontWeight.bold,
                                  color: _preferFullTracks
                                      ? Colors.green
                                      : Colors.orange,
                                ),
                              ),
                            ),
                            color: _preferFullTracks
                                ? Colors.green
                                : Colors.orange,
                            onTap: () {
                              setState(() {
                                _preferFullTracks = !_preferFullTracks;
                              });
                              // Re-fetch from the correct source so metadata always matches audio
                              _fetchSongs();
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    _preferFullTracks
                                        ? 'Switching to Jamendo — full tracks, correct metadata'
                                        : 'Switching to iTunes — 30s previews, correct metadata',
                                    style: const TextStyle(
                                      fontFamily: 'monospace',
                                    ),
                                  ),
                                  duration: const Duration(seconds: 2),
                                ),
                              );
                            },
                          ),
                          const SizedBox(height: 16),
                          _buildActionButton(
                            icon: Icons.refresh,
                            color: textColor,
                            onTap: () {
                              _fetchSongs();
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: const Text(
                                    'Refreshing and loading new songs...',
                                    style: TextStyle(fontFamily: 'monospace'),
                                  ),
                                  duration: Duration(seconds: 1),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),

                    Positioned(
                      right: 0,
                      bottom: 28,
                      child: _buildActionButton(
                        icon: Icons.tune,
                        color: textColor,
                        onTap: _showSoundPresetOptions,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildRecordDisc(String imageUrl, bool isDark, double size) {
    final frameColor = isDark
        ? const Color(0xFFFAF6EE)
        : const Color(0xFF18181A);
    final centerImageSize = size * 0.4;

    return RotatingVinyl(
      isPlaying: _isPlaying,
      size: size,
      rotationSpeedSeconds: 8.0,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: const Color(0xFF0F0F10),
          shape: BoxShape.circle,
          border: Border.all(color: frameColor, width: 3.5),
          boxShadow: [
            BoxShadow(
              color: frameColor.withValues(alpha: 0.3),
              offset: const Offset(4, 4),
              blurRadius: 0,
            ),
          ],
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            CustomPaint(
              size: Size(size, size),
              painter: VinylGroovesPainter(
                lineColor: isDark ? Colors.white54 : Colors.grey,
              ),
            ),
            ClipOval(
              child: SizedBox(
                width: centerImageSize,
                height: centerImageSize,
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  transitionBuilder: (child, animation) {
                    final scaleAnimation = Tween<double>(begin: 0.95, end: 1.0)
                        .animate(
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
                  child: imageUrl.isNotEmpty
                      ? Image.network(
                          imageUrl,
                          key: ValueKey<String>(imageUrl),
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) =>
                              Container(
                                key: const ValueKey<String>('error'),
                                color: Colors.grey,
                                child: const Icon(
                                  Icons.music_note,
                                  color: Colors.white,
                                ),
                              ),
                        )
                      : Container(
                          key: const ValueKey<String>('empty'),
                          color: Colors.grey,
                          child: const Icon(
                            Icons.music_note,
                            color: Colors.white,
                          ),
                        ),
                ),
              ),
            ),
            Container(
              width: size * 0.07,
              height: size * 0.07,
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFF18181B)
                    : const Color(0xFFFAF6EE),
                shape: BoxShape.circle,
                border: Border.all(color: frameColor, width: 2),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSeekBar(bool isDark, Color textColor) {
    return StreamBuilder<Duration>(
      stream: widget.audioPlayer.positionStream,
      builder: (context, snapshot) {
        final position = snapshot.data ?? Duration.zero;
        return StreamBuilder<Duration?>(
          stream: widget.audioPlayer.durationStream,
          builder: (context, snapshotDuration) {
            final duration = snapshotDuration.data ?? Duration.zero;
            return Row(
              children: [
                Text(
                  _formatDuration(position),
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
                      value: position.inSeconds.toDouble(),
                      max: duration.inSeconds.toDouble(),
                      activeColor: isDark
                          ? const Color(0xFFFAF6EE)
                          : const Color(0xFF18181A),
                      inactiveColor: isDark ? Colors.white24 : Colors.black12,
                      trackHeight: 4.0,
                      normalThumbRadius: 7.0,
                      activeThumbRadius: 11.0,
                      onChanged: (val) {
                        widget.audioPlayer.seek(Duration(seconds: val.toInt()));
                      },
                    ),
                  ),
                ),
                Text(
                  _formatDuration(duration),
                  style: TextStyle(
                    fontFamily: 'monospace',
                    color: textColor,
                    fontSize: 11.5,
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildActionButton({
    IconData? icon,
    Widget? child,
    required Color color,
    required VoidCallback onTap,
  }) {
    return TactileButton(
      onTap: onTap,
      backgroundColor: Colors.white,
      borderWidth: 1.5,
      borderRadius: BorderRadius.circular(10),
      padding: const EdgeInsets.all(8),
      shadowOffset: const Offset(2, 2),
      child: SizedBox(
        width: 24,
        height: 24,
        child: child ?? Icon(icon!, color: color, size: 24),
      ),
    );
  }
}
