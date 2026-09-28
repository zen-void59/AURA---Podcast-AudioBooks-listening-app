import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shimmer/shimmer.dart';
import 'package:aura/core/theme.dart';
import 'package:aura/core/routes.dart';
import 'package:aura/models/audiobook.dart';
import 'package:aura/providers/audiobook_provider.dart';
import 'package:aura/widgets/book_jacket_cover.dart';

class AudiobooksScreen extends StatefulWidget {
  const AudiobooksScreen({super.key});

  @override
  State<AudiobooksScreen> createState() => _AudiobooksScreenState();
}

class _AudiobooksScreenState extends State<AudiobooksScreen> {
  final TextEditingController _searchCtrl = TextEditingController();
  bool _isSearchExpanded = false;
  String _selectedLangFilter = 'All'; // 'All', 'Hindi', 'English'

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bookProv = context.watch<AudiobookProvider>();

    return Scaffold(
      backgroundColor: AuraColors.bg(context),
      body: SafeArea(
        child: RefreshIndicator(
          color: AuraColors.primary(context),
          backgroundColor: AuraColors.card(context),
          onRefresh: () => bookProv.fetchShelves(),
          child: CustomScrollView(
            slivers: [
              // 1. Top Header Bar
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                'Audiobooks',
                                style: GoogleFonts.dmSans(
                                  fontSize: 26,
                                  fontWeight: FontWeight.bold,
                                  color: AuraColors.text(context),
                                  letterSpacing: -0.5,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AuraColors.primary(context).withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  'FREE & OPEN',
                                  style: GoogleFonts.dmSans(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: AuraColors.primary(context),
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '50,000+ Classics, Hindi Stories & Bestsellers',
                            style: GoogleFonts.dmSans(
                              fontSize: 12,
                              color: AuraColors.subtext(context),
                            ),
                          ),
                        ],
                      ),
                      IconButton(
                        onPressed: () {
                          setState(() {
                            _isSearchExpanded = !_isSearchExpanded;
                            if (!_isSearchExpanded) {
                              _searchCtrl.clear();
                              bookProv.clearSearch();
                            }
                          });
                        },
                        icon: Icon(
                          _isSearchExpanded ? Icons.close : Icons.search,
                          color: AuraColors.text(context),
                        ),
                        tooltip: 'Search Audiobooks',
                      ),
                    ],
                  ),
                ),
              ),

              // 2. Expandable Search Bar
              if (_isSearchExpanded)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
                    child: Container(
                      decoration: BoxDecoration(
                        color: AuraColors.card(context),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AuraColors.border(context)),
                      ),
                      child: TextField(
                        controller: _searchCtrl,
                        autofocus: true,
                        style: GoogleFonts.dmSans(color: AuraColors.text(context), fontSize: 14),
                        decoration: InputDecoration(
                          hintText: 'Search title, author, or subject...',
                          hintStyle: GoogleFonts.dmSans(color: AuraColors.subtext(context), fontSize: 14),
                          prefixIcon: Icon(Icons.search, color: AuraColors.subtext(context), size: 20),
                          suffixIcon: _searchCtrl.text.isNotEmpty
                              ? IconButton(
                                  icon: Icon(Icons.clear, color: AuraColors.subtext(context), size: 18),
                                  onPressed: () {
                                    _searchCtrl.clear();
                                    bookProv.clearSearch();
                                  },
                                )
                              : null,
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        ),
                        onChanged: (val) => bookProv.search(val),
                      ),
                    ),
                  ),
                ),

              // 3. Language Filter Chips
              SliverToBoxAdapter(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                  child: Row(
                    children: [
                      _buildLangFilterChip('All', '🌍 All Languages'),
                      const SizedBox(width: 8),
                      _buildLangFilterChip('Hindi', '🇮🇳 Hindi (हिंदी)'),
                      const SizedBox(width: 8),
                      _buildLangFilterChip('English', '🇬🇧 English Classics'),
                    ],
                  ),
                ),
              ),

              // If searching, show search results
              if (bookProv.searchQuery.isNotEmpty) ...[
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                    child: Text(
                      'Search Results for "${bookProv.searchQuery}"',
                      style: GoogleFonts.dmSans(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AuraColors.text(context),
                      ),
                    ),
                  ),
                ),
                if (bookProv.isSearching)
                  const SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.all(40),
                      child: Center(child: CircularProgressIndicator()),
                    ),
                  )
                else if (bookProv.searchResults.isEmpty)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.all(40),
                      child: Center(
                        child: Text(
                          'No audiobooks found matching "${bookProv.searchQuery}"',
                          style: GoogleFonts.dmSans(color: AuraColors.subtext(context)),
                        ),
                      ),
                    ),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    sliver: SliverGrid(
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        childAspectRatio: 0.60,
                        crossAxisSpacing: 14,
                        mainAxisSpacing: 16,
                      ),
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final book = bookProv.searchResults[index];
                          return _AudiobookCard(book: book);
                        },
                        childCount: bookProv.searchResults.length,
                      ),
                    ),
                  ),
              ] else ...[
                // 4. "Jump Back In" (Resume Book Card)
                if (bookProv.currentlyListeningBooks.isNotEmpty)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                      child: _ResumeListeningCard(book: bookProv.currentlyListeningBooks.first),
                    ),
                  ),

                // 5. Hero Spotlight Banner
                if (bookProv.featuredBooks.isNotEmpty)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
                      child: _HeroSpotlightBanner(book: bookProv.featuredBooks.first),
                    ),
                  ),

                // 5.5 Personalized Recommendations based on user listening
                if (bookProv.recommendedBooks.isNotEmpty)
                  SliverToBoxAdapter(
                    child: _AudiobookShelf(
                      title: '🎯 Recommended For You',
                      subtitle: bookProv.recommendationReason,
                      books: bookProv.recommendedBooks,
                      badgeColor: AuraColors.primary(context),
                    ),
                  ),

                // 6. Curated Author Icons
                SliverToBoxAdapter(
                  child: _AuthorsSlider(
                    onAuthorTap: (name) {
                      setState(() {
                        _isSearchExpanded = true;
                        _searchCtrl.text = name;
                      });
                      bookProv.search(name);
                    },
                  ),
                ),

                // 7. Hindi Audiobooks Carousel (Prominently featured)
                if (_selectedLangFilter != 'English')
                  SliverToBoxAdapter(
                    child: _AudiobookShelf(
                      title: '🇮🇳 Hindi Classics & Kahaniyaan',
                      subtitle: 'Premchand, Tagore, Gita Vivechan & Historic Tales',
                      books: bookProv.hindiBooks,
                      badgeColor: Colors.orange,
                    ),
                  ),

                // 8. Self-Help & Personal Growth Shelf
                if (_selectedLangFilter != 'Hindi' && bookProv.genreShelves.containsKey('Self-Help'))
                  SliverToBoxAdapter(
                    child: _AudiobookShelf(
                      title: '⚡ Self-Help & Personal Growth',
                      subtitle: 'Timeless principles of mastery, focus and resilience',
                      books: bookProv.genreShelves['Self-Help'] ?? [],
                      badgeColor: Colors.amber,
                    ),
                  ),

                // 9. Mystery & Thriller Shelf
                if (_selectedLangFilter != 'Hindi' && bookProv.genreShelves.containsKey('Mystery & Detective'))
                  SliverToBoxAdapter(
                    child: _AudiobookShelf(
                      title: '🕵️ Mystery & Detective',
                      subtitle: 'Sherlock Holmes, Gothic intrigue and thrilling enigmas',
                      books: bookProv.genreShelves['Mystery & Detective'] ?? [],
                      badgeColor: Colors.deepPurple,
                    ),
                  ),

                // 10. Global Masterpieces Shelf
                if (_selectedLangFilter != 'Hindi' && bookProv.genreShelves.containsKey('Global Masterpieces'))
                  SliverToBoxAdapter(
                    child: _AudiobookShelf(
                      title: '🌍 Global Literature Masterpieces',
                      subtitle: 'The greatest novels and short stories ever written',
                      books: bookProv.genreShelves['Global Masterpieces'] ?? [],
                      badgeColor: Colors.teal,
                    ),
                  ),

                // 11. Business & Wealth Shelf
                if (_selectedLangFilter != 'Hindi' && bookProv.genreShelves.containsKey('Business & Wealth'))
                  SliverToBoxAdapter(
                    child: _AudiobookShelf(
                      title: '💡 Wealth, Strategy & Business',
                      subtitle: 'Foundations of wealth creation and financial philosophy',
                      books: bookProv.genreShelves['Business & Wealth'] ?? [],
                      badgeColor: Colors.green,
                    ),
                  ),

                // 12. Philosophy & Stoicism Shelf
                if (_selectedLangFilter != 'Hindi' && bookProv.genreShelves.containsKey('Philosophy & Wisdom'))
                  SliverToBoxAdapter(
                    child: _AudiobookShelf(
                      title: '🌿 Philosophy & Stoic Wisdom',
                      subtitle: 'Marcus Aurelius, Lao Tzu, Epictetus and deep reflections',
                      books: bookProv.genreShelves['Philosophy & Wisdom'] ?? [],
                      badgeColor: Colors.indigo,
                    ),
                  ),
              ],

              // Bottom padding for MiniPlayer
              const SliverToBoxAdapter(
                child: SizedBox(height: 100),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLangFilterChip(String key, String label) {
    final isSelected = _selectedLangFilter == key;
    final isDark = AuraColors.isDark(context);

    return GestureDetector(
      onTap: () => setState(() => _selectedLangFilter = key),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected
              ? AuraColors.primary(context)
              : (isDark ? AuraColors.surfaceDark : Colors.white),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? AuraColors.primary(context) : AuraColors.border(context),
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AuraColors.primary(context).withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ]
              : null,
        ),
        child: Text(
          label,
          style: GoogleFonts.dmSans(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            color: isSelected ? Colors.white : AuraColors.text(context),
          ),
        ),
      ),
    );
  }
}

// ─── Hero Spotlight Banner ────────────────────────────────────────────────

class _HeroSpotlightBanner extends StatelessWidget {
  final Audiobook book;
  const _HeroSpotlightBanner({required this.book});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Navigator.of(context).pushNamed(AppRoutes.audiobookDetail, arguments: book);
      },
      child: Container(
        height: 180,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: const LinearGradient(
            colors: [Color(0xFF2C3E50), Color(0xFF0F2027)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 14,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            // Background ambient glow
            Positioned(
              right: -30,
              top: -30,
              child: Container(
                width: 140,
                height: 140,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFFE67E22).withValues(alpha: 0.25),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: SizedBox(
                      width: 100,
                      height: 148,
                      child: book.hasValidCover
                          ? CachedNetworkImage(
                              imageUrl: book.coverUrl,
                              fit: BoxFit.cover,
                              placeholder: (_, _) => BookJacketCover(book: book, isLarge: true),
                              errorWidget: (_, _, _) => BookJacketCover(book: book, isLarge: true),
                            )
                          : BookJacketCover(book: book, isLarge: true),
                    ),
                  ),
                  const SizedBox(width: 16),
                  // Info & Action
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE67E22),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            'SPOTLIGHT CLASSIC',
                            style: GoogleFonts.dmSans(
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          book.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.dmSans(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            height: 1.2,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          book.authorName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.dmSans(
                            fontSize: 12,
                            color: Colors.white70,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            ElevatedButton.icon(
                              onPressed: () {
                                context.read<AudiobookProvider>().playChapter(book, 0, context);
                              },
                              icon: const Icon(Icons.play_arrow, size: 18, color: Colors.black),
                              label: Text(
                                'Listen Now',
                                style: GoogleFonts.dmSans(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black,
                                ),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.white,
                                foregroundColor: Colors.black,
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                elevation: 0,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              book.durationFormatted,
                              style: GoogleFonts.dmSans(
                                fontSize: 11,
                                color: Colors.white60,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Resume Listening Card ────────────────────────────────────────────────

class _ResumeListeningCard extends StatelessWidget {
  final Audiobook book;
  const _ResumeListeningCard({required this.book});

  @override
  Widget build(BuildContext context) {
    final bookProv = context.watch<AudiobookProvider>();
    final progress = bookProv.getProgress(book.id);
    final pct = progress != null ? progress.calculatePercentage(book) : 0.0;
    final chIndex = (progress?.currentChapterIndex ?? 0) + 1;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AuraColors.card(context),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AuraColors.border(context)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: SizedBox(
              width: 54,
              height: 54,
              child: book.hasValidCover
                  ? CachedNetworkImage(
                      imageUrl: book.coverUrl,
                      fit: BoxFit.cover,
                      errorWidget: (_, _, _) => BookJacketCover(book: book),
                    )
                  : BookJacketCover(book: book),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: Colors.green,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'RESUME READING',
                      style: GoogleFonts.dmSans(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: AuraColors.subtext(context),
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  book.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.dmSans(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: AuraColors.text(context),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Chapter $chIndex • ${(pct * 100).toInt()}% finished',
                  style: GoogleFonts.dmSans(
                    fontSize: 11,
                    color: AuraColors.subtext(context),
                  ),
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: pct > 0 ? pct : 0.05,
                    minHeight: 4,
                    backgroundColor: AuraColors.border(context),
                    valueColor: AlwaysStoppedAnimation<Color>(AuraColors.primary(context)),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          IconButton(
            onPressed: () => bookProv.resumeBook(book, context),
            icon: const Icon(Icons.play_circle_fill, size: 36),
            color: AuraColors.primary(context),
            tooltip: 'Resume',
          ),
        ],
      ),
    );
  }
}

// ─── Top Authors Slider ───────────────────────────────────────────────────

class _AuthorsSlider extends StatelessWidget {
  final ValueChanged<String> onAuthorTap;
  const _AuthorsSlider({required this.onAuthorTap});

  static const _authors = [
    {
      'name': 'Arthur Conan Doyle',
      'role': 'Sherlock Holmes',
      'avatar': 'https://upload.wikimedia.org/wikipedia/commons/thumb/b/bd/Arthur_Conan_Doyle_by_Walter_Benington%2C_1914.png/330px-Arthur_Conan_Doyle_by_Walter_Benington%2C_1914.png',
      'initials': 'AD',
      'color1': 0xFF1A365D,
      'color2': 0xFF2B6CB0,
    },
    {
      'name': 'Munshi Premchand',
      'role': 'Hindi Master',
      'avatar': 'https://upload.wikimedia.org/wikipedia/commons/thumb/a/a9/Premchand_in_1930s.jpg/330px-Premchand_in_1930s.jpg',
      'initials': 'MP',
      'color1': 0xFF9C4221,
      'color2': 0xFFDD6B20,
    },
    {
      'name': 'Jane Austen',
      'role': 'Romance & Satire',
      'avatar': 'https://upload.wikimedia.org/wikipedia/commons/thumb/c/cc/CassandraAusten-JaneAusten%28c.1810%29_hires.jpg/330px-CassandraAusten-JaneAusten%28c.1810%29_hires.jpg',
      'initials': 'JA',
      'color1': 0xFF553C9A,
      'color2': 0xFF805AD5,
    },
    {
      'name': 'Marcus Aurelius',
      'role': 'Stoic Philosophy',
      'avatar': 'https://upload.wikimedia.org/wikipedia/commons/thumb/e/ec/MSR-ra-61-b-1-DM.jpg/330px-MSR-ra-61-b-1-DM.jpg',
      'initials': 'MA',
      'color1': 0xFF744210,
      'color2': 0xFFD69E2E,
    },
    {
      'name': 'Sun Tzu',
      'role': 'Strategy & War',
      'avatar': 'https://upload.wikimedia.org/wikipedia/commons/thumb/c/cf/%E5%90%B4%E5%8F%B8%E9%A9%AC%E5%AD%99%E6%AD%A6.jpg/330px-%E5%90%B4%E5%8F%B8%E9%A9%AC%E5%AD%99%E6%AD%A6.jpg',
      'initials': 'ST',
      'color1': 0xFF7B341E,
      'color2': 0xFFE53E3E,
    },
    {
      'name': 'Franz Kafka',
      'role': 'Existential Drama',
      'avatar': 'https://upload.wikimedia.org/wikipedia/commons/thumb/2/26/Franz_Kafka%2C_1923.jpg/330px-Franz_Kafka%2C_1923.jpg',
      'initials': 'FK',
      'color1': 0xFF234E52,
      'color2': 0xFF319795,
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 10),
          child: Text(
            'Iconic Authors & Thinkers',
            style: GoogleFonts.dmSans(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AuraColors.text(context),
            ),
          ),
        ),
        SizedBox(
          height: 106,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: _authors.length,
            separatorBuilder: (_, _) => const SizedBox(width: 14),
            itemBuilder: (context, index) {
              final author = _authors[index];
              final color1 = Color(author['color1'] as int);
              final color2 = Color(author['color2'] as int);
              final initials = author['initials'] as String;
              final avatarUrl = author['avatar'] as String;

              return GestureDetector(
                onTap: () => onAuthorTap(author['name'] as String),
                child: Column(
                  children: [
                    Container(
                      width: 62,
                      height: 62,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: color2.withValues(alpha: 0.7),
                          width: 2.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: color1.withValues(alpha: 0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: ClipOval(
                        child: CachedNetworkImage(
                          imageUrl: avatarUrl,
                          width: 62,
                          height: 62,
                          fit: BoxFit.cover,
                          httpHeaders: const {
                            'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
                          },
                          placeholder: (_, _) => _AuthorFallbackAvatar(
                            initials: initials,
                            color1: color1,
                            color2: color2,
                          ),
                          errorWidget: (_, _, _) => _AuthorFallbackAvatar(
                            initials: initials,
                            color1: color1,
                            color2: color2,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    SizedBox(
                      width: 76,
                      child: Text(
                        (author['name'] as String).split(' ').last,
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.dmSans(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AuraColors.text(context),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _AuthorFallbackAvatar extends StatelessWidget {
  final String initials;
  final Color color1;
  final Color color2;

  const _AuthorFallbackAvatar({
    required this.initials,
    required this.color1,
    required this.color2,
  });

  @override
  Widget build(BuildContext context) {
    return ClipOval(
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [color1, color2],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Center(
          child: Text(
            initials,
            style: GoogleFonts.dmSans(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              letterSpacing: 0.5,
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Shelf Carousel ───────────────────────────────────────────────────────

class _AudiobookShelf extends StatelessWidget {
  final String title;
  final String subtitle;
  final List<Audiobook> books;
  final Color badgeColor;

  const _AudiobookShelf({
    required this.title,
    required this.subtitle,
    required this.books,
    required this.badgeColor,
  });

  @override
  Widget build(BuildContext context) {
    if (books.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.dmSans(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: AuraColors.text(context),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.dmSans(
                        fontSize: 11,
                        color: AuraColors.subtext(context),
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                '${books.length} books',
                style: GoogleFonts.dmSans(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AuraColors.subtext(context),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 248,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: books.length,
            separatorBuilder: (_, _) => const SizedBox(width: 14),
            itemBuilder: (context, index) {
              return SizedBox(
                width: 125,
                child: _AudiobookCard(book: books[index]),
              );
            },
          ),
        ),
      ],
    );
  }
}

// ─── Individual Audiobook Card ────────────────────────────────────────────

class _AudiobookCard extends StatelessWidget {
  final Audiobook book;
  const _AudiobookCard({required this.book});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Navigator.of(context).pushNamed(AppRoutes.audiobookDetail, arguments: book);
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Cover Art Container - Expanded ensures zero overflow regardless of font scaling
          Expanded(
            child: Stack(
              fit: StackFit.expand,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: book.hasValidCover
                      ? CachedNetworkImage(
                          imageUrl: book.coverUrl,
                          fit: BoxFit.cover,
                          placeholder: (_, _) => Shimmer.fromColors(
                            baseColor: Colors.grey.withValues(alpha: 0.2),
                            highlightColor: Colors.grey.withValues(alpha: 0.05),
                            child: BookJacketCover(book: book),
                          ),
                          errorWidget: (_, _, _) => BookJacketCover(book: book),
                        )
                      : BookJacketCover(book: book),
                ),
                // Duration Pill
                Positioned(
                  bottom: 6,
                  left: 6,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.7),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      book.durationFormatted,
                      style: GoogleFonts.dmSans(
                        fontSize: 9,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          // Title
          Text(
            book.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.dmSans(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AuraColors.text(context),
              height: 1.15,
            ),
          ),
          const SizedBox(height: 2),
          // Author
          Text(
            book.authorName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.dmSans(
              fontSize: 11,
              color: AuraColors.subtext(context),
            ),
          ),
        ],
      ),
    );
  }
}
