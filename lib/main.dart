import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:media_kit/media_kit.dart';
import 'package:provider/provider.dart';
import 'package:audio_service/audio_service.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:aura/core/theme.dart';
import 'package:aura/core/routes.dart';
import 'package:aura/providers/audio_provider.dart';
import 'package:aura/providers/search_provider.dart';
import 'package:aura/providers/theme_provider.dart';
import 'package:aura/providers/audiobook_provider.dart';
import 'package:aura/services/aura_audio_handler.dart';

late AuraAudioHandler audioHandler;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();

  // Request notification permission on Android 13+ (API 33+)
  // Without this runtime grant, the media notification bar will never appear.
  await Permission.notification.request();

  try {
    audioHandler = await AudioService.init(
      builder: () => AuraAudioHandler(),
      config: const AudioServiceConfig(
        androidNotificationChannelId: 'com.aura.podcast.channel.audio',
        androidNotificationChannelName: 'AURA Podcast Playback',
        androidNotificationChannelDescription: 'Shows playback controls for AURA audio',
        androidNotificationOngoing: true,
        androidStopForegroundOnPause: true,
        androidNotificationIcon: 'mipmap/ic_launcher',
        androidShowNotificationBadge: true,
        notificationColor: Color(0xFFB8975A),
      ),
    );
  } catch (e) {
    debugPrint('[main] AudioService init error: $e');
    audioHandler = AuraAudioHandler();
  }

  // Status bar styling
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ),
  );

  // Portrait only
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  runApp(AuraApp(audioHandler: audioHandler));
}

class AuraApp extends StatelessWidget {
  final AuraAudioHandler? audioHandler;
  const AuraApp({super.key, this.audioHandler});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(
          create: (_) => AudioProvider(audioHandler: audioHandler),
        ),
        ChangeNotifierProvider(create: (_) => SearchProvider()),
        ChangeNotifierProvider(create: (_) => AudiobookProvider()),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, _) {
          return MaterialApp(
            title: 'AURA',
            debugShowCheckedModeBanner: false,
            theme: AuraTheme.light,
            darkTheme: AuraTheme.dark,
            themeMode: themeProvider.themeMode,
            initialRoute: AppRoutes.splash,
            routes: AppRoutes.routes,
            onGenerateRoute: AppRoutes.onGenerateRoute,
          );
        },
      ),
    );
  }
}
