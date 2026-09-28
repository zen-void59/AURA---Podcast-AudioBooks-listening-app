import 'package:flutter_test/flutter_test.dart';
import 'package:aura/models/audiobook.dart';
import 'package:aura/services/audiobook_service.dart';

void main() {
  group('Audiobook Model & Chapter Mapping Tests', () {
    const sampleChapter = AudiobookChapter(
      id: 'ch_1',
      bookId: 'book_sherlock',
      order: 1,
      title: 'Chapter 01: A Scandal in Bohemia',
      durationSeconds: 1800,
      streamUrl: 'https://archive.org/download/sherlock_holmes/ch1.mp3',
    );

    const sampleBook = Audiobook(
      id: 'book_sherlock',
      title: 'The Adventures of Sherlock Holmes',
      authors: [BookPerson(name: 'Arthur Conan Doyle')],
      narrators: ['David Clarke'],
      description: 'Iconic detective tales of 221B Baker Street.',
      genres: ['Mystery', 'Classics'],
      language: 'en',
      totalDurationSeconds: 10800,
      coverUrl: 'https://archive.org/services/img/sherlock_holmes',
      source: AudiobookSource.archive,
      sourceUrl: 'https://archive.org/details/sherlock_holmes',
      chapters: [sampleChapter],
    );

    test('AudiobookChapter converts seamlessly to an AURA Episode', () {
      final episode = sampleChapter.toEpisode(sampleBook);

      expect(episode.id, equals('ab_book_sherlock_ch_1'));
      expect(episode.name, equals('Chapter 01: A Scandal in Bohemia'));
      expect(episode.showId, equals('book_sherlock'));
      expect(episode.showName, contains('Arthur Conan Doyle'));
      expect(episode.duration, equals(1800));
      expect(episode.streamUrl, equals('https://archive.org/download/sherlock_holmes/ch1.mp3'));
      expect(episode.imageUrl, equals(sampleBook.coverUrl));
      expect(episode.isYouTube, isFalse);
    });

    test('AudiobookChapter converts http to https and encodes unencoded stream URLs', () {
      const chapterWithHttpAndSpaces = AudiobookChapter(
        id: 'ch_http',
        bookId: 'book_http',
        order: 2,
        title: 'Chapter 02',
        durationSeconds: 1200,
        streamUrl: 'http://ia800100.us.archive.org/download/book_id/Chapter 02 - Audio.mp3',
      );
      final ep = chapterWithHttpAndSpaces.toEpisode(sampleBook);
      expect(ep.streamUrl, startsWith('https://'));
      expect(ep.streamUrl, contains('Chapter%2002%20-%20Audio.mp3'));
      expect(ep.isYouTube, isFalse);
      expect(ep.youtubeVideoId, isNull);
    });

    test('Audiobook JSON serialization and deserialization', () {
      final json = sampleBook.toJson();
      final recovered = Audiobook.fromJson(json);

      expect(recovered.id, equals(sampleBook.id));
      expect(recovered.title, equals(sampleBook.title));
      expect(recovered.authorName, equals('Arthur Conan Doyle'));
      expect(recovered.totalDurationSeconds, equals(10800));
      expect(recovered.chapters.length, equals(1));
      expect(recovered.chapters.first.title, equals(sampleChapter.title));
    });

    test('AudiobookProgress accurately calculates percentage across chapters', () {
      final multiChapterBook = Audiobook(
        id: 'book_multi',
        title: 'Three Chapters',
        authors: const [BookPerson(name: 'Test Author')],
        description: 'Test book',
        totalDurationSeconds: 3000,
        coverUrl: 'https://example.com/cover.jpg',
        source: AudiobookSource.librivox,
        sourceUrl: 'https://librivox.org/test',
        chapters: const [
          AudiobookChapter(
            id: '1',
            bookId: 'book_multi',
            order: 1,
            title: 'Ch 1',
            durationSeconds: 1000,
            streamUrl: 'url1',
          ),
          AudiobookChapter(
            id: '2',
            bookId: 'book_multi',
            order: 2,
            title: 'Ch 2',
            durationSeconds: 1000,
            streamUrl: 'url2',
          ),
          AudiobookChapter(
            id: '3',
            bookId: 'book_multi',
            order: 3,
            title: 'Ch 3',
            durationSeconds: 1000,
            streamUrl: 'url3',
          ),
        ],
      );

      // Listened to Chapter 1 completely, and 500s into Chapter 2 (index 1)
      final progress = AudiobookProgress(
        bookId: 'book_multi',
        currentChapterIndex: 1,
        positionMs: 500000, // 500 seconds
        lastListenedAt: DateTime.now(),
      );

      // (1000 + 500) / 3000 = 1500 / 3000 = 0.5 (50%)
      final pct = progress.calculatePercentage(multiChapterBook);
      expect(pct, closeTo(0.5, 0.01));
    });

    test('AudiobookBookmark preserves quotes and timestamps', () {
      final bookmark = AudiobookBookmark(
        id: 'bm_1',
        bookId: 'book_sherlock',
        chapterIndex: 0,
        chapterTitle: 'Chapter 01: A Scandal in Bohemia',
        timestampMs: 45000,
        note: 'When you have eliminated the impossible, whatever remains, however improbable, must be the truth.',
        createdAt: DateTime.now(),
      );

      final json = bookmark.toJson();
      final recovered = AudiobookBookmark.fromJson(json);

      expect(recovered.id, equals('bm_1'));
      expect(recovered.timestampMs, equals(45000));
      expect(recovered.note, contains('eliminated the impossible'));
    });
  });

  group('AudiobookService Fallback & Shelf Tests', () {
    final service = AudiobookService();

    test('getFeaturedBooks returns high-quality curated classics', () async {
      final featured = await service.getFeaturedBooks();
      expect(featured, isNotEmpty);
      expect(featured.any((b) => b.title.toLowerCase().contains('sherlock') || b.title.toLowerCase().contains('war') || b.title.toLowerCase().contains('dracula')), isTrue);
    });

    test('getBooksByGenre returns genre-specific shelves', () async {
      final selfHelp = await service.getBooksByGenre('Self-Help');
      expect(selfHelp, isNotEmpty);
      expect(selfHelp.any((b) => b.title.contains('Art of War') || b.title.contains('Thinketh')), isTrue);

      final hindi = await service.getBooksByGenre('Indian & Hindi Classics');
      expect(hindi, isNotEmpty);
      expect(hindi.any((b) => b.title.contains('Premchand') || b.title.contains('Gita')), isTrue);
    });

    test('Audiobook.hasValidCover correctly distinguishes real covers from LibriVox placeholders', () {
      const bookWithPlaceholder = Audiobook(
        id: 'lv_placeholder',
        title: 'Placeholder Book',
        authors: [BookPerson(name: 'Author')],
        description: 'Test',
        totalDurationSeconds: 100,
        coverUrl: 'https://archive.org/services/img/librivoxaudio',
        source: AudiobookSource.librivox,
        sourceUrl: '',
      );
      expect(bookWithPlaceholder.hasValidCover, isFalse);

      const bookWithEmpty = Audiobook(
        id: 'lv_empty',
        title: 'Empty Cover Book',
        authors: [BookPerson(name: 'Author')],
        description: 'Test',
        totalDurationSeconds: 100,
        coverUrl: '',
        source: AudiobookSource.librivox,
        sourceUrl: '',
      );
      expect(bookWithEmpty.hasValidCover, isFalse);

      const bookWithRealCover = Audiobook(
        id: 'lv_real',
        title: 'Real Cover Book',
        authors: [BookPerson(name: 'Author')],
        description: 'Test',
        totalDurationSeconds: 100,
        coverUrl: 'https://archive.org/download/LibrivoxCdCoverArt32/pride_and_prejudice_1209.jpg',
        source: AudiobookSource.librivox,
        sourceUrl: '',
      );
      expect(bookWithRealCover.hasValidCover, isTrue);
    });

    test('resolveBookCover gracefully handles search and fetches high-res covers', () async {
      final cover = await service.resolveBookCover('Pride and Prejudice', author: 'Jane Austen');
      // If network available, should return valid URL or null gracefully without throw
      if (cover != null) {
        expect(cover, startsWith('https://'));
      }
    });

    test('allCuratedBooks contains newly added Hindi & global classics with valid chapters', () {
      final curated = service.allCuratedBooks;
      expect(curated.length, greaterThanOrEqualTo(8));

      // Verify Panchatantra
      final panchatantra = curated.firstWhere((b) => b.id == 'curated-panchatantra-hindi');
      expect(panchatantra.title, contains('Panchatantra'));
      expect(panchatantra.language.toLowerCase(), contains('hi'));
      expect(panchatantra.chapters, isNotEmpty);
      expect(panchatantra.chapters.every((c) => c.durationSeconds > 0 && c.streamUrl.isNotEmpty), isTrue);

      // Verify Kabir Ke Dohe
      final kabir = curated.firstWhere((b) => b.id == 'curated-kabir-ke-dohe');
      expect(kabir.title, contains('Kabir'));
      expect(kabir.language.toLowerCase(), contains('hi'));
      expect(kabir.chapters, isNotEmpty);

      // Verify The Prophet
      final prophet = curated.firstWhere((b) => b.id == 'curated-the-prophet');
      expect(prophet.title, contains('The Prophet'));
      expect(prophet.chapters, isNotEmpty);
    });
  });
}
