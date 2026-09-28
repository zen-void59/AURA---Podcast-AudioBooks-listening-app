import 'package:flutter/foundation.dart';
import 'package:aura/models/episode.dart';
import 'package:aura/services/youtube_service.dart';
import 'package:aura/services/jiosaavn_service.dart';

class LinkStreamService {
  final YouTubeService _ytService;
  final JioSaavnService _jioService;

  LinkStreamService({
    YouTubeService? ytService,
    JioSaavnService? jioService,
  })  : _ytService = ytService ?? YouTubeService(),
        _jioService = jioService ?? JioSaavnService();

  /// Resolve an Episode from any YouTube URL, JioSaavn link, direct audio link, or media ID
  Future<Episode?> resolveEpisodeFromUrl(String rawInput) async {
    final input = rawInput.trim();
    if (input.isEmpty) return null;

    // 1. Check if it's a YouTube URL or 11-char video ID
    final ytVideoId = YouTubeService.extractVideoId(input);
    if (ytVideoId != null && (input.contains('youtu') || RegExp(r'^[a-zA-Z0-9_-]{11}$').hasMatch(input))) {
      debugPrint('[LinkStreamService] Detected YouTube link/id: $ytVideoId');
      final episode = await _ytService.getEpisodeFromUrlOrId(input);
      if (episode != null) return episode;
    }

    // 2. Check if it's a JioSaavn URL
    if (input.contains('jiosaavn.com')) {
      debugPrint('[LinkStreamService] Detected JioSaavn link: $input');
      final episode = await _resolveJioSaavnUrl(input);
      if (episode != null) return episode;
    }

    // 3. Check if it's a direct audio/stream file link (.mp3, .m4a, .aac, .ogg, .wav, etc.)
    final lower = input.toLowerCase();
    final hasAudioExtension = lower.endsWith('.mp3') ||
        lower.endsWith('.m4a') ||
        lower.endsWith('.aac') ||
        lower.endsWith('.ogg') ||
        lower.endsWith('.wav') ||
        lower.endsWith('.flac');

    if (hasAudioExtension || input.contains('audio') || input.contains('stream')) {
      debugPrint('[LinkStreamService] Detected direct stream link: $input');
      return Episode(
        id: 'stream_${DateTime.now().millisecondsSinceEpoch}',
        name: _extractTitleFromUrl(input),
        description: 'Web Audio Stream: $input',
        showId: 'web_stream',
        showName: 'Direct Audio Stream',
        imageUrl: 'https://images.unsplash.com/photo-1511671782779-c97d3d27a1d4?w=500',
        url: input,
        isYouTube: false,
      );
    }

    // 4. Try YouTube search if user passed a video title or general link
    try {
      debugPrint('[LinkStreamService] Falling back to YouTube search for: $input');
      final ytResults = await _ytService.searchPodcasts(input, limit: 1);
      if (ytResults.isNotEmpty && ytResults.first.youtubeId != null) {
        return await _ytService.getEpisodeFromUrlOrId(ytResults.first.youtubeId!);
      }
    } catch (e) {
      debugPrint('[LinkStreamService] YouTube fallback error: $e');
    }

    return null;
  }

  Future<Episode?> _resolveJioSaavnUrl(String url) async {
    try {
      final uri = Uri.tryParse(url);
      if (uri == null) return null;

      final segments = uri.pathSegments.where((s) => s.isNotEmpty).toList();
      if (segments.isEmpty) return null;

      // /shows/<show-slug>/<season>/<token>
      final showIdx = segments.indexOf('shows');
      if (showIdx != -1 && segments.length > showIdx + 1) {
        final slug = segments[showIdx + 1].replaceAll('-', ' ').replaceAll('_', ' ');
        debugPrint('[LinkStreamService] Searching JioSaavn for show slug: $slug');
        final shows = await _jioService.searchShows(slug, limit: 3);
        if (shows.isNotEmpty) {
          final targetShow = shows.first;
          final epPage = await _jioService.getEpisodes(targetShow.id, limit: 1);
          if (epPage.episodes.isNotEmpty) {
            return epPage.episodes.first;
          }
        }
      }

      // /song/<song-slug>/<token>
      final songIdx = segments.indexOf('song');
      if (songIdx != -1 && segments.length > songIdx + 1) {
        final slug = segments[songIdx + 1].replaceAll('-', ' ').replaceAll('_', ' ');
        debugPrint('[LinkStreamService] Searching JioSaavn for song slug: $slug');
        final shows = await _jioService.searchShows(slug, limit: 3);
        if (shows.isNotEmpty) {
          final epPage = await _jioService.getEpisodes(shows.first.id, limit: 1);
          if (epPage.episodes.isNotEmpty) {
            return epPage.episodes.first;
          }
        }
      }
    } catch (e) {
      debugPrint('[LinkStreamService] _resolveJioSaavnUrl error: $e');
    }
    return null;
  }

  String _extractTitleFromUrl(String url) {
    try {
      final uri = Uri.tryParse(url);
      if (uri != null && uri.pathSegments.isNotEmpty) {
        final filename = uri.pathSegments.last;
        final nameWithoutExt = filename.split('.').first;
        final cleaned = Uri.decodeComponent(nameWithoutExt).replaceAll(RegExp(r'[-_]'), ' ');
        if (cleaned.trim().isNotEmpty) {
          return cleaned.trim();
        }
      }
    } catch (_) {}
    return 'Custom Audio Stream';
  }
}
