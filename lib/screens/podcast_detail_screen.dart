import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:aura/core/theme.dart';
import 'package:aura/providers/audio_provider.dart';
import 'package:aura/models/podcast.dart';
import 'package:aura/models/episode.dart';
import 'package:aura/services/jiosaavn_service.dart';
import 'package:aura/services/youtube_service.dart';
import 'package:shimmer/shimmer.dart';

import 'package:aura/widgets/mini_player.dart';

class PodcastDetailScreen extends StatefulWidget {
  final Podcast podcast;
  const PodcastDetailScreen({super.key, required this.podcast});

  @override
  State<PodcastDetailScreen> createState() => _PodcastDetailScreenState();
}

class _PodcastDetailScreenState extends State<PodcastDetailScreen> {
  final _service = JioSaavnService();
  final _ytService = YouTubeService();
  List<Episode> _episodes = [];
  bool _loading = true;
  bool _hasMore = false;
  int _currentPage = 1;
  int _selectedSeason = 1;

  @override
  void initState() {
    super.initState();
    _selectedSeason = widget.podcast.latestSeasonNumber ?? 1;
    _loadEpisodes();
  }

  Future<void> _loadEpisodes({bool append = false}) async {
    if (!append) {
      setState(() {
        _loading = true;
        _currentPage = 1;
      });
    }

    try {
      final EpisodePage page;
      if (widget.podcast.isYouTube) {
        page = await _ytService.getEpisodes(widget.podcast);
      } else {
        page = await _service.getEpisodes(
          widget.podcast.id,
          season: _selectedSeason,
          page: _currentPage,
        );
      }
      setState(() {
        if (append) {
          _episodes.addAll(page.episodes);
        } else {
          _episodes = page.episodes;
        }
        _hasMore = page.hasMore;
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
    }
  }

  Future<void> _loadMore() async {
    if (!_hasMore) return;
    _currentPage++;
    await _loadEpisodes(append: true);
  }

  @override
  Widget build(BuildContext context) {
    final podcast = widget.podcast;
    return Scaffold(
      backgroundColor: AuraColors.cream,
      body: Stack(
        children: [
          CustomScrollView(
            slivers: [
              _buildAppBar(podcast),
              if (podcast.seasons.length > 1)
                SliverToBoxAdapter(child: _buildSeasonSelector(podcast)),
              if (_loading)
                SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) => _shimmerTile(),
                    childCount: 6,
                  ),
                )
              else if (_episodes.isEmpty)
                const SliverFillRemaining(child: _EmptyState())
              else
                SliverList(
                  delegate: SliverChildBuilderDelegate((context, i) {
                    if (i == _episodes.length) {
                      return _hasMore
                          ? Center(
                              child: TextButton(
                                onPressed: _loadMore,
                                child: const Text('Load more'),
                              ),
                            )
                          : const SizedBox(height: 100);
                    }
                    return _EpisodeTile(
                      episode: _episodes[i],
                      index: i,
                      allEpisodes: _episodes,
                    );
                  }, childCount: _episodes.length + 1),
                ),
            ],
          ),
          const Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: MiniPlayer(),
          ),
        ],
      ),
    );
  }

  Widget _buildAppBar(Podcast podcast) {
    return SliverAppBar(
      expandedHeight: 300,
      pinned: true,
      backgroundColor: AuraColors.cream,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: AuraColors.charcoal),
        onPressed: () => Navigator.pop(context),
      ),
      flexibleSpace: FlexibleSpaceBar(
        background: Stack(
          fit: StackFit.expand,
          children: [
            if (podcast.headerImageUrl != null || podcast.imageUrl != null)
              CachedNetworkImage(
                imageUrl: podcast.headerImageUrl ?? podcast.imageUrl ?? '',
                fit: BoxFit.cover,
                errorWidget: (context, url, error) =>
                    Container(color: AuraColors.creamDeep),
              ),
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, AuraColors.cream],
                ),
              ),
            ),
            Positioned(
              bottom: 20,
              left: 20,
              right: 80,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    podcast.name,
                    style: GoogleFonts.dmSans(
                      fontSize: 24,
                      color: AuraColors.charcoal,
                    ),
                    maxLines: 2,
                  ),
                  if (podcast.totalEpisodes != null)
                    Text(
                      '${podcast.totalEpisodes} episodes',
                      style: GoogleFonts.dmSans(
                        fontSize: 13,
                        color: AuraColors.charcoalMed,
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

  Widget _buildSeasonSelector(Podcast podcast) {
    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
        itemCount: podcast.seasons.length,
        separatorBuilder: (context, index) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final s = podcast.seasons[i];
          final selected = s.number == _selectedSeason;
          return GestureDetector(
            onTap: () {
              setState(() => _selectedSeason = s.number);
              _loadEpisodes();
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
              decoration: BoxDecoration(
                color: selected ? AuraColors.charcoal : AuraColors.creamCard,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: selected
                      ? AuraColors.charcoal
                      : AuraColors.creamBorder,
                ),
              ),
              child: Text(
                s.name,
                style: GoogleFonts.dmSans(
                  fontSize: 13,
                  color: selected ? AuraColors.cream : AuraColors.charcoalMed,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _shimmerTile() {
    return Shimmer.fromColors(
      baseColor: AuraColors.creamDeep,
      highlightColor: AuraColors.cream,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
        height: 80,
        decoration: BoxDecoration(
          color: AuraColors.creamDeep,
          borderRadius: BorderRadius.circular(14),
        ),
      ),
    );
  }
}

class _EpisodeTile extends StatelessWidget {
  final Episode episode;
  final int index;
  final List<Episode> allEpisodes;

  const _EpisodeTile({
    required this.episode,
    required this.index,
    required this.allEpisodes,
  });

  @override
  Widget build(BuildContext context) {
    final audio = context.watch<AudioProvider>();
    final isPlaying = audio.currentEpisode?.id == episode.id && audio.isPlaying;

    return GestureDetector(
      onTap: () {
        final audioProvider = context.read<AudioProvider>();
        if (audio.currentEpisode?.id == episode.id) {
          audioProvider.togglePlayPause();
        } else {
          audioProvider.play(episode, queue: allEpisodes, queueIndex: index);
        }
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isPlaying
              ? AuraColors.charcoal.withValues(alpha: 0.05)
              : AuraColors.creamCard,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isPlaying
                ? AuraColors.charcoal.withValues(alpha: 0.2)
                : AuraColors.creamBorder,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: isPlaying ? AuraColors.charcoal : AuraColors.creamDeep,
                shape: BoxShape.circle,
              ),
              child: Icon(
                isPlaying ? Icons.pause : Icons.play_arrow,
                color: isPlaying ? AuraColors.cream : AuraColors.charcoalMed,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    episode.name,
                    style: GoogleFonts.dmSans(
                      fontSize: 13,
                      color: AuraColors.charcoal,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      if (episode.releaseDate != null && episode.releaseDate!.isNotEmpty)
                        Text(
                          episode.releaseDate!.length >= 7
                              ? episode.releaseDate!.substring(0, 7)
                              : episode.releaseDate!,
                          style: GoogleFonts.dmSans(
                            fontSize: 11,
                            color: AuraColors.charcoalLight,
                          ),
                        ),
                      if (episode.releaseDate != null &&
                          episode.formattedDuration.isNotEmpty)
                        const Text(
                          ' · ',
                          style: TextStyle(
                            color: AuraColors.charcoalLight,
                            fontSize: 11,
                          ),
                        ),
                      Text(
                        episode.formattedDuration,
                        style: GoogleFonts.dmSans(
                          fontSize: 11,
                          color: AuraColors.charcoalLight,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(
                Icons.more_vert,
                size: 18,
                color: AuraColors.charcoalLight,
              ),
              onPressed: () => _showOptions(context),
            ),
          ],
        ),
      ),
    );
  }

  void _showOptions(BuildContext context) {
    final audio = context.read<AudioProvider>();
    final favId = episode.showId;
    final isFav = audio.isFavorite(favId);

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
              // Episode Title Preview
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                child: Row(
                  children: [
                    if (episode.imageUrl != null)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: CachedNetworkImage(
                          imageUrl: episode.imageUrl!,
                          width: 44,
                          height: 44,
                          fit: BoxFit.cover,
                          errorWidget: (_, _, _) => Container(
                            width: 44,
                            height: 44,
                            color: AuraColors.cardDeep(context),
                            child: Icon(Icons.music_note, color: AuraColors.subtext(context)),
                          ),
                        ),
                      ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            episode.name,
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
                            episode.showName,
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
              // 1. Play Now
              ListTile(
                leading: const Icon(Icons.play_circle_fill, color: AuraColors.accent),
                title: Text(
                  'Play Now',
                  style: GoogleFonts.dmSans(
                    color: AuraColors.text(context),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                onTap: () {
                  Navigator.pop(sheetContext);
                  audio.play(episode);
                },
              ),
              // 2. Play Next
              ListTile(
                leading: Icon(Icons.playlist_play, color: AuraColors.text(context)),
                title: Text(
                  'Play Next in Queue',
                  style: GoogleFonts.dmSans(color: AuraColors.text(context)),
                ),
                onTap: () {
                  Navigator.pop(sheetContext);
                  audio.playAsNext(episode);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Playing next in queue', style: GoogleFonts.dmSans()),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                },
              ),
              // 3. Add to Queue
              ListTile(
                leading: Icon(Icons.queue, color: AuraColors.text(context)),
                title: Text(
                  'Add to Queue',
                  style: GoogleFonts.dmSans(color: AuraColors.text(context)),
                ),
                onTap: () {
                  Navigator.pop(sheetContext);
                  audio.addToQueue(episode);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Added to queue', style: GoogleFonts.dmSans()),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                },
              ),
              // 4. Bookmark / Favorite
              ListTile(
                leading: Icon(
                  isFav ? Icons.star : Icons.star_border,
                  color: isFav ? Colors.amber : AuraColors.text(context),
                ),
                title: Text(
                  isFav ? 'In Favorites (Tap to remove)' : 'Add to Favorites',
                  style: GoogleFonts.dmSans(color: AuraColors.text(context)),
                ),
                onTap: () {
                  Navigator.pop(sheetContext);
                  audio.toggleFavorite(favId);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        !isFav ? 'Saved to Favorites ⭐' : 'Removed from Favorites',
                        style: GoogleFonts.dmSans(),
                      ),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                },
              ),
              // 5. Episode Details
              ListTile(
                leading: Icon(Icons.info_outline, color: AuraColors.text(context)),
                title: Text(
                  'Episode Details',
                  style: GoogleFonts.dmSans(color: AuraColors.text(context)),
                ),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _showDetailDialog(context);
                },
              ),
              // 6. Share / Copy Link
              ListTile(
                leading: Icon(Icons.share_outlined, color: AuraColors.text(context)),
                title: Text(
                  'Share Episode Link',
                  style: GoogleFonts.dmSans(color: AuraColors.text(context)),
                ),
                onTap: () {
                  Navigator.pop(sheetContext);
                  final link = episode.url ?? episode.streamUrl ?? '';
                  Clipboard.setData(ClipboardData(text: '${episode.name}\n$link'));
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Episode link copied to clipboard! 📋', style: GoogleFonts.dmSans()),
                      behavior: SnackBarBehavior.floating,
                    ),
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

  void _showDetailDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AuraColors.card(context),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          episode.name,
          style: GoogleFonts.dmSans(
            color: AuraColors.text(context),
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (episode.showName.isNotEmpty) ...[
                Text(
                  episode.showName,
                  style: GoogleFonts.dmSans(
                    color: AuraColors.accent,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 10),
              ],
              if (episode.releaseDate != null) ...[
                Text(
                  'Released: ${episode.releaseDate}',
                  style: GoogleFonts.dmSans(
                    color: AuraColors.subtext(context),
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 10),
              ],
              Text(
                episode.description?.isNotEmpty == true
                    ? episode.description!
                    : 'No description available for this episode.',
                style: GoogleFonts.dmSans(
                  color: AuraColors.text(context).withValues(alpha: 0.85),
                  fontSize: 13,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Close', style: GoogleFonts.dmSans(color: AuraColors.accent)),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.headphones_outlined,
            size: 48,
            color: AuraColors.charcoalLight,
          ),
          const SizedBox(height: 12),
          Text(
            'No episodes found',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}
