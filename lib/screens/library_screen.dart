import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:aura/core/theme.dart';
import 'package:aura/providers/theme_provider.dart';
import 'package:aura/providers/audio_provider.dart';
import 'package:aura/providers/audiobook_provider.dart';
import 'package:aura/models/episode.dart';
import 'package:aura/core/routes.dart';
import 'package:aura/widgets/book_jacket_cover.dart';

class LibraryScreen extends StatelessWidget {
  const LibraryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AuraColors.bg(context),
      body: SafeArea(
        child: Consumer2<ThemeProvider, AudioProvider>(
          builder: (context, themeProv, audioProv, _) {
            final history = audioProv.history;

            return CustomScrollView(
              slivers: [
                // Header
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Your Library',
                              style: GoogleFonts.dmSans(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: AuraColors.text(context),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Personal stacks, history & preferences',
                              style: GoogleFonts.dmSans(
                                fontSize: 12,
                                color: AuraColors.subtext(context),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                // 1. Theme Mode Switcher Card
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    child: _ThemeModeSelectorCard(
                      currentMode: themeProv.themeMode,
                      onModeSelected: (mode) => themeProv.setThemeMode(mode),
                    ),
                  ),
                ),

                // 2. Listening Stats Banner
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    child: _ListeningStatsCard(
                      episodesPlayed: history.length,
                    ),
                  ),
                ),

                // 2.5 My Bookshelf Section
                const SliverToBoxAdapter(
                  child: _MyBookshelfSection(),
                ),

                // 3. Listening History Section
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.history, size: 18, color: AuraColors.accent),
                            const SizedBox(width: 8),
                            Text(
                              'Listening History',
                              style: GoogleFonts.dmSans(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: AuraColors.text(context),
                              ),
                            ),
                          ],
                        ),
                        if (history.isNotEmpty)
                          GestureDetector(
                            onTap: () {
                              _confirmClearHistory(context, audioProv);
                            },
                            child: Text(
                              'Clear All',
                              style: GoogleFonts.dmSans(
                                fontSize: 12,
                                color: AuraColors.subtext(context),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),

                if (history.isEmpty)
                  SliverToBoxAdapter(
                    child: _EmptyStateCard(
                      icon: Icons.headphones_outlined,
                      message: 'No listening history yet',
                      subtitle: 'Episodes you play will automatically appear here',
                    ),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final ep = history[index];
                          return _HistoryListTile(
                            episode: ep,
                            onPlay: () => audioProv.play(ep),
                          );
                        },
                        childCount: history.length,
                      ),
                    ),
                  ),

                // 4. Downloaded Episodes
                SliverToBoxAdapter(
                  child: _SectionHeader(title: 'Downloaded Episodes', icon: Icons.download_outlined),
                ),
                SliverToBoxAdapter(
                  child: _EmptyStateCard(
                    icon: Icons.download_done,
                    message: 'No downloads saved',
                    subtitle: 'Save episodes to listen offline without internet',
                  ),
                ),

                // 5. Playlists
                SliverToBoxAdapter(
                  child: _SectionHeader(
                    title: 'Your Playlists',
                    icon: Icons.playlist_play,
                    trailingAction: '+ New',
                    onTrailingTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Playlist creation coming in next update!')),
                      );
                    },
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Row(
                      children: [
                        Expanded(
                          child: _PlaylistCard(
                            title: 'Daily Commute',
                            count: '4 episodes',
                            icon: Icons.directions_car,
                            gradient: const [Color(0xFF4A148C), Color(0xFF7B1FA2)],
                            onTap: () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('🚗 Daily Commute: Quick 20-30m podcast highlights', style: GoogleFonts.dmSans()),
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _PlaylistCard(
                            title: 'Deep Focus',
                            count: '7 episodes',
                            icon: Icons.bolt,
                            gradient: const [Color(0xFF004D40), Color(0xFF00897B)],
                            onTap: () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('⚡ Deep Focus: Long-form intellectual deep dives', style: GoogleFonts.dmSans()),
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SliverToBoxAdapter(child: SizedBox(height: 120)),
              ],
            );
          },
        ),
      ),
    );
  }

  void _confirmClearHistory(BuildContext context, AudioProvider provider) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AuraColors.card(context),
        title: Text(
          'Clear Listening History?',
          style: GoogleFonts.dmSans(color: AuraColors.text(context), fontWeight: FontWeight.bold),
        ),
        content: Text(
          'This will remove all saved history entries from this device.',
          style: GoogleFonts.dmSans(color: AuraColors.subtext(context), fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: TextStyle(color: AuraColors.subtext(context))),
          ),
          ElevatedButton(
            onPressed: () {
              provider.clearHistory();
              Navigator.pop(ctx);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFD32F2F),
              foregroundColor: Colors.white,
            ),
            child: const Text('Clear'),
          ),
        ],
      ),
    );
  }
}

// ─── Theme Mode Selector Card ─────────────────────────────────────────────────

class _ThemeModeSelectorCard extends StatelessWidget {
  final ThemeMode currentMode;
  final ValueChanged<ThemeMode> onModeSelected;

  const _ThemeModeSelectorCard({
    required this.currentMode,
    required this.onModeSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AuraColors.card(context),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AuraColors.border(context)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AuraColors.accent.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.palette_outlined, size: 16, color: AuraColors.accent),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Appearance & Atmosphere',
                      style: GoogleFonts.dmSans(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: AuraColors.text(context),
                      ),
                    ),
                    Text(
                      'Choose your preferred visual theme',
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
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _ThemeOptionButton(
                  icon: Icons.light_mode,
                  label: 'Light ☀️',
                  isSelected: currentMode == ThemeMode.light,
                  onTap: () => onModeSelected(ThemeMode.light),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _ThemeOptionButton(
                  icon: Icons.dark_mode,
                  label: 'Dark 🌙',
                  isSelected: currentMode == ThemeMode.dark,
                  onTap: () => onModeSelected(ThemeMode.dark),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _ThemeOptionButton(
                  icon: Icons.brightness_auto,
                  label: 'System ⚙️',
                  isSelected: currentMode == ThemeMode.system,
                  onTap: () => onModeSelected(ThemeMode.system),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ThemeOptionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _ThemeOptionButton({
    required this.icon,
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
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? (isDark ? Colors.white : AuraColors.charcoal)
              : AuraColors.cardDeep(context),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? (isDark ? Colors.white : AuraColors.charcoal)
                : AuraColors.border(context),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected
                  ? (isDark ? Colors.black : Colors.white)
                  : AuraColors.text(context),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: GoogleFonts.dmSans(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected
                    ? (isDark ? Colors.black : Colors.white)
                    : AuraColors.text(context),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Listening Stats Card ─────────────────────────────────────────────────────

class _ListeningStatsCard extends StatelessWidget {
  final int episodesPlayed;

  const _ListeningStatsCard({required this.episodesPlayed});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AuraColors.card(context),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AuraColors.border(context)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _StatColumn(
            count: episodesPlayed.toString(),
            label: 'Listened',
            icon: Icons.play_circle_fill,
            iconColor: AuraColors.accent,
          ),
          Container(width: 1, height: 36, color: AuraColors.border(context)),
          _StatColumn(
            count: '${(episodesPlayed * 24)}m',
            label: 'Time Tuned',
            icon: Icons.timer,
            iconColor: const Color(0xFF00B0FF),
          ),
          Container(width: 1, height: 36, color: AuraColors.border(context)),
          _StatColumn(
            count: 'Pro',
            label: 'Listener Tier',
            icon: Icons.verified,
            iconColor: const Color(0xFFFFB300),
          ),
        ],
      ),
    );
  }
}

class _StatColumn extends StatelessWidget {
  final String count;
  final String label;
  final IconData icon;
  final Color iconColor;

  const _StatColumn({
    required this.count,
    required this.label,
    required this.icon,
    required this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: iconColor),
            const SizedBox(width: 5),
            Text(
              count,
              style: GoogleFonts.dmSans(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AuraColors.text(context),
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: GoogleFonts.dmSans(
            fontSize: 11,
            color: AuraColors.subtext(context),
          ),
        ),
      ],
    );
  }
}

// ─── History List Tile ────────────────────────────────────────────────────────

class _HistoryListTile extends StatelessWidget {
  final Episode episode;
  final VoidCallback onPlay;

  const _HistoryListTile({
    required this.episode,
    required this.onPlay,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AuraColors.card(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AuraColors.border(context)),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: SizedBox(
              width: 50,
              height: 50,
              child: (episode.displayImageUrl != null && episode.displayImageUrl!.isNotEmpty)
                  ? CachedNetworkImage(
                      imageUrl: episode.displayImageUrl!,
                      width: 50,
                      height: 50,
                      fit: BoxFit.cover,
                      httpHeaders: const {
                        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
                      },
                      placeholder: (context, url) => Container(color: AuraColors.cardDeep(context)),
                      errorWidget: (context, url, error) => _buildFallbackThumbnail(context),
                    )
                  : _buildFallbackThumbnail(context),
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
                    fontWeight: FontWeight.w600,
                    color: AuraColors.text(context),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    _buildMediaTag(context),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        episode.showName,
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
            icon: const Icon(Icons.play_circle_fill, size: 28, color: AuraColors.accent),
            onPressed: onPlay,
          ),
          IconButton(
            icon: Icon(Icons.more_vert, size: 20, color: AuraColors.subtext(context)),
            onPressed: () => _showHistoryOptions(context, episode),
          ),
        ],
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
      width: 50,
      height: 50,
      child: Center(
        child: Icon(icon, color: iconColor, size: 22),
      ),
    );
  }

  Widget _buildMediaTag(BuildContext context) {
    String label = 'Podcast';
    Color pillColor = AuraColors.accent;
    Color textColor = AuraColors.accent;

    if (episode.isYouTube) {
      label = 'YouTube';
      pillColor = const Color(0xFFFF0000);
      textColor = const Color(0xFFCC0000);
    } else if (episode.id.startsWith('ab_')) {
      label = 'Audiobook';
      pillColor = const Color(0xFFE67E22);
      textColor = const Color(0xFFD35400);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
      decoration: BoxDecoration(
        color: pillColor.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: GoogleFonts.dmSans(
          fontSize: 9,
          fontWeight: FontWeight.w700,
          color: textColor,
        ),
      ),
    );
  }

  void _showHistoryOptions(BuildContext context, Episode episode) {
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
              ListTile(
                leading: const Icon(Icons.play_circle_fill, color: AuraColors.accent),
                title: Text(
                  'Play Now',
                  style: GoogleFonts.dmSans(color: AuraColors.text(context), fontWeight: FontWeight.w600),
                ),
                onTap: () {
                  Navigator.pop(sheetContext);
                  audio.play(episode);
                },
              ),
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
                    SnackBar(content: Text('Playing next in queue', style: GoogleFonts.dmSans()), behavior: SnackBarBehavior.floating),
                  );
                },
              ),
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
                    SnackBar(content: Text('Added to queue', style: GoogleFonts.dmSans()), behavior: SnackBarBehavior.floating),
                  );
                },
              ),
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
                      content: Text(!isFav ? 'Saved to Favorites ⭐' : 'Removed from Favorites', style: GoogleFonts.dmSans()),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                },
              ),
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
                    SnackBar(content: Text('Episode link copied to clipboard! 📋', style: GoogleFonts.dmSans()), behavior: SnackBarBehavior.floating),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete_outline, color: AuraColors.error),
                title: Text(
                  'Remove from History',
                  style: GoogleFonts.dmSans(color: AuraColors.error),
                ),
                onTap: () {
                  Navigator.pop(sheetContext);
                  audio.removeFromHistory(episode.id);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Removed from listening history', style: GoogleFonts.dmSans()), behavior: SnackBarBehavior.floating),
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

// ─── Playlist Card ────────────────────────────────────────────────────────────

class _PlaylistCard extends StatelessWidget {
  final String title;
  final String count;
  final IconData icon;
  final List<Color> gradient;
  final VoidCallback? onTap;

  const _PlaylistCard({
    required this.title,
    required this.count,
    required this.icon,
    required this.gradient,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: gradient,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: gradient.first.withValues(alpha: 0.25),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: Colors.white, size: 24),
            const SizedBox(height: 14),
            Text(
              title,
              style: GoogleFonts.dmSans(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            Text(
              count,
              style: GoogleFonts.dmSans(
                fontSize: 11,
                color: Colors.white.withValues(alpha: 0.8),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Helpers ─────────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String title;
  final IconData icon;
  final String? trailingAction;
  final VoidCallback? onTrailingTap;

  const _SectionHeader({
    required this.title,
    required this.icon,
    this.trailingAction,
    this.onTrailingTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: AuraColors.subtext(context)),
              const SizedBox(width: 8),
              Text(
                title,
                style: GoogleFonts.dmSans(
                  fontSize: 16,
                  color: AuraColors.text(context),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          if (trailingAction != null)
            GestureDetector(
              onTap: onTrailingTap,
              child: Text(
                trailingAction!,
                style: GoogleFonts.dmSans(
                  fontSize: 12,
                  color: AuraColors.accent,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _EmptyStateCard extends StatelessWidget {
  final IconData icon;
  final String message;
  final String subtitle;

  const _EmptyStateCard({
    required this.icon,
    required this.message,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AuraColors.card(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AuraColors.border(context)),
      ),
      child: Row(
        children: [
          Icon(icon, color: AuraColors.subtext(context), size: 28),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  message,
                  style: GoogleFonts.dmSans(
                    fontSize: 13,
                    color: AuraColors.text(context),
                    fontWeight: FontWeight.w600,
                  ),
                ),
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
        ],
      ),
    );
  }
}

// ─── My Bookshelf Section ───────────────────────────────────────────────────

class _MyBookshelfSection extends StatelessWidget {
  const _MyBookshelfSection();

  @override
  Widget build(BuildContext context) {
    final bookProv = context.watch<AudiobookProvider>();
    final inProgress = bookProv.currentlyListeningBooks;
    final saved = bookProv.savedBooks;
    final bookmarks = bookProv.bookmarks;
    final hasBooks = inProgress.isNotEmpty || saved.isNotEmpty || bookmarks.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.menu_book, size: 18, color: AuraColors.primary(context)),
                  const SizedBox(width: 8),
                  Text(
                    'My Bookshelf',
                    style: GoogleFonts.dmSans(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AuraColors.text(context),
                    ),
                  ),
                ],
              ),
              GestureDetector(
                onTap: () {
                  Navigator.of(context).pushNamed(AppRoutes.audiobooks);
                },
                child: Text(
                  'Browse All',
                  style: GoogleFonts.dmSans(
                    fontSize: 12,
                    color: AuraColors.primary(context),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),

        if (!hasBooks)
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AuraColors.card(context),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AuraColors.border(context)),
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AuraColors.primary(context).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.auto_stories, color: AuraColors.primary(context), size: 24),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Start Your Audiobook Journey',
                        style: GoogleFonts.dmSans(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: AuraColors.text(context),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '50,000+ free classics & Hindi stories with chapter tracking',
                        style: GoogleFonts.dmSans(
                          fontSize: 11,
                          color: AuraColors.subtext(context),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pushNamed(AppRoutes.audiobooks);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AuraColors.primary(context),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    elevation: 0,
                  ),
                  child: Text(
                    'Explore',
                    style: GoogleFonts.dmSans(fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          )
        else ...[
          // Currently Listening Books
          if (inProgress.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
              child: Text(
                'CURRENTLY READING',
                style: GoogleFonts.dmSans(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1,
                  color: AuraColors.subtext(context),
                ),
              ),
            ),
            SizedBox(
              height: 115,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                itemCount: inProgress.length,
                separatorBuilder: (_, _) => const SizedBox(width: 12),
                itemBuilder: (context, index) {
                  final book = inProgress[index];
                  final prog = bookProv.getProgress(book.id);
                  final pct = prog?.calculatePercentage(book) ?? 0.0;
                  final chIndex = (prog?.currentChapterIndex ?? 0) + 1;

                  return GestureDetector(
                    onTap: () {
                      Navigator.of(context).pushNamed(AppRoutes.audiobookDetail, arguments: book);
                    },
                    child: Container(
                      width: 220,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AuraColors.card(context),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AuraColors.border(context)),
                      ),
                      child: Row(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: SizedBox(
                              width: 50,
                              height: 70,
                              child: book.hasValidCover
                                  ? CachedNetworkImage(
                                      imageUrl: book.coverUrl,
                                      fit: BoxFit.cover,
                                      errorWidget: (_, _, _) => BookJacketCover(book: book),
                                    )
                                  : BookJacketCover(book: book),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  book.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.dmSans(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: AuraColors.text(context),
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Ch $chIndex • ${(pct * 100).toInt()}%',
                                  style: GoogleFonts.dmSans(
                                    fontSize: 10,
                                    color: AuraColors.subtext(context),
                                  ),
                                ),
                                const SizedBox(height: 6),
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(3),
                                  child: LinearProgressIndicator(
                                    value: pct > 0 ? pct : 0.05,
                                    minHeight: 3,
                                    backgroundColor: AuraColors.border(context),
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      AuraColors.primary(context),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 6),
                                GestureDetector(
                                  onTap: () => bookProv.resumeBook(book, context),
                                  child: Row(
                                    children: [
                                      Icon(Icons.play_arrow,
                                          size: 14, color: AuraColors.primary(context)),
                                      const SizedBox(width: 2),
                                      Text(
                                        'Resume',
                                        style: GoogleFonts.dmSans(
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                          color: AuraColors.primary(context),
                                        ),
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
                },
              ),
            ),
            const SizedBox(height: 10),
          ],

          // Saved Titles Carousel
          if (saved.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
              child: Text(
                'SAVED BOOKS (${saved.length})',
                style: GoogleFonts.dmSans(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1,
                  color: AuraColors.subtext(context),
                ),
              ),
            ),
            SizedBox(
              height: 140,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                itemCount: saved.length,
                separatorBuilder: (_, _) => const SizedBox(width: 10),
                itemBuilder: (context, index) {
                  final book = saved[index];
                  return GestureDetector(
                    onTap: () {
                      Navigator.of(context).pushNamed(AppRoutes.audiobookDetail, arguments: book);
                    },
                    child: SizedBox(
                      width: 85,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: SizedBox(
                              width: 85,
                              height: 100,
                              child: book.hasValidCover
                                  ? CachedNetworkImage(
                                      imageUrl: book.coverUrl,
                                      fit: BoxFit.cover,
                                      errorWidget: (_, _, _) => BookJacketCover(book: book),
                                    )
                                  : BookJacketCover(book: book),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            book.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.dmSans(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: AuraColors.text(context),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 10),
          ],

          // Saved Passages & Quotes
          if (bookmarks.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
              child: Text(
                'SAVED PASSAGES (${bookmarks.length})',
                style: GoogleFonts.dmSans(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1,
                  color: AuraColors.subtext(context),
                ),
              ),
            ),
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemCount: bookmarks.take(3).length,
              itemBuilder: (context, index) {
                final bm = bookmarks[index];
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AuraColors.card(context),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AuraColors.border(context)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.format_quote, size: 20, color: AuraColors.primary(context)),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              bm.note.isNotEmpty ? bm.note : 'Bookmarked timestamp',
                              style: GoogleFonts.dmSans(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: AuraColors.text(context),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${bm.chapterTitle} • ${(bm.timestampMs / 1000).floor()}s',
                              style: GoogleFonts.dmSans(
                                fontSize: 10,
                                color: AuraColors.subtext(context),
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline, size: 16),
                        color: AuraColors.subtext(context),
                        onPressed: () => bookProv.deleteBookmark(bm.id),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ],
      ],
    );
  }
}

