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
            onChanged: (q) => context.read<SearchProvider>().search(q),
            style: GoogleFonts.dmSans(fontSize: 15, color: AuraColors.text(context)),
            decoration: InputDecoration(
              hintText: 'Search podcasts, creators, video streams...',
              hintStyle: GoogleFonts.dmSans(color: AuraColors.subtext(context)),
              fillColor: AuraColors.card(context),
              filled: true,
              prefixIcon: Icon(
                Icons.search,
                color: AuraColors.subtext(context),
                size: 20,
              ),
              suffixIcon: Consumer<SearchProvider>(
                builder: (context, p, child) => p.isSearching
                    ? GestureDetector(
                        onTap: () {
                          _controller.clear();
                          p.clear();
                          _focusNode.unfocus();
                        },
                        child: Icon(
                          Icons.close,
                          color: AuraColors.subtext(context),
                          size: 18,
                        ),
                      )
                    : const SizedBox.shrink(),
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

        const SizedBox(height: 120),
      ],
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
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.search_off,
            size: 40,
            color: AuraColors.subtext(context),
          ),
          const SizedBox(height: 12),
          Text(
            'No results found',
            style: TextStyle(color: AuraColors.text(context)),
          ),
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
