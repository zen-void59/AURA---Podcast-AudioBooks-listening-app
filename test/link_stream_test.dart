import 'package:flutter_test/flutter_test.dart';
import 'package:aura/services/youtube_service.dart';
import 'package:aura/services/link_stream_service.dart';

void main() {
  group('YouTubeService.extractVideoId', () {
    test('extracts ID from standard watch URL', () {
      expect(
        YouTubeService.extractVideoId('https://www.youtube.com/watch?v=dQw4w9WgXcQ'),
        'dQw4w9WgXcQ',
      );
    });

    test('extracts ID from youtu.be shortened URL', () {
      expect(
        YouTubeService.extractVideoId('https://youtu.be/dQw4w9WgXcQ'),
        'dQw4w9WgXcQ',
      );
    });

    test('extracts ID from shorts URL', () {
      expect(
        YouTubeService.extractVideoId('https://www.youtube.com/shorts/dQw4w9WgXcQ'),
        'dQw4w9WgXcQ',
      );
    });

    test('extracts ID from live stream URL', () {
      expect(
        YouTubeService.extractVideoId('https://www.youtube.com/live/dQw4w9WgXcQ'),
        'dQw4w9WgXcQ',
      );
    });

    test('extracts raw 11-character video ID', () {
      expect(
        YouTubeService.extractVideoId('dQw4w9WgXcQ'),
        'dQw4w9WgXcQ',
      );
    });
  });

  group('LinkStreamService', () {
    test('resolves direct audio link to an Episode', () async {
      final service = LinkStreamService();
      final ep = await service.resolveEpisodeFromUrl('https://example.com/audio/sample-podcast.mp3');
      expect(ep, isNotNull);
      expect(ep!.url, 'https://example.com/audio/sample-podcast.mp3');
      expect(ep.isYouTube, false);
      expect(ep.name, 'sample podcast');
    });
  });
}
