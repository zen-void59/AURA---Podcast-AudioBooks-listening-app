import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
import 'package:aura/services/youtube_service.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();

  static const _trendingHashtags = [
    '#TheRanveerShow',
    '#FiguringOut',
    '#PGRadio',
    '#HubermanLab',
    '#FinshotsDaily',
    '#DesiCrime',
    '#JoeRogan',
    '#NikhilKamath',
    '#MahaBharat',
    '#LexFridman',
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<SearchProvider>().loadTrending();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _searchFor(String query) {
    _controller.text = query.replaceFirst('#', '');
    _focusNode.unfocus();
    context.read<SearchProvider>().searchNow(_controller.text);
  }

  /// Returns true if [text] looks like a URL (YouTube or direct audio link)
  bool _looksLikeUrl(String text) {
    final t = text.trim();
    return t.startsWith('http://') ||
        t.startsWith('https://') ||
        t.contains('youtube.com/') ||
        t.contains('youtu.be/') ||
        t.contains('.mp3') ||
        t.contains('.m4a') ||
        t.contains('.ogg') ||
        t.contains('.opus') ||
        t.contains('.wav') ||
        t.contains('.flac');
  }

  /// Shows the paste-link bottom sheet pre-filled with [initialUrl]
  void _showPasteLinkSheet({String? initialUrl}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _PasteLinkSheet(
        initialUrl: initialUrl,
        onPlay: (episode) {
          Navigator.pop(ctx);
          context.read<AudioProvider>().play(episode);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AuraColors.bg(context),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            _buildSearchBar(),
            const SizedBox(height: 4),
            Expanded(child: _buildBody()),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Search & Stream',
            style: GoogleFonts.dmSans(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: AuraColors.text(context),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: AuraColors.cardDeep(context),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.bolt, size: 13, color: AuraColors.accent),
                const SizedBox(width: 3),
                Text(
                  'Live Feed',
                  style: GoogleFonts.dmSans(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: AuraColors.text(context),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          child: TextField(
            controller: _controller,
            focusNode: _focusNode,
            onChanged: (q) {
              // If user pastes/types a URL, open the link-play sheet directly
              if (_looksLikeUrl(q)) {
                _focusNode.unfocus();
                _showPasteLinkSheet(initialUrl: q.trim());
                _controller.clear();
                context.read<SearchProvider>().clear();
                return;
              }
              context.read<SearchProvider>().search(q);
            },
            style: GoogleFonts.dmSans(fontSize: 15, color: AuraColors.text(context)),
            decoration: InputDecoration(
              hintText: 'Search or paste a YouTube / audio link...',
              hintStyle: GoogleFonts.dmSans(color: AuraColors.subtext(context)),
              fillColor: AuraColors.card(context),
              filled: true,
              prefixIcon: Icon(
                Icons.search,
                color: AuraColors.subtext(context),
                size: 20,
              ),
              suffixIcon: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Paste-link icon button
                  GestureDetector(
                    onTap: () => _showPasteLinkSheet(),
                    child: Tooltip(
                      message: 'Paste a link to play',
                      child: Padding(
                        padding: const EdgeInsets.only(right: 4),
                        child: Icon(
                          Icons.link_rounded,
                          color: AuraColors.accent,
                          size: 22,
                        ),
                      ),
                    ),
                  ),
                  Consumer<SearchProvider>(
                    builder: (context, p, child) => p.isSearching
                        ? GestureDetector(
                            onTap: () {
                              _controller.clear();
                              p.clear();
                              _focusNode.unfocus();
                            },
                            child: Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: Icon(
                                Icons.close,
                                color: AuraColors.subtext(context),
                                size: 18,
                              ),
                            ),
                          )
                        : const SizedBox.shrink(),
                  ),
                ],
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: AuraColors.border(context)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: AuraColors.border(context)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: AuraColors.accent, width: 1.5),
              ),
            ),
          ),
        ),
        _buildSourceFilter(),
      ],
    );
  }

  Widget _buildSourceFilter() {
    return Consumer<SearchProvider>(
      builder: (context, p, child) {
        return Align(
          alignment: Alignment.centerLeft,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.only(left: 20, right: 20, bottom: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                _FilterChip(
                  label: 'All Sources',
                  selected: p.filter == SearchSourceFilter.all,
                  onTap: () => p.setFilter(SearchSourceFilter.all),
                ),
                const SizedBox(width: 10),
                _FilterChip(
                  label: '🔴 YouTube',
                  selected: p.filter == SearchSourceFilter.youtube,
                  onTap: () => p.setFilter(SearchSourceFilter.youtube),
                ),
                const SizedBox(width: 10),
                _FilterChip(
                  label: '🎵 JioSaavn',
                  selected: p.filter == SearchSourceFilter.jiosaavn,
                  onTap: () => p.setFilter(SearchSourceFilter.jiosaavn),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildBody() {
    return Consumer<SearchProvider>(
      builder: (context, provider, _) {
        if (!provider.isSearching) {
          return _buildIdleSuggestedHub(provider);
        }
        switch (provider.state) {
          case SearchState.loading:
            return _buildShimmer();
          case SearchState.error:
            return _buildError(provider.error ?? 'Something went wrong');
          case SearchState.loaded:
            if (provider.results.isEmpty) return _buildEmpty();
            return _buildResults(provider.results);
          case SearchState.idle:
            return _buildIdleSuggestedHub(provider);
        }
      },
    );
  }

  // ─── Idle Hub: Trending Hashtags, Suggested Podcasters & Top Podcasts ───────

  Widget _buildIdleSuggestedHub(SearchProvider provider) {
    final podcasters = Podcaster.curatedList;

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      children: [
        const SizedBox(height: 8),
        // 1. Trending Hashtags
        Text(
          '🔥 Trending Topics & Shows',
          style: GoogleFonts.dmSans(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: AuraColors.text(context),
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _trendingHashtags.map((tag) {
            return GestureDetector(
              onTap: () => _searchFor(tag),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AuraColors.card(context),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AuraColors.border(context)),
                ),
                child: Text(
                  tag,
                  style: GoogleFonts.dmSans(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AuraColors.text(context),
                  ),
                ),
              ),
            );
          }).toList(),
        ),

        const SizedBox(height: 22),
        // 2. Suggested Creators to Watch
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '🎙️ Top Podcasters & Creators',
              style: GoogleFonts.dmSans(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: AuraColors.text(context),
              ),
            ),
            Text(
              'Tap to explore',
              style: GoogleFonts.dmSans(
                fontSize: 11,
                color: AuraColors.subtext(context),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 125,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: podcasters.length,
            separatorBuilder: (context, index) => const SizedBox(width: 14),
            itemBuilder: (context, index) {
              final p = podcasters[index];
              return GestureDetector(
                onTap: () => _searchFor(p.searchQuery),
                child: SizedBox(
                  width: 78,
                  child: Column(
                    children: [
                      Container(
                        width: 60,
                        height: 60,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: p.region.toLowerCase() == 'india'
                                ? const Color(0xFFFF9933)
                                : const Color(0xFF29B6F6),
                            width: 2,
                          ),
                        ),
                        child: ClipOval(
                          child: CachedNetworkImage(
                            imageUrl: p.avatarUrl,
                            fit: BoxFit.cover,
                            placeholder: (context, url) => Container(color: AuraColors.cardDeep(context)),
                            errorWidget: (context, url, error) => Container(
                              color: AuraColors.cardDeep(context),
                              child: const Icon(Icons.person, color: Colors.grey),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        p.name,
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
                        p.followerCount,
                        style: GoogleFonts.dmSans(
                          fontSize: 10,
                          color: AuraColors.subtext(context),
                        ),
                        maxLines: 1,
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),

        const SizedBox(height: 18),
        // 3. Recommended Must-Listen Shows
        Text(
          '🎧 Suggested Podcasts For You',
          style: GoogleFonts.dmSans(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: AuraColors.text(context),
          ),
        ),
        const SizedBox(height: 10),
        if (provider.loadingTrending && provider.trending.isEmpty)
          _buildShimmer()
        else
          ...provider.trending.take(10).map((p) => _SearchResultTile(podcast: p)),

        const SizedBox(height: 20),
        _buildPasteLinkBanner(),
        const SizedBox(height: 120),
      ],
    );
  }

  Widget _buildPasteLinkBanner() {
    return GestureDetector(
      onTap: () => _showPasteLinkSheet(),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AuraColors.accent.withValues(alpha: 0.12),
              AuraColors.accent.withValues(alpha: 0.05),
            ],
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: AuraColors.accent.withValues(alpha: 0.3),
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AuraColors.accent.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.link_rounded,
                color: AuraColors.accent,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Can't find it? Paste a link",
                    style: GoogleFonts.dmSans(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AuraColors.text(context),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Play any YouTube video or audio URL directly',
                    style: GoogleFonts.dmSans(
                      fontSize: 11,
                      color: AuraColors.subtext(context),
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios_rounded,
              size: 14,
              color: AuraColors.accent,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResults(List<Podcast> results) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      itemCount: results.length,
      itemBuilder: (context, i) => _SearchResultTile(podcast: results[i]),
    );
  }

  Widget _buildShimmer() {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.zero,
      itemCount: 6,
      itemBuilder: (context, index) => Shimmer.fromColors(
        baseColor: AuraColors.cardDeep(context),
        highlightColor: AuraColors.card(context),
        child: Container(
          margin: const EdgeInsets.only(bottom: 14),
          height: 72,
          decoration: BoxDecoration(
            color: AuraColors.cardDeep(context),
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
    );
  }

  Widget _buildError(String msg) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.wifi_off_outlined,
            size: 40,
            color: AuraColors.subtext(context),
          ),
          const SizedBox(height: 12),
          Text(msg, style: TextStyle(color: AuraColors.text(context))),
          const SizedBox(height: 12),
          TextButton(
            onPressed: () =>
                context.read<SearchProvider>().search(_controller.text),
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmpty() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 32),
          Icon(
            Icons.search_off,
            size: 48,
            color: AuraColors.subtext(context),
          ),
          const SizedBox(height: 12),
          Text(
            'No results found',
            style: GoogleFonts.dmSans(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AuraColors.text(context),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Try a different keyword or paste a direct link below',
            textAlign: TextAlign.center,
            style: GoogleFonts.dmSans(
              fontSize: 12,
              color: AuraColors.subtext(context),
            ),
          ),
          const SizedBox(height: 24),
          _buildPasteLinkBanner(),
          const SizedBox(height: 80),
        ],
      ),
    );
  }
}

class _SearchResultTile extends StatelessWidget {
  final Podcast podcast;
  const _SearchResultTile({required this.podcast});

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
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: CachedNetworkImage(
                imageUrl: podcast.imageUrl ?? '',
                width: 56,
                height: 56,
                fit: BoxFit.cover,
                placeholder: (context, url) => Container(color: AuraColors.cardDeep(context)),
                errorWidget: (context, url, error) => Container(
                  color: AuraColors.cardDeep(context),
                  child: const Icon(Icons.podcasts, color: Colors.grey),
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
                      fontSize: 14,
                      color: AuraColors.text(context),
                      fontWeight: FontWeight.w600,
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
                          color: podcast.isYouTube
                              ? const Color(0xFFFF0000).withValues(alpha: 0.12)
                              : AuraColors.accent.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          podcast.isYouTube ? 'YouTube' : 'JioSaavn',
                          style: GoogleFonts.dmSans(
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            color: podcast.isYouTube
                                ? const Color(0xFFCC0000)
                                : AuraColors.text(context),
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
                title: Text('View Show Details', style: GoogleFonts.dmSans(color: AuraColors.text(context))),
                onTap: () {
                  Navigator.pop(sheetContext);
                  Navigator.pushNamed(context, AppRoutes.podcastDetail, arguments: podcast);
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

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = AuraColors.isDark(context);
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: selected
              ? (isDark ? Colors.white : AuraColors.charcoal)
              : AuraColors.card(context),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected
                ? (isDark ? Colors.white : AuraColors.charcoal)
                : AuraColors.border(context),
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.dmSans(
            fontSize: 12,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            color: selected
                ? (isDark ? Colors.black : Colors.white)
                : AuraColors.subtext(context),
          ),
        ),
      ),
    );
  }
}

// ─── Paste Link Sheet ─────────────────────────────────────────────────────────

class _PasteLinkSheet extends StatefulWidget {
  final String? initialUrl;
  final void Function(Episode episode) onPlay;

  const _PasteLinkSheet({this.initialUrl, required this.onPlay});

  @override
  State<_PasteLinkSheet> createState() => _PasteLinkSheetState();
}

class _PasteLinkSheetState extends State<_PasteLinkSheet> {
  final _urlController = TextEditingController();
  final _ytService = YouTubeService();

  bool _loading = false;
  String? _error;
  Episode? _resolved; // preview after resolving

  @override
  void initState() {
    super.initState();
    if (widget.initialUrl != null) {
      _urlController.text = widget.initialUrl!;
      // Auto-resolve if pre-filled
      WidgetsBinding.instance.addPostFrameCallback((_) => _resolve());
    }
  }

  @override
  void dispose() {
    _urlController.dispose();
    _ytService.dispose();
    super.dispose();
  }

  Future<void> _pasteFromClipboard() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text?.trim() ?? '';
    if (text.isNotEmpty) {
      _urlController.text = text;
      _resolve();
    }
  }

  Future<void> _resolve() async {
    final url = _urlController.text.trim();
    if (url.isEmpty) return;

    setState(() {
      _loading = true;
      _error = null;
      _resolved = null;
    });

    try {
      // YouTube URL
      final ytId = YouTubeService.extractVideoId(url);
      if (ytId != null) {
        final episode = await _ytService.getEpisodeFromUrlOrId(ytId);
        if (!mounted) return;
        if (episode != null) {
          setState(() {
            _resolved = episode;
            _loading = false;
          });
          return;
        }
      }

      // Direct audio URL — wrap as a plain episode
      final isAudioUrl = url.contains('.mp3') ||
          url.contains('.m4a') ||
          url.contains('.ogg') ||
          url.contains('.opus') ||
          url.contains('.wav') ||
          url.contains('.flac') ||
          url.startsWith('http');

      if (isAudioUrl) {
        final episode = Episode(
          id: 'link_${DateTime.now().millisecondsSinceEpoch}',
          name: _friendlyName(url),
          description: 'Streamed from: $url',
          imageUrl: null,
          showId: 'direct_link',
          showName: 'Direct Link',
          isYouTube: false,
          url: url,
        );
        if (!mounted) return;
        setState(() {
          _resolved = episode;
          _loading = false;
        });
        return;
      }

      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Could not resolve this link.\nMake sure it\'s a YouTube or audio URL.';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Failed to load: ${e.toString().split('\n').first}';
      });
    }
  }

  String _friendlyName(String url) {
    try {
      final uri = Uri.parse(url);
      final seg = uri.pathSegments.where((s) => s.isNotEmpty).last;
      return seg.replaceAll(RegExp(r'[_-]'), ' ').replaceAll(RegExp(r'\.\w+$'), '');
    } catch (_) {
      return 'Audio Stream';
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = AuraColors.isDark(context);
    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.4,
      maxChildSize: 0.9,
      builder: (ctx, scrollController) => Container(
        decoration: BoxDecoration(
          color: AuraColors.card(context),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          children: [
            // Handle
            Container(
              margin: const EdgeInsets.only(top: 12, bottom: 4),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AuraColors.border(context),
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AuraColors.accent.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.link_rounded, color: AuraColors.accent, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Play from Link',
                          style: GoogleFonts.dmSans(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AuraColors.text(context),
                          ),
                        ),
                        Text(
                          'YouTube, SoundCloud, or any direct audio URL',
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

            const SizedBox(height: 16),
            Divider(color: AuraColors.border(context), height: 1),
            const SizedBox(height: 16),

            // URL input row
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _urlController,
                      style: GoogleFonts.dmSans(fontSize: 13, color: AuraColors.text(context)),
                      decoration: InputDecoration(
                        hintText: 'https://youtube.com/watch?v=...',
                        hintStyle: GoogleFonts.dmSans(
                          fontSize: 12,
                          color: AuraColors.subtext(context),
                        ),
                        fillColor: AuraColors.bg(context),
                        filled: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(color: AuraColors.border(context)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(color: AuraColors.border(context)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(color: AuraColors.accent, width: 1.5),
                        ),
                      ),
                      onSubmitted: (_) => _resolve(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Paste button
                  GestureDetector(
                    onTap: _pasteFromClipboard,
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AuraColors.cardDeep(context),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AuraColors.border(context)),
                      ),
                      child: Icon(Icons.content_paste_rounded, color: AuraColors.accent, size: 20),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Load button
                  GestureDetector(
                    onTap: _resolve,
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AuraColors.accent,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 20),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // States
            Expanded(
              child: _loading
                  ? _buildLoadingState()
                  : _error != null
                      ? _buildErrorState()
                      : _resolved != null
                          ? _buildPreview(isDark)
                          : _buildHintState(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingState() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const SizedBox(
          width: 36,
          height: 36,
          child: CircularProgressIndicator(
            color: AuraColors.accent,
            strokeWidth: 2.5,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'Resolving link...',
          style: GoogleFonts.dmSans(
            fontSize: 14,
            color: AuraColors.subtext(context),
          ),
        ),
      ],
    );
  }

  Widget _buildErrorState() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.error_outline_rounded, size: 40, color: Colors.redAccent.withValues(alpha: 0.8)),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Text(
            _error!,
            textAlign: TextAlign.center,
            style: GoogleFonts.dmSans(fontSize: 13, color: AuraColors.subtext(context)),
          ),
        ),
        const SizedBox(height: 16),
        TextButton.icon(
          onPressed: _resolve,
          icon: const Icon(Icons.refresh, size: 16, color: AuraColors.accent),
          label: Text('Try again', style: GoogleFonts.dmSans(color: AuraColors.accent)),
        ),
      ],
    );
  }

  Widget _buildHintState() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.podcasts_rounded, size: 48, color: AuraColors.border(context)),
          const SizedBox(height: 16),
          Text(
            'Supported links',
            style: GoogleFonts.dmSans(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AuraColors.text(context),
            ),
          ),
          const SizedBox(height: 12),
          ...[
            ('🎬', 'YouTube watch, shorts & live links'),
            ('🎵', 'Direct .mp3, .m4a, .ogg audio URLs'),
            ('🔗', 'youtu.be short links'),
          ].map(
            (item) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Text(item.$1, style: const TextStyle(fontSize: 16)),
                  const SizedBox(width: 10),
                  Text(
                    item.$2,
                    style: GoogleFonts.dmSans(fontSize: 12, color: AuraColors.subtext(context)),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          GestureDetector(
            onTap: _pasteFromClipboard,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                color: AuraColors.accent.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AuraColors.accent.withValues(alpha: 0.3)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.content_paste_rounded, color: AuraColors.accent, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    'Paste from clipboard',
                    style: GoogleFonts.dmSans(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AuraColors.accent,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPreview(bool isDark) {
    final ep = _resolved!;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: [
          // Episode preview card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AuraColors.bg(context),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AuraColors.border(context)),
            ),
            child: Row(
              children: [
                // Thumbnail
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: ep.imageUrl != null
                      ? CachedNetworkImage(
                          imageUrl: ep.imageUrl!,
                          width: 70,
                          height: 70,
                          fit: BoxFit.cover,
                          placeholder: (_, _) =>
                              Container(color: AuraColors.cardDeep(context), width: 70, height: 70),
                          errorWidget: (_, _, _) => _placeholderThumb(),
                        )
                      : _placeholderThumb(),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Source badge
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: ep.isYouTube
                              ? const Color(0xFFFF0000).withValues(alpha: 0.12)
                              : AuraColors.accent.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          ep.isYouTube ? '▶ YouTube' : '🔗 Direct Link',
                          style: GoogleFonts.dmSans(
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            color: ep.isYouTube ? const Color(0xFFCC0000) : AuraColors.accent,
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        ep.name,
                        style: GoogleFonts.dmSans(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AuraColors.text(context),
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (ep.showName.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          ep.showName,
                          style: GoogleFonts.dmSans(
                            fontSize: 11,
                            color: AuraColors.subtext(context),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Play button
          GestureDetector(
            onTap: () => widget.onPlay(_resolved!),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 16),
              decoration: BoxDecoration(
                color: AuraColors.accent,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: AuraColors.accent.withValues(alpha: 0.35),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 22),
                  const SizedBox(width: 8),
                  Text(
                    'Play Now',
                    style: GoogleFonts.dmSans(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 10),

          // Try another link
          TextButton.icon(
            onPressed: () {
              setState(() {
                _resolved = null;
                _error = null;
                _urlController.clear();
              });
            },
            icon: Icon(Icons.link_rounded, size: 15, color: AuraColors.subtext(context)),
            label: Text(
              'Try a different link',
              style: GoogleFonts.dmSans(fontSize: 12, color: AuraColors.subtext(context)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _placeholderThumb() {
    return Container(
      width: 70,
      height: 70,
      color: AuraColors.cardDeep(context),
      child: const Icon(Icons.play_circle_outline, color: AuraColors.accent, size: 28),
    );
  }
}
