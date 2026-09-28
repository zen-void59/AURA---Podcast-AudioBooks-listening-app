import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:aura/core/theme.dart';
import 'package:aura/core/routes.dart';
import 'package:aura/providers/audio_provider.dart';

/// Compact mini player shown at bottom of every screen when audio is active.
class MiniPlayer extends StatelessWidget {
  const MiniPlayer({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = AuraColors.isDark(context);
    final bgColor = isDark ? const Color(0xFF1C1C1E) : AuraColors.charcoal;
    final borderColor = isDark ? const Color(0xFF333333) : Colors.transparent;

    return Consumer<AudioProvider>(
      builder: (context, audio, _) {
        if (!audio.hasEpisode) return const SizedBox.shrink();

        return SafeArea(
          top: false,
          child: GestureDetector(
            onTap: () {
              final isAudiobook = audio.currentEpisode?.id.startsWith('ab_') ?? false;
              if (isAudiobook) {
                Navigator.of(context).pushNamed(AppRoutes.audiobookPlayer);
              } else {
                Navigator.of(context).pushNamed(AppRoutes.player);
              }
            },
            child: Container(
              margin: const EdgeInsets.fromLTRB(12, 0, 12, 8),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: borderColor),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.4 : 0.25),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      // Artwork
                      if (audio.currentEpisode?.displayImageUrl != null &&
                          audio.currentEpisode!.displayImageUrl!.isNotEmpty)
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: CachedNetworkImage(
                            imageUrl: audio.currentEpisode!.displayImageUrl!,
                            width: 42,
                            height: 42,
                            fit: BoxFit.cover,
                            httpHeaders: const {
                              'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
                            },
                            errorWidget: (context, url, error) => _placeholder(),
                          ),
                        )
                      else
                        _placeholder(),

                      const SizedBox(width: 12),

                      // Title
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              audio.currentEpisode!.name,
                              style: GoogleFonts.dmSans(
                                fontSize: 13,
                                color: AuraColors.cream,
                                fontWeight: FontWeight.w600,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              audio.currentEpisode!.showName,
                              style: GoogleFonts.dmSans(
                                fontSize: 11,
                                color: AuraColors.cream.withValues(alpha: 0.6),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),

                      // Moving Waveform Indicator
                      _MiniAudioWaveform(
                        isPlaying: audio.isPlaying,
                        color: AuraColors.accent,
                      ),
                      const SizedBox(width: 8),

                      // Controls
                      if (audio.isLoading)
                        const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AuraColors.cream,
                          ),
                        )
                      else ...[
                        IconButton(
                          icon: Icon(
                            audio.isPlaying ? Icons.pause : Icons.play_arrow,
                            color: AuraColors.cream,
                            size: 24,
                          ),
                          onPressed: audio.togglePlayPause,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                        ),
                        if (audio.hasNext)
                          IconButton(
                            icon: const Icon(Icons.skip_next, color: AuraColors.cream, size: 20),
                            onPressed: audio.playNext,
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(minWidth: 32, minHeight: 36),
                          ),
                      ],
                    ],
                  ),
                  // Progress bar
                  const SizedBox(height: 6),
                  LinearProgressIndicator(
                    value: audio.progress,
                    backgroundColor: AuraColors.cream.withValues(alpha: 0.15),
                    valueColor: const AlwaysStoppedAnimation(AuraColors.accent),
                    minHeight: 2,
                    borderRadius: BorderRadius.circular(1),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _placeholder() {
    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        color: AuraColors.darkCard,
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Icon(Icons.podcasts, color: AuraColors.charcoalLight, size: 20),
    );
  }
}

class _MiniAudioWaveform extends StatefulWidget {
  final bool isPlaying;
  final Color color;

  const _MiniAudioWaveform({required this.isPlaying, required this.color});

  @override
  State<_MiniAudioWaveform> createState() => _MiniAudioWaveformState();
}

class _MiniAudioWaveformState extends State<_MiniAudioWaveform>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));
    if (widget.isPlaying) _ctrl.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(_MiniAudioWaveform oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isPlaying != oldWidget.isPlaying) {
      if (widget.isPlaying) {
        _ctrl.repeat(reverse: true);
      } else {
        _ctrl.stop();
      }
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, _) {
        final t = _ctrl.value;
        return Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: List.generate(4, (i) {
            final heights = [
              widget.isPlaying ? (6.0 + (math.sin(t * math.pi + i) * 10).abs()) : 4.0,
              widget.isPlaying ? (4.0 + (math.cos(t * math.pi + i * 0.7) * 12).abs()) : 7.0,
              widget.isPlaying ? (8.0 + (math.sin(t * math.pi * 1.3 + i * 0.5) * 8).abs()) : 5.0,
              widget.isPlaying ? (5.0 + (math.cos(t * math.pi * 0.9 + i) * 9).abs()) : 6.0,
            ];
            return Container(
              width: 2.5,
              height: heights[i].clamp(3.0, 18.0),
              margin: const EdgeInsets.symmetric(horizontal: 1),
              decoration: BoxDecoration(
                color: widget.color,
                borderRadius: BorderRadius.circular(2),
              ),
            );
          }),
        );
      },
    );
  }
}
