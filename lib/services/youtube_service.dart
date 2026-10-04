import 'package:flutter/foundation.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import 'package:aura/models/podcast.dart';
import 'package:aura/models/episode.dart';
import 'package:aura/services/jiosaavn_service.dart';

class YouTubeService {
  final YoutubeExplode _yt = YoutubeExplode();

  /// Search YouTube for podcast videos or channels
  Future<List<Podcast>> searchPodcasts(String query, {int limit = 20}) async {
    try {
      final q = query.toLowerCase().contains('podcast') ? query : '$query podcast';
      final searchResults = await _yt.search.search(
        q,
        filter: TypeFilters.video,
      );
      final podcasts = <Podcast>[];

      for (final video in searchResults.take(limit)) {
        // Wrap per-video: YouTube API occasionally returns malformed data for
        // livestreams (e.g. "Streamed" as viewCount → FormatException, or a
        // missing map key → NoSuchMethodError on getT). Skip bad entries
        // instead of aborting the whole search.
        try {
          // Access fields that may throw for malformed livestream results
          final title = video.title;
          final author = video.author;
          final description = video.description;
          final thumbHigh = video.thumbnails.highResUrl;
          final thumbMax = video.thumbnails.maxResUrl;
          final url = video.url;
          final id = video.id.value;

          podcasts.add(
            Podcast(
              id: 'yt_vid_$id',
              name: title,
              description: 'Channel: $author\n$description',
              imageUrl: thumbHigh,
              headerImageUrl: thumbMax,
              totalEpisodes: 1,
              url: url,
              isYouTube: true,
              youtubeId: id,
              channelName: author,
            ),
          );
        } catch (videoErr) {
          debugPrint('[YouTubeService] Skipping malformed video result: $videoErr');
        }
      }

      return podcasts;
    } catch (e) {
      debugPrint('[YouTubeService] searchPodcasts error: $e');
      return [];
    }
  }

  /// Get episodes for a YouTube podcast item
  Future<EpisodePage> getEpisodes(Podcast podcast) async {
    try {
      if (podcast.youtubeId != null) {
        final videoId = podcast.youtubeId!;
        final video = await _yt.videos.get(videoId);

        final episode = Episode(
          id: 'yt_ep_${video.id.value}',
          name: video.title,
          description: video.description,
          duration: video.duration?.inSeconds,
          releaseDate: video.uploadDate?.toIso8601String().substring(0, 10),
          imageUrl: video.thumbnails.highResUrl,
          showId: podcast.id,
          showName: video.author,
          isYouTube: true,
          youtubeVideoId: video.id.value,
          url: video.url,
        );

        return EpisodePage(episodes: [episode], hasMore: false, page: 1);
      }

      return const EpisodePage(episodes: [], hasMore: false, page: 1);
    } catch (e) {
      debugPrint('[YouTubeService] getEpisodes error: $e');
      return const EpisodePage(episodes: [], hasMore: false, page: 1);
    }
  }

  /// Get audio stream for a YouTube video — returns a byte stream directly
  Future<Stream<List<int>>?> getAudioStream(String videoId) async {
    try {
      final manifest = await _yt.videos.streamsClient
          .getManifest(videoId)
          .timeout(const Duration(seconds: 30));
      final audioOnly = manifest.audioOnly;
      if (audioOnly.isEmpty) return null;

      final bestAudio = audioOnly.withHighestBitrate();
      return _yt.videos.streamsClient.get(bestAudio);
    } catch (e) {
      debugPrint('[YouTubeService] getAudioStream error: $e');
      return null;
    }
  }

  /// Get direct stream URL for a YouTube video.
  /// Prioritizes muxed streams (audio + video, e.g. itag 18 MP4) because YouTube
  /// CDN enforces bot/PO-token checks that reject standalone adaptive audio-only
  /// streams with HTTP 403 Forbidden. Muxed streams are progressive MP4 downloads
  /// that stream reliably and libmpv/media_kit plays the audio track effortlessly.
  Future<String?> getAudioStreamUrl(String videoId) async {
    try {
      debugPrint('[YouTubeService] Fetching manifest for $videoId');
      final manifest = await _yt.videos.streamsClient
          .getManifest(videoId)
          .timeout(const Duration(seconds: 30));

      // 1. Prioritize muxed streams (e.g. itag 18, 360p MP4 with AAC stereo audio).
      // Progressive download avoids YouTube CDN's 403 Forbidden botguard restrictions.
      final muxed = manifest.muxed;
      if (muxed.isNotEmpty) {
        final mp4Muxed = muxed.where((s) => s.container.name == 'mp4');
        final best = mp4Muxed.isNotEmpty
            ? mp4Muxed.withHighestBitrate()
            : muxed.withHighestBitrate();
        final url = best.url.toString();
        debugPrint(
          '[YouTubeService] Muxed stream URL: $url (itag ${best.tag}, ${best.bitrate}, ${best.container.name})',
        );
        return url;
      }

      // 2. Fall back to audio-only streams if no muxed stream is available.
      final audioOnly = manifest.audioOnly;
      if (audioOnly.isNotEmpty) {
        final mp4 = audioOnly.where((s) => s.container.name == 'mp4');
        final best = mp4.isNotEmpty
            ? mp4.withHighestBitrate()
            : audioOnly.withHighestBitrate();
        final url = best.url.toString();
        debugPrint(
          '[YouTubeService] Audio-only fallback URL: $url (${best.bitrate}, ${best.container.name})',
        );
        return url;
      }

      debugPrint('[YouTubeService] No streams found for $videoId');
      return null;
    } catch (e) {
      debugPrint('[YouTubeService] getAudioStreamUrl error for $videoId: $e');
      return null;
    }
  }

  /// Extract video ID from any YouTube URL (watch, youtu.be, shorts, embed, live) or raw ID
  static String? extractVideoId(String input) {
    final trimmed = input.trim();
    if (trimmed.isEmpty) return null;

    // Direct 11-char ID (standard YouTube video ID)
    if (RegExp(r'^[a-zA-Z0-9_-]{11}$').hasMatch(trimmed)) {
      return trimmed;
    }

    try {
      final uri = Uri.tryParse(trimmed);
      if (uri != null) {
        // Query param ?v=...
        if (uri.queryParameters.containsKey('v')) {
          final v = uri.queryParameters['v'];
          if (v != null && v.isNotEmpty) return v;
        }

        // Shortened youtu.be/ID
        if (uri.host.contains('youtu.be')) {
          final segs = uri.pathSegments.where((s) => s.isNotEmpty).toList();
          if (segs.isNotEmpty) return segs.first;
        }

        // Paths like /shorts/ID, /live/ID, /embed/ID, /v/ID
        final segs = uri.pathSegments.where((s) => s.isNotEmpty).toList();
        if (segs.length >= 2) {
          final first = segs[0].toLowerCase();
          if (first == 'shorts' || first == 'live' || first == 'embed' || first == 'v') {
            return segs[1];
          }
        }
      }
    } catch (_) {}

    // Regex fallback
    final regExp = RegExp(
      r'(?:youtube\.com\/(?:[^\/\n\s]+\/\S+\/|(?:v|e(?:mbed)?|shorts|live)\/|.*[?&]v=)|youtu\.be\/)([a-zA-Z0-9_-]{11})',
      caseSensitive: false,
    );
    final match = regExp.firstMatch(trimmed);
    if (match != null && match.groupCount >= 1) {
      return match.group(1);
    }

    return null;
  }

  /// Fetches video details from a YouTube URL or ID and converts it to an Episode
  Future<Episode?> getEpisodeFromUrlOrId(String input) async {
    try {
      final videoId = extractVideoId(input);
      if (videoId == null) return null;

      final video = await _yt.videos.get(videoId);
      return Episode(
        id: 'yt_ep_${video.id.value}',
        name: video.title,
        description: video.description,
        duration: video.duration?.inSeconds,
        releaseDate: video.uploadDate?.toIso8601String().substring(0, 10),
        imageUrl: video.thumbnails.highResUrl,
        showId: video.channelId.value,
        showName: video.author,
        isYouTube: true,
        youtubeVideoId: video.id.value,
        url: video.url,
      );
    } catch (e) {
      debugPrint('[YouTubeService] getEpisodeFromUrlOrId error: $e');
      return null;
    }
  }

  void dispose() {
    _yt.close();
  }
}
