import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:media_kit/media_kit.dart';
import 'package:audio_session/audio_session.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:aura/models/episode.dart';
import 'package:aura/services/youtube_service.dart';
import 'package:aura/services/youtube_proxy.dart';
import 'package:aura/services/aura_audio_handler.dart';

enum PlaybackState { idle, loading, playing, paused, stopped, error }

class AudioProvider extends ChangeNotifier {
  final Player _player = Player();
  final YouTubeService _ytService = YouTubeService();
  final List<StreamSubscription<dynamic>> _subscriptions = [];
  Timer? _bufferTimeout;
  final YouTubeLocalProxy _proxy = YouTubeLocalProxy();
  final AuraAudioHandler? audioHandler;

  Episode? _currentEpisode;
  List<Episode> _queue = [];
  int _queueIndex = 0;
  PlaybackState _state = PlaybackState.idle;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  double _speed = 1.0;
  String? _error;

  // History & Favorites
  final List<Episode> _history = [];
  final Set<String> _favoriteIds = {};

  // Sleep timer
  DateTime? _sleepUntil;

  // Getters
  Episode? get currentEpisode => _currentEpisode;
  List<Episode> get queue => List.unmodifiable(_queue);
  PlaybackState get state => _state;
  Duration get position => _position;
  Duration get duration => _duration;
  double get speed => _speed;
  String? get error => _error;
  bool get isPlaying => _state == PlaybackState.playing;
  bool get isLoading => _state == PlaybackState.loading;
  bool get hasEpisode => _currentEpisode != null;

  List<Episode> get history => List.unmodifiable(_history);
  Set<String> get favoriteIds => Set.unmodifiable(_favoriteIds);
  bool isFavorite(String id) => _favoriteIds.contains(id);

  double get progress {
    if (_duration.inMilliseconds == 0) return 0;
    return (_position.inMilliseconds / _duration.inMilliseconds).clamp(0.0, 1.0);
  }

  bool get hasPrevious => _queueIndex > 0;
  bool get hasNext => _queueIndex < _queue.length - 1;
  int get queueIndex => _queueIndex;

  AudioProvider({this.audioHandler}) {
    _init();
  }

  void _syncAudioHandler() {
    audioHandler?.updatePlaybackState(
      isPlaying: isPlaying,
      position: _position,
      duration: _duration,
      speed: _speed,
      isLoading: isLoading,
    );
  }

  Future<void> _init() async {
    _loadHistoryAndFavorites();

    if (audioHandler != null) {
      audioHandler!.onPlay = resume;
      audioHandler!.onPause = pause;
      audioHandler!.onStop = stop;
      audioHandler!.onSeek = seekTo;
      audioHandler!.onSkipNext = () {
        if (hasNext) playNext();
      };
      audioHandler!.onSkipPrevious = () {
        if (hasPrevious) playPrevious();
      };
      audioHandler!.onFastForward = skipForward;
      audioHandler!.onRewind = skipBackward;
    }

    // Configure audio session (mobile/desktop only)
    if (!kIsWeb) {
      try {
        final session = await AudioSession.instance;
        await session.configure(const AudioSessionConfiguration.music());
      } catch (e) {
        debugPrint('AudioSession not available: $e');
      }
    }

    // Listen to buffering state — MUST be subscribed before playing so we
    // correctly track both the start and end of buffering.
    _subscriptions.add(_player.stream.buffering.listen((buffering) {
      if (buffering) {
        _state = PlaybackState.loading;
      } else {
        // Buffering ended — cancel watchdog and resolve to playing/paused.
        _bufferTimeout?.cancel();
        if (_state == PlaybackState.loading) {
          _error = null;
          _state = _player.state.playing
              ? PlaybackState.playing
              : PlaybackState.paused;
        }
      }
      _syncAudioHandler();
      notifyListeners();
    }));

    // Listen to playing state — always honour this event regardless of
    // current state so the UI never gets stuck on the loading spinner.
    _subscriptions.add(_player.stream.playing.listen((playing) {
      // While media_kit is buffering, its playing flag may briefly toggle;
      // only update state when we are NOT in the middle of a buffer.
      if (!_player.state.buffering) {
        _bufferTimeout?.cancel();
        if (playing) {
          _error = null;
        }
        _state = playing ? PlaybackState.playing : PlaybackState.paused;
        _syncAudioHandler();
        notifyListeners();
      }
    }));

    // Listen to position
    _subscriptions.add(_player.stream.position.listen((pos) {
      _position = pos;
      if (pos > Duration.zero) {
        if (_error != null || _state == PlaybackState.error) {
          _error = null;
          _state = _player.state.playing ? PlaybackState.playing : PlaybackState.paused;
        }
      }
      _checkSleepTimer();
      _syncAudioHandler();
      notifyListeners();
    }));

    // Listen to duration
    _subscriptions.add(_player.stream.duration.listen((dur) {
      _duration = dur;
      if (_currentEpisode != null) {
        audioHandler?.updateItem(_currentEpisode!, dur);
      }
      _syncAudioHandler();
      notifyListeners();
    }));

    // Listen to completion
    _subscriptions.add(_player.stream.completed.listen((completed) {
      if (completed) {
        _onEpisodeComplete();
      }
    }));

    // Listen to player errors (silent MPV failures show up here)
    _subscriptions.add(_player.stream.error.listen((error) {
      if (error.isNotEmpty) {
        debugPrint('[AudioProvider] Player stream error: $error');
        final lower = error.toLowerCase();
        // Ignore benign Android OpenSLES configuration logs or warnings
        if (lower.contains('unknown key') ||
            lower.contains('sl_result') ||
            lower.contains('configuration error') ||
            lower.contains('androidconfiguration') ||
            lower.contains('opensles') ||
            lower.contains('throttle time')) {
          debugPrint('[AudioProvider] Ignoring benign platform audio configuration log: $error');
          return;
        }

        // If the player is actively playing or audio position is advancing,
        // ignore background socket teardowns or transient connection closes.
        if (_player.state.playing || _position > Duration.zero) {
          debugPrint('[AudioProvider] Ignoring transient error while actively playing: $error');
          return;
        }
        // Give media_kit 6.0 seconds to settle: if it starts playing or position
        // advances (e.g. after recovering from probe socket closure or following CDN redirects), suppress the error.
        Future.delayed(const Duration(milliseconds: 6000), () {
          if (_player.state.playing || _position > Duration.zero) {
            debugPrint('[AudioProvider] Recovered from transient error: $error');
            return;
          }
          if (_state == PlaybackState.loading) {
            _bufferTimeout?.cancel();
            _state = PlaybackState.error;
            _error = 'Playback failed: $error';
            _syncAudioHandler();
            notifyListeners();
          }
        });
      }
    }));
  }

  // ─── Playback Controls ────────────────────────────────────

  // Headers for regular (non-YouTube) audio streams
  static const _audioHeaders = {
    'User-Agent':
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36',
  };

  Future<void> play(Episode episode, {List<Episode>? queue, int? queueIndex}) async {
    try {
      _error = null;
      _state = PlaybackState.loading;
      _currentEpisode = episode;
      _addToHistory(episode);
      // Reset position / duration immediately so the UI looks fresh.
      _position = Duration.zero;
      _duration = episode.duration != null ? Duration(seconds: episode.duration!) : Duration.zero;
      audioHandler?.updateItem(episode, _duration);
      _syncAudioHandler();

      if (queue != null) {
        _queue = queue;
        _queueIndex = queueIndex ?? queue.indexOf(episode);
        if (_queueIndex < 0) _queueIndex = 0;
      } else {
        _queue = [episode];
        _queueIndex = 0;
      }

      notifyListeners();

      String? audioUrl = episode.localPath ?? episode.streamUrl;
      if (audioUrl != null) {
        audioUrl = audioUrl.trim();
        if (audioUrl.isEmpty) {
          audioUrl = null;
        } else {
          if (audioUrl.startsWith('http://')) {
            audioUrl = audioUrl.replaceFirst('http://', 'https://');
          }
          try {
            audioUrl = Uri.encodeFull(audioUrl);
          } catch (_) {}
        }
      }

      String? ytUrl;
      if (episode.isYouTube && episode.youtubeVideoId != null) {
        debugPrint('[AudioProvider] Fetching YouTube audio stream for ${episode.youtubeVideoId}');
        ytUrl = await _ytService.getAudioStreamUrl(episode.youtubeVideoId!);
        if (ytUrl == null) {
          throw Exception('Could not get YouTube audio stream URL. The video may be unavailable or restricted.');
        }
        debugPrint('[AudioProvider] Got YouTube URL, opening player...');
      }

      // If no audio source at all, bail out cleanly.
      if (episode.localPath == null && ytUrl == null && audioUrl == null) {
        throw Exception('No audio URL available for this episode');
      }

      if (episode.localPath != null) {
        await _proxy.stop();
        debugPrint('[AudioProvider] Playing local file: ${episode.localPath}');
        await _player.open(Media(episode.localPath!));
      } else if (ytUrl != null) {
        // Use local HTTP proxy: Dart's HttpClient authenticates with the
        // YouTube CDN; libmpv just reads from http://127.0.0.1:PORT.
        // This bypasses all libmpv/Android CDN compatibility issues.
        debugPrint('[AudioProvider] Starting local proxy for YouTube...');
        final proxyUrl = await _proxy.serve(ytUrl);
        debugPrint('[AudioProvider] Opening via proxy: $proxyUrl');
        await _player.open(Media(proxyUrl));
        // 30-second watchdog in case the proxy or network is unresponsive.
        _bufferTimeout?.cancel();
        _bufferTimeout = Timer(const Duration(seconds: 30), () {
          if (_state == PlaybackState.loading) {
            debugPrint('[AudioProvider] YouTube buffer timeout — giving up');
            _state = PlaybackState.error;
            _error = 'Playback timed out. The video may be geo-restricted or unavailable.';
            notifyListeners();
          }
        });
      } else {
        await _proxy.stop();
        final isYouTubeUrl = audioUrl!.contains('googlevideo.com') ||
            audioUrl.contains('youtube.com');
        final media = isYouTubeUrl
            ? Media(audioUrl, httpHeaders: _audioHeaders)
            : Media(audioUrl, httpHeaders: _audioHeaders);
        debugPrint('[AudioProvider] Opening stream: $audioUrl');
        await _player.open(media);

        // 25-second watchdog in case the stream server is completely unresponsive.
        _bufferTimeout?.cancel();
        _bufferTimeout = Timer(const Duration(seconds: 25), () {
          if (_state == PlaybackState.loading) {
            debugPrint('[AudioProvider] Stream buffer timeout — giving up');
            _state = PlaybackState.error;
            _error = 'Audio playback timed out. Please check your internet connection.';
            notifyListeners();
          }
        });
      }

      await _player.setRate(_speed);
      // _player.open() is non-blocking — the buffering/playing listeners
      // will update state as the media loads.
    } catch (e) {
      debugPrint('[AudioProvider] Playback error: $e');
      _bufferTimeout?.cancel();
      _state = PlaybackState.error;
      _error = e.toString();
      notifyListeners();
    }
  }

  Future<void> resume() async {
    if (_currentEpisode != null) {
      if (_state == PlaybackState.idle || _state == PlaybackState.error) {
        await play(_currentEpisode!, queue: _queue, queueIndex: _queueIndex);
      } else {
        _error = null;
        await _player.play();
      }
    }
  }

  Future<void> pause() async {
    await _player.pause();
    _syncAudioHandler();
  }

  Future<void> stop() async {
    await _player.stop();
    _state = PlaybackState.stopped;
    _syncAudioHandler();
    notifyListeners();
  }

  Future<void> togglePlayPause() async {
    if (_player.state.playing) {
      await pause();
    } else {
      await resume();
    }
  }

  Future<void> seekTo(Duration position) async {
    await _player.seek(position);
  }

  Future<void> seekRelative(Duration offset) async {
    final newPos = _position + offset;
    final clamped = newPos < Duration.zero
        ? Duration.zero
        : newPos > _duration
            ? _duration
            : newPos;
    await seekTo(clamped);
  }

  Future<void> skipForward() => seekRelative(const Duration(seconds: 30));
  Future<void> skipBackward() => seekRelative(const Duration(seconds: -15));

  Future<void> setSpeed(double speed) async {
    _speed = speed;
    await _player.setRate(speed);
    notifyListeners();
  }

  Future<void> playNext() async {
    if (!hasNext) return;
    _queueIndex++;
    await play(_queue[_queueIndex], queue: _queue, queueIndex: _queueIndex);
  }

  Future<void> playPrevious() async {
    if (_position.inSeconds > 3) {
      await seekTo(Duration.zero);
      return;
    }
    if (!hasPrevious) return;
    _queueIndex--;
    await play(_queue[_queueIndex], queue: _queue, queueIndex: _queueIndex);
  }

  void addToQueue(Episode episode) {
    if (!_queue.any((e) => e.id == episode.id)) {
      _queue.add(episode);
      notifyListeners();
    }
  }

  void playAsNext(Episode episode) {
    _queue.removeWhere((e) => e.id == episode.id);
    final insertIndex = (_queueIndex + 1).clamp(0, _queue.length);
    _queue.insert(insertIndex, episode);
    notifyListeners();
  }

  void removeFromQueue(int index) {
    if (index >= 0 && index < _queue.length && index != _queueIndex) {
      _queue.removeAt(index);
      if (index < _queueIndex) {
        _queueIndex--;
      }
      notifyListeners();
    }
  }

  void clearQueue() {
    if (_currentEpisode != null) {
      _queue = [_currentEpisode!];
      _queueIndex = 0;
    } else {
      _queue.clear();
      _queueIndex = 0;
    }
    notifyListeners();
  }

  Future<void> jumpToQueueIndex(int index) async {
    if (index >= 0 && index < _queue.length) {
      _queueIndex = index;
      await play(_queue[index], queue: _queue, queueIndex: index);
    }
  }

  // ─── Sleep Timer ──────────────────────────────────────────

  void setSleepTimer(Duration duration) {
    _sleepUntil = DateTime.now().add(duration);
    notifyListeners();
  }

  void cancelSleepTimer() {
    _sleepUntil = null;
    notifyListeners();
  }

  Duration? get sleepRemaining {
    if (_sleepUntil == null) return null;
    final remaining = _sleepUntil!.difference(DateTime.now());
    return remaining.isNegative ? null : remaining;
  }

  void _checkSleepTimer() {
    if (_sleepUntil != null && DateTime.now().isAfter(_sleepUntil!)) {
      _sleepUntil = null;
      pause();
    }
  }

  // ─── Lifecycle ────────────────────────────────────────────

  void _onEpisodeComplete() {
    if (hasNext) {
      playNext();
    } else {
      _state = PlaybackState.idle;
      notifyListeners();
    }
  }

  // ─── History & Favorites ───────────────────────────────────

  void _addToHistory(Episode ep) {
    _history.removeWhere((e) => e.id == ep.id);
    _history.insert(0, ep);
    if (_history.length > 30) {
      _history.removeLast();
    }
    _saveHistory();
  }

  Future<void> _loadHistoryAndFavorites() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final historyJson = prefs.getStringList('listening_history') ?? [];
      _history.clear();
      for (final raw in historyJson) {
        try {
          final map = jsonDecode(raw) as Map<String, dynamic>;
          _history.add(Episode.fromJson(map));
        } catch (_) {}
      }

      final favs = prefs.getStringList('favorite_podcast_ids') ?? [];
      _favoriteIds.clear();
      _favoriteIds.addAll(favs);
      notifyListeners();
    } catch (_) {}
  }

  Future<void> _saveHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = _history.map((e) => jsonEncode(e.toJson())).toList();
      await prefs.setStringList('listening_history', list);
    } catch (_) {}
  }

  Future<void> toggleFavorite(String id) async {
    if (_favoriteIds.contains(id)) {
      _favoriteIds.remove(id);
    } else {
      _favoriteIds.add(id);
    }
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList('favorite_podcast_ids', _favoriteIds.toList());
    } catch (_) {}
  }

  Future<void> removeFromHistory(String episodeId) async {
    _history.removeWhere((e) => e.id == episodeId);
    notifyListeners();
    _saveHistory();
  }

  Future<void> clearHistory() async {
    _history.clear();
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('listening_history');
    } catch (_) {}
  }

  @override
  void dispose() {
    _bufferTimeout?.cancel();
    for (final s in _subscriptions) {
      s.cancel();
    }
    _subscriptions.clear();
    _proxy.dispose();
    _ytService.dispose();
    _player.dispose();
    super.dispose();
  }
}
