import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:aura/core/constants.dart';
import 'package:aura/models/podcast.dart';
import 'package:aura/models/episode.dart';

class JioSaavnService {
  static const String _base = AppConstants.apiBaseUrl;

  final http.Client _client;

  JioSaavnService({http.Client? client}) : _client = client ?? http.Client();

  // ─── Search ───────────────────────────────────────────────
  Future<List<Podcast>> searchShows(String query, {int limit = 30}) async {
    final uri = Uri.parse('$_base/search').replace(
      queryParameters: {'query': query, 'limit': limit.toString()},
    );
    final response = await _client.get(uri).timeout(const Duration(seconds: 10));
    _checkStatus(response);

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final data = body['data'] as Map<String, dynamic>;
    final shows = data['shows'] as List<dynamic>? ?? [];
    return shows
        .map((s) => Podcast.fromJson(s as Map<String, dynamic>))
        .toList();
  }

  // ─── Show Details ─────────────────────────────────────────
  Future<Podcast> getShowDetails(String showId) async {
    final uri = Uri.parse('$_base/shows/$showId');
    final response = await _client.get(uri).timeout(const Duration(seconds: 10));
    _checkStatus(response);

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    return Podcast.fromJson(body['data'] as Map<String, dynamic>);
  }

  // ─── Episodes ─────────────────────────────────────────────
  Future<EpisodePage> getEpisodes(
    String showId, {
    int season = 1,
    String sort = 'desc',
    int page = 1,
    int limit = 20,
  }) async {
    final uri = Uri.parse('$_base/shows/$showId/episodes').replace(
      queryParameters: {
        'season': season.toString(),
        'sort': sort,
        'page': page.toString(),
        'limit': limit.toString(),
      },
    );
    final response = await _client.get(uri).timeout(const Duration(seconds: 10));
    _checkStatus(response);

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final data = body['data'] as Map<String, dynamic>;
    final results = data['results'] as List<dynamic>? ?? [];
    final hasMore = data['hasMore'] as bool? ?? false;

    return EpisodePage(
      episodes: results
          .map((e) => Episode.fromJson(e as Map<String, dynamic>))
          .toList(),
      hasMore: hasMore,
      page: page,
    );
  }

  // ─── Trending / Featured ──────────────────────────────────
  /// Fetches real, popular podcasts on JioSaavn
  Future<List<Podcast>> getTrending() async {
    final popularTitles = [
      'The Ranveer Show',
      'Finshots Daily',
      'Desi Crime',
      'Maha Bharat Dhruv',
      'Cyrus Says',
      'Kahaani Suno',
    ];
    final results = <Podcast>[];
    for (final title in popularTitles) {
      try {
        final shows = await searchShows(title, limit: 4);
        results.addAll(shows);
      } catch (_) {}
    }
    // deduplicate
    final seen = <String>{};
    return results.where((p) => seen.add(p.id)).toList();
  }

  /// Fetches insightful, hidden gem podcasts
  Future<List<Podcast>> getUnderratedShows() async {
    final gemTitles = [
      'The Seen and the Unseen',
      'Woice with Warikoo',
      'Puri Musings',
      'Indian History Podcast',
      'Gita for Daily Living',
    ];
    final results = <Podcast>[];
    for (final title in gemTitles) {
      try {
        final shows = await searchShows(title, limit: 3);
        results.addAll(shows);
      } catch (_) {}
    }
    final seen = <String>{};
    return results.where((p) => seen.add(p.id)).toList();
  }

  // ─── Helpers ──────────────────────────────────────────────
  void _checkStatus(http.Response response) {
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(
        message: 'Request failed',
        statusCode: response.statusCode,
      );
    }
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    if (body['success'] == false) {
      throw ApiException(message: body['message'] as String? ?? 'Unknown error');
    }
  }
}

class EpisodePage {
  final List<Episode> episodes;
  final bool hasMore;
  final int page;

  const EpisodePage({
    required this.episodes,
    required this.hasMore,
    required this.page,
  });
}

class ApiException implements Exception {
  final String message;
  final int? statusCode;

  const ApiException({required this.message, this.statusCode});

  @override
  String toString() => 'ApiException($statusCode): $message';
}
