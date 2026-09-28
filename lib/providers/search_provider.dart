import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:aura/models/podcast.dart';
import 'package:aura/models/episode.dart';
import 'package:aura/models/podcaster.dart';
import 'package:aura/services/jiosaavn_service.dart';
import 'package:aura/services/youtube_service.dart';

enum SearchState { idle, loading, loaded, error }
enum SearchSourceFilter { all, jiosaavn, youtube }

class SearchProvider extends ChangeNotifier {
  final JioSaavnService _jioService;
  final YouTubeService _ytService;

  SearchProvider({
    JioSaavnService? jioService,
    YouTubeService? ytService,
  })  : _jioService = jioService ?? JioSaavnService(),
        _ytService = ytService ?? YouTubeService();

  SearchState _state = SearchState.idle;
  SearchSourceFilter _filter = SearchSourceFilter.all;
  List<Podcast> _results = [];
  String _query = '';
  String? _error;

  Timer? _debounceTimer;
  int _searchCounter = 0;

  // Trending / Curated Sections
  List<Podcast> _trending = [];
  List<Podcast> _trendingJio = [];
  List<Podcast> _trendingYouTube = [];
  List<Podcast> _featuredPodcasts = [];
  List<Podcast> _hotPicks = [];
  List<Podcast> _freshReleases = [];
  List<Podcast> _underratedGems = [];
  List<Podcast> _liveOrPremiere = [];
  String _discoverFilter = 'all'; // 'all', 'youtube', 'jiosaavn'
  bool _loadingTrending = false;

  // Podcasters
  final List<Podcaster> _allPodcasters = Podcaster.curatedList;
  String _podcasterRegion = 'all'; // 'all', 'india', 'global'

  SearchState get state => _state;
  SearchSourceFilter get filter => _filter;
  List<Podcast> get results {
    if (_filter == SearchSourceFilter.jiosaavn) {
      return _results.where((p) => !p.isYouTube).toList();
    }
    if (_filter == SearchSourceFilter.youtube) {
      return _results.where((p) => p.isYouTube).toList();
    }
    return _results;
  }
  String get query => _query;
  String? get error => _error;
  List<Podcast> get trending => _trending;
  List<Podcast> get trendingJio => _trendingJio;
  List<Podcast> get trendingYouTube => _trendingYouTube;
  List<Podcast> get featuredPodcasts => _featuredPodcasts;
  List<Podcast> get hotPicks => _hotPicks;
  List<Podcast> get freshReleases => _freshReleases;
  List<Podcast> get underratedGems => _underratedGems;
  List<Podcast> get liveOrPremiere => _liveOrPremiere;
  String get discoverFilter => _discoverFilter;
  String get podcasterRegion => _podcasterRegion;
  bool get loadingTrending => _loadingTrending;
  bool get hasResults => results.isNotEmpty;
  bool get isSearching => _query.isNotEmpty;

  List<Podcaster> get podcasters {
    if (_podcasterRegion == 'india') {
      return _allPodcasters.where((p) => p.region.toLowerCase() == 'india').toList();
    }
    if (_podcasterRegion == 'global') {
      return _allPodcasters.where((p) => p.region.toLowerCase() == 'global').toList();
    }
    return _allPodcasters;
  }

  void setPodcasterRegion(String region) {
    if (_podcasterRegion == region) return;
    _podcasterRegion = region;
    notifyListeners();
  }

  void setDiscoverFilter(String filter) {
    if (_discoverFilter == filter) return;
    _discoverFilter = filter;
    notifyListeners();
  }

  List<Podcast> getSuggestionsForUser(List<Episode> history) {
    if (history.isEmpty) {
      return _hotPicks.isNotEmpty ? _hotPicks : _trending;
    }
    // Match based on creators/shows the user recently listened to
    final listenedShowNames = history.map((e) => e.showName.toLowerCase()).toSet();
    final matches = _trending.where((p) {
      final name = p.name.toLowerCase();
      final channel = (p.channelName ?? '').toLowerCase();
      return listenedShowNames.any((s) => name.contains(s) || channel.contains(s));
    }).toList();

    if (matches.isNotEmpty) {
      return matches;
    }
    return _hotPicks.isNotEmpty ? _hotPicks : _trending;
  }

  void setFilter(SearchSourceFilter filter) {
    if (_filter == filter) return;
    _filter = filter;
    notifyListeners();
    if (_query.isNotEmpty) {
      searchNow(_query);
    }
  }

  void search(String query) {
    _debounceTimer?.cancel();
    final trimmed = query.trim();
    if (trimmed.isEmpty) {
      clear();
      return;
    }
    _query = query;

    // 350ms debounce stops rapid typing from firing multiple overlapping requests
    _debounceTimer = Timer(const Duration(milliseconds: 350), () {
      _executeSearch(trimmed);
    });
  }

  void searchNow(String query) {
    _debounceTimer?.cancel();
    final trimmed = query.trim();
    if (trimmed.isEmpty) {
      clear();
      return;
    }
    _query = query;
    _executeSearch(trimmed);
  }

  Future<void> _executeSearch(String query) async {
    final requestId = ++_searchCounter;
    _state = SearchState.loading;
    _error = null;
    notifyListeners();

    try {
      final List<Podcast> jioResults;
      final List<Podcast> ytResults;

      if (_filter == SearchSourceFilter.jiosaavn) {
        jioResults = await _jioService.searchShows(query);
        ytResults = [];
      } else if (_filter == SearchSourceFilter.youtube) {
        jioResults = [];
        ytResults = await _ytService.searchPodcasts(query);
      } else {
        final res = await Future.wait([
          _jioService.searchShows(query).catchError((_) => <Podcast>[]),
          _ytService.searchPodcasts(query).catchError((_) => <Podcast>[]),
        ]);
        jioResults = res[0];
        ytResults = res[1];
      }

      // If a newer search was initiated, discard this stale response to prevent fluctuation
      if (requestId != _searchCounter || _query.trim() != query) {
        return;
      }

      // Interleave results smoothly
      final combined = <Podcast>[];
      final maxLen = jioResults.length > ytResults.length
          ? jioResults.length
          : ytResults.length;
      for (int i = 0; i < maxLen; i++) {
        if (i < jioResults.length) combined.add(jioResults[i]);
        if (i < ytResults.length) combined.add(ytResults[i]);
      }

      _results = combined;
      _state = SearchState.loaded;
    } catch (e) {
      if (requestId != _searchCounter) return;
      _error = _friendlyError(e);
      _state = SearchState.error;
    }
    notifyListeners();
  }

  List<Podcast> _diversifyByChannel(List<Podcast> list, {int maxPerChannel = 1}) {
    final counts = <String, int>{};
    final primary = <Podcast>[];
    final secondary = <Podcast>[];

    for (final p in list) {
      final ch = (p.channelName ?? p.name).toLowerCase().trim();
      final current = counts[ch] ?? 0;
      if (current < maxPerChannel) {
        counts[ch] = current + 1;
        primary.add(p);
      } else {
        secondary.add(p);
      }
    }

    if (primary.length < 6) {
      primary.addAll(secondary.take(6 - primary.length));
    }
    return primary;
  }

  Future<void> loadTrending({bool force = false}) async {
    if (_loadingTrending) return;

    // Daily auto-refresh check
    final now = DateTime.now();
    final todayStr = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    SharedPreferences? prefs;
    try {
      prefs = await SharedPreferences.getInstance();
      final lastDate = prefs.getString('last_trending_date');
      if (lastDate != todayStr) {
        force = true;
      }
    } catch (_) {}

    if (!force && (_trendingJio.isNotEmpty || _trendingYouTube.isNotEmpty)) return;
    _loadingTrending = true;
    notifyListeners();

    try {
      final results = await Future.wait([
        _jioService.getTrending().catchError((e) {
          debugPrint('[SearchProvider] JioSaavn getTrending error: $e');
          return <Podcast>[];
        }),
        _ytService.searchPodcasts('The Ranveer Show OR Huberman Lab OR WTF Nikhil Kamath full podcast', limit: 12).catchError((e) {
          debugPrint('[SearchProvider] YouTube trending error: $e');
          return <Podcast>[];
        }),
        _jioService.getUnderratedShows().catchError((e) {
          debugPrint('[SearchProvider] JioSaavn underrated error: $e');
          return <Podcast>[];
        }),
        _ytService.searchPodcasts('The Joe Rogan Experience OR Lex Fridman OR Tanmay Bhat podcast', limit: 12).catchError((e) {
          debugPrint('[SearchProvider] YouTube hot picks error: $e');
          return <Podcast>[];
        }),
        _ytService.searchPodcasts('new podcast episode today full episode', limit: 10).catchError((e) {
          debugPrint('[SearchProvider] YouTube fresh error: $e');
          return <Podcast>[];
        }),
        _ytService.searchPodcasts('live podcast premiere full episode', limit: 8).catchError((e) {
          debugPrint('[SearchProvider] YouTube live error: $e');
          return <Podcast>[];
        }),
      ]);

      _trendingJio = results[0];
      _trendingYouTube = _diversifyByChannel(results[1], maxPerChannel: 1);
      _underratedGems = results[2];
      _hotPicks = _diversifyByChannel(results[3], maxPerChannel: 1);
      _freshReleases = _diversifyByChannel(results[4], maxPerChannel: 1);
      _liveOrPremiere = _diversifyByChannel(results[5], maxPerChannel: 1);

      // Enrich YouTube trending if needed
      if (_trendingYouTube.length < 6) {
        try {
          final moreYt = await _ytService.searchPodcasts('popular full podcast', limit: 8);
          final existingIds = _trendingYouTube.map((p) => p.id).toSet();
          for (final p in moreYt) {
            if (existingIds.add(p.id)) {
              _trendingYouTube.add(p);
            }
          }
        } catch (_) {}
      }

      // Populate featured spotlight
      final featured = <Podcast>[];
      if (_trendingYouTube.isNotEmpty) featured.add(_trendingYouTube.first);
      if (_trendingJio.isNotEmpty) featured.add(_trendingJio.first);
      if (_trendingYouTube.length > 1) featured.add(_trendingYouTube[1]);
      if (_trendingJio.length > 1) featured.add(_trendingJio[1]);
      _featuredPodcasts = featured;

      // Combined list
      final combined = <Podcast>[];
      final maxLen = _trendingJio.length > _trendingYouTube.length
          ? _trendingJio.length
          : _trendingYouTube.length;
      for (int i = 0; i < maxLen; i++) {
        if (i < _trendingYouTube.length) combined.add(_trendingYouTube[i]);
        if (i < _trendingJio.length) combined.add(_trendingJio[i]);
      }
      _trending = combined;

      // Save today's date so tomorrow automatically refreshes
      if (prefs != null) {
        await prefs.setString('last_trending_date', todayStr);
      }
    } catch (e) {
      debugPrint('[SearchProvider] loadTrending error: $e');
    } finally {
      _loadingTrending = false;
      notifyListeners();
    }
  }

  void clear() {
    _debounceTimer?.cancel();
    _query = '';
    _results = [];
    _state = SearchState.idle;
    _error = null;
    notifyListeners();
  }

  String _friendlyError(Object e) {
    if (e is ApiException) return 'Could not load results. Try again.';
    return 'Something went wrong.';
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    super.dispose();
  }
}
