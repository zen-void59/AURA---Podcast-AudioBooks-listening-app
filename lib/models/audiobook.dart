import 'package:aura/models/episode.dart';

enum AudiobookSource {
  librivox,
  archive,
  gutenberg,
  youtube,
}

/// Represents an Author or Narrator
class BookPerson {
  final String name;
  final String? url;

  const BookPerson({required this.name, this.url});

  Map<String, dynamic> toJson() => {'name': name, 'url': url};

  factory BookPerson.fromJson(Map<String, dynamic> json) => BookPerson(
        name: json['name'] as String? ?? 'Unknown',
        url: json['url'] as String?,
      );
}

/// Represents an Audiobook
class Audiobook {
  final String id;
  final String title;
  final List<BookPerson> authors;
  final List<String> narrators;
  final String description;
  final List<String> genres;
  final String language;
  final int totalDurationSeconds;
  final String coverUrl;
  final AudiobookSource source;
  final String sourceUrl;
  final String? publishedYear;
  final List<AudiobookChapter> chapters;

  const Audiobook({
    required this.id,
    required this.title,
    required this.authors,
    this.narrators = const [],
    required this.description,
    this.genres = const [],
    this.language = 'en',
    required this.totalDurationSeconds,
    required this.coverUrl,
    required this.source,
    required this.sourceUrl,
    this.publishedYear,
    this.chapters = const [],
  });

  String get authorName => authors.isNotEmpty ? authors.first.name : 'Classic Author';

  String get durationFormatted {
    if (totalDurationSeconds <= 0) return '0m';
    final m = (totalDurationSeconds / 60).floor();
    final h = (m / 60).floor();
    final remM = m % 60;
    if (h > 0) {
      return '${h}h ${remM}m';
    }
    return '${remM}m';
  }

  String get sourceBadge {
    switch (source) {
      case AudiobookSource.librivox:
        return 'LibriVox';
      case AudiobookSource.archive:
        return 'Internet Archive';
      case AudiobookSource.gutenberg:
        return 'Project Gutenberg';
      case AudiobookSource.youtube:
        return 'YouTube';
    }
  }

  /// Returns true if the cover is a real, legitimate book cover image
  /// and not a generic placeholder or the oversized "LibriVox" collection logo.
  bool get hasValidCover {
    if (coverUrl.isEmpty) return false;
    final lower = coverUrl.toLowerCase();
    if (lower.contains('librivoxaudio') ||
        lower.contains('librivox-logo') ||
        lower.contains('default_cover') ||
        lower.contains('placeholder') ||
        lower.endsWith('/services/img/') ||
        lower.endsWith('/services/img')) {
      return false;
    }
    return true;
  }

  Audiobook copyWith({
    String? id,
    String? title,
    List<BookPerson>? authors,
    List<String>? narrators,
    String? description,
    List<String>? genres,
    String? language,
    int? totalDurationSeconds,
    String? coverUrl,
    AudiobookSource? source,
    String? sourceUrl,
    String? publishedYear,
    List<AudiobookChapter>? chapters,
  }) {
    return Audiobook(
      id: id ?? this.id,
      title: title ?? this.title,
      authors: authors ?? this.authors,
      narrators: narrators ?? this.narrators,
      description: description ?? this.description,
      genres: genres ?? this.genres,
      language: language ?? this.language,
      totalDurationSeconds: totalDurationSeconds ?? this.totalDurationSeconds,
      coverUrl: coverUrl ?? this.coverUrl,
      source: source ?? this.source,
      sourceUrl: sourceUrl ?? this.sourceUrl,
      publishedYear: publishedYear ?? this.publishedYear,
      chapters: chapters ?? this.chapters,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'authors': authors.map((a) => a.toJson()).toList(),
        'narrators': narrators,
        'description': description,
        'genres': genres,
        'language': language,
        'totalDurationSeconds': totalDurationSeconds,
        'coverUrl': coverUrl,
        'source': source.name,
        'sourceUrl': sourceUrl,
        'publishedYear': publishedYear,
        'chapters': chapters.map((c) => c.toJson()).toList(),
      };

  factory Audiobook.fromJson(Map<String, dynamic> json) {
    final authorsRaw = json['authors'] as List? ?? [];
    final chaptersRaw = json['chapters'] as List? ?? [];
    final sourceStr = json['source'] as String? ?? 'librivox';

    return Audiobook(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? 'Untitled Book',
      authors: authorsRaw.map((a) => BookPerson.fromJson(a as Map<String, dynamic>)).toList(),
      narrators: (json['narrators'] as List?)?.map((e) => e.toString()).toList() ?? [],
      description: json['description'] as String? ?? '',
      genres: (json['genres'] as List?)?.map((e) => e.toString()).toList() ?? [],
      language: json['language'] as String? ?? 'en',
      totalDurationSeconds: json['totalDurationSeconds'] as int? ?? 0,
      coverUrl: json['coverUrl'] as String? ?? '',
      source: AudiobookSource.values.firstWhere(
        (s) => s.name == sourceStr,
        orElse: () => AudiobookSource.librivox,
      ),
      sourceUrl: json['sourceUrl'] as String? ?? '',
      publishedYear: json['publishedYear'] as String?,
      chapters: chaptersRaw.map((c) => AudiobookChapter.fromJson(c as Map<String, dynamic>)).toList(),
    );
  }
}

/// Represents a single Chapter of an Audiobook
class AudiobookChapter {
  final String id;
  final String bookId;
  final int order; // 1-indexed (Chapter 1, 2...)
  final String title;
  final int durationSeconds;
  final String streamUrl;
  final int startOffsetMs;

  const AudiobookChapter({
    required this.id,
    required this.bookId,
    required this.order,
    required this.title,
    required this.durationSeconds,
    required this.streamUrl,
    this.startOffsetMs = 0,
  });

  String get durationFormatted {
    if (durationSeconds <= 0) return '0m';
    final m = (durationSeconds / 60).floor();
    final s = durationSeconds % 60;
    if (m >= 60) {
      final h = (m / 60).floor();
      final remM = m % 60;
      return '${h}h ${remM}m';
    }
    return '${m}m ${s}s';
  }

  /// Converts this chapter into an AURA [Episode] so it plays natively
  /// with AudioProvider, background notifications, waveform, and lock-screen controls.
  Episode toEpisode(Audiobook book) {
    String cleanUrl = streamUrl.trim();
    if (cleanUrl.startsWith('http://')) {
      cleanUrl = cleanUrl.replaceFirst('http://', 'https://');
    }
    try {
      cleanUrl = Uri.encodeFull(cleanUrl);
    } catch (_) {}

    final bool isYt = book.source == AudiobookSource.youtube;
    return Episode(
      id: 'ab_${book.id}_ch_$order',
      name: title,
      showId: book.id,
      showName: '${book.title} • ${book.authorName}',
      duration: durationSeconds > 0 ? durationSeconds : null,
      imageUrl: book.coverUrl,
      url: cleanUrl,
      downloadUrls: [AudioQuality(quality: '160kbps', url: cleanUrl)],
      description: 'Chapter $order of ${book.chapters.length} in "${book.title}" by ${book.authorName}.\n\n${book.description}',
      isYouTube: isYt,
      youtubeVideoId: isYt ? streamUrl : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'bookId': bookId,
        'order': order,
        'title': title,
        'durationSeconds': durationSeconds,
        'streamUrl': streamUrl,
        'startOffsetMs': startOffsetMs,
      };

  factory AudiobookChapter.fromJson(Map<String, dynamic> json) => AudiobookChapter(
        id: json['id'] as String? ?? '',
        bookId: json['bookId'] as String? ?? '',
        order: json['order'] as int? ?? 1,
        title: json['title'] as String? ?? 'Chapter',
        durationSeconds: json['durationSeconds'] as int? ?? 0,
        streamUrl: json['streamUrl'] as String? ?? '',
        startOffsetMs: json['startOffsetMs'] as int? ?? 0,
      );
}

/// Reading progress for a book saved in SharedPreferences
class AudiobookProgress {
  final String bookId;
  int currentChapterIndex; // 0-indexed into book.chapters
  int positionMs;
  DateTime lastListenedAt;
  bool isCompleted;

  AudiobookProgress({
    required this.bookId,
    required this.currentChapterIndex,
    required this.positionMs,
    required this.lastListenedAt,
    this.isCompleted = false,
  });

  double calculatePercentage(Audiobook book) {
    if (book.totalDurationSeconds <= 0 || book.chapters.isEmpty) return 0.0;
    int elapsed = 0;
    for (int i = 0; i < currentChapterIndex && i < book.chapters.length; i++) {
      elapsed += book.chapters[i].durationSeconds;
    }
    elapsed += (positionMs / 1000).round();
    return (elapsed / book.totalDurationSeconds).clamp(0.0, 1.0);
  }

  Map<String, dynamic> toJson() => {
        'bookId': bookId,
        'currentChapterIndex': currentChapterIndex,
        'positionMs': positionMs,
        'lastListenedAt': lastListenedAt.toIso8601String(),
        'isCompleted': isCompleted,
      };

  factory AudiobookProgress.fromJson(Map<String, dynamic> json) => AudiobookProgress(
        bookId: json['bookId'] as String? ?? '',
        currentChapterIndex: json['currentChapterIndex'] as int? ?? 0,
        positionMs: json['positionMs'] as int? ?? 0,
        lastListenedAt: json['lastListenedAt'] != null
            ? DateTime.tryParse(json['lastListenedAt'] as String) ?? DateTime.now()
            : DateTime.now(),
        isCompleted: json['isCompleted'] as bool? ?? false,
      );
}

/// Bookmark / Saved Quote with timestamp
class AudiobookBookmark {
  final String id;
  final String bookId;
  final int chapterIndex;
  final String chapterTitle;
  final int timestampMs;
  final String note;
  final DateTime createdAt;

  const AudiobookBookmark({
    required this.id,
    required this.bookId,
    required this.chapterIndex,
    required this.chapterTitle,
    required this.timestampMs,
    required this.note,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'bookId': bookId,
        'chapterIndex': chapterIndex,
        'chapterTitle': chapterTitle,
        'timestampMs': timestampMs,
        'note': note,
        'createdAt': createdAt.toIso8601String(),
      };

  factory AudiobookBookmark.fromJson(Map<String, dynamic> json) => AudiobookBookmark(
        id: json['id'] as String? ?? '',
        bookId: json['bookId'] as String? ?? '',
        chapterIndex: json['chapterIndex'] as int? ?? 0,
        chapterTitle: json['chapterTitle'] as String? ?? '',
        timestampMs: json['timestampMs'] as int? ?? 0,
        note: json['note'] as String? ?? '',
        createdAt: json['createdAt'] != null
            ? DateTime.tryParse(json['createdAt'] as String) ?? DateTime.now()
            : DateTime.now(),
      );
}
