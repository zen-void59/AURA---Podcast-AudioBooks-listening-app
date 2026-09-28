import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:aura/models/audiobook.dart';
import 'package:aura/providers/audio_provider.dart';
import 'package:aura/services/audiobook_service.dart';

class AudiobookProvider extends ChangeNotifier {
  final AudiobookService _service = AudiobookService();

  // ─── Shelves & Catalog ──────────────────────────────────────────
  List<Audiobook> _featuredBooks = [];
  List<Audiobook> _hindiBooks = [];
  final Map<String, List<Audiobook>> _genreShelves = {};
  bool _isLoading = false;
  String? _error;

  // ─── Search ─────────────────────────────────────────────────────
  String _searchQuery = '';
  List<Audiobook> _searchResults = [];
  bool _isSearching = false;

  // ─── Active Book & Playback Coordination ────────────────────────
  Audiobook? _activeBook;
  int _activeChapterIndex = 0;
  bool _isLoadingDetails = false;

  // ─── Persistence ("My Bookshelf") ──────────────────────────────
  final Map<String, AudiobookProgress> _progressMap = {};
  final Set<String> _savedBookIds = {};
  final List<AudiobookBookmark> _bookmarks = [];
  final Map<String, Audiobook> _knownBooks = {};

  // ─── Getters ────────────────────────────────────────────────────
  List<Audiobook> get featuredBooks => List.unmodifiable(_featuredBooks);
  List<Audiobook> get hindiBooks => List.unmodifiable(_hindiBooks);
  Map<String, List<Audiobook>> get genreShelves => Map.unmodifiable(_genreShelves);
  bool get isLoading => _isLoading;
  String? get error => _error;

  String get searchQuery => _searchQuery;
  List<Audiobook> get searchResults => List.unmodifiable(_searchResults);
  bool get isSearching => _isSearching;

  Audiobook? get activeBook => _activeBook;
  int get activeChapterIndex => _activeChapterIndex;
  bool get isLoadingDetails => _isLoadingDetails;

  AudiobookChapter? get activeChapter {
    if (_activeBook == null || _activeBook!.chapters.isEmpty) return null;
    if (_activeChapterIndex >= 0 && _activeChapterIndex < _activeBook!.chapters.length) {
      return _activeBook!.chapters[_activeChapterIndex];
    }
    return _activeBook!.chapters.first;
  }

  Set<String> get savedBookIds => Set.unmodifiable(_savedBookIds);
  bool isBookSaved(String bookId) => _savedBookIds.contains(bookId);

  List<AudiobookBookmark> get bookmarks => List.unmodifiable(_bookmarks);

  AudiobookProgress? getProgress(String bookId) => _progressMap[bookId];
  Audiobook? getBook(String bookId) => _knownBooks[bookId];

  List<Audiobook> get currentlyListeningBooks {
    final list = _progressMap.values
        .where((p) => !p.isCompleted && _knownBooks.containsKey(p.bookId))
        .map((p) => _knownBooks[p.bookId]!)
        .toList();
    list.sort((a, b) {
      final pa = _progressMap[a.id]?.lastListenedAt ?? DateTime(2000);
      final pb = _progressMap[b.id]?.lastListenedAt ?? DateTime(2000);
      return pb.compareTo(pa);
    });
    return list;
  }

  List<Audiobook> get savedBooks {
    return _savedBookIds
        .where((id) => _knownBooks.containsKey(id))
        .map((id) => _knownBooks[id]!)
        .toList();
  }

  List<Audiobook> get completedBooks {
    return _progressMap.values
        .where((p) => p.isCompleted && _knownBooks.containsKey(p.bookId))
        .map((p) => _knownBooks[p.bookId]!)
        .toList();
  }

  /// Generates personalized audiobook recommendations based on user listening history & saved books
  List<Audiobook> get recommendedBooks {
    final listenedOrSaved = <Audiobook>[];
    for (final p in _progressMap.values) {
      if (_knownBooks.containsKey(p.bookId)) {
        listenedOrSaved.add(_knownBooks[p.bookId]!);
      }
    }
    for (final id in _savedBookIds) {
      if (_knownBooks.containsKey(id) && !listenedOrSaved.any((b) => b.id == id)) {
        listenedOrSaved.add(_knownBooks[id]!);
      }
    }

    final interactedIds = listenedOrSaved.map((b) => b.id).toSet();

    if (listenedOrSaved.isNotEmpty) {
      final genreWeights = <String, int>{};
      final authorWeights = <String, int>{};
      final langWeights = <String, int>{};

      for (final book in listenedOrSaved) {
        for (final g in book.genres) {
          final key = g.toLowerCase();
          genreWeights[key] = (genreWeights[key] ?? 0) + 1;
        }
        for (final a in book.authors) {
          final key = a.name.toLowerCase();
          authorWeights[key] = (authorWeights[key] ?? 0) + 1;
        }
        final lKey = book.language.toLowerCase();
        langWeights[lKey] = (langWeights[lKey] ?? 0) + 1;
      }

      final candidates = _knownBooks.values.where((b) => !interactedIds.contains(b.id)).toList();

      candidates.sort((a, b) {
        int scoreA = 0;
        int scoreB = 0;

        for (final g in a.genres) {
          scoreA += (genreWeights[g.toLowerCase()] ?? 0) * 3;
        }
        for (final auth in a.authors) {
          scoreA += (authorWeights[auth.name.toLowerCase()] ?? 0) * 5;
        }
        scoreA += (langWeights[a.language.toLowerCase()] ?? 0) * 2;

        for (final g in b.genres) {
          scoreB += (genreWeights[g.toLowerCase()] ?? 0) * 3;
        }
        for (final auth in b.authors) {
          scoreB += (authorWeights[auth.name.toLowerCase()] ?? 0) * 5;
        }
        scoreB += (langWeights[b.language.toLowerCase()] ?? 0) * 2;

        return scoreB.compareTo(scoreA);
      });

      if (candidates.isNotEmpty) {
        return candidates.take(8).toList();
      }
    }

    // Default starter recommendations if no history yet
    return _knownBooks.values.where((b) => !interactedIds.contains(b.id)).take(6).toList();
  }

  /// Dynamic user-facing reason for the recommendations
  String get recommendationReason {
    if (currentlyListeningBooks.isNotEmpty) {
      return 'Because you listened to "${currentlyListeningBooks.first.title}"';
    } else if (savedBooks.isNotEmpty) {
      return 'Tailored to your saved books & favorite genres';
    }
    return 'Handpicked timeless classics to start your journey';
  }

  AudiobookProvider() {
    _init();
  }

  Future<void> _init() async {
    _isLoading = true;
    notifyListeners();

    for (final b in _service.allCuratedBooks) {
      _knownBooks[b.id] = b;
    }

    await _loadPersistedData();
    await fetchShelves();

    _isLoading = false;
    notifyListeners();
  }

  // ─── Fetch Shelves & Catalogs ────────────────────────────────────

  Future<void> fetchShelves() async {
    try {
      _error = null;

      // 1. Featured Books
      _featuredBooks = await _service.getFeaturedBooks();
      for (final b in _featuredBooks) {
        _knownBooks[b.id] = b;
      }

      // 2. Hindi Audiobooks Showcase
      _hindiBooks = await _service.getHindiAudiobooks(limit: 12);
      for (final b in _hindiBooks) {
        _knownBooks[b.id] = b;
      }

      // 3. Genre Shelves
      final genres = [
        'Self-Help',
        'Indian & Hindi Classics',
        'Mystery & Detective',
        'Global Masterpieces',
        'Business & Wealth',
        'Philosophy & Wisdom',
      ];

      for (final genre in genres) {
        final books = await _service.getBooksByGenre(genre);
        _genreShelves[genre] = books;
        for (final b in books) {
          _knownBooks[b.id] = b;
        }
      }
    } catch (e) {
      _error = 'Failed to load audiobooks catalog: $e';
      debugPrint('[AudiobookProvider] fetchShelves error: $e');
    }
  }

  // ─── Search ──────────────────────────────────────────────────────

  Future<void> search(String query) async {
    _searchQuery = query.trim();
    if (_searchQuery.isEmpty) {
      _searchResults = [];
      _isSearching = false;
      notifyListeners();
      return;
    }

    _isSearching = true;
    notifyListeners();

    try {
      final results = await _service.searchBooks(_searchQuery, limit: 30);
      _searchResults = results;
      for (final b in results) {
        _knownBooks[b.id] = b;
      }
    } catch (e) {
      debugPrint('[AudiobookProvider] Search error: $e');
      _searchResults = [];
    } finally {
      _isSearching = false;
      notifyListeners();
    }
  }

  void clearSearch() {
    _searchQuery = '';
    _searchResults = [];
    _isSearching = false;
    notifyListeners();
  }

  // ─── Book Details & Chapter Loading ──────────────────────────────

  Future<Audiobook> loadBookDetails(Audiobook book) async {
    _knownBooks[book.id] = book;
    if (book.chapters.isNotEmpty) {
      _activeBook = book;
      notifyListeners();
      return book;
    }

    _isLoadingDetails = true;
    notifyListeners();

    try {
      final fullBook = await _service.getBookDetails(book.id, fallback: book);
      _knownBooks[fullBook.id] = fullBook;
      _activeBook = fullBook;
      return fullBook;
    } catch (e) {
      debugPrint('[AudiobookProvider] loadBookDetails error: $e');
      _activeBook = book;
      return book;
    } finally {
      _isLoadingDetails = false;
      notifyListeners();
    }
  }

  // ─── Playback Coordination ───────────────────────────────────────

  Future<void> playChapter(
    Audiobook book,
    int chapterIndex,
    BuildContext context, {
    int? seekPositionMs,
  }) async {
    final audioProvider = Provider.of<AudioProvider>(context, listen: false);

    // 1. Ensure full chapters are loaded
    final fullBook = await loadBookDetails(book);
    if (fullBook.chapters.isEmpty) {
      debugPrint('[AudiobookProvider] No chapters available to play.');
      return;
    }

    final validIndex = chapterIndex.clamp(0, fullBook.chapters.length - 1);
    _activeBook = fullBook;
    _activeChapterIndex = validIndex;
    _knownBooks[fullBook.id] = fullBook;

    // 2. Convert all chapters to Episodes for AudioProvider
    final queue = fullBook.chapters.map((ch) => ch.toEpisode(fullBook)).toList();
    final targetEpisode = queue[validIndex];

    // 3. Play chapter via core AudioProvider
    await audioProvider.play(targetEpisode, queue: queue, queueIndex: validIndex);

    // If starting from saved resume point
    if (seekPositionMs != null && seekPositionMs > 0) {
      audioProvider.seekTo(Duration(milliseconds: seekPositionMs));
    }

    // 4. Update progress entry
    saveProgress(
      fullBook.id,
      validIndex,
      seekPositionMs ?? 0,
    );

    notifyListeners();
  }

  void resumeBook(Audiobook book, BuildContext context) {
    final progress = _progressMap[book.id];
    final chapterIdx = progress?.currentChapterIndex ?? 0;
    final posMs = progress?.positionMs ?? 0;
    playChapter(book, chapterIdx, context, seekPositionMs: posMs);
  }

  // ─── Progress & Persistence ──────────────────────────────────────

  void saveProgress(String bookId, int chapterIndex, int positionMs, {bool isCompleted = false, bool notify = true}) {
    _progressMap[bookId] = AudiobookProgress(
      bookId: bookId,
      currentChapterIndex: chapterIndex,
      positionMs: positionMs,
      lastListenedAt: DateTime.now(),
      isCompleted: isCompleted,
    );
    _activeChapterIndex = chapterIndex;
    _persistProgress();
    if (notify) {
      notifyListeners();
    }
  }

  void markBookCompleted(String bookId) {
    final current = _progressMap[bookId];
    _progressMap[bookId] = AudiobookProgress(
      bookId: bookId,
      currentChapterIndex: current?.currentChapterIndex ?? 0,
      positionMs: current?.positionMs ?? 0,
      lastListenedAt: DateTime.now(),
      isCompleted: true,
    );
    _persistProgress();
    notifyListeners();
  }

  void toggleSaveBook(Audiobook book) {
    _knownBooks[book.id] = book;
    if (_savedBookIds.contains(book.id)) {
      _savedBookIds.remove(book.id);
    } else {
      _savedBookIds.add(book.id);
    }
    _persistSavedBooks();
    notifyListeners();
  }

  // ─── Bookmarks & Saved Quotes ────────────────────────────────────

  void addBookmark({
    required Audiobook book,
    required int chapterIndex,
    required String chapterTitle,
    required int timestampMs,
    required String note,
  }) {
    final bookmark = AudiobookBookmark(
      id: '${book.id}_${chapterIndex}_$timestampMs',
      bookId: book.id,
      chapterIndex: chapterIndex,
      chapterTitle: chapterTitle,
      timestampMs: timestampMs,
      note: note,
      createdAt: DateTime.now(),
    );
    _bookmarks.insert(0, bookmark);
    _persistBookmarks();
    notifyListeners();
  }

  void deleteBookmark(String bookmarkId) {
    _bookmarks.removeWhere((b) => b.id == bookmarkId);
    _persistBookmarks();
    notifyListeners();
  }

  List<AudiobookBookmark> getBookmarksForBook(String bookId) {
    return _bookmarks.where((b) => b.bookId == bookId).toList();
  }

  // ─── SharedPreferences Serialization ─────────────────────────────

  static const _keySavedBooks = 'aura_saved_audiobooks';
  static const _keyProgress = 'aura_audiobook_progress';
  static const _keyBookmarks = 'aura_audiobook_bookmarks';
  static const _keyKnownBooks = 'aura_known_audiobooks';

  Future<void> _loadPersistedData() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Load known books cache for bookshelf lookup
      final knownStr = prefs.getString(_keyKnownBooks);
      if (knownStr != null) {
        final list = (jsonDecode(knownStr) as List?) ?? [];
        for (final item in list) {
          try {
            final book = Audiobook.fromJson(item as Map<String, dynamic>);
            _knownBooks[book.id] = book;
          } catch (_) {}
        }
      }

      // Load saved book IDs
      final savedList = prefs.getStringList(_keySavedBooks) ?? [];
      _savedBookIds.addAll(savedList);

      // Load reading progress
      final progressStr = prefs.getString(_keyProgress);
      if (progressStr != null) {
        final map = (jsonDecode(progressStr) as Map<String, dynamic>?) ?? {};
        map.forEach((k, v) {
          try {
            _progressMap[k] = AudiobookProgress.fromJson(v as Map<String, dynamic>);
          } catch (_) {}
        });
      }

      // Load bookmarks
      final bookmarksStr = prefs.getString(_keyBookmarks);
      if (bookmarksStr != null) {
        final list = (jsonDecode(bookmarksStr) as List?) ?? [];
        _bookmarks.clear();
        for (final item in list) {
          try {
            _bookmarks.add(AudiobookBookmark.fromJson(item as Map<String, dynamic>));
          } catch (_) {}
        }
      }
    } catch (e) {
      debugPrint('[AudiobookProvider] _loadPersistedData error: $e');
    }
  }

  Future<void> _persistSavedBooks() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_keySavedBooks, _savedBookIds.toList());
      _persistKnownBooks();
    } catch (e) {
      debugPrint('[AudiobookProvider] _persistSavedBooks error: $e');
    }
  }

  Future<void> _persistProgress() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final map = <String, dynamic>{};
      _progressMap.forEach((k, v) => map[k] = v.toJson());
      await prefs.setString(_keyProgress, jsonEncode(map));
      _persistKnownBooks();
    } catch (e) {
      debugPrint('[AudiobookProvider] _persistProgress error: $e');
    }
  }

  Future<void> _persistBookmarks() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = _bookmarks.map((b) => b.toJson()).toList();
      await prefs.setString(_keyBookmarks, jsonEncode(list));
    } catch (e) {
      debugPrint('[AudiobookProvider] _persistBookmarks error: $e');
    }
  }

  Future<void> _persistKnownBooks() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = _knownBooks.values.map((b) => b.toJson()).toList();
      await prefs.setString(_keyKnownBooks, jsonEncode(list));
    } catch (e) {
      debugPrint('[AudiobookProvider] _persistKnownBooks error: $e');
    }
  }
}
