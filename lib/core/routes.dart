import 'package:flutter/material.dart';
import 'package:aura/screens/splash_screen.dart';
import 'package:aura/screens/home_screen.dart';
import 'package:aura/screens/search_screen.dart';
import 'package:aura/screens/library_screen.dart';
import 'package:aura/screens/player_screen.dart';
import 'package:aura/screens/podcast_detail_screen.dart';
import 'package:aura/models/podcast.dart';

import 'package:aura/screens/audiobooks_screen.dart';
import 'package:aura/screens/audiobook_detail_screen.dart';
import 'package:aura/screens/audiobook_player_screen.dart';
import 'package:aura/models/audiobook.dart';

class AppRoutes {
  static const String splash = '/';
  static const String home = '/home';
  static const String search = '/search';
  static const String library = '/library';
  static const String player = '/player';
  static const String podcastDetail = '/podcast';
  static const String audiobooks = '/audiobooks';
  static const String audiobookDetail = '/audiobook-detail';
  static const String audiobookPlayer = '/audiobook-player';

  static Map<String, WidgetBuilder> get routes => {
    splash: (_) => const SplashScreen(),
    home: (_) => const HomeScreen(),
    search: (_) => const SearchScreen(),
    library: (_) => const LibraryScreen(),
    player: (_) => const PlayerScreen(),
    audiobooks: (_) => const AudiobooksScreen(),
  };

  static Route<dynamic>? onGenerateRoute(RouteSettings settings) {
    switch (settings.name) {
      case podcastDetail:
        final podcast = settings.arguments as Podcast;
        return _fadeRoute(PodcastDetailScreen(podcast: podcast), settings);
      case audiobookDetail:
        final book = settings.arguments as Audiobook;
        return _fadeRoute(AudiobookDetailScreen(book: book), settings);
      case audiobookPlayer:
        final book = settings.arguments as Audiobook?;
        return _fadeRoute(AudiobookPlayerScreen(book: book), settings);
      default:
        return null;
    }
  }

  static PageRoute _fadeRoute(Widget page, RouteSettings settings) {
    return PageRouteBuilder(
      settings: settings,
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        return FadeTransition(opacity: animation, child: child);
      },
      transitionDuration: const Duration(milliseconds: 300),
    );
  }
}
