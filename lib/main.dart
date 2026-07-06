import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'screens/home_screen.dart';

// Global ValueNotifier to manage app-wide ThemeMode changes
final ValueNotifier<ThemeMode> themeNotifier = ValueNotifier(ThemeMode.light);

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await JustAudioBackground.init(
    androidNotificationChannelId: 'com.lucasjosino.musicplayer.channel.audio',
    androidNotificationChannelName: 'Music Playback',
    androidNotificationOngoing: true,
  );
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final lightTheme = ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: const Color(0xFFFAF8F3),
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF222222),
        primary: const Color(0xFF222222),
        surface: const Color(0xFFFAF8F3),
      ),
      textTheme: GoogleFonts.patrickHandTextTheme(ThemeData.light().textTheme)
          .apply(
            bodyColor: const Color(0xFF222222),
            displayColor: const Color(0xFF222222),
          ),
    );

    final darkTheme = ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: const Color(0xFF1B1C1E),
      colorScheme: ColorScheme.fromSeed(
        brightness: Brightness.dark,
        seedColor: const Color(0xFFE5E5DE),
        primary: const Color(0xFFE5E5DE),
        surface: const Color(0xFF1B1C1E),
      ),
      textTheme: GoogleFonts.patrickHandTextTheme(ThemeData.dark().textTheme)
          .apply(
            bodyColor: const Color(0xFFE5E5DE),
            displayColor: const Color(0xFFE5E5DE),
          ),
    );

    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeNotifier,
      builder: (_, mode, child) {
        return MaterialApp(
          title: 'PaperWave',
          themeMode: mode,
          theme: lightTheme,
          darkTheme: darkTheme,
          debugShowCheckedModeBanner: false,
          home: const MusicPlayerPage(),
        );
      },
    );
  }
}
