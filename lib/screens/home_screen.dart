import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shimmer/shimmer.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:aura/core/theme.dart';
import 'package:aura/core/routes.dart';
import 'package:aura/providers/search_provider.dart';
import 'package:aura/providers/audio_provider.dart';
import 'package:aura/models/podcast.dart';
import 'package:aura/models/episode.dart';
import 'package:aura/models/podcaster.dart';
import 'package:aura/widgets/mini_player.dart';
import 'package:aura/screens/search_screen.dart';
import 'package:aura/screens/library_screen.dart';
import 'package:aura/screens/audiobooks_screen.dart';
import 'package:flutter/services.dart';
import 'package:aura/services/link_stream_service.dart';
import 'package:aura/services/update_service.dart';
import 'package:aura/providers/theme_provider.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _navIndex = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkForAppUpdate();
    });
  }

  Future<void> _checkForAppUpdate() async {
    await Future.delayed(const Duration(milliseconds: 1500));
    if (!mounted) return;
    final update = await AppUpdateService().checkForUpdate();
    if (update != null && mounted) {
      AppUpdateService().showUpdateAlertModal(context, update);
    }
  }

  void _navigateToSearch([String? initialQuery]) {
    setState(() => _navIndex = 2);
    if (initialQuery != null && initialQuery.isNotEmpty) {
      context.read<SearchProvider>().searchNow(initialQuery);
    }
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      _DiscoverPage(
        onNavigateToSearch: _navigateToSearch,
        onNavigateToAudiobooks: () => setState(() => _navIndex = 1),
      ),
      const AudiobooksScreen(),
      const SearchScreen(),
      const LibraryScreen(),
    ];

    return Scaffold(
      backgroundColor: AuraColors.bg(context),
      body: Stack(
        children: [
          IndexedStack(
            index: _navIndex,
            children: pages,
          ),
          const Positioned(left: 0, right: 0, bottom: 0, child: MiniPlayer()),
        ],
      ),
      bottomNavigationBar: _buildNavBar(context),
    );
  }

  Widget _buildNavBar(BuildContext context) {
    final isDark = AuraColors.isDark(context);
    return Container(
      decoration: BoxDecoration(
        color: AuraColors.card(context),
        border: Border(
          top: BorderSide(color: AuraColors.border(context), width: 1),
        ),
      ),
      child: BottomNavigationBar(
        currentIndex: _navIndex,
        onTap: (i) => setState(() => _navIndex = i),
        type: BottomNavigationBarType.fixed,
        backgroundColor: AuraColors.card(context),
        selectedItemColor: isDark ? Colors.white : AuraColors.charcoal,
        unselectedItemColor: AuraColors.subtext(context),
        elevation: 0,
        selectedLabelStyle: GoogleFonts.dmSans(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.3,
        ),
        unselectedLabelStyle: GoogleFonts.dmSans(
          fontSize: 11,
          fontWeight: FontWeight.w400,
        ),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.explore_outlined),
            activeIcon: Icon(Icons.explore),
            label: 'Discover',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.menu_book_outlined),
            activeIcon: Icon(Icons.menu_book),
            label: 'Audiobooks',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.search_outlined),
            activeIcon: Icon(Icons.search),
            label: 'Search',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.library_music_outlined),
            activeIcon: Icon(Icons.library_music),
            label: 'Library',
          ),
        ],
      ),
    );
  }
}

// ─── Discover Page ────────────────────────────────────────────────────────────

class _DiscoverPage extends StatefulWidget {
  final void Function([String? query]) onNavigateToSearch;
  final VoidCallback onNavigateToAudiobooks;

  const _DiscoverPage({
    required this.onNavigateToSearch,
    required this.onNavigateToAudiobooks,
  });

  @override
  State<_DiscoverPage> createState() => _DiscoverPageState();
}

class _DiscoverPageState extends State<_DiscoverPage> {
  final PageController _spotlightController = PageController(viewportFraction: 0.92);
  int _activeSpotlightIndex = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<SearchProvider>().loadTrending();
    });
  }

  @override
  void dispose() {
    _spotlightController.dispose();
    super.dispose();
  }

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour >= 5 && hour < 12) {
      return '☀️ Good morning';
    } else if (hour >= 12 && hour < 17) {
      return '🌤️ Good afternoon';
    } else if (hour >= 17 && hour < 22) {
      return '🌆 Good evening';
    } else {
      return '🌙 Late night listening';
    }
  }

  String _formattedDate() {
    final now = DateTime.now();
    const days = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final d = days[now.weekday - 1];
    final m = months[now.month - 1];
    return '$d, $m ${now.day}';
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<SearchProvider, AudioProvider>(
      builder: (context, provider, audio, _) {
        final filter = provider.discoverFilter;
        final showAll = filter == 'all';
        final showYouTube = filter == 'all' || filter == 'youtube';
        final showJio = filter == 'all' || filter == 'jiosaavn';
        final history = audio.history;

        return RefreshIndicator(
          onRefresh: () => provider.loadTrending(force: true),
          color: AuraColors.charcoal,
          backgroundColor: AuraColors.card(context),
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              // 1. Header with greeting & search trigger
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 48, 20, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    _greeting(),
                                    style: GoogleFonts.dmSans(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: AuraColors.accent,
                                      letterSpacing: 0.3,
                                    ),
                                  ),
                                  Text(
                                    ' • ${_formattedDate()}',
                                    style: GoogleFonts.dmSans(
                                      fontSize: 12,
                                      color: AuraColors.subtext(context),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 2),
                              Text(
                                "What's trending today?",
                                style: GoogleFonts.dmSans(
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                  color: AuraColors.text(context),
                                ),
                              ),
                            ],
                          ),
                          PopupMenuButton<String>(
                            tooltip: 'Quick Actions',
                            icon: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: AuraColors.cardDeep(context),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.more_vert_rounded,
                                color: AuraColors.text(context),
                                size: 20,
                              ),
                            ),
                            elevation: 8,
                            color: AuraColors.card(context),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                              side: BorderSide(color: AuraColors.border(context)),
                            ),
                            onSelected: (value) {
                              if (value == 'theme') {
                                context.read<ThemeProvider>().toggleTheme();
                              } else if (value == 'audiobooks') {
                                widget.onNavigateToAudiobooks();
                              } else if (value == 'refresh') {
                                context.read<SearchProvider>().loadTrending(force: true);
                              }
                            },
                            itemBuilder: (ctx) {
                              final isDark = Theme.of(context).brightness == Brightness.dark;
                              return [
                                PopupMenuItem<String>(
                                  value: 'theme',
                                  child: Row(
                                    children: [
                                      Icon(
                                        isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
                                        size: 20,
                                        color: AuraColors.accent,
                                      ),
                                      const SizedBox(width: 12),
                                      Text(
                                        isDark ? 'Light Mode' : 'Dark Mode',
                                        style: GoogleFonts.dmSans(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                          color: AuraColors.text(context),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                PopupMenuItem<String>(
                                  value: 'audiobooks',
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.auto_stories_rounded,
                                        size: 20,
                                        color: AuraColors.accent,
                                      ),
                                      const SizedBox(width: 12),
                                      Text(
                                        'Explore Audiobooks',
                                        style: GoogleFonts.dmSans(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                          color: AuraColors.text(context),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                PopupMenuItem<String>(
                                  value: 'refresh',
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.refresh_rounded,
                                        size: 20,
                                        color: AuraColors.accent,
                                      ),
                                      const SizedBox(width: 12),
                                      Text(
                                        'Refresh Feed',
                                        style: GoogleFonts.dmSans(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                          color: AuraColors.text(context),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ];
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      // Search Trigger Bar
                      GestureDetector(
                        onTap: () => widget.onNavigateToSearch(),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(
                            color: AuraColors.card(context),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: AuraColors.border(context)),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.04),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.search,
                                color: AuraColors.subtext(context),
                                size: 20,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  'Search YouTube shows, JioSaavn podcasts...',
                                  style: GoogleFonts.dmSans(
                                    fontSize: 13,
                                    color: AuraColors.subtext(context),
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: AuraColors.cardDeep(context),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.tune,
                                      size: 13,
                                      color: AuraColors.subtext(context),
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      'Explore',
                                      style: GoogleFonts.dmSans(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w600,
                                        color: AuraColors.text(context),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // 2. Filter Tabs (All, YouTube, JioSaavn)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: _FilterPillsBar(
                    currentFilter: filter,
                    onSelectFilter: (f) => provider.setDiscoverFilter(f),
                  ),
                ),
              ),

              // 3. Jump Back In (Listening History Auto-Suggest)
              if (history.isNotEmpty) ...[
                SliverToBoxAdapter(
                  child: _JumpBackInSection(
                    history: history,
                    onTapEpisode: (ep) => audio.play(ep),
                  ),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 22)),
              ],

              // 4. Hero Spotlight Carousel
              if (provider.loadingTrending)
                const SliverToBoxAdapter(child: _SpotlightShimmer())
              else if (provider.featuredPodcasts.isNotEmpty && showAll) ...[
                SliverToBoxAdapter(
                  child: Column(
                    children: [
                      SizedBox(
                        height: 205,
                        child: PageView.builder(
                          controller: _spotlightController,
                          itemCount: provider.featuredPodcasts.length,
                          onPageChanged: (idx) => setState(() => _activeSpotlightIndex = idx),
                          itemBuilder: (context, idx) {
                            final podcast = provider.featuredPodcasts[idx];
                            return _SpotlightHeroCard(podcast: podcast);
                          },
                        ),
                      ),
                      const SizedBox(height: 8),
                      // Dot Indicator
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(
                          provider.featuredPodcasts.length,
                          (i) => AnimatedContainer(
                            duration: const Duration(milliseconds: 250),
                            margin: const EdgeInsets.symmetric(horizontal: 3),
                            width: _activeSpotlightIndex == i ? 18 : 6,
                            height: 6,
                            decoration: BoxDecoration(
                              color: _activeSpotlightIndex == i
                                  ? (AuraColors.isDark(context) ? Colors.white : AuraColors.charcoal)
                                  : AuraColors.border(context),
                              borderRadius: BorderRadius.circular(3),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 24)),
              ],

              // 5. Paste Link & Stream Video-to-Audio (YouTube or JioSaavn/Web)
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(20, 0, 20, 24),
                  child: _PasteLinkStreamCard(),
                ),
              ),

              // 6. Popular Podcasters Slider (Across Nations & Region Specific)
              SliverToBoxAdapter(
                child: _PopularPodcastersSection(
                  podcasters: provider.podcasters,
                  selectedRegion: provider.podcasterRegion,
                  onRegionChanged: (r) => provider.setPodcasterRegion(r),
                  onSelectPodcaster: (podcaster) {
                    widget.onNavigateToSearch(podcaster.searchQuery);
                  },
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 24)),

              // 6. 🔴 Live & Premiere Podcasts Section
              if (provider.liveOrPremiere.isNotEmpty && showYouTube) ...[
                SliverToBoxAdapter(
                  child: _SectionHeader(
                    title: 'Live & Premiere Shows',
                    subtitle: 'Happening now, live streams & podcast premieres',
                    icon: Icons.sensors,
                    iconColor: const Color(0xFFFF2222),
                    onSeeAll: () => widget.onNavigateToSearch('live podcast'),
                  ),
                ),
                SliverToBoxAdapter(
                  child: SizedBox(
                    height: 232,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      itemCount: provider.liveOrPremiere.length,
                      separatorBuilder: (context, index) => const SizedBox(width: 14),
                      itemBuilder: (context, i) => _LivePodcastCard(
                        podcast: provider.liveOrPremiere[i],
                      ),
                    ),
                  ),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 24)),
              ],

              // 7. 🔥 Hot Picks (Trending Episodes)
              if (provider.hotPicks.isNotEmpty && showYouTube) ...[
                SliverToBoxAdapter(
                  child: _SectionHeader(
                    title: 'Hot Picks',
                    subtitle: 'Episodes generating massive buzz right now',
                    icon: Icons.local_fire_department,
                    iconColor: const Color(0xFFFF6F00),
                    onSeeAll: () => widget.onNavigateToSearch('hot podcast'),
                  ),
                ),
                SliverToBoxAdapter(
                  child: SizedBox(
                    height: 228,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      itemCount: provider.hotPicks.length,
                      separatorBuilder: (context, index) => const SizedBox(width: 14),
                      itemBuilder: (context, i) => _YouTubePodcastCard(
                        podcast: provider.hotPicks[i],
                        badgeText: '🔥 HOT',
                      ),
                    ),
                  ),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 24)),
              ],

              // 8. 🚀 Fresh & Just Dropped
              if (provider.freshReleases.isNotEmpty && showYouTube) ...[
                SliverToBoxAdapter(
                  child: _SectionHeader(
                    title: 'Fresh & Just Dropped',
                    subtitle: 'Brand new releases and newly uploaded episodes',
                    icon: Icons.new_releases,
                    iconColor: const Color(0xFF00B0FF),
                    onSeeAll: () => widget.onNavigateToSearch('new podcast episode'),
                  ),
                ),
                SliverToBoxAdapter(
                  child: SizedBox(
                    height: 228,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      itemCount: provider.freshReleases.length,
                      separatorBuilder: (context, index) => const SizedBox(width: 14),
                      itemBuilder: (context, i) => _YouTubePodcastCard(
                        podcast: provider.freshReleases[i],
                        badgeText: '⚡ NEW',
                      ),
                    ),
                  ),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 24)),
              ],

              // 9. 💎 Underrated Hidden Gems (Real JioSaavn Shows)
              if (provider.underratedGems.isNotEmpty && showJio) ...[
                SliverToBoxAdapter(
                  child: _SectionHeader(
                    title: 'Underrated Hidden Gems',
                    subtitle: 'Exceptional storytelling, indie podcasts & depth',
                    icon: Icons.diamond_outlined,
                    iconColor: const Color(0xFF7C4DFF),
                    onSeeAll: () => widget.onNavigateToSearch('stories podcast'),
                  ),
                ),
                SliverToBoxAdapter(
                  child: SizedBox(
                    height: 215,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      itemCount: provider.underratedGems.length,
                      separatorBuilder: (context, index) => const SizedBox(width: 14),
                      itemBuilder: (context, i) => _JioPodcastCard(
                        podcast: provider.underratedGems[i],
                        badgeText: '💎 GEM',
                      ),
                    ),
                  ),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 24)),
              ],

              // 10. Trending on JioSaavn (Real Shows: Ranveer, Finshots, Desi Crime)
              if (showJio) ...[
                SliverToBoxAdapter(
                  child: _SectionHeader(
                    title: 'Top Charts on JioSaavn',
                    subtitle: 'Leading original talk shows, finance & crime',
                    icon: Icons.graphic_eq,
                    iconColor: AuraColors.accent,
                    onSeeAll: () => widget.onNavigateToSearch('popular podcast'),
                  ),
                ),
                SliverToBoxAdapter(
                  child: provider.loadingTrending && provider.trendingJio.isEmpty
                      ? const _HorizontalShimmerList(height: 205, itemWidth: 145)
                      : provider.trendingJio.isEmpty
                          ? const SizedBox.shrink()
                          : SizedBox(
                              height: 215,
                              child: ListView.separated(
                                scrollDirection: Axis.horizontal,
                                padding: const EdgeInsets.symmetric(horizontal: 20),
                                itemCount: provider.trendingJio.length,
                                separatorBuilder: (context, index) => const SizedBox(width: 14),
                                itemBuilder: (context, i) => _JioPodcastCard(
                                  podcast: provider.trendingJio[i],
                                ),
                              ),
                            ),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 24)),
              ],

              // 11. Expanded Thematic Hubs (12 Categories)
              SliverToBoxAdapter(
                child: _CuratedThemesSection(
                  onThemeSelected: (query) => widget.onNavigateToSearch(query),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 24)),

              // 12. Top Recommended Leaderboard
              if (provider.trending.isNotEmpty) ...[
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Top Recommended Picks',
                          style: GoogleFonts.dmSans(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AuraColors.text(context),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Curated mix of both audio and YouTube podcasts',
                          style: GoogleFonts.dmSans(
                            fontSize: 12,
                            color: AuraColors.subtext(context),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 12)),
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final podcast = provider.trending[index];
                        return _RecommendedPodcastRow(
                          rank: index + 1,
                          podcast: podcast,
                        );
                      },
                      childCount: provider.trending.take(8).length,
                    ),
                  ),
                ),
              ],

              const SliverToBoxAdapter(child: SizedBox(height: 120)),
            ],
          ),
        );
      },
    );
  }
}

// ─── Jump Back In (Listening History Auto-Suggest) ───────────────────────────

class _JumpBackInSection extends StatelessWidget {
  final List<Episode> history;
  final ValueChanged<Episode> onTapEpisode;

  const _JumpBackInSection({
    required this.history,
    required this.onTapEpisode,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            children: [
              const Icon(Icons.history, size: 18, color: AuraColors.accent),
              const SizedBox(width: 8),
              Text(
                'Jump Back In',
                style: GoogleFonts.dmSans(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: AuraColors.text(context),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 115,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: history.take(6).length,
            separatorBuilder: (context, index) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              final ep = history[index];
              return _HistoryEpisodeCard(
                episode: ep,
                onTap: () => onTapEpisode(ep),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _HistoryEpisodeCard extends StatelessWidget {
  final Episode episode;
  final VoidCallback onTap;

  const _HistoryEpisodeCard({
    required this.episode,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 250,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: AuraColors.card(context),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AuraColors.border(context)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Stack(
              alignment: Alignment.center,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: SizedBox(
                    width: 70,
                    height: 70,
                    child: (episode.displayImageUrl != null && episode.displayImageUrl!.isNotEmpty)
                        ? CachedNetworkImage(
                            imageUrl: episode.displayImageUrl!,
                            width: 70,
                            height: 70,
                            fit: BoxFit.cover,
                            httpHeaders: const {
                              'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
                            },
                            placeholder: (context, url) => Container(
                              color: AuraColors.cardDeep(context),
                              child: Center(
                                child: SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: AuraColors.accent.withValues(alpha: 0.5),
                                  ),
                                ),
                              ),
                            ),
                            errorWidget: (context, url, error) => _buildFallbackThumbnail(context),
                          )
                        : _buildFallbackThumbnail(context),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(5),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.6),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.play_arrow, color: Colors.white, size: 16),
                ),
              ],
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Row(
                    children: [
                      _buildMediaPill(context),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    episode.name,
                    style: GoogleFonts.dmSans(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AuraColors.text(context),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    episode.showName,
                    style: GoogleFonts.dmSans(
                      fontSize: 11,
                      color: AuraColors.subtext(context),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFallbackThumbnail(BuildContext context) {
    IconData icon = Icons.podcasts;
    Color iconColor = AuraColors.accent;
    if (episode.isYouTube) {
      icon = Icons.smart_display;
      iconColor = const Color(0xFFFF0000);
    } else if (episode.id.startsWith('ab_')) {
      icon = Icons.auto_stories;
      iconColor = const Color(0xFFE67E22);
    }
    return Container(
      color: AuraColors.cardDeep(context),
      width: 70,
      height: 70,
      child: Center(
        child: Icon(icon, color: iconColor, size: 28),
      ),
    );
  }

  Widget _buildMediaPill(BuildContext context) {
    String label = 'Podcast';
    Color pillColor = AuraColors.accent;
    Color textColor = AuraColors.accent;

    if (episode.isYouTube) {
      label = 'YouTube';
      pillColor = const Color(0xFFFF0000);
      textColor = const Color(0xFFDD0000);
    } else if (episode.id.startsWith('ab_')) {
      label = 'Audiobook';
      pillColor = const Color(0xFFE67E22);
      textColor = const Color(0xFFD35400);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
      decoration: BoxDecoration(
        color: pillColor.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: GoogleFonts.dmSans(
          fontSize: 9,
          fontWeight: FontWeight.bold,
          color: textColor,
        ),
      ),
    );
  }
}

// ─── Popular Podcasters Section ───────────────────────────────────────────────

class _PopularPodcastersSection extends StatelessWidget {
  final List<Podcaster> podcasters;
  final String selectedRegion;
  final ValueChanged<String> onRegionChanged;
  final ValueChanged<Podcaster> onSelectPodcaster;

  const _PopularPodcastersSection({
    required this.podcasters,
    required this.selectedRegion,
    required this.onRegionChanged,
    required this.onSelectPodcaster,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.stars, color: Color(0xFFFFB300), size: 18),
                        const SizedBox(width: 8),
                        Text(
                          'Popular Creators & Podcasters',
                          style: GoogleFonts.dmSans(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                            color: AuraColors.text(context),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Leading voices across nations & your region',
                      style: GoogleFonts.dmSans(
                        fontSize: 11,
                        color: AuraColors.subtext(context),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        // Region Filter Chips
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            children: [
              _RegionChip(
                label: 'All Creators',
                isSelected: selectedRegion == 'all',
                onTap: () => onRegionChanged('all'),
              ),
              const SizedBox(width: 8),
              _RegionChip(
                label: '🇮🇳 India Top',
                isSelected: selectedRegion == 'india',
                onTap: () => onRegionChanged('india'),
              ),
              const SizedBox(width: 8),
              _RegionChip(
                label: '🌍 Global Stars',
                isSelected: selectedRegion == 'global',
                onTap: () => onRegionChanged('global'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        // Horizontal Podcasters Row
        SizedBox(
          height: 136,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: podcasters.length,
            separatorBuilder: (context, index) => const SizedBox(width: 14),
            itemBuilder: (context, index) {
              final p = podcasters[index];
              return _PodcasterAvatarCard(
                podcaster: p,
                onTap: () => onSelectPodcaster(p),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _RegionChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _RegionChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = AuraColors.isDark(context);
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected
              ? (isDark ? Colors.white : AuraColors.charcoal)
              : AuraColors.card(context),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected
                ? (isDark ? Colors.white : AuraColors.charcoal)
                : AuraColors.border(context),
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.dmSans(
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            color: isSelected
                ? (isDark ? Colors.black : Colors.white)
                : AuraColors.text(context),
          ),
        ),
      ),
    );
  }
}

class _PodcasterAvatarCard extends StatelessWidget {
  final Podcaster podcaster;
  final VoidCallback onTap;

  const _PodcasterAvatarCard({
    required this.podcaster,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 86,
        child: Column(
          children: [
            Stack(
              alignment: Alignment.bottomRight,
              children: [
                Container(
                  width: 68,
                  height: 68,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: podcaster.region.toLowerCase() == 'india'
                          ? const Color(0xFFFF9933)
                          : const Color(0xFF29B6F6),
                      width: 2,
                    ),
                  ),
                  child: ClipOval(
                    child: CachedNetworkImage(
                      imageUrl: podcaster.avatarUrl,
                      fit: BoxFit.cover,
                      placeholder: (context, url) => Container(color: AuraColors.cardDeep(context)),
                      errorWidget: (context, url, error) => Container(
                        color: AuraColors.cardDeep(context),
                        child: const Icon(Icons.person, color: Colors.grey),
                      ),
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(2),
                  decoration: const BoxDecoration(
                    color: Colors.blueAccent,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.check, size: 10, color: Colors.white),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              podcaster.name,
              style: GoogleFonts.dmSans(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AuraColors.text(context),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
            Text(
              podcaster.tag,
              style: GoogleFonts.dmSans(
                fontSize: 9,
                color: AuraColors.subtext(context),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Live & Premiere Card ─────────────────────────────────────────────────────

class _LivePodcastCard extends StatelessWidget {
  final Podcast podcast;

  const _LivePodcastCard({required this.podcast});

  void _quickPlay(BuildContext context) {
    if (podcast.youtubeId != null) {
      final episode = Episode(
        id: 'yt_ep_${podcast.youtubeId}',
        name: podcast.name,
        description: podcast.description,
        imageUrl: podcast.imageUrl,
        showId: podcast.id,
        showName: podcast.channelName ?? 'YouTube Live',
        isYouTube: true,
        youtubeVideoId: podcast.youtubeId,
        url: podcast.url,
      );
      context.read<AudioProvider>().play(episode);
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.of(context).pushNamed(
        AppRoutes.podcastDetail,
        arguments: podcast,
      ),
      child: SizedBox(
        width: 175,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: AspectRatio(
                    aspectRatio: 16 / 10,
                    child: CachedNetworkImage(
                      imageUrl: podcast.imageUrl ?? '',
                      fit: BoxFit.cover,
                      placeholder: (context, url) => Container(color: AuraColors.cardDeep(context)),
                      errorWidget: (context, url, error) => Container(
                        color: AuraColors.cardDeep(context),
                        child: const Icon(Icons.sensors, color: Colors.grey),
                      ),
                    ),
                  ),
                ),
                // Red LIVE badge
                Positioned(
                  top: 6,
                  left: 6,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE50914),
                      borderRadius: BorderRadius.circular(6),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFE50914).withValues(alpha: 0.5),
                          blurRadius: 8,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'LIVE NOW',
                          style: GoogleFonts.dmSans(
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                // Play Button
                Positioned(
                  bottom: 6,
                  right: 6,
                  child: GestureDetector(
                    onTap: () => _quickPlay(context),
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: const BoxDecoration(
                        color: Color(0xFFE50914),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.play_arrow,
                        color: Colors.white,
                        size: 16,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              podcast.name,
              style: GoogleFonts.dmSans(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AuraColors.text(context),
                height: 1.25,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Text(
              podcast.channelName ?? 'Live Stream',
              style: GoogleFonts.dmSans(
                fontSize: 11,
                color: AuraColors.subtext(context),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Filter Pills Bar ─────────────────────────────────────────────────────────

class _FilterPillsBar extends StatelessWidget {
  final String currentFilter;
  final ValueChanged<String> onSelectFilter;

  const _FilterPillsBar({
    required this.currentFilter,
    required this.onSelectFilter,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = AuraColors.isDark(context);
    final filters = [
      ('all', '✨ All Trending'),
      ('youtube', '🔴 YouTube'),
      ('jiosaavn', '🎵 JioSaavn'),
    ];

    return SizedBox(
      height: 38,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: filters.length,
        separatorBuilder: (context, index) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final (id, label) = filters[i];
          final isSelected = currentFilter == id;

          return GestureDetector(
            onTap: () => onSelectFilter(id),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: isSelected
                    ? (isDark ? Colors.white : AuraColors.charcoal)
                    : AuraColors.card(context),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isSelected
                      ? (isDark ? Colors.white : AuraColors.charcoal)
                      : AuraColors.border(context),
                ),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.15),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ]
                    : null,
              ),
              child: Center(
                child: Text(
                  label,
                  style: GoogleFonts.dmSans(
                    fontSize: 12,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                    color: isSelected
                        ? (isDark ? Colors.black : AuraColors.cream)
                        : AuraColors.subtext(context),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

// ─── Section Header ──────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color iconColor;
  final VoidCallback onSeeAll;

  const _SectionHeader({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.iconColor,
    required this.onSeeAll,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(icon, size: 18, color: iconColor),
                    const SizedBox(width: 8),
                    Text(
                      title,
                      style: GoogleFonts.dmSans(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: AuraColors.text(context),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: GoogleFonts.dmSans(
                    fontSize: 11,
                    color: AuraColors.subtext(context),
                  ),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: onSeeAll,
            child: Text(
              'See all',
              style: GoogleFonts.dmSans(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AuraColors.text(context),
                decoration: TextDecoration.underline,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Spotlight Hero Card ──────────────────────────────────────────────────────

class _SpotlightHeroCard extends StatelessWidget {
  final Podcast podcast;

  const _SpotlightHeroCard({required this.podcast});

  void _playDirectly(BuildContext context) {
    if (podcast.isYouTube && podcast.youtubeId != null) {
      final episode = Episode(
        id: 'yt_ep_${podcast.youtubeId}',
        name: podcast.name,
        description: podcast.description,
        imageUrl: podcast.imageUrl,
        showId: podcast.id,
        showName: podcast.channelName ?? 'YouTube',
        isYouTube: true,
        youtubeVideoId: podcast.youtubeId,
        url: podcast.url,
      );
      context.read<AudioProvider>().play(episode);
    } else {
      Navigator.of(context).pushNamed(AppRoutes.podcastDetail, arguments: podcast);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isYt = podcast.isYouTube;

    return GestureDetector(
      onTap: () => Navigator.of(context).pushNamed(
        AppRoutes.podcastDetail,
        arguments: podcast,
      ),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 6),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.12),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (podcast.imageUrl != null && podcast.imageUrl!.isNotEmpty)
                CachedNetworkImage(
                  imageUrl: podcast.headerImageUrl ?? podcast.imageUrl!,
                  fit: BoxFit.cover,
                  placeholder: (context, url) => Container(color: AuraColors.darkCard),
                  errorWidget: (context, url, error) => Container(color: AuraColors.darkCard),
                )
              else
                Container(color: AuraColors.darkCard),

              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.2),
                      Colors.black.withValues(alpha: 0.85),
                    ],
                  ),
                ),
              ),

              Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: isYt
                            ? const Color(0xFFFF0000).withValues(alpha: 0.85)
                            : AuraColors.accent.withValues(alpha: 0.85),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            isYt ? Icons.play_arrow : Icons.graphic_eq,
                            color: Colors.white,
                            size: 13,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            isYt ? 'YouTube Spotlight' : 'Featured Original',
                            style: GoogleFonts.dmSans(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ),

                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          podcast.name,
                          style: GoogleFonts.dmSans(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            height: 1.25,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          podcast.channelName ?? 'Trending Show',
                          style: GoogleFonts.dmSans(
                            fontSize: 12,
                            color: Colors.white.withValues(alpha: 0.75),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            ElevatedButton.icon(
                              onPressed: () => _playDirectly(context),
                              icon: const Icon(Icons.play_arrow, size: 16, color: AuraColors.charcoal),
                              label: Text(
                                'Listen Now',
                                style: GoogleFonts.dmSans(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: AuraColors.charcoal,
                                ),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AuraColors.cream,
                                elevation: 0,
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(18),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            TextButton(
                              onPressed: () => Navigator.of(context).pushNamed(
                                AppRoutes.podcastDetail,
                                arguments: podcast,
                              ),
                              child: Text(
                                'View Episodes',
                                style: GoogleFonts.dmSans(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.white.withValues(alpha: 0.85),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── YouTube Podcast Card ────────────────────────────────────────────────────

class _YouTubePodcastCard extends StatelessWidget {
  final Podcast podcast;
  final String? badgeText;

  const _YouTubePodcastCard({
    required this.podcast,
    this.badgeText,
  });

  void _quickPlay(BuildContext context) {
    if (podcast.youtubeId != null) {
      final episode = Episode(
        id: 'yt_ep_${podcast.youtubeId}',
        name: podcast.name,
        description: podcast.description,
        imageUrl: podcast.imageUrl,
        showId: podcast.id,
        showName: podcast.channelName ?? 'YouTube',
        isYouTube: true,
        youtubeVideoId: podcast.youtubeId,
        url: podcast.url,
      );
      context.read<AudioProvider>().play(episode);
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.of(context).pushNamed(
        AppRoutes.podcastDetail,
        arguments: podcast,
      ),
      child: SizedBox(
        width: 165,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: AspectRatio(
                    aspectRatio: 16 / 10,
                    child: CachedNetworkImage(
                      imageUrl: podcast.imageUrl ?? '',
                      fit: BoxFit.cover,
                      placeholder: (context, url) => Container(color: AuraColors.cardDeep(context)),
                      errorWidget: (context, url, error) => Container(
                        color: AuraColors.cardDeep(context),
                        child: const Icon(Icons.videocam, color: Colors.grey),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: 6,
                  right: 6,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.75),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.play_arrow, color: Colors.red, size: 11),
                        const SizedBox(width: 2),
                        Text(
                          badgeText ?? 'YouTube',
                          style: GoogleFonts.dmSans(
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Positioned(
                  bottom: 6,
                  right: 6,
                  child: GestureDetector(
                    onTap: () => _quickPlay(context),
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: (AuraColors.isDark(context) ? Colors.white : AuraColors.charcoal).withValues(alpha: 0.85),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.play_arrow,
                        color: AuraColors.isDark(context) ? Colors.black : Colors.white,
                        size: 16,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              podcast.name,
              style: GoogleFonts.dmSans(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AuraColors.text(context),
                height: 1.25,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Text(
              podcast.channelName ?? 'YouTube Podcast',
              style: GoogleFonts.dmSans(
                fontSize: 11,
                color: AuraColors.subtext(context),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

// ─── JioSaavn Podcast Card ───────────────────────────────────────────────────

class _JioPodcastCard extends StatelessWidget {
  final Podcast podcast;
  final String? badgeText;

  const _JioPodcastCard({
    required this.podcast,
    this.badgeText,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.of(context).pushNamed(
        AppRoutes.podcastDetail,
        arguments: podcast,
      ),
      child: SizedBox(
        width: 145,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: AspectRatio(
                    aspectRatio: 1,
                    child: CachedNetworkImage(
                      imageUrl: podcast.imageUrl ?? '',
                      fit: BoxFit.cover,
                      placeholder: (context, url) => Container(color: AuraColors.cardDeep(context)),
                      errorWidget: (context, url, error) => Container(
                        color: AuraColors.cardDeep(context),
                        child: const Icon(Icons.podcasts, color: Colors.grey),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: 6,
                  left: 6,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AuraColors.charcoal.withValues(alpha: 0.75),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.graphic_eq, color: AuraColors.accent, size: 10),
                        const SizedBox(width: 3),
                        Text(
                          badgeText ?? 'JioSaavn',
                          style: GoogleFonts.dmSans(
                            fontSize: 9,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              podcast.name,
              style: GoogleFonts.dmSans(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AuraColors.text(context),
                height: 1.25,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            if (podcast.totalEpisodes != null) ...[
              const SizedBox(height: 2),
              Text(
                '${podcast.totalEpisodes} episodes',
                style: GoogleFonts.dmSans(
                  fontSize: 11,
                  color: AuraColors.subtext(context),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ─── Curated Themes Section (12 Expanded Themes) ─────────────────────────────

class _CuratedThemesSection extends StatelessWidget {
  final ValueChanged<String> onThemeSelected;

  const _CuratedThemesSection({required this.onThemeSelected});

  static const _themes = [
    _Theme('True Crime', '🔍', 'true crime'),
    _Theme('Tech & AI', '💡', 'technology ai'),
    _Theme('Mindfulness', '🌿', 'mindfulness psychology'),
    _Theme('Business', '📈', 'business startups'),
    _Theme('Comedy', '😂', 'comedy podcast'),
    _Theme('Science', '🔬', 'science huberman'),
    _Theme('Motivation', '⚡', 'motivation fitness'),
    _Theme('History', '📜', 'history mythology'),
    _Theme('Philosophy', '🧠', 'philosophy ideas'),
    _Theme('Geopolitics', '🌐', 'geopolitics global'),
    _Theme('Cinema & Art', '🎬', 'cinema movies podcast'),
    _Theme('Finance', '💰', 'finance investing stock'),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Explore Thematic Hubs',
                style: GoogleFonts.dmSans(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: AuraColors.text(context),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Over 12 handpicked categories across audio & video formats',
                style: GoogleFonts.dmSans(
                  fontSize: 11,
                  color: AuraColors.subtext(context),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 95,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: _themes.length,
            separatorBuilder: (context, index) => const SizedBox(width: 10),
            itemBuilder: (context, i) => _ThemeCard(
              theme: _themes[i],
              onTap: () => onThemeSelected(_themes[i].query),
            ),
          ),
        ),
      ],
    );
  }
}

class _Theme {
  final String label;
  final String emoji;
  final String query;
  const _Theme(this.label, this.emoji, this.query);
}

class _ThemeCard extends StatelessWidget {
  final _Theme theme;
  final VoidCallback onTap;

  const _ThemeCard({required this.theme, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 92,
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
        decoration: BoxDecoration(
          color: AuraColors.card(context),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AuraColors.border(context)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(theme.emoji, style: const TextStyle(fontSize: 26)),
            const SizedBox(height: 6),
            Text(
              theme.label,
              style: GoogleFonts.dmSans(
                fontSize: 11,
                color: AuraColors.text(context),
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Recommended Podcast Row (Numbered List) ───────────────────────────────────

class _RecommendedPodcastRow extends StatelessWidget {
  final int rank;
  final Podcast podcast;

  const _RecommendedPodcastRow({
    required this.rank,
    required this.podcast,
  });

  void _quickPlay(BuildContext context) {
    if (podcast.isYouTube && podcast.youtubeId != null) {
      final episode = Episode(
        id: 'yt_ep_${podcast.youtubeId}',
        name: podcast.name,
        description: podcast.description,
        imageUrl: podcast.imageUrl,
        showId: podcast.id,
        showName: podcast.channelName ?? 'YouTube',
        isYouTube: true,
        youtubeVideoId: podcast.youtubeId,
        url: podcast.url,
      );
      context.read<AudioProvider>().play(episode);
    } else {
      Navigator.of(context).pushNamed(AppRoutes.podcastDetail, arguments: podcast);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isYt = podcast.isYouTube;

    return GestureDetector(
      onTap: () => Navigator.of(context).pushNamed(
        AppRoutes.podcastDetail,
        arguments: podcast,
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AuraColors.card(context),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AuraColors.border(context)),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 26,
              child: Text(
                rank.toString().padLeft(2, '0'),
                style: GoogleFonts.dmSans(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: AuraColors.accent,
                ),
              ),
            ),
            const SizedBox(width: 8),

            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: CachedNetworkImage(
                imageUrl: podcast.imageUrl ?? '',
                width: 52,
                height: 52,
                fit: BoxFit.cover,
                placeholder: (context, url) => Container(color: AuraColors.cardDeep(context)),
                errorWidget: (context, url, error) => Container(
                  color: AuraColors.cardDeep(context),
                  child: const Icon(Icons.podcasts, size: 24, color: Colors.grey),
                ),
              ),
            ),
            const SizedBox(width: 14),

            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    podcast.name,
                    style: GoogleFonts.dmSans(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AuraColors.text(context),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                        decoration: BoxDecoration(
                          color: isYt
                              ? const Color(0xFFFF0000).withValues(alpha: 0.12)
                              : AuraColors.accent.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          isYt ? 'YouTube' : 'JioSaavn',
                          style: GoogleFonts.dmSans(
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            color: isYt ? const Color(0xFFCC0000) : AuraColors.text(context),
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          podcast.channelName ?? (podcast.totalEpisodes != null ? '${podcast.totalEpisodes} episodes' : 'Podcast'),
                          style: GoogleFonts.dmSans(
                            fontSize: 11,
                            color: AuraColors.subtext(context),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            IconButton(
              icon: Icon(
                Icons.play_circle_outline,
                size: 26,
                color: AuraColors.text(context),
              ),
              onPressed: () => _quickPlay(context),
            ),
            IconButton(
              icon: Icon(
                Icons.more_vert,
                size: 20,
                color: AuraColors.subtext(context),
              ),
              onPressed: () => _showPodcastOptions(context),
            ),
          ],
        ),
      ),
    );
  }

  void _showPodcastOptions(BuildContext context) {
    final audio = context.read<AudioProvider>();
    final isFav = audio.isFavorite(podcast.id);

    showModalBottomSheet(
      context: context,
      backgroundColor: AuraColors.card(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => SafeArea(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                margin: const EdgeInsets.symmetric(vertical: 10),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AuraColors.border(context),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                child: Row(
                  children: [
                    if (podcast.imageUrl != null)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: CachedNetworkImage(
                          imageUrl: podcast.imageUrl!,
                          width: 44,
                          height: 44,
                          fit: BoxFit.cover,
                          errorWidget: (_, _, _) => Container(
                            width: 44,
                            height: 44,
                            color: AuraColors.cardDeep(context),
                            child: Icon(Icons.podcasts, color: AuraColors.subtext(context)),
                          ),
                        ),
                      ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            podcast.name,
                            style: GoogleFonts.dmSans(
                              color: AuraColors.text(context),
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            podcast.channelName ?? 'Podcast',
                            style: GoogleFonts.dmSans(
                              color: AuraColors.subtext(context),
                              fontSize: 12,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Divider(color: AuraColors.border(context), height: 16),
              ListTile(
                leading: const Icon(Icons.play_circle_fill, color: AuraColors.accent),
                title: Text('Play Latest Episode', style: GoogleFonts.dmSans(color: AuraColors.text(context), fontWeight: FontWeight.w600)),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _quickPlay(context);
                },
              ),
              ListTile(
                leading: Icon(Icons.format_list_bulleted, color: AuraColors.text(context)),
                title: Text('View Show Catalog', style: GoogleFonts.dmSans(color: AuraColors.text(context))),
                onTap: () {
                  Navigator.pop(sheetContext);
                  Navigator.of(context).pushNamed(
                    AppRoutes.podcastDetail,
                    arguments: podcast,
                  );
                },
              ),
              ListTile(
                leading: Icon(isFav ? Icons.star : Icons.star_border, color: isFav ? Colors.amber : AuraColors.text(context)),
                title: Text(isFav ? 'In Favorites (Tap to remove)' : 'Add to Favorites', style: GoogleFonts.dmSans(color: AuraColors.text(context))),
                onTap: () {
                  Navigator.pop(sheetContext);
                  audio.toggleFavorite(podcast.id);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(!isFav ? 'Added to Favorites ⭐' : 'Removed from Favorites', style: GoogleFonts.dmSans()),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                },
              ),
              ListTile(
                leading: Icon(Icons.share_outlined, color: AuraColors.text(context)),
                title: Text('Share Show Link', style: GoogleFonts.dmSans(color: AuraColors.text(context))),
                onTap: () {
                  Navigator.pop(sheetContext);
                  Clipboard.setData(ClipboardData(text: '${podcast.name}\n${podcast.url ?? ""}'));
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Show link copied to clipboard! 📋', style: GoogleFonts.dmSans()), behavior: SnackBarBehavior.floating),
                  );
                },
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Shimmers ─────────────────────────────────────────────────────────────────

class _SpotlightShimmer extends StatelessWidget {
  const _SpotlightShimmer();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Shimmer.fromColors(
        baseColor: AuraColors.cardDeep(context),
        highlightColor: AuraColors.card(context),
        child: Container(
          height: 195,
          decoration: BoxDecoration(
            color: AuraColors.cardDeep(context),
            borderRadius: BorderRadius.circular(20),
          ),
        ),
      ),
    );
  }
}

class _HorizontalShimmerList extends StatelessWidget {
  final double height;
  final double itemWidth;

  const _HorizontalShimmerList({required this.height, required this.itemWidth});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: 4,
        separatorBuilder: (context, index) => const SizedBox(width: 14),
        itemBuilder: (context, index) => Shimmer.fromColors(
          baseColor: AuraColors.cardDeep(context),
          highlightColor: AuraColors.card(context),
          child: Container(
            width: itemWidth,
            decoration: BoxDecoration(
              color: AuraColors.cardDeep(context),
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Paste Link to Stream Audio Card ──────────────────────────────────────────

class _PasteLinkStreamCard extends StatefulWidget {
  const _PasteLinkStreamCard();

  @override
  State<_PasteLinkStreamCard> createState() => _PasteLinkStreamCardState();
}

class _PasteLinkStreamCardState extends State<_PasteLinkStreamCard> {
  final TextEditingController _linkController = TextEditingController();
  final LinkStreamService _linkService = LinkStreamService();
  bool _isLoading = false;
  String? _errorMessage;
  Episode? _resolvedEpisode;

  @override
  void dispose() {
    _linkController.dispose();
    super.dispose();
  }

  Future<void> _handlePasteFromClipboard() async {
    try {
      final data = await Clipboard.getData(Clipboard.kTextPlain);
      if (data != null && data.text != null && data.text!.trim().isNotEmpty) {
        final text = data.text!.trim();
        _linkController.text = text;
        _convertAndPlay(text);
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Clipboard is empty or does not contain a link.')),
        );
      }
    } catch (e) {
      debugPrint('Clipboard read error: $e');
    }
  }

  Future<void> _convertAndPlay([String? inputUrl]) async {
    final raw = (inputUrl ?? _linkController.text).trim();
    if (raw.isEmpty) {
      setState(() => _errorMessage = 'Please enter or paste a valid link.');
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final episode = await _linkService.resolveEpisodeFromUrl(raw);
      if (!mounted) return;

      if (episode != null) {
        setState(() {
          _resolvedEpisode = episode;
          _isLoading = false;
        });

        // Automatically start playback via AudioProvider
        context.read<AudioProvider>().play(episode);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AuraColors.charcoal,
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: AuraColors.accent, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Streaming audio: ${episode.name}',
                    style: GoogleFonts.dmSans(color: Colors.white, fontWeight: FontWeight.bold),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            duration: const Duration(seconds: 4),
          ),
        );
      } else {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Could not resolve audio from this link. Make sure it is a valid YouTube or JioSaavn link.';
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'Error converting link: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = AuraColors.isDark(context);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AuraColors.card(context),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AuraColors.border(context)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFF007A), Color(0xFF7928CA)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.stream, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Paste Link & Stream Audio',
                      style: GoogleFonts.dmSans(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AuraColors.text(context),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Convert any YouTube video or JioSaavn link into streamable audio',
                      style: GoogleFonts.dmSans(
                        fontSize: 11,
                        color: AuraColors.subtext(context),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Badges (Using Wrap to prevent any overflow on narrow screens)
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _buildPillBadge('🔴 YouTube Video-to-Audio', const Color(0xFFFF0000).withValues(alpha: 0.12), isDark ? const Color(0xFFFF5252) : const Color(0xFFCC0000)),
              _buildPillBadge('🎵 JioSaavn Audio', AuraColors.accent.withValues(alpha: 0.15), AuraColors.text(context)),
              _buildPillBadge('⚡ Instant', Colors.blue.withValues(alpha: 0.12), Colors.blueAccent),
            ],
          ),
          const SizedBox(height: 14),

          // Input Box with Paste Button
          Container(
            decoration: BoxDecoration(
              color: AuraColors.cardDeep(context),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AuraColors.border(context)),
            ),
            child: Row(
              children: [
                const SizedBox(width: 12),
                Icon(Icons.link, color: AuraColors.subtext(context), size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: _linkController,
                    onSubmitted: (_) => _convertAndPlay(),
                    style: GoogleFonts.dmSans(fontSize: 13, color: AuraColors.text(context)),
                    decoration: InputDecoration(
                      hintText: 'Paste YouTube video or JioSaavn link...',
                      hintStyle: GoogleFonts.dmSans(
                        fontSize: 12,
                        color: AuraColors.subtext(context),
                      ),
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
                if (_linkController.text.isNotEmpty)
                  GestureDetector(
                    onTap: () {
                      _linkController.clear();
                      setState(() {});
                    },
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Icon(Icons.close, size: 16, color: AuraColors.subtext(context)),
                    ),
                  ),
                // Clipboard Paste Button
                GestureDetector(
                  onTap: _handlePasteFromClipboard,
                  child: Container(
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white.withValues(alpha: 0.1) : AuraColors.creamDeep,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.content_paste, size: 13, color: AuraColors.text(context)),
                        const SizedBox(width: 4),
                        Text(
                          'Paste',
                          style: GoogleFonts.dmSans(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: AuraColors.text(context),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Convert & Play Button
          SizedBox(
            width: double.infinity,
            height: 44,
            child: ElevatedButton(
              onPressed: _isLoading ? null : () => _convertAndPlay(),
              style: ElevatedButton.styleFrom(
                backgroundColor: isDark ? Colors.white : AuraColors.charcoal,
                foregroundColor: isDark ? Colors.black : Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: _isLoading
                  ? Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: isDark ? Colors.black : Colors.white,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          'Converting video to audio track...',
                          style: GoogleFonts.dmSans(fontSize: 12, fontWeight: FontWeight.w600),
                        ),
                      ],
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.play_circle_fill, size: 18),
                        const SizedBox(width: 8),
                        Text(
                          'Convert Video & Stream Audio',
                          style: GoogleFonts.dmSans(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
            ),
          ),

          // Error Message
          if (_errorMessage != null) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.redAccent, size: 16),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    _errorMessage!,
                    style: GoogleFonts.dmSans(fontSize: 11, color: Colors.redAccent),
                  ),
                ),
              ],
            ),
          ],

          // Quick-Test Sample Links
          const SizedBox(height: 14),
          Text(
            'Try sample links:',
            style: GoogleFonts.dmSans(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AuraColors.subtext(context),
            ),
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildSampleChip(
                  label: '▶️ The Ranveer Show',
                  url: 'https://www.youtube.com/watch?v=8son5OkbC90',
                ),
                const SizedBox(width: 8),
                _buildSampleChip(
                  label: '▶️ Huberman Lab',
                  url: 'https://www.youtube.com/watch?v=gX7_B_9P9lQ',
                ),
                const SizedBox(width: 8),
                _buildSampleChip(
                  label: '▶️ Finshots Daily',
                  url: 'https://www.jiosaavn.com/shows/finshots-daily/1',
                ),
                const SizedBox(width: 8),
                _buildSampleChip(
                  label: '▶️ Desi Crime',
                  url: 'https://www.jiosaavn.com/shows/the-desi-crime-podcast/1',
                ),
              ],
            ),
          ),

          // Active Stream Card (Preview of Resolved Episode)
          if (_resolvedEpisode != null) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AuraColors.cardDeep(context),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AuraColors.accent.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: CachedNetworkImage(
                      imageUrl: _resolvedEpisode!.imageUrl ?? '',
                      width: 52,
                      height: 52,
                      fit: BoxFit.cover,
                      placeholder: (context, url) => Container(color: AuraColors.card(context)),
                      errorWidget: (context, url, error) => Container(
                        color: AuraColors.card(context),
                        child: const Icon(Icons.music_note, color: Colors.grey),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                              decoration: BoxDecoration(
                                color: _resolvedEpisode!.isYouTube
                                    ? const Color(0xFFFF0000).withValues(alpha: 0.15)
                                    : AuraColors.accent.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                _resolvedEpisode!.isYouTube ? 'YouTube Audio' : 'JioSaavn',
                                style: GoogleFonts.dmSans(
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                  color: _resolvedEpisode!.isYouTube
                                      ? const Color(0xFFDD0000)
                                      : AuraColors.text(context),
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            const Icon(Icons.graphic_eq, size: 14, color: AuraColors.accent),
                            const SizedBox(width: 3),
                            Text(
                              'Now Ready',
                              style: GoogleFonts.dmSans(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: AuraColors.accent,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _resolvedEpisode!.name,
                          style: GoogleFonts.dmSans(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: AuraColors.text(context),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          _resolvedEpisode!.showName,
                          style: GoogleFonts.dmSans(
                            fontSize: 11,
                            color: AuraColors.subtext(context),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.play_circle_fill, size: 30, color: AuraColors.accent),
                    onPressed: () => context.read<AudioProvider>().play(_resolvedEpisode!),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPillBadge(String label, Color bg, Color text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: GoogleFonts.dmSans(
          fontSize: 9,
          fontWeight: FontWeight.bold,
          color: text,
        ),
      ),
    );
  }

  Widget _buildSampleChip({required String label, required String url}) {
    return GestureDetector(
      onTap: () {
        _linkController.text = url;
        _convertAndPlay(url);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: AuraColors.cardDeep(context),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AuraColors.border(context)),
        ),
        child: Text(
          label,
          style: GoogleFonts.dmSans(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: AuraColors.text(context),
          ),
        ),
      ),
    );
  }
}

