import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_volume_controller/flutter_volume_controller.dart';
import 'package:flutter/foundation.dart';
import 'package:on_audio_query/on_audio_query.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/services.dart';

import '../main.dart';
import '../widgets/ambient_background.dart';
import '../widgets/sketchy_container.dart';
import '../widgets/song_tile.dart';
import '../widgets/permission_denied_view.dart';
import '../widgets/mini_player.dart';
import '../widgets/playlist_dialog.dart';
import 'music_reels_screen.dart';
import '../widgets/animation_widgets.dart';
import 'full_player_screen.dart';

class CustomPlaylist {
  final String name;
  final List<int> songIds;

  CustomPlaylist({required this.name, required this.songIds});

  Map<String, dynamic> toJson() => {'name': name, 'songIds': songIds};

  factory CustomPlaylist.fromJson(Map<String, dynamic> json) {
    return CustomPlaylist(
      name: json['name'] as String,
      songIds: List<int>.from(json['songIds'] as List),
    );
  }
}

enum AudioCategory { music, recording, other }

class MusicPlayerPage extends StatefulWidget {
  const MusicPlayerPage({super.key});

  @override
  State<MusicPlayerPage> createState() => _MusicPlayerPageState();
}

class _MusicPlayerPageState extends State<MusicPlayerPage>
    with WidgetsBindingObserver {
  final OnAudioQuery _audioQuery = OnAudioQuery();
  final AudioPlayer _audioPlayer = AudioPlayer();

  List<SongModel> _songs = [];
  int _currentSongIndex = -1;
  bool _isPlaying = false;
  bool _isLoading = false;
  bool _permissionDenied = false;
  bool _isDemoMode = false;

  Duration _currentPosition = Duration.zero;
  Duration _totalDuration = Duration.zero;

  // Stream Subscriptions
  StreamSubscription? _playerStateSub;
  StreamSubscription? _positionSub;
  StreamSubscription? _durationSub;
  String _paperStyle = 'Grid';
  String _rotationSpeed = 'Vibe';
  String _soundPreset = 'Cassette (Lo-Fi)';

  // Mode Selection: Offline vs Online (Reels)
  bool _isOnlineMode = false;
  bool _hasSelectedMode = false;
  final List<String> _selectedGenres = [
    'English Pop',
    'Bollywood',
    'Lo-Fi / Chill',
  ];
  final List<String> _availableGenres = [
    'Bollywood',
    'Hindi Indie',
    'Punjabi',
    'English Pop',
    'English Rock',
    'Hip-Hop / Rap',
    'EDM / Dance',
    'K-Pop',
    'Lo-Fi / Chill',
    'Latin',
    'Jazz',
    'Classical',
  ];

  // Bottom Navigation & Tabs
  int _currentTab = 0; // 0 = Home/Reels, 1 = Playlists, 2 = Settings
  String _selectedCategory = 'Music';

  // Search state
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = "";

  // Playlists & Highlight Color Customization
  // Playlists & Highlight Color Customization
  List<Map<String, dynamic>> _reelsSongs = [];
  int _reelsCurrentIndex = 0;

  List<CustomPlaylist> _playlists = [];
  List<SongModel> _onlineLikedSongs = [];
  String? _activePlaylistName;
  Color _highlightColor = const Color(0xFFFFE38A);
  String _highlightColorName = 'Yellow';

  final List<SongModel> _demoSongs = [
    SongModel({
      '_id': 999901,
      'title': 'Synthwave Dreams',
      'artist': 'SoundHelix',
      'album': 'SoundHelix Vol. 1',
      'duration': 372000,
      'uri': 'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-1.mp3',
      '_uri': 'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-1.mp3',
      'data': 'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-1.mp3',
      '_data': 'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-1.mp3',
    }),
    SongModel({
      '_id': 999902,
      'title': 'Cyber Ambient',
      'artist': 'SoundHelix',
      'album': 'SoundHelix Vol. 2',
      'duration': 423000,
      'uri': 'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-2.mp3',
      '_uri': 'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-2.mp3',
      'data': 'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-2.mp3',
      '_data': 'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-2.mp3',
    }),
    SongModel({
      '_id': 999903,
      'title': 'Acoustic Chill',
      'artist': 'SoundHelix',
      'album': 'SoundHelix Vol. 3',
      'duration': 344000,
      'uri': 'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-3.mp3',
      '_uri': 'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-3.mp3',
      'data': 'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-3.mp3',
      '_data': 'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-3.mp3',
    }),
    SongModel({
      '_id': 999904,
      'title': 'Sunset Groove',
      'artist': 'SoundHelix',
      'album': 'SoundHelix Vol. 4',
      'duration': 502000,
      'uri': 'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-4.mp3',
      '_uri': 'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-4.mp3',
      'data': 'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-4.mp3',
      '_data': 'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-4.mp3',
    }),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _setupAudioListeners();
    _loadPlaylists();
    _loadHighlightColor();
    _loadThemeMode();
    _loadSettings();

    _loadOnlineLikedSongs();

    // ponytail: pip overlay removed — notification controls handle play/pause
  }

  // System volume listener removed since navbar is static

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _paperStyle = prefs.getString('settings_paper_style') ?? 'Grid';
      _rotationSpeed = prefs.getString('settings_rotation_speed') ?? 'Vibe';
      _soundPreset =
          prefs.getString('settings_sound_preset') ?? 'Cassette (Lo-Fi)';
    });
  }

  Future<void> _savePaperStyle(String style) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('settings_paper_style', style);
    setState(() {
      _paperStyle = style;
    });
  }

  Future<void> _saveRotationSpeed(String speed) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('settings_rotation_speed', speed);
    setState(() {
      _rotationSpeed = speed;
    });
  }

  Future<void> _saveSoundPreset(String preset) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('settings_sound_preset', preset);
    setState(() {
      _soundPreset = preset;
    });
  }

  @override
  void dispose() {
    _playerStateSub?.cancel();
    _positionSub?.cancel();
    _durationSub?.cancel();
    _sequenceSub?.cancel();
    if (!kIsWeb) {
      try {
        FlutterVolumeController.removeListener();
      } catch (e) {
        debugPrint('Error removing volume listener: $e');
      }
    }
    _audioPlayer.dispose();
    _searchController.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  bool _supportsNativeAudioQuery() {
    if (kIsWeb) return false;
    return defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS;
  }

  void _loadDemoSongs() {
    setState(() {
      _songs = List.from(_demoSongs);
      _songs.addAll(_onlineLikedSongs);
      _isDemoMode = true;
      _isLoading = false;
      _permissionDenied = false;
    });
  }

  Future<void> _requestPermissionAndScan() async {
    if (!_supportsNativeAudioQuery()) {
      _loadDemoSongs();
      return;
    }

    setState(() {
      _isLoading = true;
      _permissionDenied = false;
    });

    var status = await Permission.audio.request();

    if (!status.isGranted) {
      status = await Permission.storage.request();
    }

    if (status.isGranted) {
      _scanSongs();
    } else {
      setState(() {
        _permissionDenied = true;
        _isLoading = false;
      });
    }
  }

  void _scanSongs() async {
    try {
      final songs = await _audioQuery.querySongs(
        sortType: SongSortType.TITLE,
        orderType: OrderType.ASC_OR_SMALLER,
        uriType: UriType.EXTERNAL,
        ignoreCase: true,
      );

      setState(() {
        if (songs.isEmpty) {
          _songs = List.from(_demoSongs);
        } else {
          _songs = List.from(songs);
        }
        _songs.addAll(_onlineLikedSongs);
        _isDemoMode = false;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _songs = List.from(_demoSongs);
        _songs.addAll(_onlineLikedSongs);
        _isDemoMode = true;
        _isLoading = false;
      });
    }
  }

  StreamSubscription? _sequenceSub;

  void _setupAudioListeners() {
    _positionSub = _audioPlayer.positionStream.listen((position) {
      if (!mounted) return;
      setState(() {
        _currentPosition = position;
      });
    });

    _durationSub = _audioPlayer.durationStream.listen((duration) {
      if (!mounted) return;
      setState(() {
        _totalDuration = duration ?? Duration.zero;
      });
    });

    _playerStateSub = _audioPlayer.playerStateStream.listen((state) {
      if (!mounted) return;
      setState(() {
        _isPlaying = state.playing;
      });
    });

    // Volume listener removed

    _sequenceSub = _audioPlayer.sequenceStateStream.listen((seq) {
      if (!mounted) return;
      if (seq != null) {
        final newIndex = seq.currentIndex;
        if (newIndex != _currentSongIndex &&
            newIndex >= 0 &&
            newIndex < _songs.length) {
          setState(() {
            _currentSongIndex = newIndex;
          });
        }
      }
    });
  }

  // Playlists persistence
  Future<void> _loadPlaylists() async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList('custom_playlists');
    if (list != null) {
      setState(() {
        _playlists = list
            .map(
              (str) => CustomPlaylist.fromJson(
                jsonDecode(str) as Map<String, dynamic>,
              ),
            )
            .toList();
      });
    }
  }

  Future<void> _savePlaylists() async {
    final prefs = await SharedPreferences.getInstance();
    final list = _playlists.map((pl) => jsonEncode(pl.toJson())).toList();
    await prefs.setStringList('custom_playlists', list);
  }

  // Online liked tracks serialization
  Future<void> _loadOnlineLikedSongs() async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList('online_liked_songs');
    if (list != null) {
      final parsed = list.map((item) {
        final Map<String, dynamic> map = jsonDecode(item);
        return SongModel(map);
      }).toList();
      setState(() {
        _onlineLikedSongs = parsed;
      });
    }
  }

  Future<void> _saveOnlineLikedSongs() async {
    final prefs = await SharedPreferences.getInstance();
    final list = _onlineLikedSongs
        .map((song) => jsonEncode(song.getMap))
        .toList();
    await prefs.setStringList('online_liked_songs', list);
  }

  void _toggleLikeOnlineSong(Map<String, dynamic> track) {
    final trackId = track['id'] as int;
    final index = _onlineLikedSongs.indexWhere((s) => s.id == trackId);

    setState(() {
      if (index != -1) {
        _onlineLikedSongs.removeAt(index);
        _songs.removeWhere((s) => s.id == trackId);

        final plIndex = _playlists.indexWhere((p) => p.name == 'Liked Online');
        if (plIndex != -1) {
          _playlists[plIndex].songIds.remove(trackId);
          _savePlaylists();
        }
        _saveOnlineLikedSongs();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Removed from Liked Online',
              style: TextStyle(fontFamily: 'monospace'),
            ),
            backgroundColor: Color(0xFFFFD1D1),
          ),
        );
      } else {
        final newSong = SongModel({
          '_id': trackId,
          'title': track['title'],
          'artist': track['artist'],
          'album': track['album'],
          'duration': track['duration'] as int? ?? 30000,
          'uri': track['previewUrl'],
          '_uri': track['previewUrl'],
          'data': track['previewUrl'],
          '_data': track['previewUrl'],
        });

        _onlineLikedSongs.add(newSong);
        _songs.add(newSong);
        _saveOnlineLikedSongs();

        int plIndex = _playlists.indexWhere((p) => p.name == 'Liked Online');
        if (plIndex == -1) {
          _playlists.add(CustomPlaylist(name: 'Liked Online', songIds: []));
          plIndex = _playlists.length - 1;
        }
        if (!_playlists[plIndex].songIds.contains(trackId)) {
          _playlists[plIndex].songIds.add(trackId);
          _playlists = List.from(_playlists);
          _savePlaylists();
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              'Saved to Liked Online playlist!',
              style: TextStyle(
                fontFamily: 'monospace',
                color: Color(0xFF18181A),
              ),
            ),
            backgroundColor: _highlightColor,
          ),
        );
      }
    });
  }

  bool _isOnlineSongLiked(int trackId) {
    return _onlineLikedSongs.any((s) => s.id == trackId);
  }

  // Theme mode persistence
  Future<void> _loadThemeMode() async {
    final prefs = await SharedPreferences.getInstance();
    final isDark = prefs.getBool('is_dark_mode') ?? false;
    themeNotifier.value = isDark ? ThemeMode.dark : ThemeMode.light;
  }

  Future<void> _toggleTheme(bool isDark) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('is_dark_mode', isDark);
    themeNotifier.value = isDark ? ThemeMode.dark : ThemeMode.light;
  }

  // Accent highlight customizer persistence
  Future<void> _loadHighlightColor() async {
    final prefs = await SharedPreferences.getInstance();
    final name = prefs.getString('highlight_color_name') ?? 'Yellow';
    setState(() {
      _highlightColorName = name;
      _highlightColor = _getColorFromName(name);
    });
  }

  Future<void> _saveHighlightColor(String name) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('highlight_color_name', name);
    setState(() {
      _highlightColorName = name;
      _highlightColor = _getColorFromName(name);
    });
  }

  Color _getColorFromName(String name) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    switch (name) {
      case 'Yellow':
        return isDark ? const Color(0xFFFFE29D) : const Color(0xFFFFE38A);
      case 'Purple':
        return isDark ? const Color(0xFFDCC5FF) : const Color(0xFFDCC5FF);
      case 'Blue':
        return isDark ? const Color(0xFF90B6FF) : const Color(0xFF7DA9FF);
      case 'Green':
        return isDark ? const Color(0xFFB4EFA4) : const Color(0xFFA8E6A3);
      case 'Orange':
        return isDark ? const Color(0xFFFFD1A9) : const Color(0xFFFFCC99);
      case 'Pink':
        return isDark ? const Color(0xFFFFC6E5) : const Color(0xFFFFB3D9);
      case 'Teal':
        return isDark ? const Color(0xFFAEF7ED) : const Color(0xFF99F5E9);
      case 'Lime':
        return isDark ? const Color(0xFFE9FA9D) : const Color(0xFFE2F784);
      case 'Red':
        return isDark ? const Color(0xFFFFB3B3) : const Color(0xFFFF9999);
      case 'Indigo':
        return isDark ? const Color(0xFFB8C5FF) : const Color(0xFFA3B3FF);
      default:
        return isDark ? const Color(0xFFFFE29D) : const Color(0xFFFFE38A);
    }
  }

  void _addSongToPlaylist(int songId, String playlistName) {
    setState(() {
      final index = _playlists.indexWhere((p) => p.name == playlistName);
      if (index != -1) {
        final playlist = _playlists[index];
        if (!playlist.songIds.contains(songId)) {
          playlist.songIds.add(songId);
          _playlists = List.from(_playlists);
          _savePlaylists();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Added to ${playlist.name}',
                style: const TextStyle(
                  fontFamily: 'monospace',
                  color: Color(0xFF18181A),
                ),
              ),
              backgroundColor: _highlightColor,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Song already in playlist!',
                style: TextStyle(fontFamily: 'monospace'),
              ),
              backgroundColor: Color(0xFFFFD1D1),
            ),
          );
        }
      }
    });
  }

  void _removeSongFromPlaylist(int songId, String playlistName) {
    setState(() {
      final index = _playlists.indexWhere((p) => p.name == playlistName);
      if (index != -1) {
        _playlists[index].songIds.remove(songId);
        _playlists = List.from(_playlists);
        _savePlaylists();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Removed from $playlistName',
              style: const TextStyle(fontFamily: 'monospace'),
            ),
            backgroundColor: const Color(0xFFFFD1D1),
          ),
        );
      }
    });
  }

  void _deletePlaylist(String name) {
    setState(() {
      _playlists.removeWhere((p) => p.name == name);
      _playlists = List.from(_playlists);
      if (_activePlaylistName == name) {
        _activePlaylistName = null;
      }
      _savePlaylists();
    });
  }

  Future<void> _showCreatePlaylistDialog() async {
    final name = await showDialog<String>(
      context: context,
      builder: (context) => const PlaylistDialog(),
    );

    if (name != null && name.isNotEmpty) {
      if (_playlists.any((p) => p.name.toLowerCase() == name.toLowerCase())) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Playlist already exists!',
              style: TextStyle(fontFamily: 'monospace'),
            ),
            backgroundColor: Colors.redAccent,
          ),
        );
        return;
      } else {
        setState(() {
          _playlists.add(CustomPlaylist(name: name, songIds: []));
          _playlists = List.from(_playlists);
          _savePlaylists();
        });
      }
    }
  }

  void _showAddToPlaylistDialog(SongModel song) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    if (_playlists.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            'No playlists. Create one in the Playlists tab!',
            style: TextStyle(fontFamily: 'monospace', color: Color(0xFF18181A)),
          ),
          backgroundColor: _highlightColor,
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          child: SketchyContainer(
            backgroundColor: isDark
                ? const Color(0xFF26262B)
                : const Color(0xFFFFFDF9),
            padding: const EdgeInsets.all(20.0),
            borderRadius: BorderRadius.circular(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Add to Playlist',
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: isDark
                        ? const Color(0xFFFAF6EE)
                        : const Color(0xFF18181A),
                  ),
                ),
                const SizedBox(height: 12),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 250),
                  child: SingleChildScrollView(
                    child: Column(
                      children: _playlists.map((playlist) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8.0),
                          child: GestureDetector(
                            onTap: () {
                              _addSongToPlaylist(song.id, playlist.name);
                              Navigator.pop(context);
                            },
                            child: SketchyContainer(
                              backgroundColor: isDark
                                  ? const Color(0xFF333338)
                                  : Colors.white,
                              borderWidth: 1.5,
                              borderRadius: BorderRadius.circular(8),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 10,
                              ),
                              shadowOffset: const Offset(2, 2),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.playlist_add,
                                    color: isDark
                                        ? const Color(0xFFFAF6EE)
                                        : const Color(0xFF18181A),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    playlist.name,
                                    style: TextStyle(
                                      fontFamily: 'monospace',
                                      color: isDark
                                          ? const Color(0xFFFAF6EE)
                                          : const Color(0xFF18181A),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  AudioCategory _categorizeSong(SongModel song) {
    if (song.uri != null &&
        (song.uri!.startsWith('http://') || song.uri!.startsWith('https://'))) {
      return AudioCategory.music;
    }

    final path = (song.data).toLowerCase();
    final title = (song.title).toLowerCase();
    final isRecordingPath =
        path.contains('record') ||
        path.contains('call') ||
        title.contains('recording') ||
        title.contains('call rec') ||
        title.contains('voice rec');

    if (isRecordingPath) {
      return AudioCategory.recording;
    } else if (song.isMusic == true) {
      return AudioCategory.music;
    } else {
      return AudioCategory.other;
    }
  }

  List<SongModel> get _filteredSongs {
    if (_currentTab == 0) {
      if (_selectedCategory == 'Music') {
        return _songs
            .where((s) => _categorizeSong(s) == AudioCategory.music)
            .toList();
      } else if (_selectedCategory == 'Recordings') {
        return _songs
            .where((s) => _categorizeSong(s) == AudioCategory.recording)
            .toList();
      } else if (_selectedCategory == 'Other') {
        return _songs
            .where((s) => _categorizeSong(s) == AudioCategory.other)
            .toList();
      }
    } else if (_currentTab == 1) {
      if (_activePlaylistName != null) {
        final playlist = _playlists.firstWhere(
          (p) => p.name == _activePlaylistName,
          orElse: () => CustomPlaylist(name: '', songIds: []),
        );
        return _songs.where((s) => playlist.songIds.contains(s.id)).toList();
      }
    }
    return [];
  }

  List<SongModel> _getSearchedSongs(List<SongModel> list) {
    if (_searchQuery.isEmpty) return list;
    final query = _searchQuery.toLowerCase();
    return list.where((song) {
      final titleMatch = song.title.toLowerCase().contains(query);
      final artistMatch = (song.artist ?? '').toLowerCase().contains(query);
      return titleMatch || artistMatch;
    }).toList();
  }

  Future<void> _playSong(int index, List<SongModel> list) async {
    try {
      if (list.isEmpty) return;

      bool needsRebuild = _songs.length != list.length;
      if (!needsRebuild) {
        for (int i = 0; i < list.length; i++) {
          if (_songs[i].id != list[i].id) {
            needsRebuild = true;
            break;
          }
        }
      }

      _songs = list;
      _currentSongIndex = index;

      if (needsRebuild ||
          _audioPlayer.audioSource == null ||
          _audioPlayer.audioSource is! ConcatenatingAudioSource) {
        final playlistSources = list.map((s) {
          String sSource = '';
          if (s.uri != null && s.uri!.isNotEmpty) {
            sSource = s.uri!;
          } else if (s.data.isNotEmpty) {
            sSource = s.data;
          } else {
            sSource = 'content://media/external/audio/media/${s.id}';
          }

          final sMediaItem = MediaItem(
            id: s.id.toString(),
            album: s.album ?? 'Unknown Album',
            title: s.title,
            artist: s.artist ?? 'Unknown Artist',
          );

          if (sSource.startsWith('content://') ||
              sSource.startsWith('http://') ||
              sSource.startsWith('https://')) {
            return AudioSource.uri(Uri.parse(sSource), tag: sMediaItem);
          } else {
            return AudioSource.uri(Uri.file(sSource), tag: sMediaItem);
          }
        }).toList();

        final queue = ConcatenatingAudioSource(children: playlistSources);
        await _audioPlayer.setAudioSource(queue, initialIndex: index);
      } else {
        if (_audioPlayer.currentIndex != index) {
          await _audioPlayer.seek(Duration.zero, index: index);
        }
      }

      _audioPlayer.play();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Error playing song: ${e.toString()}',
            style: const TextStyle(fontFamily: 'monospace'),
          ),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  void _togglePlay() {
    final list = _getSearchedSongs(_filteredSongs);
    if (_currentSongIndex == -1 && list.isNotEmpty) {
      _playSong(0, list);
    } else {
      if (_isPlaying) {
        _audioPlayer.pause();
      } else {
        _audioPlayer.play();
      }
    }
  }

  void _playNext() {
    if (_audioPlayer.hasNext) {
      _audioPlayer.seekToNext();
    } else if (_songs.isNotEmpty) {
      _audioPlayer.seek(Duration.zero, index: 0);
    }
  }

  void _playPrevious() {
    if (_audioPlayer.hasPrevious) {
      _audioPlayer.seekToPrevious();
    } else if (_songs.isNotEmpty) {
      _audioPlayer.seek(Duration.zero, index: _songs.length - 1);
    }
  }

  void _seek(double seconds) {
    _audioPlayer.seek(Duration(seconds: seconds.toInt()));
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Detect Android Picture-in-Picture window constraint
    final size = MediaQuery.of(context).size;
    final isPip = size.height < 300.0;

    if (isPip) {
      return Scaffold(
        backgroundColor: Colors.transparent,
        body: Center(
          child: StreamBuilder<SequenceState?>(
            stream: _audioPlayer.sequenceStateStream,
            builder: (context, seqSnapshot) {
              final seq = seqSnapshot.data;
              if (seq == null || seq.currentSource == null) {
                return const Center(
                  child: Text(
                    "PaperWave",
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                );
              }
              final mediaItem = seq.currentSource!.tag as MediaItem?;
              if (mediaItem == null) return const SizedBox.shrink();

              return StreamBuilder<bool>(
                stream: _audioPlayer.playingStream,
                builder: (context, playingSnapshot) {
                  final isPlaying = playingSnapshot.data ?? false;
                  return DynamicIslandWidget(
                    mediaItem: mediaItem,
                    isPlaying: isPlaying,
                    audioPlayer: _audioPlayer,
                    isDark: isDark,
                    highlightColor: _highlightColor,
                    isPipMode: true,
                    isLiked: _isOnlineSongLiked(
                      int.tryParse(mediaItem.id) ?? -1,
                    ),
                    onTapSong: _redirectToPlayingSong,
                    onLikeToggle: () {
                      final idVal = int.tryParse(mediaItem.id) ?? -1;
                      final matchIndex = _reelsSongs.indexWhere(
                        (s) => s['id'] == idVal,
                      );
                      if (matchIndex != -1) {
                        _toggleLikeOnlineSong(_reelsSongs[matchIndex]);
                      } else {
                        _toggleLikeOnlineSong({
                          'id': idVal,
                          'title': mediaItem.title,
                          'artist': mediaItem.artist ?? 'Unknown Artist',
                          'album': mediaItem.album ?? 'Unknown Album',
                          'previewUrl':
                              _audioPlayer.audioSource is UriAudioSource
                              ? (_audioPlayer.audioSource as UriAudioSource).uri
                                    .toString()
                              : '',
                        });
                      }
                    },
                  );
                },
              );
            },
          ),
        ),
      );
    }

    if (!_hasSelectedMode) {
      return Scaffold(
        backgroundColor: isDark
            ? const Color(0xFF1B1C1E)
            : const Color(0xFFFAF6EE),
        body: Stack(
          children: [
            AmbientBackground(style: _paperStyle),
            SafeArea(child: _buildLandingPortal()),

            // Dynamic Island on Logo Page
            Positioned(
              top: 76.0,
              left: 0,
              right: 0,
              child: Center(child: _buildDynamicIslandOverlay()),
            ),
          ],
        ),
      );
    }

    final showImmersiveReels = _isOnlineMode && _currentTab == 0;

    if (showImmersiveReels) {
      return Scaffold(
        backgroundColor: isDark
            ? const Color(0xFF1B1C1E)
            : const Color(0xFFFAF6EE),
        body: Stack(
          children: [
            AmbientBackground(style: _paperStyle),
            SafeArea(
              child: Column(
                children: [
                  Expanded(child: _buildBody()),
                  _buildBottomNavigationBar(),
                ],
              ),
            ),
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: SafeArea(bottom: false, child: _buildHeader()),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      backgroundColor: isDark
          ? const Color(0xFF1B1C1E)
          : const Color(0xFFFAF6EE),
      body: Stack(
        children: [
          AmbientBackground(style: _paperStyle),
          SafeArea(
            child: Column(
              children: [
                _buildHeader(),
                Expanded(child: _buildBody()),
                _buildBottomNavigationBar(),
              ],
            ),
          ),

          // Dynamic Island overlay
          Positioned(
            top: 76.0,
            left: 0,
            right: 0,
            child: Center(child: _buildDynamicIslandOverlay()),
          ),
        ],
      ),
    );
  }

  Widget _buildDynamicIslandOverlay() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return StreamBuilder<SequenceState?>(
      stream: _audioPlayer.sequenceStateStream,
      builder: (context, seqSnapshot) {
        final seq = seqSnapshot.data;
        if (seq == null || seq.currentSource == null) {
          return const SizedBox.shrink();
        }
        final mediaItem = seq.currentSource!.tag as MediaItem?;
        if (mediaItem == null) {
          return const SizedBox.shrink();
        }

        return StreamBuilder<bool>(
          stream: _audioPlayer.playingStream,
          builder: (context, playingSnapshot) {
            final isPlaying = playingSnapshot.data ?? false;
            return DynamicIslandWidget(
              mediaItem: mediaItem,
              isPlaying: isPlaying,
              audioPlayer: _audioPlayer,
              isDark: isDark,
              highlightColor: _highlightColor,
              isLiked: _isOnlineSongLiked(int.tryParse(mediaItem.id) ?? -1),
              onTapSong: _redirectToPlayingSong,
              onLikeToggle: () {
                final idVal = int.tryParse(mediaItem.id) ?? -1;
                final matchIndex = _reelsSongs.indexWhere(
                  (s) => s['id'] == idVal,
                );
                if (matchIndex != -1) {
                  _toggleLikeOnlineSong(_reelsSongs[matchIndex]);
                } else {
                  _toggleLikeOnlineSong({
                    'id': idVal,
                    'title': mediaItem.title,
                    'artist': mediaItem.artist ?? 'Unknown Artist',
                    'album': mediaItem.album ?? 'Unknown Album',
                    'previewUrl': _audioPlayer.audioSource is UriAudioSource
                        ? (_audioPlayer.audioSource as UriAudioSource).uri
                              .toString()
                        : '',
                  });
                }
              },
            );
          },
        );
      },
    );
  }

  void _closeMiniPlayer() {
    setState(() {
      _audioPlayer.stop();
      _currentSongIndex = -1;
    });
  }

  void _redirectToPlayingSong() {
    final seq = _audioPlayer.sequenceState;
    if (seq == null || seq.currentSource == null) return;
    final mediaItem = seq.currentSource!.tag as MediaItem?;
    if (mediaItem == null) return;

    final idVal = int.tryParse(mediaItem.id);
    if (idVal == null) return;

    final isOnlineSong =
        _reelsSongs.any((s) => s['id'] == idVal) ||
        mediaItem.album == 'iTunes' ||
        mediaItem.album == 'Jamendo';

    setState(() {
      _hasSelectedMode = true;
      _currentTab = 0; // Go to Reels/Home tab
      if (isOnlineSong) {
        _isOnlineMode = true;
        final targetIndex = _reelsSongs.indexWhere((s) => s['id'] == idVal);
        if (targetIndex != -1) {
          _reelsCurrentIndex = targetIndex;
        }
      } else {
        _isOnlineMode = false;
        final targetIndex = _songs.indexWhere((s) => s.id == idVal);
        if (targetIndex != -1) {
          _currentSongIndex = targetIndex;
        }
      }
    });
  }

  void _selectOfflineMode() {
    setState(() {
      _isOnlineMode = false;
      _hasSelectedMode = true;
    });
    if (_supportsNativeAudioQuery()) {
      _requestPermissionAndScan();
    } else {
      _loadDemoSongs();
    }
  }

  void _selectOnlineMode() {
    _showGenreSelectionDialog();
  }

  void _showGenreSelectionDialog() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark
        ? const Color(0xFFFAF6EE)
        : const Color(0xFF18181A);

    showGeneralDialog(
      context: context,
      barrierDismissible: false,
      barrierLabel: 'Genre Selection',
      barrierColor: Colors.black.withValues(alpha: 0.40),
      transitionDuration: const Duration(milliseconds: 250),
      pageBuilder: (context, animation, secondaryAnimation) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Dialog(
              backgroundColor: Colors.transparent,
              child: SketchyContainer(
                backgroundColor: isDark
                    ? const Color(0xFF26262B)
                    : const Color(0xFFFFFDF9),
                padding: const EdgeInsets.all(24.0),
                borderRadius: BorderRadius.circular(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Online Music Flavors',
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: textColor,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Select one or more genres to stream:',
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 12,
                        color: isDark ? Colors.white60 : Colors.black54,
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      height: 320,
                      child: SingleChildScrollView(
                        child: Column(
                          children: _availableGenres.asMap().entries.map((
                            entry,
                          ) {
                            final index = entry.key;
                            final genre = entry.value;
                            final isSelected = _selectedGenres.contains(genre);
                            return StaggeredCheckboxEntrance(
                              index: index,
                              child: Padding(
                                padding: const EdgeInsets.only(bottom: 12.0),
                                child: _buildGenreCheckbox(
                                  title: genre,
                                  value: isSelected,
                                  textColor: textColor,
                                  onChanged: (val) {
                                    setDialogState(() {
                                      if (val == true) {
                                        if (!_selectedGenres.contains(genre)) {
                                          _selectedGenres.add(genre);
                                        }
                                      } else {
                                        if (_selectedGenres.length > 1) {
                                          _selectedGenres.remove(genre);
                                        }
                                      }
                                    });
                                  },
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    TactileButton(
                      backgroundColor: _highlightColor,
                      borderWidth: 1.5,
                      borderRadius: BorderRadius.circular(10),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shadowOffset: const Offset(2, 2),
                      onTap: () {
                        HapticFeedback.mediumImpact();
                        Navigator.pop(context);
                        setState(() {
                          _isOnlineMode = true;
                          _hasSelectedMode = true;
                          _currentTab = 0; // Default to Reels
                        });
                      },
                      child: const Center(
                        child: Text(
                          'Tune In!',
                          style: TextStyle(
                            fontFamily: 'monospace',
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF18181A),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        final scale = Tween<double>(begin: 0.9, end: 1.0).animate(
          CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
        );
        return Opacity(
          opacity: animation.value,
          child: Transform.scale(scale: scale.value, child: child),
        );
      },
    );
  }

  Widget _buildGenreCheckbox({
    required String title,
    required bool value,
    required Color textColor,
    required ValueChanged<bool?> onChanged,
  }) {
    return GestureDetector(
      onTap: () => onChanged(!value),
      child: Row(
        children: [
          Container(
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              color: value ? _highlightColor : Colors.transparent,
              border: Border.all(color: textColor, width: 1.5),
              borderRadius: BorderRadius.circular(4),
            ),
            child: value
                ? const Icon(Icons.check, size: 14, color: Color(0xFF18181A))
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 14,
                color: textColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLandingPortal() {
    return LandingPortalWidget(
      onSelectOffline: _selectOfflineMode,
      onSelectOnline: _selectOnlineMode,
      paperStyle: _paperStyle,
    );
  }

  Widget _buildHeader() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark
        ? const Color(0xFFFAF6EE)
        : const Color(0xFF18181A);

    return Padding(
      padding: EdgeInsets.only(
        left: _hasSelectedMode ? 14.0 : 20.0,
        right: _hasSelectedMode ? 14.0 : 20.0,
        top: 20.0,
        bottom: 12.0,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_hasSelectedMode) ...[
                    ScribbledBackButton(
                      color: textColor,
                      onTap: () {
                        setState(() {
                          _hasSelectedMode = false;
                        });
                      },
                    ),
                    const SizedBox(width: 8),
                  ],
                  const SketchyLogo(size: 30),
                  const SizedBox(width: 8),
                  Text(
                    _currentTab == 0
                        ? 'PaperWave'
                        : (_currentTab == 1 ? 'Playlists' : 'Settings'),
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                      color: textColor,
                    ),
                  ),
                ],
              ),
              if (_currentTab == 0 && _isDemoMode && !_isOnlineMode)
                Padding(
                  padding: const EdgeInsets.only(top: 4.0),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: _highlightColor,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: const Color(0xFF18181A),
                        width: 1.5,
                      ),
                    ),
                    child: const Text(
                      'DEMO MODE (ONLINE)',
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF18181A),
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          if (_currentTab == 0) Row(children: [_buildModeToggle(isDark)]),
        ],
      ),
    );
  }

  Widget _buildModeToggle(bool isDark) {
    final textColor = isDark
        ? const Color(0xFFFAF6EE)
        : const Color(0xFF222222);
    final activeBg = _highlightColor;
    const double width = 132.0;
    const double height = 36.0;

    return GestureDetector(
      onTap: () async {
        _audioPlayer.stop();
        setState(() {
          _isOnlineMode = !_isOnlineMode;
          _currentSongIndex = -1;
        });
      },
      child: SketchyContainer(
        width: width,
        height: height,
        backgroundColor: isDark ? const Color(0xFF26262B) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        borderWidth: 1.8,
        shadowOffset: const Offset(1.5, 1.5),
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Padding(
                  padding: const EdgeInsets.only(left: 8.0),
                  child: Text(
                    'OFF',
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: !_isOnlineMode
                          ? const Color(0xFF222222)
                          : textColor.withValues(alpha: 0.5),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: Text(
                    'ON',
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: _isOnlineMode
                          ? const Color(0xFF222222)
                          : textColor.withValues(alpha: 0.5),
                    ),
                  ),
                ),
              ],
            ),
            AnimatedAlign(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeOutCubic,
              alignment: _isOnlineMode
                  ? Alignment.centerRight
                  : Alignment.centerLeft,
              child: SketchyContainer(
                width: 68,
                height: 28,
                backgroundColor: activeBg,
                borderRadius: BorderRadius.circular(14),
                borderWidth: 1.5,
                shadowOffset: Offset.zero,
                hasPencilShading: true,
                child: Center(
                  child: Text(
                    _isOnlineMode ? 'Online' : 'Offline',
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF222222),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    switch (_currentTab) {
      case 0:
        if (_isOnlineMode) {
          return MusicReelsView(
            audioPlayer: _audioPlayer,
            highlightColor: _highlightColor,
            onLikeToggle: _toggleLikeOnlineSong,
            isLiked: _isOnlineSongLiked,
            rotationSpeed: _rotationSpeed,
            soundPreset: _soundPreset,
            onSoundPresetChanged: (preset) {
              _saveSoundPreset(preset);
            },
            selectedGenres: _selectedGenres,
            onChangeGenres: _showGenreSelectionDialog,
            initialSongs: _reelsSongs,
            initialIndex: _reelsCurrentIndex,
            onSongsFetched: (songs) {
              setState(() {
                _reelsSongs = songs;
              });
            },
            onIndexChanged: (index) {
              setState(() {
                _reelsCurrentIndex = index;
              });
            },
          );
        } else {
          return _buildHomeTab();
        }
      case 1:
        return _buildPlaylistsTab();
      case 2:
        return _buildSettingsTab();
      default:
        return _buildHomeTab();
    }
  }

  // --- TAB 1: HOME ---
  Widget _buildHomeTab() {
    if (_permissionDenied) {
      return PermissionDeniedView(
        onGrantAccess: _requestPermissionAndScan,
        onPlayDemo: _loadDemoSongs,
      );
    }

    if (_isLoading) {
      return const Expanded(child: SkeletonSongList());
    }

    final filtered = _getSearchedSongs(_filteredSongs);

    return Column(
      children: [
        _buildCategorySelector(),
        _buildSearchBar(),
        Expanded(
          child: filtered.isEmpty
              ? _buildEmptyStateView()
              : ListView.builder(
                  itemCount: filtered.length,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  itemBuilder: (context, index) {
                    final song = filtered[index];
                    final isCurrent =
                        _currentSongIndex != -1 &&
                        _songs[_currentSongIndex].id == song.id;

                    return SongTile(
                      song: song,
                      isCurrent: isCurrent,
                      highlightColor: _highlightColor,
                      onTap: () => _playSong(index, filtered),
                      onAddToPlaylist: () => _showAddToPlaylistDialog(song),
                    );
                  },
                ),
        ),
        if (_currentSongIndex != -1)
          MiniPlayer(
            currentSong: _songs[_currentSongIndex],
            isPlaying: _isPlaying,
            currentPosition: _currentPosition,
            totalDuration: _totalDuration,
            onPlayPause: _togglePlay,
            onNext: _playNext,
            onPrevious: _playPrevious,
            onSeek: _seek,
            onClose: _closeMiniPlayer,
            onTapBody: () {
              Navigator.push(
                context,
                PageRouteBuilder(
                  transitionDuration: const Duration(milliseconds: 350),
                  reverseTransitionDuration: const Duration(milliseconds: 350),
                  pageBuilder: (context, animation, secondaryAnimation) =>
                      FullPlayerScreen(
                        audioPlayer: _audioPlayer,
                        paperStyle: _paperStyle,
                        highlightColor: _highlightColor,
                        isLiked: _isOnlineSongLiked,
                        onLikeToggle: _toggleLikeOnlineSong,
                      ),
                  transitionsBuilder:
                      (context, animation, secondaryAnimation, child) {
                        return FadeTransition(opacity: animation, child: child);
                      },
                ),
              );
            },
          ),
      ],
    );
  }

  Widget _buildCategorySelector() {
    final categories = ['Music', 'Recordings', 'Other'];
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF26262B) : Colors.white;
    final textColor = isDark
        ? const Color(0xFFFAF6EE)
        : const Color(0xFF18181A);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: categories.map((category) {
          final isSelected = _selectedCategory == category;

          IconData icon;
          Color badgeColor;
          if (category == 'Music') {
            icon = Icons.music_note_outlined;
            badgeColor = isDark
                ? const Color(0xFF5C5C3D)
                : const Color(0xFFFFF9C4);
          } else if (category == 'Recordings') {
            icon = Icons.mic_none;
            badgeColor = isDark
                ? const Color(0xFF5C2D2D)
                : const Color(0xFFFFD1D1);
          } else {
            icon = Icons.album_outlined;
            badgeColor = isDark
                ? const Color(0xFF2D5C5C)
                : const Color(0xFFC4E8E8);
          }

          return GestureDetector(
            onTap: () {
              setState(() {
                _selectedCategory = category;
              });
            },
            child: SketchyContainer(
              width: 95,
              height: 90,
              backgroundColor: isSelected ? badgeColor : cardBg,
              borderRadius: BorderRadius.circular(16),
              borderWidth: 1.8,
              shadowOffset: isSelected
                  ? const Offset(1.5, 1.5)
                  : const Offset(3.5, 3.5),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: isSelected
                          ? (isDark ? const Color(0xFF18181B) : Colors.white)
                          : badgeColor,
                      shape: BoxShape.circle,
                      border: Border.all(color: textColor, width: 1.5),
                      boxShadow: isSelected
                          ? null
                          : [
                              BoxShadow(
                                color: textColor,
                                offset: const Offset(1, 1),
                                blurRadius: 0,
                              ),
                            ],
                    ),
                    child: Icon(
                      icon,
                      size: 20,
                      color: isSelected ? textColor : const Color(0xFF18181A),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    category,
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 11,
                      fontWeight: isSelected
                          ? FontWeight.bold
                          : FontWeight.normal,
                      color: isSelected
                          ? (isDark
                                ? const Color(0xFFFAF6EE)
                                : const Color(0xFF18181A))
                          : textColor,
                    ),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildSearchBar() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark
        ? const Color(0xFFFAF6EE)
        : const Color(0xFF18181A);
    final hintColor = isDark ? Colors.white38 : Colors.black38;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
      child: SketchyContainer(
        backgroundColor: isDark ? const Color(0xFF333338) : Colors.white,
        borderWidth: 1.8,
        borderRadius: BorderRadius.circular(12),
        padding: const EdgeInsets.symmetric(horizontal: 12.0),
        shadowOffset: const Offset(2, 2),
        child: Row(
          children: [
            Icon(Icons.search, color: textColor, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: _searchController,
                style: TextStyle(
                  fontFamily: 'monospace',
                  color: textColor,
                  fontSize: 13,
                ),
                decoration: InputDecoration(
                  hintText: 'Search songs or artists...',
                  hintStyle: TextStyle(
                    fontFamily: 'monospace',
                    color: hintColor,
                    fontSize: 13,
                  ),
                  border: InputBorder.none,
                ),
                onChanged: (value) {
                  setState(() {
                    _searchQuery = value.trim();
                  });
                },
              ),
            ),
            if (_searchQuery.isNotEmpty)
              GestureDetector(
                onTap: () {
                  _searchController.clear();
                  setState(() {
                    _searchQuery = "";
                  });
                },
                child: Icon(Icons.clear, color: textColor, size: 18),
              ),
          ],
        ),
      ),
    );
  }

  // --- TAB 2: PLAYLISTS ---
  Widget _buildPlaylistsTab() {
    if (_activePlaylistName == null) {
      return _buildPlaylistsListView();
    } else {
      return _buildPlaylistDetailsView();
    }
  }

  Widget _buildPlaylistsListView() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark
        ? const Color(0xFFFAF6EE)
        : const Color(0xFF18181A);

    return Column(
      children: [
        GestureDetector(
          onTap: _showCreatePlaylistDialog,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 16.0,
              vertical: 8.0,
            ),
            child: SketchyContainer(
              backgroundColor: isDark ? const Color(0xFF333338) : Colors.white,
              borderRadius: BorderRadius.circular(12),
              borderWidth: 1.8,
              padding: const EdgeInsets.symmetric(vertical: 14.0),
              shadowOffset: const Offset(3, 3),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.add_circle_outline, color: textColor),
                  const SizedBox(width: 8),
                  Text(
                    'Create New Playlist',
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontWeight: FontWeight.bold,
                      color: textColor,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        Expanded(
          child: _playlists.isEmpty
              ? Center(
                  child: Text(
                    'No Playlists Yet',
                    style: TextStyle(
                      fontFamily: 'monospace',
                      color: isDark ? Colors.white60 : Colors.black54,
                    ),
                  ),
                )
              : ListView.builder(
                  itemCount: _playlists.length,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  itemBuilder: (context, index) {
                    final playlist = _playlists[index];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12.0),
                      child: SketchyContainer(
                        backgroundColor: isDark
                            ? const Color(0xFF333338)
                            : Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        borderWidth: 1.8,
                        shadowOffset: const Offset(3, 3),
                        child: ListTile(
                          title: Text(
                            playlist.name,
                            style: TextStyle(
                              fontFamily: 'monospace',
                              fontWeight: FontWeight.bold,
                              color: textColor,
                            ),
                          ),
                          subtitle: Text(
                            '${playlist.songIds.length} songs',
                            style: TextStyle(
                              fontFamily: 'monospace',
                              color: isDark ? Colors.white60 : Colors.black54,
                            ),
                          ),
                          leading: Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: isDark
                                  ? const Color(0xFF3B5C3B)
                                  : const Color(0xFFD1F3D1),
                              border: Border.all(color: textColor, width: 1.5),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(Icons.playlist_play, color: textColor),
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: Icon(
                                  Icons.play_circle_outline,
                                  color: textColor,
                                ),
                                onPressed: () {
                                  final plSongs = _songs
                                      .where(
                                        (s) => playlist.songIds.contains(s.id),
                                      )
                                      .toList();
                                  if (plSongs.isNotEmpty) {
                                    _playSong(0, plSongs);
                                  } else {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: const Text(
                                          'Playlist is empty! Add songs first.',
                                          style: TextStyle(
                                            fontFamily: 'monospace',
                                          ),
                                        ),
                                        backgroundColor: _highlightColor,
                                      ),
                                    );
                                  }
                                },
                              ),
                              IconButton(
                                icon: const Icon(
                                  Icons.delete_outline,
                                  color: Colors.redAccent,
                                ),
                                onPressed: () => _deletePlaylist(playlist.name),
                              ),
                            ],
                          ),
                          onTap: () {
                            setState(() {
                              _activePlaylistName = playlist.name;
                            });
                          },
                        ),
                      ),
                    );
                  },
                ),
        ),
        if (_currentSongIndex != -1)
          MiniPlayer(
            currentSong: _songs[_currentSongIndex],
            isPlaying: _isPlaying,
            currentPosition: _currentPosition,
            totalDuration: _totalDuration,
            onPlayPause: _togglePlay,
            onNext: _playNext,
            onPrevious: _playPrevious,
            onSeek: _seek,
            onClose: _closeMiniPlayer,
            onTapBody: () {
              Navigator.push(
                context,
                PageRouteBuilder(
                  transitionDuration: const Duration(milliseconds: 350),
                  reverseTransitionDuration: const Duration(milliseconds: 350),
                  pageBuilder: (context, animation, secondaryAnimation) =>
                      FullPlayerScreen(
                        audioPlayer: _audioPlayer,
                        paperStyle: _paperStyle,
                        highlightColor: _highlightColor,
                        isLiked: _isOnlineSongLiked,
                        onLikeToggle: _toggleLikeOnlineSong,
                      ),
                  transitionsBuilder:
                      (context, animation, secondaryAnimation, child) {
                        return FadeTransition(opacity: animation, child: child);
                      },
                ),
              );
            },
          ),
      ],
    );
  }

  Widget _buildPlaylistDetailsView() {
    final filtered = _getSearchedSongs(_filteredSongs);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark
        ? const Color(0xFFFAF6EE)
        : const Color(0xFF18181A);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Row(
            children: [
              GestureDetector(
                onTap: () {
                  setState(() {
                    _activePlaylistName = null;
                  });
                },
                child: SketchyContainer(
                  backgroundColor: isDark
                      ? const Color(0xFF333338)
                      : Colors.white,
                  borderWidth: 1.5,
                  borderRadius: BorderRadius.circular(8),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  shadowOffset: const Offset(2, 2),
                  child: Row(
                    children: [
                      Icon(Icons.arrow_back, size: 16, color: textColor),
                      const SizedBox(width: 4),
                      Text(
                        'Back',
                        style: TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 12,
                          color: textColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Playlist: $_activePlaylistName',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: textColor,
                  ),
                ),
              ),
              if (filtered.isNotEmpty) ...[
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () {
                    final playlistSongs = List<SongModel>.from(filtered);
                    playlistSongs.shuffle();
                    _playSong(0, playlistSongs);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: const Text(
                          'Shuffling playlist...',
                          style: TextStyle(fontFamily: 'monospace'),
                        ),
                        backgroundColor: _highlightColor,
                        duration: const Duration(seconds: 1),
                      ),
                    );
                  },
                  child: SketchyContainer(
                    backgroundColor: _highlightColor,
                    borderWidth: 1.5,
                    borderRadius: BorderRadius.circular(8),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    shadowOffset: const Offset(2, 2),
                    child: const Row(
                      children: [
                        Icon(Icons.shuffle, size: 16, color: Color(0xFF18181A)),
                        SizedBox(width: 4),
                        Text(
                          'Shuffle',
                          style: TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF18181A),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        _buildSearchBar(),
        Expanded(
          child: filtered.isEmpty
              ? Center(
                  child: Text(
                    'No Songs in Playlist',
                    style: TextStyle(
                      fontFamily: 'monospace',
                      color: isDark ? Colors.white60 : Colors.black54,
                    ),
                  ),
                )
              : ListView.builder(
                  itemCount: filtered.length,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  itemBuilder: (context, index) {
                    final song = filtered[index];
                    final isCurrent =
                        _currentSongIndex != -1 &&
                        _songs[_currentSongIndex].id == song.id;

                    return SongTile(
                      song: song,
                      isCurrent: isCurrent,
                      highlightColor: _highlightColor,
                      onTap: () => _playSong(index, filtered),
                      showRemoveOption: true,
                      onRemoveFromPlaylist: () => _removeSongFromPlaylist(
                        song.id,
                        _activePlaylistName!,
                      ),
                    );
                  },
                ),
        ),
        if (_currentSongIndex != -1)
          MiniPlayer(
            currentSong: _songs[_currentSongIndex],
            isPlaying: _isPlaying,
            currentPosition: _currentPosition,
            totalDuration: _totalDuration,
            onPlayPause: _togglePlay,
            onNext: _playNext,
            onPrevious: _playPrevious,
            onSeek: _seek,
            onClose: _closeMiniPlayer,
            onTapBody: () {
              Navigator.push(
                context,
                PageRouteBuilder(
                  transitionDuration: const Duration(milliseconds: 350),
                  reverseTransitionDuration: const Duration(milliseconds: 350),
                  pageBuilder: (context, animation, secondaryAnimation) =>
                      FullPlayerScreen(
                        audioPlayer: _audioPlayer,
                        paperStyle: _paperStyle,
                        highlightColor: _highlightColor,
                        isLiked: _isOnlineSongLiked,
                        onLikeToggle: _toggleLikeOnlineSong,
                      ),
                  transitionsBuilder:
                      (context, animation, secondaryAnimation, child) {
                        return FadeTransition(opacity: animation, child: child);
                      },
                ),
              );
            },
          ),
      ],
    );
  }

  // --- TAB 3: SETTINGS & DIAGNOSTICS ---
  Widget _buildSettingsTab() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark
        ? const Color(0xFFFAF6EE)
        : const Color(0xFF18181A);
    final subtitleColor = isDark ? Colors.white60 : Colors.black54;

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(16.0),
            children: [
              // 0. Night Mode Switch
              SketchyContainer(
                backgroundColor: isDark
                    ? const Color(0xFF26262B)
                    : Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16.0,
                  vertical: 8.0,
                ),
                margin: const EdgeInsets.only(bottom: 16.0),
                borderRadius: BorderRadius.circular(16),
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    'Night Mode (Chalkboard)',
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontWeight: FontWeight.bold,
                      color: textColor,
                      fontSize: 14.5,
                    ),
                  ),
                  trailing: Switch(
                    value: isDark,
                    onChanged: (val) => _toggleTheme(val),
                    activeThumbColor: _highlightColor,
                  ),
                ),
              ),

              // 1. Accent Customization Color
              SketchyContainer(
                backgroundColor: isDark
                    ? const Color(0xFF26262B)
                    : Colors.white,
                padding: const EdgeInsets.all(16.0),
                margin: const EdgeInsets.only(bottom: 16.0),
                borderRadius: BorderRadius.circular(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Highlighter Accent',
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: textColor,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Choose a hand-drawn highlight marker color:',
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 11,
                        color: subtitleColor,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      alignment: WrapAlignment.center,
                      children:
                          [
                            'Yellow',
                            'Purple',
                            'Blue',
                            'Green',
                            'Orange',
                            'Pink',
                            'Teal',
                            'Lime',
                            'Red',
                            'Indigo',
                          ].map((name) {
                            final color = _getColorFromName(name);
                            final isSelected = _highlightColorName == name;
                            return GestureDetector(
                              onTap: () => _saveHighlightColor(name),
                              child: Container(
                                width: 38,
                                height: 38,
                                decoration: BoxDecoration(
                                  color: color,
                                  border: Border.all(
                                    color: textColor,
                                    width: isSelected ? 2.5 : 1.5,
                                  ),
                                  borderRadius: BorderRadius.circular(19),
                                  boxShadow: isSelected
                                      ? [
                                          BoxShadow(
                                            color: textColor,
                                            offset: const Offset(1.5, 1.5),
                                            blurRadius: 0,
                                          ),
                                        ]
                                      : null,
                                ),
                                child: isSelected
                                    ? const Icon(
                                        Icons.check,
                                        size: 18,
                                        color: Color(0xFF18181A),
                                      )
                                    : null,
                              ),
                            );
                          }).toList(),
                    ),
                  ],
                ),
              ),

              // 2. Paper Grid Background Style Selector
              _buildSegmentedSetting<String>(
                title: 'Background Grid Style',
                description: 'Pick a notebook background canvas style:',
                currentValue: _paperStyle,
                options: ['Grid', 'Ruled', 'Dotted', 'Blank'],
                labels: [
                  'Graph Paper',
                  'Ruled Notebook',
                  'Bullet Journal',
                  'Blank Sketchbook',
                ],
                onChanged: (val) => _savePaperStyle(val),
                isDark: isDark,
                textColor: textColor,
                subtitleColor: subtitleColor,
              ),

              // 3. Record Disc Rotation Speed
              _buildSegmentedSetting<String>(
                title: 'Vinyl Record Spin Speed',
                description:
                    'Adjust the spinning speed of the record in Reels:',
                currentValue: _rotationSpeed,
                options: ['Chill', 'Vibe', 'Hyper', 'Off'],
                labels: [
                  'Chill (Slow)',
                  'Vibe (Medium)',
                  'Hyper (Fast)',
                  'Off (Static)',
                ],
                onChanged: (val) => _saveRotationSpeed(val),
                isDark: isDark,
                textColor: textColor,
                subtitleColor: subtitleColor,
              ),

              // 4. Sound Profile Preset
              _buildSegmentedSetting<String>(
                title: 'Audio Sound Signature',
                description: 'Select an acoustic reproduction profiles preset:',
                currentValue: _soundPreset,
                options: [
                  'Cassette (Lo-Fi)',
                  'Vinyl (Warm)',
                  'Compact Disc (Hi-Fi)',
                  'Studio (FLAC)',
                ],
                labels: [
                  'Cassette (Lo-Fi)',
                  'Vinyl (Warm)',
                  'CD (Hi-Fi)',
                  'Studio (FLAC)',
                ],
                onChanged: (val) => _saveSoundPreset(val),
                isDark: isDark,
                textColor: textColor,
                subtitleColor: subtitleColor,
              ),

              // 2. Missing Music Troubleshooting Guide
              SketchyContainer(
                backgroundColor: isDark
                    ? const Color(0xFF5C2D2D)
                    : const Color(0xFFFFD1D1),
                padding: const EdgeInsets.all(16.0),
                margin: const EdgeInsets.only(bottom: 16.0),
                borderRadius: BorderRadius.circular(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.help_outline, color: Color(0xFF18181A)),
                        SizedBox(width: 8),
                        Text(
                          'Missing Music Files?',
                          style: TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF18181A),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _buildTroublePoint(
                      '1. Media Indexing Lag',
                      'Android registers new files dynamically. If you just copied music, please reboot your phone to force scan.',
                    ),
                    _buildTroublePoint(
                      '2. Call Recording Paths',
                      'Call recording apps often save in private or non-standard folders. Copy recordings to your "Music" directory.',
                    ),
                    _buildTroublePoint(
                      '3. File Formats',
                      'Ensure your tracks are standard audio formats like .mp3, .m4a, or .wav.',
                    ),
                    _buildTroublePoint(
                      '4. SD Card Volume',
                      'Queries access external SD card space automatically. If missing, verify your SD card is mounted.',
                    ),
                    const SizedBox(height: 16),
                    GestureDetector(
                      onTap: _requestPermissionAndScan,
                      child: SketchyContainer(
                        backgroundColor: Colors.white,
                        borderWidth: 1.5,
                        borderRadius: BorderRadius.circular(8),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shadowOffset: const Offset(2, 2),
                        child: const Center(
                          child: Text(
                            'Rescan Device Audio',
                            style: TextStyle(
                              fontFamily: 'monospace',
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF18181A),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // 3. Audio Diagnostics Report
              SketchyContainer(
                backgroundColor: isDark
                    ? const Color(0xFF26262B)
                    : Colors.white,
                padding: const EdgeInsets.all(16.0),
                borderRadius: BorderRadius.circular(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Audio Store Diagnostics',
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: textColor,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildDiagLine(
                      'Total Scanned Audio',
                      '${_songs.length} tracks',
                      textColor,
                    ),
                    _buildDiagLine(
                      'Local Music Tracks',
                      '${_songs.where((s) => _categorizeSong(s) == AudioCategory.music && !(s.uri ?? '').startsWith('http')).length} files',
                      textColor,
                    ),
                    _buildDiagLine(
                      'Call Recordings',
                      '${_songs.where((s) => _categorizeSong(s) == AudioCategory.recording).length} files',
                      textColor,
                    ),
                    _buildDiagLine(
                      'Online Liked Tracks',
                      '${_onlineLikedSongs.length} files',
                      textColor,
                    ),
                    _buildDiagLine(
                      'Other Audio',
                      '${_songs.where((s) => _categorizeSong(s) == AudioCategory.other).length} files',
                      textColor,
                    ),
                    _buildDiagLine(
                      'Created Playlists',
                      '${_playlists.length} playlists',
                      textColor,
                    ),
                    _buildDiagLine(
                      'Platform Mode',
                      kIsWeb ? 'Web Engine' : 'Native Mobile OS',
                      textColor,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        if (_currentSongIndex != -1)
          MiniPlayer(
            currentSong: _songs[_currentSongIndex],
            isPlaying: _isPlaying,
            currentPosition: _currentPosition,
            totalDuration: _totalDuration,
            onPlayPause: _togglePlay,
            onNext: _playNext,
            onPrevious: _playPrevious,
            onSeek: _seek,
            onClose: _closeMiniPlayer,
            onTapBody: () {
              Navigator.push(
                context,
                PageRouteBuilder(
                  transitionDuration: const Duration(milliseconds: 350),
                  reverseTransitionDuration: const Duration(milliseconds: 350),
                  pageBuilder: (context, animation, secondaryAnimation) =>
                      FullPlayerScreen(
                        audioPlayer: _audioPlayer,
                        paperStyle: _paperStyle,
                        highlightColor: _highlightColor,
                        isLiked: _isOnlineSongLiked,
                        onLikeToggle: _toggleLikeOnlineSong,
                      ),
                  transitionsBuilder:
                      (context, animation, secondaryAnimation, child) {
                        return FadeTransition(opacity: animation, child: child);
                      },
                ),
              );
            },
          ),
      ],
    );
  }

  Widget _buildTroublePoint(String title, String desc) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontFamily: 'monospace',
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Color(0xFF18181A),
            ),
          ),
          const SizedBox(height: 1),
          Text(
            desc,
            style: const TextStyle(
              fontFamily: 'monospace',
              fontSize: 11,
              color: Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDiagLine(String label, String value, Color textColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontFamily: 'monospace',
              fontSize: 12,
              color: Colors.black45,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontFamily: 'monospace',
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
          ),
        ],
      ),
    );
  }

  // --- GENERAL WIDGETS ---
  Widget _buildBottomNavigationBar() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.only(left: 12.0, right: 12.0, bottom: 16.0),
      child: SketchyContainer(
        backgroundColor: isDark
            ? const Color(0xFF26262B)
            : const Color(0xFFFFFDF9),
        borderRadius: BorderRadius.circular(16),
        padding: const EdgeInsets.symmetric(vertical: 4.0),
        shadowOffset: const Offset(3, 3),
        child: Stack(
          children: [
            // Sliding Background Pill
            Positioned.fill(
              child: AnimatedAlign(
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeOutCubic,
                alignment: _currentTab == 0
                    ? const Alignment(-0.93, 0.0)
                    : (_currentTab == 1
                          ? const Alignment(0.0, 0.0)
                          : const Alignment(0.93, 0.0)),
                child: FractionallySizedBox(
                  widthFactor: 0.28,
                  heightFactor: 0.75,
                  child: SketchyContainer(
                    backgroundColor: _currentTab == 0
                        ? const Color(0xFFFFF9C4)
                        : (_currentTab == 1
                              ? const Color(0xFFD1F3D1)
                              : const Color(0xFFC4E8E8)),
                    borderRadius: BorderRadius.circular(12),
                    borderWidth: 1.5,
                    padding: EdgeInsets.zero,
                    shadowOffset: const Offset(1.5, 1.5),
                    hasPencilShading: true,
                    child: const SizedBox.shrink(),
                  ),
                ),
              ),
            ),
            // Nav Items on top
            Row(
              children: [
                Expanded(child: _buildNavItem(0, Icons.home_outlined, 'Home')),
                Expanded(
                  child: _buildNavItem(1, Icons.playlist_play, 'Playlists'),
                ),
                Expanded(
                  child: _buildNavItem(2, Icons.settings_outlined, 'Settings'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNavItem(int index, IconData icon, String label) {
    final isSelected = _currentTab == index;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark
        ? const Color(0xFFFAF6EE)
        : const Color(0xFF18181A);
    final iconColor = isSelected ? const Color(0xFF18181A) : textColor;

    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        setState(() {
          _currentTab = index;
        });
      },
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        height: 48,
        child: Center(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedScale(
                scale: isSelected ? 1.15 : 1.0,
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeOutCubic,
                child: Icon(icon, color: iconColor, size: 22),
              ),
              AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeOutCubic,
                width: isSelected ? 6.0 : 0.0,
                child: const SizedBox.shrink(),
              ),
              ClipRect(
                child: AnimatedSize(
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeOutCubic,
                  child: isSelected
                      ? AnimatedOpacity(
                          opacity: isSelected ? 1.0 : 0.0,
                          duration: const Duration(milliseconds: 200),
                          child: Text(
                            label,
                            maxLines: 1,
                            softWrap: false,
                            overflow: TextOverflow.clip,
                            style: const TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 12.5,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF18181A),
                            ),
                          ),
                        )
                      : const SizedBox.shrink(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyStateView() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark
        ? const Color(0xFFFAF6EE)
        : const Color(0xFF18181A);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: SketchyContainer(
          width: 300,
          height: 220,
          borderRadius: BorderRadius.circular(24),
          borderWidth: 1.8,
          shadowOffset: const Offset(3, 3),
          backgroundColor: isDark ? const Color(0xFF26262B) : Colors.white,
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SketchyLogo(size: 52),
                const SizedBox(height: 12),
                Text(
                  'No $_selectedCategory Found',
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: textColor,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Scan storage for local audio files',
                  style: TextStyle(
                    fontFamily: 'monospace',
                    color: Colors.black45,
                    fontSize: 11,
                  ),
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: const Color(0xFF18181A),
                    elevation: 0,
                    side: const BorderSide(
                      color: Color(0xFF18181A),
                      width: 1.5,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  onPressed: _requestPermissionAndScan,
                  icon: const Icon(Icons.search, size: 18),
                  label: const Text(
                    'Start Scanning',
                    style: TextStyle(fontFamily: 'monospace'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSegmentedSetting<T>({
    required String title,
    required String description,
    required T currentValue,
    required List<T> options,
    required List<String> labels,
    required Function(T) onChanged,
    required bool isDark,
    required Color textColor,
    required Color subtitleColor,
  }) {
    return SketchyContainer(
      backgroundColor: isDark ? const Color(0xFF26262B) : Colors.white,
      padding: const EdgeInsets.all(16.0),
      margin: const EdgeInsets.only(bottom: 16.0),
      borderRadius: BorderRadius.circular(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            style: TextStyle(
              fontFamily: 'monospace',
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            description,
            style: TextStyle(
              fontFamily: 'monospace',
              fontSize: 11,
              color: subtitleColor,
            ),
          ),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: List.generate(options.length, (idx) {
                final opt = options[idx];
                final label = labels[idx];
                final isSelected = opt == currentValue;
                return GestureDetector(
                  onTap: () => onChanged(opt),
                  child: Container(
                    margin: const EdgeInsets.only(right: 8.0),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? _highlightColor.withValues(
                              alpha: isDark ? 0.3 : 0.8,
                            )
                          : (isDark
                                ? const Color(0xFF1E1E22)
                                : const Color(0xFFF0F0EE)),
                      border: Border.all(
                        color: isSelected
                            ? textColor
                            : (isDark ? Colors.white24 : Colors.black26),
                        width: isSelected ? 1.8 : 1.0,
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      label,
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 11,
                        fontWeight: isSelected
                            ? FontWeight.bold
                            : FontWeight.normal,
                        color: textColor,
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }
}

class ScribbledBackButton extends StatelessWidget {
  final Color color;
  final VoidCallback onTap;

  const ScribbledBackButton({
    super.key,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 32,
        height: 32,
        color: Colors.transparent,
        child: CustomPaint(painter: ScribbledArrowPainter(color: color)),
      ),
    );
  }
}

class ScribbledArrowPainter extends CustomPainter {
  final Color color;

  ScribbledArrowPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final w = size.width;
    final h = size.height;

    // Draw overlapping loops for hand-drawn scribble background circle
    final scribblePaint = Paint()
      ..color = color.withValues(alpha: 0.2)
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    canvas.drawOval(Rect.fromLTWH(2, 2, w - 4, h - 4), scribblePaint);
    canvas.drawOval(Rect.fromLTWH(3, 1, w - 5, h - 6), scribblePaint);
    canvas.drawOval(Rect.fromLTWH(1, 3, w - 4, h - 5), scribblePaint);

    // Draw main arrow shaft (twice for sketchy hand-drawn feel)
    canvas.drawLine(
      Offset(w * 0.72, h * 0.5),
      Offset(w * 0.28, h * 0.5),
      paint,
    );
    canvas.drawLine(
      Offset(w * 0.70, h * 0.51),
      Offset(w * 0.30, h * 0.49),
      paint,
    );

    // Draw top barb (twice for sketchy feel)
    canvas.drawLine(
      Offset(w * 0.28, h * 0.5),
      Offset(w * 0.46, h * 0.32),
      paint,
    );
    canvas.drawLine(
      Offset(w * 0.29, h * 0.49),
      Offset(w * 0.45, h * 0.33),
      paint,
    );

    // Draw bottom barb (twice for sketchy feel)
    canvas.drawLine(
      Offset(w * 0.28, h * 0.5),
      Offset(w * 0.46, h * 0.68),
      paint,
    );
    canvas.drawLine(
      Offset(w * 0.27, h * 0.51),
      Offset(w * 0.47, h * 0.67),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant ScribbledArrowPainter oldDelegate) {
    return oldDelegate.color != color;
  }
}

class DynamicIslandWidget extends StatefulWidget {
  final MediaItem mediaItem;
  final bool isPlaying;
  final AudioPlayer audioPlayer;
  final bool isDark;
  final Color highlightColor;
  final bool isPipMode;
  final bool isLiked;
  final VoidCallback onLikeToggle;
  final VoidCallback onTapSong;

  const DynamicIslandWidget({
    super.key,
    required this.mediaItem,
    required this.isPlaying,
    required this.audioPlayer,
    required this.isDark,
    required this.highlightColor,
    this.isPipMode = false,
    required this.isLiked,
    required this.onLikeToggle,
    required this.onTapSong,
  });

  @override
  State<DynamicIslandWidget> createState() => _DynamicIslandWidgetState();
}

class _DynamicIslandWidgetState extends State<DynamicIslandWidget>
    with SingleTickerProviderStateMixin {
  bool _isExpanded = false;
  late AnimationController _rotationController;

  String _formatDuration(Duration d) {
    final min = d.inMinutes;
    final sec = d.inSeconds % 60;
    return '$min:${sec.toString().padLeft(2, '0')}';
  }

  @override
  void initState() {
    super.initState();
    _rotationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 12),
    );
    if (widget.isPlaying) {
      _rotationController.repeat();
    }
  }

  @override
  void didUpdateWidget(covariant DynamicIslandWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isPlaying != oldWidget.isPlaying) {
      if (widget.isPlaying) {
        _rotationController.repeat();
      } else {
        _rotationController.stop();
      }
    }
  }

  @override
  void dispose() {
    _rotationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final textColor = widget.isDark
        ? const Color(0xFFFAF6EE)
        : const Color(0xFF18181A);
    final isDark = widget.isDark;

    // Compact content
    final compactChild = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Mini vinyl art
        RotatingVinyl(
          isPlaying: widget.isPlaying,
          size: 28,
          child: Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF0F0F10),
              border: Border.all(color: textColor, width: 1.0),
            ),
            child: ClipOval(
              child: widget.mediaItem.artUri != null
                  ? Image.network(
                      widget.mediaItem.artUri.toString(),
                      fit: BoxFit.cover,
                      errorBuilder: (c, e, s) => const Icon(
                        Icons.music_note,
                        color: Colors.white,
                        size: 14,
                      ),
                    )
                  : const Icon(Icons.music_note, color: Colors.white, size: 14),
            ),
          ),
        ),
        const SizedBox(width: 10),
        // Title & Artist
        Flexible(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.mediaItem.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: textColor,
                ),
              ),
              Text(
                widget.mediaItem.artist ?? 'Unknown Artist',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 9,
                  color: textColor.withValues(alpha: 0.6),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        // Mini Waveform Visualizer
        if (widget.isPlaying)
          _MiniWaveform(color: widget.highlightColor)
        else
          Icon(Icons.pause, size: 12, color: textColor.withValues(alpha: 0.6)),
      ],
    );

    // Expanded Content
    final expandedChild = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            // Larger vinyl art
            GestureDetector(
              onTap: widget.onTapSong,
              child: RotatingVinyl(
                isPlaying: widget.isPlaying,
                size: 44,
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFF0F0F10),
                    border: Border.all(color: textColor, width: 1.5),
                  ),
                  child: ClipOval(
                    child: widget.mediaItem.artUri != null
                        ? Image.network(
                            widget.mediaItem.artUri.toString(),
                            fit: BoxFit.cover,
                            errorBuilder: (c, e, s) => const Icon(
                              Icons.music_note,
                              color: Colors.white,
                              size: 20,
                            ),
                          )
                        : const Icon(
                            Icons.music_note,
                            color: Colors.white,
                            size: 20,
                          ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: GestureDetector(
                onTap: widget.onTapSong,
                behavior: HitTestBehavior.opaque,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.mediaItem.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: textColor,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      widget.mediaItem.artist ?? 'Unknown Artist',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 10,
                        color: textColor.withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.close, size: 18),
              color: textColor.withValues(alpha: 0.6),
              onPressed: () {
                setState(() {
                  _isExpanded = false;
                });
              },
            ),
          ],
        ),
        const SizedBox(height: 12),
        // Progress timeline
        StreamBuilder<Duration>(
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
                        fontSize: 9,
                        color: textColor.withValues(alpha: 0.6),
                      ),
                    ),
                    Expanded(
                      child: SmoothSlider(
                        value: position.inSeconds.toDouble(),
                        max: duration.inSeconds.toDouble(),
                        activeColor: widget.highlightColor,
                        inactiveColor: isDark ? Colors.white24 : Colors.black12,
                        trackHeight: 2.0,
                        normalThumbRadius: 4.0,
                        activeThumbRadius: 8.0,
                        onChanged: (val) {
                          widget.audioPlayer.seek(
                            Duration(seconds: val.toInt()),
                          );
                        },
                      ),
                    ),
                    Text(
                      _formatDuration(duration),
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 9,
                        color: textColor.withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                );
              },
            );
          },
        ),
        const SizedBox(height: 12),
        // Mini player controls
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            IconButton(
              icon: const Icon(Icons.skip_previous),
              color: textColor,
              onPressed: () => widget.audioPlayer.seekToPrevious(),
            ),
            IconButton(
              icon: Icon(
                widget.isPlaying
                    ? Icons.pause_circle_filled
                    : Icons.play_circle_filled,
              ),
              iconSize: 36,
              color: widget.highlightColor,
              onPressed: () {
                if (widget.isPlaying) {
                  widget.audioPlayer.pause();
                } else {
                  widget.audioPlayer.play();
                }
              },
            ),
            IconButton(
              icon: const Icon(Icons.skip_next),
              color: textColor,
              onPressed: () => widget.audioPlayer.seekToNext(),
            ),
            IconButton(
              icon: Icon(
                widget.isLiked ? Icons.favorite : Icons.favorite_border,
                color: widget.isLiked ? Colors.red : textColor,
              ),
              onPressed: widget.onLikeToggle,
            ),
          ],
        ),
      ],
    );

    final showExpanded = _isExpanded && !widget.isPipMode;

    return GestureDetector(
      onTap: widget.isPipMode
          ? null
          : () {
              setState(() {
                _isExpanded = !_isExpanded;
              });
            },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.fastOutSlowIn,
        width: showExpanded ? 310 : 200,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: SketchyContainer(
          backgroundColor: isDark ? const Color(0xFF26262B) : Colors.white,
          borderRadius: BorderRadius.circular(showExpanded ? 24 : 20),
          borderWidth: 1.5,
          padding: const EdgeInsets.all(8.0),
          shadowOffset: const Offset(2.0, 2.0),
          child: AnimatedCrossFade(
            firstChild: compactChild,
            secondChild: expandedChild,
            crossFadeState: showExpanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 200),
          ),
        ),
      ),
    );
  }
}

class _MiniWaveform extends StatefulWidget {
  final Color color;

  const _MiniWaveform({required this.color});

  @override
  State<_MiniWaveform> createState() => _MiniWaveformState();
}

class _MiniWaveformState extends State<_MiniWaveform>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: List.generate(4, (index) {
            final factor = math
                .sin((_controller.value * 2 * math.pi) + (index * 1.5))
                .abs();
            final height = 4.0 + (factor * 12.0);
            return Container(
              width: 2.5,
              height: height,
              margin: const EdgeInsets.symmetric(horizontal: 1.0),
              decoration: BoxDecoration(
                color: widget.color,
                borderRadius: BorderRadius.circular(1.5),
              ),
            );
          }),
        );
      },
    );
  }
}

class LandingPortalWidget extends StatefulWidget {
  final VoidCallback onSelectOffline;
  final VoidCallback onSelectOnline;
  final String paperStyle;

  const LandingPortalWidget({
    super.key,
    required this.onSelectOffline,
    required this.onSelectOnline,
    required this.paperStyle,
  });

  @override
  State<LandingPortalWidget> createState() => _LandingPortalWidgetState();
}

class _LandingPortalWidgetState extends State<LandingPortalWidget> with TickerProviderStateMixin {
  bool _hasPressedStart = false;
  late AnimationController _arrowController;

  @override
  void initState() {
    super.initState();
    _arrowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );
    // Draw the arrow after a short delay
    Future.delayed(const Duration(milliseconds: 400), () {
      if (mounted) {
        _arrowController.forward();
      }
    });
  }

  @override
  void dispose() {
    _arrowController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark
        ? const Color(0xFFFAF6EE)
        : const Color(0xFF18181A);
    final subtitleColor = isDark ? Colors.white60 : Colors.black54;

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SketchyLogo(size: 80),
            const SizedBox(height: 16),
            Text(
              'PaperWave',
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 32,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.0,
                color: textColor,
              ),
            ),
            const SizedBox(height: 8),
            AnimatedCrossFade(
              firstChild: Text(
                'A hand-crafted music player canvas',
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 12.5,
                  color: subtitleColor,
                ),
              ),
              secondChild: Text(
                'Choose your canvas to start listening:',
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 12.5,
                  color: subtitleColor,
                ),
              ),
              crossFadeState: _hasPressedStart
                  ? CrossFadeState.showSecond
                  : CrossFadeState.showFirst,
              duration: const Duration(milliseconds: 300),
              firstCurve: Curves.easeOutCubic,
              secondCurve: Curves.easeOutCubic,
              sizeCurve: Curves.easeOutCubic,
            ),
            const SizedBox(height: 12),

            AnimatedSize(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOutCubic,
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
                child: !_hasPressedStart
                    ? Column(
                        key: const ValueKey('start_screen'),
                        children: [
                          // Custom Paint for drawing the sketchy arrow
                          SizedBox(
                            height: 140,
                            width: 240,
                            child: AnimatedBuilder(
                              animation: _arrowController,
                              builder: (context, child) {
                                return CustomPaint(
                                  painter: SketchyArrowPainter(
                                    progress: _arrowController.value,
                                    color: textColor,
                                  ),
                                );
                              },
                            ),
                          ),
                          const SizedBox(height: 8),
                          // The Start Button
                          FadeSlideEntrance(
                            delay: const Duration(milliseconds: 200),
                            child: TactileButton(
                              onTap: () {
                                HapticFeedback.mediumImpact();
                                setState(() {
                                  _hasPressedStart = true;
                                });
                              },
                              pressedScale: 0.95,
                              backgroundColor: isDark
                                  ? const Color(0xFF26262B)
                                  : Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              borderWidth: 2.0,
                              padding: const EdgeInsets.symmetric(horizontal: 48.0, vertical: 16.0),
                              shadowOffset: const Offset(4, 4),
                              child: Text(
                                'START',
                                style: TextStyle(
                                  fontFamily: 'monospace',
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: textColor,
                                  letterSpacing: 2.0,
                                ),
                              ),
                            ),
                          ),
                        ],
                      )
                    : Column(
                        key: const ValueKey('options_screen'),
                        children: [
                          const SizedBox(height: 24),
                          // Card 1: Offline Mode
                          Padding(
                            padding: const EdgeInsets.only(bottom: 20.0),
                            child: ScribbleEntrance(
                              delay: Duration.zero,
                              borderColor: isDark ? const Color(0xFFE5E5DE) : const Color(0xFF1E1E1E),
                              borderWidth: 2.0,
                              borderRadius: BorderRadius.circular(16),
                              child: TactileButton(
                                onTap: widget.onSelectOffline,
                                pressedScale: 0.97,
                                backgroundColor: isDark
                                    ? const Color(0xFF26262B)
                                    : Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                borderWidth: 2.0,
                                padding: const EdgeInsets.all(20.0),
                                shadowOffset: const Offset(4, 4),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 52,
                                      height: 52,
                                      decoration: BoxDecoration(
                                        color: isDark
                                            ? const Color(0xFF5C5C3D)
                                            : const Color(0xFFFFF9C4),
                                        shape: BoxShape.circle,
                                        border: Border.all(color: textColor, width: 1.5),
                                      ),
                                      child: Icon(
                                        Icons.folder_open_outlined,
                                        color: textColor,
                                        size: 26,
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Offline Mode',
                                            style: TextStyle(
                                              fontFamily: 'monospace',
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                              color: textColor,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            'Scan local music files, mic recordings, and create playlists.',
                                            style: TextStyle(
                                              fontFamily: 'monospace',
                                              fontSize: 11,
                                              color: subtitleColor,
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
                          // Card 2: Online Mode
                          ScribbleEntrance(
                            delay: const Duration(milliseconds: 280),
                            borderColor: isDark ? const Color(0xFFE5E5DE) : const Color(0xFF1E1E1E),
                            borderWidth: 2.0,
                            borderRadius: BorderRadius.circular(16),
                            child: TactileButton(
                              onTap: widget.onSelectOnline,
                              pressedScale: 0.97,
                              backgroundColor: isDark
                                  ? const Color(0xFF26262B)
                                  : Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              borderWidth: 2.0,
                              padding: const EdgeInsets.all(20.0),
                              shadowOffset: const Offset(4, 4),
                              child: Row(
                                children: [
                                  Container(
                                    width: 52,
                                    height: 52,
                                    decoration: BoxDecoration(
                                      color: isDark
                                          ? const Color(0xFF2D5C5C)
                                          : const Color(0xFFC4E8E8),
                                      shape: BoxShape.circle,
                                      border: Border.all(color: textColor, width: 1.5),
                                    ),
                                    child: Icon(
                                      Icons.play_circle_outline,
                                      color: textColor,
                                      size: 26,
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Online Mode',
                                          style: TextStyle(
                                            fontFamily: 'monospace',
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                            color: textColor,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          'Explore vertical music reels, dynamic colors, and like online tracks.',
                                          style: TextStyle(
                                            fontFamily: 'monospace',
                                            fontSize: 11,
                                            color: subtitleColor,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class SketchyArrowPainter extends CustomPainter {
  final double progress;
  final Color color;
  final double strokeWidth;

  SketchyArrowPainter({
    required this.progress,
    required this.color,
    this.strokeWidth = 2.2,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0) return;

    final w = size.width;
    final h = size.height;

    // ── Three layered paints — matches SketchyBoxPainter's border style ──────────
    final paint1 = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final paint2 = Paint()
      ..color = color.withValues(alpha: 0.75)
      ..strokeWidth = strokeWidth * 0.75
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final paint3 = Paint()
      ..color = color.withValues(alpha: 0.45)
      ..strokeWidth = strokeWidth * 0.55
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    // ── Shaft: smooth quadratic Bezier ──────────────────────────────────────────
    final start = Offset(w * 0.44, h * 0.05);
    final control = Offset(w * 0.95, h * 0.38);
    final end = Offset(w * 0.50, h * 0.92);

    double shaftProgress = (progress / 0.75).clamp(0.0, 1.0);
    double headProgress = ((progress - 0.75) / 0.25).clamp(0.0, 1.0);

    final shaftPath = Path()
      ..moveTo(start.dx, start.dy)
      ..quadraticBezierTo(control.dx, control.dy, end.dx, end.dy);

    // Primary stroke
    _drawAnimatedPath(canvas, shaftPath, paint1, shaftProgress);
    // Second layer — offset like SketchyBoxPainter
    canvas.save();
    canvas.translate(0.8, -0.6);
    _drawAnimatedPath(canvas, shaftPath, paint2, shaftProgress);
    canvas.restore();
    // Third layer
    canvas.save();
    canvas.translate(-0.7, 0.9);
    _drawAnimatedPath(canvas, shaftPath, paint3, shaftProgress);
    canvas.restore();

    if (headProgress > 0) {
      // ── Tangent at t=1 for quadratic Bezier: 2*(end - control) ───────────────
      final tangentDx = 2 * (end.dx - control.dx);
      final tangentDy = 2 * (end.dy - control.dy);
      final tangentLen = math.sqrt(tangentDx * tangentDx + tangentDy * tangentDy);
      final tx = tangentDx / tangentLen;
      final ty = tangentDy / tangentLen;
      final nx = -ty;
      final ny = tx;

      const wingLen = 28.0;
      const wingSpread = 14.0;

      // Wings start slightly before tip so they cross/overlap the shaft
      final origin = Offset(
        end.dx - tx * wingLen * 0.15,
        end.dy - ty * wingLen * 0.15,
      );

      final w1cp = Offset(
        origin.dx - tx * wingLen * 0.5 + nx * wingSpread * 0.5,
        origin.dy - ty * wingLen * 0.5 + ny * wingSpread * 0.5,
      );
      final w1end = Offset(
        origin.dx - tx * wingLen + nx * wingSpread,
        origin.dy - ty * wingLen + ny * wingSpread,
      );
      final wing1Path = Path()
        ..moveTo(origin.dx, origin.dy)
        ..quadraticBezierTo(w1cp.dx, w1cp.dy, w1end.dx, w1end.dy);

      final w2cp = Offset(
        origin.dx - tx * wingLen * 0.5 - nx * wingSpread * 0.5,
        origin.dy - ty * wingLen * 0.5 - ny * wingSpread * 0.5,
      );
      final w2end = Offset(
        origin.dx - tx * wingLen - nx * wingSpread,
        origin.dy - ty * wingLen - ny * wingSpread,
      );
      final wing2Path = Path()
        ..moveTo(origin.dx, origin.dy)
        ..quadraticBezierTo(w2cp.dx, w2cp.dy, w2end.dx, w2end.dy);

      // Draw wings with all three layers
      _drawAnimatedPath(canvas, wing1Path, paint1, headProgress);
      _drawAnimatedPath(canvas, wing2Path, paint1, headProgress);

      canvas.save();
      canvas.translate(0.8, -0.6);
      _drawAnimatedPath(canvas, wing1Path, paint2, headProgress);
      _drawAnimatedPath(canvas, wing2Path, paint2, headProgress);
      canvas.restore();

      canvas.save();
      canvas.translate(-0.7, 0.9);
      _drawAnimatedPath(canvas, wing1Path, paint3, headProgress);
      _drawAnimatedPath(canvas, wing2Path, paint3, headProgress);
      canvas.restore();
    }
  }

  void _drawAnimatedPath(Canvas canvas, Path path, Paint paint, double pathProgress) {
    if (pathProgress <= 0) return;
    if (pathProgress >= 1.0) {
      canvas.drawPath(path, paint);
      return;
    }
    for (final metric in path.computeMetrics()) {
      final extract = metric.extractPath(0.0, metric.length * pathProgress);
      canvas.drawPath(extract, paint);
    }
  }

  @override
  bool shouldRepaint(covariant SketchyArrowPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.color != color ||
        oldDelegate.strokeWidth != strokeWidth;
  }
}
