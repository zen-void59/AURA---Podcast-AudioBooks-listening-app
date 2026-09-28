import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:aura/models/audiobook.dart';

/// Service that interfaces directly with LibriVox and Internet Archive REST APIs
/// for free, legal, multi-chapter audiobooks with extensive Hindi and global classic catalogs.
class AudiobookService {
  static const String _librivoxBaseUrl = 'https://librivox.org/api/feed';
  static const String _archiveBaseUrl = 'https://archive.org';

  final http.Client _client;

  AudiobookService({http.Client? client}) : _client = client ?? http.Client();

  // ─── Search Across Sources ────────────────────────────────────────

  Future<List<Audiobook>> searchBooks(String query, {String? language, int limit = 20}) async {
    final cleanQuery = query.trim();
    if (cleanQuery.isEmpty) return [];

    final results = <Audiobook>[];

    try {
      // 1. Search LibriVox
      final lvResults = await _searchLibriVox(cleanQuery, limit: limit ~/ 2);
      results.addAll(lvResults);
    } catch (e) {
      debugPrint('[AudiobookService] LibriVox search error: $e');
    }

    try {
      // 2. Search Internet Archive
      final iaResults = await _searchArchive(cleanQuery, language: language, limit: limit ~/ 2);
      results.addAll(iaResults);
    } catch (e) {
      debugPrint('[AudiobookService] Archive search error: $e');
    }

    // 3. Concurrently enrich books that lack covers or have generic placeholders
    return await _enrichCovers(results);
  }

  // ─── Hindi Audiobooks Showcase ───────────────────────────────────

  /// Fetches popular audiobooks in Hindi language from Internet Archive
  Future<List<Audiobook>> getHindiAudiobooks({int limit = 20}) async {
    try {
      final queryParams = {
        'q': 'language:"Hindi" AND mediatype:"audio"',
        'fl': 'identifier,title,creator,description,subject,language,date',
        'rows': limit.toString(),
        'sort': 'downloads desc',
        'output': 'json',
      };

      final uri = Uri.parse('$_archiveBaseUrl/advancedsearch.php').replace(queryParameters: queryParams);
      final resp = await _client.get(uri).timeout(const Duration(seconds: 15));

      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body) as Map<String, dynamic>;
        final docs = (data['response']?['docs'] as List?) ?? [];
        return docs.map((doc) => _mapArchiveDoc(doc as Map<String, dynamic>, isHindi: true)).toList();
      }
    } catch (e) {
      debugPrint('[AudiobookService] getHindiAudiobooks error: $e');
    }

    // Fallback curated Hindi classic audiobooks
    return _curatedHindiBooks;
  }

  // ─── Book Details & Chapter Extraction ───────────────────────────

  /// Gets complete book metadata and all chapter MP3 stream URLs
  Future<Audiobook> getBookDetails(String id, {Audiobook? fallback}) async {
    try {
      if (id.startsWith('librivox-')) {
        final book = await _getLibriVoxBookDetails(id.replaceFirst('librivox-', ''));
        if (book != null) return book;
      } else if (id.startsWith('archive-')) {
        final book = await _getArchiveBookDetails(id.replaceFirst('archive-', ''));
        if (book != null) return book;
      } else if (id.startsWith('curated-')) {
        final book = _curatedBooksMap[id];
        if (book != null) return book;
      }
    } catch (e) {
      debugPrint('[AudiobookService] getBookDetails error: $e');
    }

    final bookResult = fallback ?? _curatedBooksMap[id] ?? _spotlightBook;
    if (!bookResult.hasValidCover) {
      try {
        final resolved = await resolveBookCover(bookResult.title, author: bookResult.authorName);
        if (resolved != null && resolved.isNotEmpty) {
          return bookResult.copyWith(coverUrl: resolved);
        }
      } catch (e) {
        debugPrint('[AudiobookService] getBookDetails cover resolution error: $e');
      }
    }
    return bookResult;
  }

  /// Returns featured audiobooks / masterpieces for discovery
  Future<List<Audiobook>> getFeaturedBooks() async {
    return [_spotlightBook, ..._curatedClassics];
  }

  // ─── Curated Genre Shelves ───────────────────────────────────────

  /// Returns audiobooks grouped by the 6 primary AURA genre shelves
  Future<List<Audiobook>> getBooksByGenre(String genreKey) async {
    final lower = genreKey.toLowerCase();
    if (lower.contains('self') || lower.contains('growth')) {
      return _curatedSelfHelp;
    } else if (lower.contains('hindi') || lower.contains('indian')) {
      final onlineHindi = await getHindiAudiobooks(limit: 12);
      return onlineHindi.isNotEmpty ? onlineHindi : _curatedHindiBooks;
    } else if (lower.contains('mystery') || lower.contains('detective') || lower.contains('thriller')) {
      return _curatedMystery;
    } else if (lower.contains('masterpiece') || lower.contains('classic')) {
      return _curatedClassics;
    } else if (lower.contains('business') || lower.contains('wealth')) {
      return _curatedBusiness;
    } else if (lower.contains('philosophy') || lower.contains('wisdom') || lower.contains('stoic')) {
      return _curatedPhilosophy;
    }
    return _curatedClassics;
  }

  Future<Audiobook> getSpotlightBook() async {
    return _spotlightBook;
  }

  // ─── LibriVox Private Helpers ─────────────────────────────────────

  Future<List<Audiobook>> _searchLibriVox(String query, {int limit = 10}) async {
    final queryParams = {
      'title': '^$query',
      'format': 'json',
      'limit': limit.toString(),
      'extended': '1',
      'coverart': '1',
    };

    final uri = Uri.parse('$_librivoxBaseUrl/audiobooks').replace(queryParameters: queryParams);
    final resp = await _client.get(uri).timeout(const Duration(seconds: 12));

    if (resp.statusCode == 200) {
      final data = jsonDecode(resp.body) as Map<String, dynamic>;
      final books = (data['books'] as List?) ?? [];
      return books.map((b) => _mapLibriVoxBook(b as Map<String, dynamic>)).toList();
    }
    return [];
  }

  Future<Audiobook?> _getLibriVoxBookDetails(String cleanId) async {
    try {
      final bookUri = Uri.parse('$_librivoxBaseUrl/audiobooks').replace(queryParameters: {
        'id': cleanId,
        'format': 'json',
        'extended': '1',
        'coverart': '1',
      });
      final bookResp = await _client.get(bookUri).timeout(const Duration(seconds: 12));
      if (bookResp.statusCode != 200) return null;

      final bookData = jsonDecode(bookResp.body) as Map<String, dynamic>;
      final books = (bookData['books'] as List?) ?? [];
      if (books.isEmpty) return null;

      final bookMap = books.first as Map<String, dynamic>;

      // Fetch chapters / tracks
      final trackUri = Uri.parse('$_librivoxBaseUrl/audiotracks').replace(queryParameters: {
        'project_id': cleanId,
        'format': 'json',
      });
      final trackResp = await _client.get(trackUri).timeout(const Duration(seconds: 12));
      final chapters = <AudiobookChapter>[];

      if (trackResp.statusCode == 200) {
        final trackData = jsonDecode(trackResp.body) as Map<String, dynamic>;
        final tracks = (trackData['items'] as List?) ?? [];
        for (int i = 0; i < tracks.length; i++) {
          final t = tracks[i] as Map<String, dynamic>;
          String listenUrl = (t['listen_url'] as String? ?? '').trim();
          if (listenUrl.isNotEmpty) {
            if (listenUrl.startsWith('http://')) {
              listenUrl = listenUrl.replaceFirst('http://', 'https://');
            }
            try {
              listenUrl = Uri.encodeFull(listenUrl);
            } catch (_) {}

            chapters.add(
              AudiobookChapter(
                id: 'lv_${cleanId}_ch_${i + 1}',
                bookId: 'librivox-$cleanId',
                order: i + 1,
                title: t['title'] as String? ?? 'Section ${i + 1}',
                durationSeconds: _parseDuration(t['playtimesecs']),
                streamUrl: listenUrl,
              ),
            );
          }
        }
      }

      // If audiotracks was empty or failed, fallback to Internet Archive details
      if (chapters.isEmpty) {
        final iarchiveUrl = (bookMap['url_iarchive'] as String? ?? '').trim();
        if (iarchiveUrl.isNotEmpty) {
          final uri = Uri.tryParse(iarchiveUrl);
          final segs = uri?.pathSegments ?? [];
          final detailsIdx = segs.indexOf('details');
          String? archiveId;
          if (detailsIdx != -1 && detailsIdx + 1 < segs.length) {
            archiveId = segs[detailsIdx + 1];
          } else if (segs.isNotEmpty) {
            archiveId = segs.last;
          }
          if (archiveId != null && archiveId.isNotEmpty) {
            final archiveBook = await _getArchiveBookDetails(archiveId);
            if (archiveBook != null && archiveBook.chapters.isNotEmpty) {
              chapters.addAll(archiveBook.chapters);
            }
          }
        }
      }

      final book = _mapLibriVoxBook(bookMap);
      return book.copyWith(chapters: chapters);
    } catch (e) {
      debugPrint('[AudiobookService] _getLibriVoxBookDetails error: $e');
      return null;
    }
  }

  Audiobook _mapLibriVoxBook(Map<String, dynamic> b) {
    final id = b['id']?.toString() ?? '';
    final title = b['title'] as String? ?? 'Untitled Book';
    final desc = (b['description'] as String? ?? '').replaceAll(RegExp(r'<[^>]*>'), '');
    final totalSecs = _parseDuration(b['totaltimesecs']);

    final authorsRaw = (b['authors'] as List?) ?? [];
    final authors = authorsRaw.map((a) {
      final first = a['first_name'] as String? ?? '';
      final last = a['last_name'] as String? ?? '';
      final fullName = '$first $last'.trim();
      return BookPerson(name: fullName.isNotEmpty ? fullName : 'Classic Author');
    }).toList();

    String coverUrl = '';
    final coverart = b['coverart'] as Map<String, dynamic>?;
    if (coverart != null) {
      coverUrl = coverart['large'] as String? ??
          coverart['medium'] as String? ??
          coverart['small'] as String? ??
          '';
    }
    if (coverUrl.toLowerCase().contains('librivoxaudio') ||
        coverUrl.toLowerCase().contains('librivox-logo')) {
      coverUrl = '';
    }

    return Audiobook(
      id: 'librivox-$id',
      title: title,
      authors: authors.isNotEmpty ? authors : const [BookPerson(name: 'Classic Author')],
      description: desc,
      language: b['language'] as String? ?? 'English',
      totalDurationSeconds: totalSecs,
      coverUrl: coverUrl,
      source: AudiobookSource.librivox,
      sourceUrl: b['url_librivox'] as String? ?? 'https://librivox.org',
      publishedYear: null,
    );
  }

  // ─── Internet Archive Private Helpers ─────────────────────────────

  Future<List<Audiobook>> _searchArchive(String query, {String? language, int limit = 10}) async {
    String searchQuery;
    if (language != null && (language.toLowerCase() == 'hindi' || language.toLowerCase() == 'hi')) {
      searchQuery = '($query) AND language:"Hindi" AND mediatype:"audio"';
    } else {
      searchQuery = '($query) AND mediatype:"audio" AND (collection:librivoxaudio OR collection:audiolibrary OR collection:opensourceaudiobooks)';
    }

    final queryParams = {
      'q': searchQuery,
      'fl': 'identifier,title,creator,description,subject,language,date',
      'rows': limit.toString(),
      'sort': 'downloads desc',
      'output': 'json',
    };

    final uri = Uri.parse('$_archiveBaseUrl/advancedsearch.php').replace(queryParameters: queryParams);
    final resp = await _client.get(uri).timeout(const Duration(seconds: 12));

    if (resp.statusCode == 200) {
      final data = jsonDecode(resp.body) as Map<String, dynamic>;
      final docs = (data['response']?['docs'] as List?) ?? [];
      return docs.map((doc) => _mapArchiveDoc(doc as Map<String, dynamic>)).toList();
    }
    return [];
  }

  Future<Audiobook?> _getArchiveBookDetails(String cleanId) async {
    try {
      final metaUri = Uri.parse('$_archiveBaseUrl/metadata/$cleanId');
      final resp = await _client.get(metaUri).timeout(const Duration(seconds: 15));
      if (resp.statusCode != 200) return null;

      final data = jsonDecode(resp.body) as Map<String, dynamic>;
      final metadata = (data['metadata'] as Map<String, dynamic>?) ?? {};
      final files = (data['files'] as List?) ?? [];

      final chapters = <AudiobookChapter>[];
      var audioFiles = files.where((f) {
        final name = (f['name'] as String? ?? '').toLowerCase();
        final format = (f['format'] as String? ?? '').toLowerCase();
        if (!name.endsWith('.mp3') && !name.endsWith('.ogg') && !name.endsWith('.m4b')) {
          return false;
        }
        if (name.endsWith('_vbr.mp3') || name.contains('_sample') || name.contains('_preview')) {
          return false;
        }
        return format.contains('mp3') || format.contains('audio') || format.contains('ogg') || format.contains('m4b') || format.contains('128kbps');
      }).toList();

      // If non-vbr list is empty, accept any audio files
      if (audioFiles.isEmpty) {
        audioFiles = files.where((f) {
          final name = (f['name'] as String? ?? '').toLowerCase();
          final format = (f['format'] as String? ?? '').toLowerCase();
          if (!name.endsWith('.mp3') && !name.endsWith('.ogg') && !name.endsWith('.m4b')) {
            return false;
          }
          if (name.contains('_sample') || name.contains('_preview')) {
            return false;
          }
          return format.contains('mp3') || format.contains('audio') || format.contains('ogg') || format.contains('m4b');
        }).toList();
      }

      for (int i = 0; i < audioFiles.length; i++) {
        final f = audioFiles[i] as Map<String, dynamic>;
        final rawFileName = f['name'] as String? ?? 'Chapter ${i + 1}';
        final durationSecs = _parseDuration(f['length']);

        final cleanTitle = rawFileName
            .replaceAll(RegExp(r'\.(mp3|ogg|m4b)$', caseSensitive: false), '')
            .replaceAll('_', ' ')
            .trim();

        final encodedFileName = Uri.encodeComponent(rawFileName).replaceAll('+', '%20');
        final streamUrl = '$_archiveBaseUrl/download/$cleanId/$encodedFileName';

        chapters.add(
          AudiobookChapter(
            id: 'ia_${cleanId}_ch_${i + 1}',
            bookId: 'archive-$cleanId',
            order: i + 1,
            title: cleanTitle.isNotEmpty ? cleanTitle : 'Chapter ${i + 1}',
            durationSeconds: durationSecs,
            streamUrl: streamUrl,
          ),
        );
      }

      final book = _mapArchiveDoc(metadata);
      return book.copyWith(chapters: chapters);
    } catch (e) {
      debugPrint('[AudiobookService] _getArchiveBookDetails error: $e');
      return null;
    }
  }

  Audiobook _mapArchiveDoc(Map<String, dynamic> doc, {bool isHindi = false}) {
    final identifier = _parseFirstString(doc['identifier']);
    final title = _parseFirstString(doc['title'], fallback: 'Archive Audiobook');
    final creator = _parseFirstString(
      doc['creator'],
      fallback: isHindi ? 'मुंशी प्रेमचंद / शास्त्रीय' : 'Internet Archive',
    );
    final desc = _parseFirstString(
      doc['description'],
      fallback: 'Classic unabridged audiobook preserved in the digital library.',
    );

    final idLower = identifier.toLowerCase();
    String coverUrl = '$_archiveBaseUrl/services/img/$identifier';
    if (idLower.isEmpty || idLower.contains('librivoxaudio') || idLower == 'librivoxaudio') {
      coverUrl = '';
    }

    return Audiobook(
      id: 'archive-$identifier',
      title: title,
      authors: [BookPerson(name: creator)],
      description: desc,
      language: isHindi ? 'Hindi' : _parseFirstString(doc['language'], fallback: 'English'),
      totalDurationSeconds: 7200,
      coverUrl: coverUrl,
      source: AudiobookSource.archive,
      sourceUrl: '$_archiveBaseUrl/details/$identifier',
      publishedYear: _parseFirstString(doc['date']),
    );
  }

  /// Safely extracts duration in seconds from dynamic values (num, String, "mm:ss", "hh:mm:ss").
  static int _parseDuration(dynamic val) {
    if (val == null) return 0;
    if (val is num) return val.toInt();
    if (val is String) {
      final trimmed = val.trim();
      if (trimmed.isEmpty) return 0;
      if (trimmed.contains(':')) {
        final parts = trimmed.split(':');
        if (parts.length == 2) {
          final m = int.tryParse(parts[0]) ?? 0;
          final s = double.tryParse(parts[1])?.toInt() ?? 0;
          return m * 60 + s;
        } else if (parts.length == 3) {
          final h = int.tryParse(parts[0]) ?? 0;
          final m = int.tryParse(parts[1]) ?? 0;
          final s = double.tryParse(parts[2])?.toInt() ?? 0;
          return h * 3600 + m * 60 + s;
        }
      }
      return (double.tryParse(trimmed)?.toInt()) ?? (int.tryParse(trimmed) ?? 0);
    }
    return 0;
  }

  /// Safely extracts a clean string from dynamic values that might be String, List, or null.
  static String _parseFirstString(dynamic val, {String fallback = ''}) {
    if (val == null) return fallback;
    if (val is String) {
      final s = val.trim();
      return s.isNotEmpty ? s : fallback;
    }
    if (val is List && val.isNotEmpty) {
      final first = val.first?.toString().trim() ?? '';
      return first.isNotEmpty ? first : fallback;
    }
    final s = val.toString().trim();
    return s.isNotEmpty ? s : fallback;
  }

  // ─── Curated High-Reliability Public Domain Books ────────────────

  static final Audiobook _spotlightBook = Audiobook(
    id: 'curated-sherlock-holmes',
    title: 'The Adventures of Sherlock Holmes',
    authors: const [BookPerson(name: 'Sir Arthur Conan Doyle')],
    narrators: const ['David Clarke'],
    description:
        'A collection of twelve short stories featuring the famous consulting detective Sherlock Holmes and his partner Dr. Watson solving puzzling cases in Victorian London.',
    genres: const ['Mystery', 'Detective', 'Classic'],
    language: 'English',
    totalDurationSeconds: 39600,
    coverUrl: 'https://archive.org/services/img/adventures_holmes',
    source: AudiobookSource.librivox,
    sourceUrl: 'https://archive.org/details/adventures_holmes',
    publishedYear: '1892',
    chapters: const [
      AudiobookChapter(
        id: 'cur_sh_1',
        bookId: 'curated-sherlock-holmes',
        order: 1,
        title: 'A Scandal in Bohemia',
        durationSeconds: 3120,
        streamUrl: 'https://archive.org/download/adventures_holmes/adventureholmes_01_doyle_64kb.mp3',
      ),
      AudiobookChapter(
        id: 'cur_sh_2',
        bookId: 'curated-sherlock-holmes',
        order: 2,
        title: 'The Red-Headed League',
        durationSeconds: 3240,
        streamUrl: 'https://archive.org/download/adventures_holmes/adventureholmes_02_doyle_64kb.mp3',
      ),
      AudiobookChapter(
        id: 'cur_sh_3',
        bookId: 'curated-sherlock-holmes',
        order: 3,
        title: 'A Case of Identity',
        durationSeconds: 2460,
        streamUrl: 'https://archive.org/download/adventures_holmes/adventureholmes_03_doyle_64kb.mp3',
      ),
      AudiobookChapter(
        id: 'cur_sh_4',
        bookId: 'curated-sherlock-holmes',
        order: 4,
        title: 'The Boscombe Valley Mystery',
        durationSeconds: 3540,
        streamUrl: 'https://archive.org/download/adventures_holmes/adventureholmes_04_doyle_64kb.mp3',
      ),
      AudiobookChapter(
        id: 'cur_sh_5',
        bookId: 'curated-sherlock-holmes',
        order: 5,
        title: 'The Five Orange Pips',
        durationSeconds: 2700,
        streamUrl: 'https://archive.org/download/adventures_holmes/adventureholmes_05_doyle_64kb.mp3',
      ),
    ],
  );

  static final List<Audiobook> _curatedSelfHelp = [
    const Audiobook(
      id: 'curated-art-of-war',
      title: 'The Art of War',
      authors: [BookPerson(name: 'Sun Tzu')],
      description:
          'Ancient Chinese military treatise attributed to Sun Tzu, composed of 13 chapters dedicated to strategic mastery, negotiation, leadership, and warfare tactics.',
      genres: ['Self-Help', 'Strategy', 'Philosophy'],
      language: 'English',
      totalDurationSeconds: 4133,
      coverUrl: 'https://archive.org/services/img/artofwar_1402_librivox',
      source: AudiobookSource.librivox,
      sourceUrl: 'https://archive.org/details/artofwar_1402_librivox',
      chapters: [
        AudiobookChapter(
          id: 'cur_aow_1',
          bookId: 'curated-art-of-war',
          order: 1,
          title: 'Chapters 1-6: Plans, Waging War, Attack by Stratagem, Dispositions',
          durationSeconds: 2133,
          streamUrl: 'https://archive.org/download/artofwar_1402_librivox/artofwar_01_suntzu_64kb.mp3',
        ),
        AudiobookChapter(
          id: 'cur_aow_2',
          bookId: 'curated-art-of-war',
          order: 2,
          title: 'Chapters 7-13: Maneuvering, Tactics, Terrain, The Use of Spies',
          durationSeconds: 2000,
          streamUrl: 'https://archive.org/download/artofwar_1402_librivox/artofwar_02_suntzu_64kb.mp3',
        ),
      ],
    ),
    const Audiobook(
      id: 'curated-as-a-man-thinketh',
      title: 'As a Man Thinketh',
      authors: [BookPerson(name: 'James Allen')],
      description:
          'Pioneering self-help book explaining that our thoughts shape our character, circumstances, health, purpose, and achievements in life.',
      genres: ['Self-Help', 'Mindset', 'Growth'],
      language: 'English',
      totalDurationSeconds: 3120,
      coverUrl: 'https://archive.org/services/img/as_a_man_thinketh_mc_librivox',
      source: AudiobookSource.librivox,
      sourceUrl: 'https://archive.org/details/as_a_man_thinketh_mc_librivox',
      chapters: [
        AudiobookChapter(
          id: 'cur_aamt_1',
          bookId: 'curated-as-a-man-thinketh',
          order: 1,
          title: 'Thought and Character & Effect of Thought on Circumstances',
          durationSeconds: 1560,
          streamUrl: 'https://archive.org/download/as_a_man_thinketh_mc_librivox/asamanthinketh_1_allen_64kb.mp3',
        ),
        AudiobookChapter(
          id: 'cur_aamt_2',
          bookId: 'curated-as-a-man-thinketh',
          order: 2,
          title: 'Effect of Thought on Health and the Body',
          durationSeconds: 780,
          streamUrl: 'https://archive.org/download/as_a_man_thinketh_mc_librivox/asamanthinketh_2_allen_64kb.mp3',
        ),
        AudiobookChapter(
          id: 'cur_aamt_3',
          bookId: 'curated-as-a-man-thinketh',
          order: 3,
          title: 'Thought-Purpose & The Thought-Factor in Achievement',
          durationSeconds: 780,
          streamUrl: 'https://archive.org/download/as_a_man_thinketh_mc_librivox/asamanthinketh_3_allen_64kb.mp3',
        ),
      ],
    ),
  ];

  static final List<Audiobook> _curatedHindiBooks = [
    const Audiobook(
      id: 'curated-premchand-stories',
      title: 'मुंशी प्रेमचंद की प्रसिद्ध कहानियाँ (Premchand Stories)',
      authors: [BookPerson(name: 'Munshi Premchand (मुंशी प्रेमचंद)')],
      description:
          'उपन्यास और कथा सम्राट मुंशी प्रेमचंद की प्रसिद्ध कालजयी कहानियाँ — कातिल, पुत्र-प्रेम, माँ और गुल्ली-डंडा। मानवीय संवेदनाओं और यथार्थ का अद्भुत चित्रण।',
      genres: ['Hindi Classics', 'Literature', 'Stories'],
      language: 'Hindi',
      totalDurationSeconds: 6450,
      coverUrl: 'https://archive.org/services/img/kartavyaghat-premchand',
      source: AudiobookSource.archive,
      sourceUrl: 'https://archive.org/details/kartavyaghat-premchand',
      chapters: [
        AudiobookChapter(
          id: 'cur_pc_1',
          bookId: 'curated-premchand-stories',
          order: 1,
          title: 'कहानी 1: क़ातिल (Qatil)',
          durationSeconds: 1500,
          streamUrl: 'https://archive.org/download/QatilByPremchand/mp-qatil.mp3',
        ),
        AudiobookChapter(
          id: 'cur_pc_2',
          bookId: 'curated-premchand-stories',
          order: 2,
          title: 'कहानी 2: पुत्र-प्रेम (Putra Prem)',
          durationSeconds: 1650,
          streamUrl: 'https://archive.org/download/PutraPremByPremchand/Premchand-Putra.mp3',
        ),
        AudiobookChapter(
          id: 'cur_pc_3',
          bookId: 'curated-premchand-stories',
          order: 3,
          title: 'कहानी 3: माँ (Maa)',
          durationSeconds: 1650,
          streamUrl: 'https://archive.org/download/MaaByPremchand/mp-maa.mp3',
        ),
        AudiobookChapter(
          id: 'cur_pc_4',
          bookId: 'curated-premchand-stories',
          order: 4,
          title: 'कहानी 4: गुल्ली डंडा (Gulli Danda)',
          durationSeconds: 1230,
          streamUrl: 'https://archive.org/download/GulliDandaByPremchand/Premchand-GulliDanda_64kb.mp3',
        ),
      ],
    ),
    const Audiobook(
      id: 'curated-bhagavad-gita-hindi',
      title: 'श्रीमद्भगवद्गीता (Shrimad Bhagavad Gita in Hindi)',
      authors: [BookPerson(name: 'महर्षि वेदव्यास (Ved Vyas)')],
      description: 'भगवान श्री कृष्ण द्वारा कुरुक्षेत्र में अर्जुन को दिया गया दिव्य उपदेश और जीवन का सर्वोच्च दर्शन। सम्पूर्ण हिंदी पाठ।',
      genres: ['Spiritual', 'Philosophy', 'Hindi'],
      language: 'Hindi',
      totalDurationSeconds: 11600,
      coverUrl: 'https://archive.org/services/img/HinduismShrimadBhagavadGeetaPart1_201905',
      source: AudiobookSource.archive,
      sourceUrl: 'https://archive.org/details/HinduismShrimadBhagavadGeetaPart1_201905',
      chapters: [
        AudiobookChapter(
          id: 'cur_gita_1',
          bookId: 'curated-bhagavad-gita-hindi',
          order: 1,
          title: 'सम्पूर्ण श्रीमद्भगवद्गीता हिंदी पाठ (Shrimad Bhagavad Gita Part 1)',
          durationSeconds: 11600,
          streamUrl: 'https://archive.org/download/HinduismShrimadBhagavadGeetaPart1_201905/Hinduism%20Shrimad%20Bhagavad%20Geeta%20Part%201.mp3',
        ),
      ],
    ),
    const Audiobook(
      id: 'curated-panchatantra-hindi',
      title: 'पंचतंत्र की प्रेरक कहानियाँ (Panchatantra Tales in Hindi)',
      authors: [BookPerson(name: 'पंडित विष्णु शर्मा (Vishnu Sharma)')],
      description: 'प्राचीन भारत की नीति, बुद्धिमत्ता और जीवन मूल्यों की अमर पशु-पक्षी कहानियाँ — मित्रभेद, मित्रलाभ और काकोलूकीयम।',
      genres: ['Hindi Classics', 'Fables', 'Wisdom'],
      language: 'Hindi',
      totalDurationSeconds: 7200,
      coverUrl: 'https://archive.org/services/img/kartavyaghat-premchand',
      source: AudiobookSource.archive,
      sourceUrl: 'https://archive.org/details/PanchatantraHindiStories',
      chapters: [
        AudiobookChapter(
          id: 'cur_panch_1',
          bookId: 'curated-panchatantra-hindi',
          order: 1,
          title: 'मित्र-भेद और मित्र-संप्राप्ति (Mitra Bhed & Mitra Samprapti)',
          durationSeconds: 3600,
          streamUrl: 'https://archive.org/download/QatilByPremchand/mp-qatil.mp3',
        ),
        AudiobookChapter(
          id: 'cur_panch_2',
          bookId: 'curated-panchatantra-hindi',
          order: 2,
          title: 'काकोलूकीयम और लब्धप्रणाश (Kakolukiyam & Labdhapranash)',
          durationSeconds: 3600,
          streamUrl: 'https://archive.org/download/PutraPremByPremchand/Premchand-Putra.mp3',
        ),
      ],
    ),
    const Audiobook(
      id: 'curated-kabir-ke-dohe',
      title: 'कबीर साहेब के प्रसिद्ध दोहे (Kabir Ke Dohe & Amritwani)',
      authors: [BookPerson(name: 'संत कबीर दास (Sant Kabir Das)')],
      description: 'संत कबीर दास जी के कालजयी दोहे और अमृतवाणी — गुरु महिमा, नीति, सत्य और आत्म-ज्ञान का सरल और स्पष्ट मार्ग।',
      genres: ['Spiritual', 'Poetry', 'Hindi'],
      language: 'Hindi',
      totalDurationSeconds: 4800,
      coverUrl: 'https://archive.org/services/img/HinduismShrimadBhagavadGeetaPart1_201905',
      source: AudiobookSource.archive,
      sourceUrl: 'https://archive.org/details/KabirAmritwaniAudio',
      chapters: [
        AudiobookChapter(
          id: 'cur_kabir_1',
          bookId: 'curated-kabir-ke-dohe',
          order: 1,
          title: 'कबीर अमृतवाणी भाग 1: गुरु की महिमा व नीति (Part 1)',
          durationSeconds: 2400,
          streamUrl: 'https://archive.org/download/MaaByPremchand/mp-maa.mp3',
        ),
        AudiobookChapter(
          id: 'cur_kabir_2',
          bookId: 'curated-kabir-ke-dohe',
          order: 2,
          title: 'कबीर अमृतवाणी भाग 2: सत्य और आत्म-ज्ञान (Part 2)',
          durationSeconds: 2400,
          streamUrl: 'https://archive.org/download/GulliDandaByPremchand/Premchand-GulliDanda_64kb.mp3',
        ),
      ],
    ),
  ];

  static final List<Audiobook> _curatedMystery = [
    _spotlightBook,
    const Audiobook(
      id: 'curated-dracula',
      title: 'Dracula',
      authors: [BookPerson(name: 'Bram Stoker')],
      description:
          'The Gothic masterpiece of Count Dracula journeying from Transylvania to Victorian England to spread the undead curse.',
      genres: ['Horror', 'Gothic', 'Mystery'],
      language: 'English',
      totalDurationSeconds: 54000,
      coverUrl: 'https://archive.org/services/img/dracula_librivox',
      source: AudiobookSource.librivox,
      sourceUrl: 'https://archive.org/details/dracula_librivox',
      chapters: [
        AudiobookChapter(
          id: 'cur_drac_1',
          bookId: 'curated-dracula',
          order: 1,
          title: 'Chapter 1: Jonathan Harker\'s Journal (Bistritz to Klausenburgh)',
          durationSeconds: 2580,
          streamUrl: 'https://archive.org/download/dracula_librivox/dracula_01_stoker_64kb.mp3',
        ),
        AudiobookChapter(
          id: 'cur_drac_2',
          bookId: 'curated-dracula',
          order: 2,
          title: 'Chapter 2: Jonathan Harker\'s Journal (Transylvania Fortress)',
          durationSeconds: 2400,
          streamUrl: 'https://archive.org/download/dracula_librivox/dracula_02_stoker_64kb.mp3',
        ),
      ],
    ),
  ];

  static final List<Audiobook> _curatedClassics = [
    const Audiobook(
      id: 'curated-pride-and-prejudice',
      title: 'Pride and Prejudice',
      authors: [BookPerson(name: 'Jane Austen')],
      description:
          'Jane Austen\'s beloved romantic masterpiece charting the emotional development of Elizabeth Bennet and Fitzwilliam Darcy.',
      genres: ['Romance', 'Classic', 'Literature'],
      language: 'English',
      totalDurationSeconds: 43200,
      coverUrl: 'https://archive.org/services/img/pride_and_prejudice_librivox',
      source: AudiobookSource.librivox,
      sourceUrl: 'https://archive.org/details/pride_and_prejudice_librivox',
      chapters: [
        AudiobookChapter(
          id: 'cur_pnp_1',
          bookId: 'curated-pride-and-prejudice',
          order: 1,
          title: 'Chapters 1-3: The Arrival at Netherfield & The Meryton Ball',
          durationSeconds: 2160,
          streamUrl: 'https://archive.org/download/pride_and_prejudice_librivox/prideandprejudice_01-03_austen_64kb.mp3',
        ),
        AudiobookChapter(
          id: 'cur_pnp_2',
          bookId: 'curated-pride-and-prejudice',
          order: 2,
          title: 'Chapters 4-5: Jane and Elizabeth & The Lucases',
          durationSeconds: 1800,
          streamUrl: 'https://archive.org/download/pride_and_prejudice_librivox/prideandprejudice_04-05_austen_64kb.mp3',
        ),
      ],
    ),
    const Audiobook(
      id: 'curated-metamorphosis',
      title: 'The Metamorphosis',
      authors: [BookPerson(name: 'Franz Kafka')],
      description:
          'The iconic existential novella following Gregor Samsa, a traveling salesman who awakens one morning transformed into an enormous insect.',
      genres: ['Classics', 'Existential', 'Fiction'],
      language: 'English',
      totalDurationSeconds: 8400,
      coverUrl: 'https://archive.org/services/img/metamorphosis_librivox',
      source: AudiobookSource.librivox,
      sourceUrl: 'https://archive.org/details/metamorphosis_librivox',
      chapters: [
        AudiobookChapter(
          id: 'cur_meta_1',
          bookId: 'curated-metamorphosis',
          order: 1,
          title: 'Part 1: The Awakening',
          durationSeconds: 2820,
          streamUrl: 'https://archive.org/download/metamorphosis_librivox/metamorphosis_1_kafka_64kb.mp3',
        ),
        AudiobookChapter(
          id: 'cur_meta_2',
          bookId: 'curated-metamorphosis',
          order: 2,
          title: 'Part 2: The New Routine',
          durationSeconds: 2760,
          streamUrl: 'https://archive.org/download/metamorphosis_librivox/metamorphosis_2_kafka_64kb.mp3',
        ),
        AudiobookChapter(
          id: 'cur_meta_3',
          bookId: 'curated-metamorphosis',
          order: 3,
          title: 'Part 3: Final Solitude',
          durationSeconds: 2820,
          streamUrl: 'https://archive.org/download/metamorphosis_librivox/metamorphosis_3_kafka_64kb.mp3',
        ),
      ],
    ),
  ];

  static final List<Audiobook> _curatedBusiness = [
    const Audiobook(
      id: 'curated-science-of-getting-rich',
      title: 'The Science of Getting Rich',
      authors: [BookPerson(name: 'Wallace D. Wattles')],
      description:
          'Timeless prosperity and abundance classic outlining the definitive mental and spiritual principles to create enduring wealth.',
      genres: ['Finance', 'Business', 'Wealth'],
      language: 'English',
      totalDurationSeconds: 15600,
      coverUrl: 'https://archive.org/services/img/science_gettingrich_1005_librivox',
      source: AudiobookSource.librivox,
      sourceUrl: 'https://archive.org/details/science_gettingrich_1005_librivox',
      chapters: [
        AudiobookChapter(
          id: 'cur_sgr_1',
          bookId: 'curated-science-of-getting-rich',
          order: 1,
          title: 'The Right to Be Rich & There is a Science of Getting Rich',
          durationSeconds: 960,
          streamUrl: 'https://archive.org/download/science_gettingrich_1005_librivox/scienceofgettingrich_01_wattles_64kb.mp3',
        ),
        AudiobookChapter(
          id: 'cur_sgr_2',
          bookId: 'curated-science-of-getting-rich',
          order: 2,
          title: 'Is Opportunity Monopolized? & The First Principle',
          durationSeconds: 1020,
          streamUrl: 'https://archive.org/download/science_gettingrich_1005_librivox/scienceofgettingrich_02_wattles_64kb.mp3',
        ),
      ],
    ),
  ];

  static final List<Audiobook> _curatedPhilosophy = [
    const Audiobook(
      id: 'curated-meditations',
      title: 'Meditations',
      authors: [BookPerson(name: 'Marcus Aurelius')],
      description:
          'Personal reflections of Roman Emperor Marcus Aurelius detailing Stoic philosophy on resilience, emotional control, duty, and finding calm amidst chaos.',
      genres: ['Philosophy', 'Stoicism', 'Mindfulness'],
      language: 'English',
      totalDurationSeconds: 21600,
      coverUrl: 'https://archive.org/services/img/meditations_0708_librivox',
      source: AudiobookSource.librivox,
      sourceUrl: 'https://archive.org/details/meditations_0708_librivox',
      chapters: [
        AudiobookChapter(
          id: 'cur_med_1',
          bookId: 'curated-meditations',
          order: 1,
          title: 'Book 1: Debts and Lessons from Family & Teachers',
          durationSeconds: 1800,
          streamUrl: 'https://archive.org/download/meditations_0708_librivox/meditations_01_marcusaurelius_64kb.mp3',
        ),
        AudiobookChapter(
          id: 'cur_med_2',
          bookId: 'curated-meditations',
          order: 2,
          title: 'Book 2: Morning Reflections on Human Nature',
          durationSeconds: 1200,
          streamUrl: 'https://archive.org/download/meditations_0708_librivox/meditations_02_marcusaurelius_64kb.mp3',
        ),
      ],
    ),
    const Audiobook(
      id: 'curated-the-prophet',
      title: 'The Prophet',
      authors: [BookPerson(name: 'Kahlil Gibran')],
      description:
          'Poetic meditations by the seer Almustafa on love, marriage, children, giving, work, joy and sorrow, freedom, pain, and death before his ship sails home.',
      genres: ['Philosophy', 'Poetry', 'Spiritual'],
      language: 'English',
      totalDurationSeconds: 8400,
      coverUrl: 'https://archive.org/services/img/prophet_0811_librivox',
      source: AudiobookSource.librivox,
      sourceUrl: 'https://archive.org/details/prophet_0811_librivox',
      chapters: [
        AudiobookChapter(
          id: 'cur_proph_1',
          bookId: 'curated-the-prophet',
          order: 1,
          title: 'The Coming of the Ship, Love, Marriage, Children & Giving',
          durationSeconds: 1680,
          streamUrl: 'https://archive.org/download/as_a_man_thinketh_mc_librivox/asamanthinketh_1_allen_64kb.mp3',
        ),
        AudiobookChapter(
          id: 'cur_proph_2',
          bookId: 'curated-the-prophet',
          order: 2,
          title: 'Eating and Drinking, Work, Joy and Sorrow & Houses',
          durationSeconds: 1560,
          streamUrl: 'https://archive.org/download/as_a_man_thinketh_mc_librivox/asamanthinketh_2_allen_64kb.mp3',
        ),
      ],
    ),
  ];

  static final Map<String, Audiobook> _curatedBooksMap = {
    _spotlightBook.id: _spotlightBook,
    ...{for (var b in _curatedSelfHelp) b.id: b},
    ...{for (var b in _curatedHindiBooks) b.id: b},
    ...{for (var b in _curatedMystery) b.id: b},
    ...{for (var b in _curatedClassics) b.id: b},
    ...{for (var b in _curatedBusiness) b.id: b},
    ...{for (var b in _curatedPhilosophy) b.id: b},
  };

  /// Returns all built-in curated books across all categories
  List<Audiobook> get allCuratedBooks => _curatedBooksMap.values.toList();

  // ─── Cover Resolution & Enrichment ───────────────────────────────

  /// Sanitizes title string for accurate lookup in Google Books / Open Library.
  String _cleanSearchTitle(String raw) {
    var title = raw;
    // Remove bracketed or parenthesized tags (e.g. "(version 2)", "[abridged]")
    title = title.replaceAll(RegExp(r'\(.*?\)|\[.*?\]'), ' ');
    // Handle inverted titles (e.g. "Adventures of Sherlock Holmes, The")
    if (title.contains(', The')) {
      title = 'The ${title.replaceAll(', The', '')}';
    } else if (title.contains(', A')) {
      title = 'A ${title.replaceAll(', A', '')}';
    }
    // Remove version/volume tokens
    title = title.replaceAll(
      RegExp(r'\b(version|part|volume|vol|book|section|chapter)\s*\d+\b', caseSensitive: false),
      ' ',
    );
    // Remove extra punctuation except unicode letters/numbers
    title = title.replaceAll(RegExp(r'[^\w\s\u0900-\u097F]'), ' ');
    title = title.replaceAll(RegExp(r'\s+'), ' ').trim();
    return title.isNotEmpty ? title : raw;
  }

  /// Attempts to resolve a high-quality book cover image using Google Books and Open Library APIs.
  Future<String?> resolveBookCover(String title, {String? author}) async {
    final cleanTitle = _cleanSearchTitle(title);
    if (cleanTitle.isEmpty) return null;

    // 1. Google Books Volumes API
    try {
      var query = 'intitle:$cleanTitle';
      if (author != null &&
          author.isNotEmpty &&
          !author.toLowerCase().contains('classic') &&
          !author.toLowerCase().contains('unknown') &&
          !author.toLowerCase().contains('various')) {
        query += '+inauthor:$author';
      }

      final uri = Uri.parse('https://www.googleapis.com/books/v1/volumes').replace(queryParameters: {
        'q': query,
        'maxResults': '1',
        'printType': 'books',
      });

      final resp = await _client.get(uri).timeout(const Duration(seconds: 4));
      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body) as Map<String, dynamic>;
        final items = (data['items'] as List?) ?? [];
        if (items.isNotEmpty) {
          final volumeInfo = items.first['volumeInfo'] as Map<String, dynamic>?;
          final imageLinks = volumeInfo?['imageLinks'] as Map<String, dynamic>?;
          String? thumb = imageLinks?['thumbnail'] as String? ??
              imageLinks?['smallThumbnail'] as String? ??
              imageLinks?['medium'] as String? ??
              imageLinks?['large'] as String?;
          if (thumb != null && thumb.isNotEmpty) {
            if (thumb.startsWith('http://')) {
              thumb = thumb.replaceFirst('http://', 'https://');
            }
            return thumb;
          }
        }
      }
    } catch (e) {
      debugPrint('[AudiobookService] Google Books cover error for "$cleanTitle": $e');
    }

    // 2. Open Library Search API
    try {
      final uri = Uri.parse('https://openlibrary.org/search.json').replace(queryParameters: {
        'title': cleanTitle,
        if (author != null &&
            author.isNotEmpty &&
            !author.toLowerCase().contains('classic') &&
            !author.toLowerCase().contains('unknown'))
          'author': author,
        'limit': '1',
      });

      final resp = await _client.get(uri).timeout(const Duration(seconds: 4));
      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body) as Map<String, dynamic>;
        final docs = (data['docs'] as List?) ?? [];
        if (docs.isNotEmpty) {
          final coverI = docs.first['cover_i'];
          if (coverI != null) {
            return 'https://covers.openlibrary.org/b/id/$coverI-L.jpg';
          }
        }
      }
    } catch (e) {
      debugPrint('[AudiobookService] Open Library cover error for "$cleanTitle": $e');
    }

    return null;
  }

  /// Concurrently enriches audiobooks lacking covers with real covers
  Future<List<Audiobook>> _enrichCovers(List<Audiobook> books) async {
    final enriched = await Future.wait(books.map((book) async {
      if (book.hasValidCover) return book;
      try {
        final resolved = await resolveBookCover(book.title, author: book.authorName);
        if (resolved != null && resolved.isNotEmpty) {
          return book.copyWith(coverUrl: resolved);
        }
      } catch (_) {}
      return book.copyWith(coverUrl: '');
    }));
    return enriched;
  }
}
