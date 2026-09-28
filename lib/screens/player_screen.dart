import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:aura/core/theme.dart';
import 'package:aura/models/episode.dart';
import 'package:aura/providers/audio_provider.dart';

/// Full-screen Now Playing screen — dark AURA aesthetic.
class PlayerScreen extends StatefulWidget {
  const PlayerScreen({super.key});

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseCtrl;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    );
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AudioProvider>(
      builder: (context, audio, _) {
        final episode = audio.currentEpisode;
        if (episode == null) {
          return const Scaffold(
            backgroundColor: AuraColors.darkBg,
            body: Center(
              child: Text(
                'No episode playing',
                style: TextStyle(color: AuraColors.cream),
              ),
            ),
          );
        }

        // Sync animation controller safely after frame build
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          if (audio.isPlaying && !_pulseCtrl.isAnimating) {
            _pulseCtrl.repeat();
          } else if (!audio.isPlaying && _pulseCtrl.isAnimating) {
            _pulseCtrl.stop();
          }
        });

        return Scaffold(
          backgroundColor: AuraColors.darkBg,
          body: Stack(
            children: [
              // Ambient soft background glow - zero hard edges, smooth 360 radial diffusion
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                height: 420,
                child: IgnorePointer(
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: RadialGradient(
                        center: const Alignment(0.0, -0.4),
                        radius: 1.1,
                        colors: [
                          AuraColors.accent.withValues(alpha: audio.isPlaying ? 0.20 : 0.08),
                          AuraColors.accent.withValues(alpha: audio.isPlaying ? 0.06 : 0.02),
                          Colors.transparent,
                        ],
                        stops: const [0.0, 0.55, 1.0],
                      ),
                    ),
                  ),
                ),
              ),
              SafeArea(
                child: Column(
                  children: [
                    _buildTopBar(context),
                    Expanded(
                      child: SingleChildScrollView(
                        clipBehavior: Clip.none, // Prevents clipping top ambient glow into a hard line
                        padding: const EdgeInsets.symmetric(horizontal: 28),
                        child: Column(
                          children: [
                            const SizedBox(height: 24),
                            _buildArtwork(episode.displayImageUrl, audio.isPlaying),
                        const SizedBox(height: 28),
                        _buildEpisodeInfo(episode.name, episode.showName),
                        if (audio.error != null && audio.state == PlaybackState.error) ...[
                          const SizedBox(height: 12),
                          _buildErrorBanner(audio.error!),
                        ],
                        const SizedBox(height: 32),
                        _buildWaveform(audio),
                        const SizedBox(height: 8),
                        _buildProgressBar(audio),
                        const SizedBox(height: 24),
                        _buildControls(audio),
                        const SizedBox(height: 24),
                        _buildSpeedAndSleep(audio, context),
                        const SizedBox(height: 32),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
      },
    );
  }

  Widget _buildTopBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(
              Icons.keyboard_arrow_down,
              color: AuraColors.cream,
              size: 28,
            ),
            onPressed: () => Navigator.pop(context),
          ),
          const Expanded(
            child: Text(
              'NOW PLAYING',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AuraColors.cream,
                fontSize: 11,
                letterSpacing: 2.5,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Consumer<AudioProvider>(
            builder: (ctx, audio, _) => IconButton(
              icon: const Icon(
                Icons.more_vert,
                color: AuraColors.cream,
                size: 22,
              ),
              onPressed: () => _showPlayerOptions(context, audio),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildArtwork(String? imageUrl, bool isPlaying) {
    return Center(
      child: AnimatedScale(
        scale: isPlaying ? 1.0 : 0.94,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOutCubic,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeOutCubic,
          width: 260,
          height: 260,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: AuraColors.accentLight.withValues(alpha: isPlaying ? 0.25 : 0.10),
                blurRadius: isPlaying ? 48 : 28,
                spreadRadius: isPlaying ? 4 : 0,
                offset: Offset.zero,
              ),
              if (isPlaying)
                BoxShadow(
                  color: AuraColors.accent.withValues(alpha: 0.12),
                  blurRadius: 80,
                  spreadRadius: 8,
                  offset: Offset.zero,
                ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: (imageUrl != null && imageUrl.isNotEmpty)
                ? CachedNetworkImage(
                    imageUrl: imageUrl,
                    fit: BoxFit.cover,
                    httpHeaders: const {
                      'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
                    },
                    errorWidget: (context, url, error) => _artworkPlaceholder(),
                  )
                : _artworkPlaceholder(),
          ),
        ),
      ),
    );
  }

  Widget _artworkPlaceholder() {
    return Container(
      color: AuraColors.darkCard,
      child: const Icon(
        Icons.podcasts,
        size: 64,
        color: AuraColors.charcoalMed,
      ),
    );
  }

  Widget _buildEpisodeInfo(String name, String showName) {
    return Column(
      children: [
        Text(
          name,
          style: GoogleFonts.dmSans(
            fontSize: 20,
            color: AuraColors.cream,
            height: 1.3,
          ),
          textAlign: TextAlign.center,
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 6),
        Text(
          showName,
          style: GoogleFonts.dmSans(
            fontSize: 13,
            color: AuraColors.cream.withValues(alpha: 0.55),
            letterSpacing: 0.3,
          ),
        ),
      ],
    );
  }

  Widget _buildWaveform(AudioProvider audio) {
    final isPlaying = audio.isPlaying;
    final speedFactor = audio.speed.clamp(0.5, 2.5);

    return SizedBox(
      height: 52,
      child: AnimatedBuilder(
        animation: _pulseCtrl,
        builder: (context, child) {
          final phase = _pulseCtrl.value * 2 * math.pi * speedFactor;
          return Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: List.generate(36, (i) {
              final progressFraction = i / 36.0;
              final isActive = progressFraction <= audio.progress;

              // Synchronize with audio progress: acoustic energy peaks around current playback position
              final distFromPlayhead = (progressFraction - audio.progress).abs();
              final playheadEnergy = math.exp(-distFromPlayhead * 5.0);

              // Multi-harmonic audio waveform
              final w1 = math.sin(phase + (i * 0.32));
              final w2 = math.cos((phase * 1.35) + (i * 0.18));
              final w3 = math.sin((phase * 0.7) + (i * 0.42));
              final wave = (w1 * 0.5 + w2 * 0.35 + w3 * 0.15);

              final dynamicHeight = isPlaying
                  ? (12.0 + (wave * 14.0) + (playheadEnergy * 14.0) + (math.sin(i * 0.55) * 4.0)).abs().clamp(6.0, 48.0)
                  : (8.0 + (math.sin(i * 0.4) * 6.0)).abs().clamp(4.0, 22.0);

              return Container(
                width: 3.5,
                height: dynamicHeight,
                margin: const EdgeInsets.symmetric(horizontal: 1.5),
                decoration: BoxDecoration(
                  gradient: isActive
                      ? const LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [AuraColors.accent, Color(0xFFFF8E53)],
                        )
                      : null,
                  color: isActive ? null : AuraColors.waveformInactive,
                  borderRadius: BorderRadius.circular(3),
                  boxShadow: isActive && isPlaying
                      ? [
                          BoxShadow(
                            color: AuraColors.accent.withValues(alpha: 0.35 + (playheadEnergy * 0.25)),
                            blurRadius: 4 + (playheadEnergy * 3),
                            offset: const Offset(0, 1),
                          ),
                        ]
                      : null,
                ),
              );
            }),
          );
        },
      ),
    );
  }

  Widget _buildProgressBar(AudioProvider audio) {
    return Column(
      children: [
        SliderTheme(
          data: SliderThemeData(
            trackHeight: 3,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
            activeTrackColor: AuraColors.cream,
            inactiveTrackColor: AuraColors.darkBorder,
            thumbColor: AuraColors.cream,
            overlayColor: AuraColors.cream.withValues(alpha: 0.12),
          ),
          child: Slider(
            value: audio.progress.clamp(0.0, 1.0),
            onChanged: (v) {
              final pos = Duration(
                milliseconds: (v * audio.duration.inMilliseconds).round(),
              );
              audio.seekTo(pos);
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(_fmt(audio.position), style: _timeStyle),
              Text(_fmt(audio.duration), style: _timeStyle),
            ],
          ),
        ),
      ],
    );
  }

  TextStyle get _timeStyle => GoogleFonts.dmSans(
    fontSize: 11,
    color: AuraColors.cream.withValues(alpha: 0.7),
    letterSpacing: 0.5,
    fontWeight: FontWeight.w600,
  );

  String _fmt(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '${h.toString().padLeft(2, '0')}:$m:$s';
  }

  Widget _buildControls(AudioProvider audio) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _ControlButton(
          icon: Icons.replay_10,
          onTap: audio.skipBackward,
          size: 28,
        ),
        _ControlButton(
          icon: Icons.skip_previous,
          onTap: audio.hasPrevious ? audio.playPrevious : null,
          size: 26,
        ),
        // Play / Pause — large
        GestureDetector(
          onTap: audio.togglePlayPause,
          child: Container(
            width: 68,
            height: 68,
            decoration: const BoxDecoration(
              color: AuraColors.cream,
              shape: BoxShape.circle,
            ),
            child: audio.isLoading
                ? const CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AuraColors.charcoal,
                  )
                : Icon(
                    audio.isPlaying ? Icons.pause : Icons.play_arrow,
                    color: AuraColors.charcoal,
                    size: 36,
                  ),
          ),
        ),
        _ControlButton(
          icon: Icons.skip_next,
          onTap: audio.hasNext ? audio.playNext : null,
          size: 26,
        ),
        _ControlButton(
          icon: Icons.forward_30,
          onTap: audio.skipForward,
          size: 28,
        ),
      ],
    );
  }

  Widget _buildSpeedAndSleep(AudioProvider audio, BuildContext context) {
    final remaining = audio.sleepRemaining;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // Playback speed
        GestureDetector(
          onTap: () => _showSpeedPicker(context, audio),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: AuraColors.darkCard,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '${audio.speed}x',
              style: GoogleFonts.dmSans(
                fontSize: 13,
                color: AuraColors.cream,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),
        // Sleep timer
        GestureDetector(
          onTap: () => _showSleepTimer(context, audio),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: AuraColors.darkCard,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.bedtime_outlined,
                  size: 16,
                  color: AuraColors.cream,
                ),
                const SizedBox(width: 6),
                Text(
                  remaining != null ? '${remaining.inMinutes}m left' : 'Sleep',
                  style: GoogleFonts.dmSans(
                    fontSize: 13,
                    color: AuraColors.cream,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildErrorBanner(String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AuraColors.error.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AuraColors.error.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: AuraColors.error, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: GoogleFonts.dmSans(
                fontSize: 12,
                color: AuraColors.error,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showSpeedPicker(BuildContext context, AudioProvider audio) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AuraColors.darkSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              margin: const EdgeInsets.symmetric(vertical: 10),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AuraColors.darkBorder,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Text(
              'Playback Speed',
              style: GoogleFonts.dmSans(
                color: AuraColors.cream,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              alignment: WrapAlignment.center,
              children: [0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0].map((speed) {
                final selected = audio.speed == speed;
                return GestureDetector(
                  onTap: () {
                    audio.setSpeed(speed);
                    Navigator.pop(context);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: selected ? AuraColors.cream : AuraColors.darkCard,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '${speed}x',
                      style: GoogleFonts.dmSans(
                        color: selected
                            ? AuraColors.charcoal
                            : AuraColors.cream,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  void _showSleepTimer(BuildContext context, AudioProvider audio) {
    final options = [5, 10, 15, 30, 45, 60];
    showModalBottomSheet(
      context: context,
      backgroundColor: AuraColors.darkSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              margin: const EdgeInsets.symmetric(vertical: 10),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AuraColors.darkBorder,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Text(
              'Sleep Timer',
              style: GoogleFonts.dmSans(
                color: AuraColors.cream,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            ...options.map(
              (min) => ListTile(
                title: Text(
                  '$min minutes',
                  style: GoogleFonts.dmSans(color: AuraColors.cream),
                ),
                leading: const Icon(
                  Icons.timer_outlined,
                  color: AuraColors.charcoalMed,
                ),
                onTap: () {
                  audio.setSleepTimer(Duration(minutes: min));
                  Navigator.pop(context);
                },
              ),
            ),
            if (audio.sleepRemaining != null)
              ListTile(
                title: Text(
                  'Cancel timer',
                  style: GoogleFonts.dmSans(color: AuraColors.error),
                ),
                leading: const Icon(
                  Icons.cancel_outlined,
                  color: AuraColors.error,
                ),
                onTap: () {
                  audio.cancelSleepTimer();
                  Navigator.pop(context);
                },
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _showPlayerOptions(BuildContext context, AudioProvider audio) {
    final ep = audio.currentEpisode;
    if (ep == null) return;
    final favId = ep.showId;
    final isFav = audio.isFavorite(favId);

    showModalBottomSheet(
      context: context,
      backgroundColor: AuraColors.darkSurface,
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
                  color: AuraColors.darkBorder,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // Episode Header preview
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Row(
                  children: [
                    if (ep.imageUrl != null)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: CachedNetworkImage(
                          imageUrl: ep.imageUrl!,
                          width: 44,
                          height: 44,
                          fit: BoxFit.cover,
                          errorWidget: (_, _, _) => Container(
                            width: 44,
                            height: 44,
                            color: AuraColors.darkCard,
                            child: const Icon(Icons.music_note, color: Colors.white54),
                          ),
                        ),
                      ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            ep.name,
                            style: GoogleFonts.dmSans(
                              color: AuraColors.cream,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            ep.showName,
                            style: GoogleFonts.dmSans(
                              color: AuraColors.charcoalMed,
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
              const Divider(color: AuraColors.darkBorder, height: 16),
              // 1. Favorite / Bookmark
              ListTile(
                leading: Icon(
                  isFav ? Icons.star : Icons.star_border,
                  color: isFav ? Colors.amber : AuraColors.cream,
                ),
                title: Text(
                  isFav ? 'In Favorites (Tap to remove)' : 'Add to Favorites',
                  style: GoogleFonts.dmSans(color: AuraColors.cream),
                ),
                onTap: () {
                  audio.toggleFavorite(favId);
                  Navigator.pop(sheetContext);
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
              // 2. Up Next Queue
              ListTile(
                leading: const Icon(Icons.queue_music, color: AuraColors.cream),
                title: Text(
                  'Up Next Queue (${audio.queue.length} tracks)',
                  style: GoogleFonts.dmSans(color: AuraColors.cream),
                ),
                subtitle: Text(
                  'View and manage upcoming playlist',
                  style: GoogleFonts.dmSans(color: AuraColors.charcoalMed, fontSize: 11),
                ),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _showQueueSheet(context, audio);
                },
              ),
              // 3. Show Notes / Description
              ListTile(
                leading: const Icon(Icons.description_outlined, color: AuraColors.cream),
                title: Text(
                  'Episode Details & Notes',
                  style: GoogleFonts.dmSans(color: AuraColors.cream),
                ),
                subtitle: Text(
                  'Read summary, timestamps & creator details',
                  style: GoogleFonts.dmSans(color: AuraColors.charcoalMed, fontSize: 11),
                ),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _showEpisodeDetails(context, ep);
                },
              ),
              // 4. Playback speed
              ListTile(
                leading: const Icon(Icons.speed, color: AuraColors.cream),
                title: Text(
                  'Playback Speed (${audio.speed}x)',
                  style: GoogleFonts.dmSans(color: AuraColors.cream),
                ),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _showSpeedPicker(context, audio);
                },
              ),
              // 5. Sleep timer
              ListTile(
                leading: const Icon(Icons.bedtime_outlined, color: AuraColors.cream),
                title: Text(
                  audio.sleepRemaining != null
                      ? 'Sleep Timer (${audio.sleepRemaining!.inMinutes}m left)'
                      : 'Sleep Timer (Off)',
                  style: GoogleFonts.dmSans(color: AuraColors.cream),
                ),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _showSleepTimer(context, audio);
                },
              ),
              // 6. Play from start
              ListTile(
                leading: const Icon(Icons.replay, color: AuraColors.cream),
                title: Text(
                  'Play from Start (00:00:00)',
                  style: GoogleFonts.dmSans(color: AuraColors.cream),
                ),
                onTap: () {
                  audio.seekTo(Duration.zero);
                  Navigator.pop(sheetContext);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Replaying from beginning ⏪', style: GoogleFonts.dmSans()),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                },
              ),
              // 7. Share Episode
              ListTile(
                leading: const Icon(Icons.share_outlined, color: AuraColors.cream),
                title: Text(
                  'Share Episode Link',
                  style: GoogleFonts.dmSans(color: AuraColors.cream),
                ),
                onTap: () {
                  final shareText = '${ep.name} - ${ep.showName}\n${ep.url ?? ep.streamUrl ?? ""}';
                  Clipboard.setData(ClipboardData(text: shareText));
                  Navigator.pop(sheetContext);
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

  void _showQueueSheet(BuildContext context, AudioProvider audio) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AuraColors.darkSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => DraggableScrollableSheet(
        initialChildSize: 0.65,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        expand: false,
        builder: (_, scrollCtrl) => SafeArea(
          child: Column(
            children: [
              Container(
                margin: const EdgeInsets.symmetric(vertical: 10),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AuraColors.darkBorder,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Up Next Queue',
                      style: GoogleFonts.dmSans(
                        color: AuraColors.cream,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (audio.queue.length > 1)
                      TextButton(
                        onPressed: () {
                          audio.clearQueue();
                          Navigator.pop(sheetContext);
                        },
                        child: Text(
                          'Clear Queue',
                          style: GoogleFonts.dmSans(color: AuraColors.error, fontSize: 13),
                        ),
                      ),
                  ],
                ),
              ),
              const Divider(color: AuraColors.darkBorder, height: 1),
              Expanded(
                child: audio.queue.isEmpty
                    ? Center(
                        child: Text(
                          'Queue is empty',
                          style: GoogleFonts.dmSans(color: AuraColors.charcoalMed),
                        ),
                      )
                    : ListView.builder(
                        controller: scrollCtrl,
                        itemCount: audio.queue.length,
                        itemBuilder: (context, i) {
                          final item = audio.queue[i];
                          final isCurrent = i == audio.queueIndex;

                          return Container(
                            margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                            decoration: BoxDecoration(
                              color: isCurrent
                                  ? AuraColors.accent.withValues(alpha: 0.15)
                                  : AuraColors.darkCard,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isCurrent
                                    ? AuraColors.accent.withValues(alpha: 0.4)
                                    : AuraColors.darkBorder,
                              ),
                            ),
                            child: ListTile(
                              leading: ClipRRect(
                                borderRadius: BorderRadius.circular(6),
                                child: CachedNetworkImage(
                                  imageUrl: item.imageUrl ?? '',
                                  width: 42,
                                  height: 42,
                                  fit: BoxFit.cover,
                                  errorWidget: (_, _, _) => Container(
                                    width: 42,
                                    height: 42,
                                    color: AuraColors.darkBorder,
                                    child: const Icon(Icons.music_note, color: Colors.white38),
                                  ),
                                ),
                              ),
                              title: Text(
                                item.name,
                                style: GoogleFonts.dmSans(
                                  color: isCurrent ? AuraColors.cream : AuraColors.cream.withValues(alpha: 0.9),
                                  fontSize: 13,
                                  fontWeight: isCurrent ? FontWeight.bold : FontWeight.w500,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              subtitle: Row(
                                children: [
                                  if (isCurrent) ...[
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                      decoration: BoxDecoration(
                                        color: AuraColors.accent,
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        'PLAYING',
                                        style: GoogleFonts.dmSans(
                                          color: Colors.white,
                                          fontSize: 9,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                  ],
                                  Expanded(
                                    child: Text(
                                      item.showName,
                                      style: GoogleFonts.dmSans(
                                        color: AuraColors.charcoalMed,
                                        fontSize: 11,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                              trailing: isCurrent
                                  ? const Icon(Icons.equalizer, color: AuraColors.accent, size: 20)
                                  : IconButton(
                                      icon: const Icon(Icons.close, color: AuraColors.charcoalMed, size: 18),
                                      onPressed: () => audio.removeFromQueue(i),
                                    ),
                              onTap: () {
                                if (!isCurrent) {
                                  audio.jumpToQueueIndex(i);
                                }
                                Navigator.pop(sheetContext);
                              },
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showEpisodeDetails(BuildContext context, Episode ep) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AuraColors.darkSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.4,
        maxChildSize: 0.92,
        expand: false,
        builder: (_, scrollCtrl) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: ListView(
              controller: scrollCtrl,
              children: [
                Center(
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 10),
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AuraColors.darkBorder,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                if (ep.imageUrl != null)
                  Center(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: CachedNetworkImage(
                        imageUrl: ep.imageUrl!,
                        width: 120,
                        height: 120,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                const SizedBox(height: 16),
                Text(
                  ep.name,
                  style: GoogleFonts.dmSans(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AuraColors.cream,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 6),
                Text(
                  ep.showName,
                  style: GoogleFonts.dmSans(
                    fontSize: 14,
                    color: AuraColors.accent,
                    fontWeight: FontWeight.w600,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 14),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (ep.releaseDate != null) ...[
                      const Icon(Icons.calendar_today_outlined, size: 14, color: AuraColors.charcoalMed),
                      const SizedBox(width: 4),
                      Text(
                        ep.releaseDate!,
                        style: GoogleFonts.dmSans(fontSize: 12, color: AuraColors.charcoalMed),
                      ),
                      const SizedBox(width: 16),
                    ],
                    if (ep.duration != null) ...[
                      const Icon(Icons.schedule, size: 14, color: AuraColors.charcoalMed),
                      const SizedBox(width: 4),
                      Text(
                        _fmt(Duration(seconds: ep.duration!)),
                        style: GoogleFonts.dmSans(fontSize: 12, color: AuraColors.charcoalMed),
                      ),
                    ],
                  ],
                ),
                const Divider(color: AuraColors.darkBorder, height: 24),
                Text(
                  'About this Episode',
                  style: GoogleFonts.dmSans(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: AuraColors.cream,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  ep.description?.isNotEmpty == true
                      ? ep.description!
                      : 'No additional show notes provided for this episode.',
                  style: GoogleFonts.dmSans(
                    fontSize: 13,
                    color: AuraColors.cream.withValues(alpha: 0.8),
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 30),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ControlButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  final double size;

  const _ControlButton({
    required this.icon,
    required this.onTap,
    this.size = 26,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Icon(
        icon,
        size: size,
        color: onTap != null
            ? AuraColors.cream
            : AuraColors.cream.withValues(alpha: 0.3),
      ),
    );
  }
}
