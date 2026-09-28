import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:aura/core/theme.dart';
import 'package:aura/models/audiobook.dart';
import 'package:aura/providers/audio_provider.dart';
import 'package:aura/providers/audiobook_provider.dart';
import 'package:aura/widgets/book_jacket_cover.dart';

class AudiobookPlayerScreen extends StatefulWidget {
  final Audiobook? book;
  const AudiobookPlayerScreen({super.key, this.book});

  @override
  State<AudiobookPlayerScreen> createState() => _AudiobookPlayerScreenState();
}

class _AudiobookPlayerScreenState extends State<AudiobookPlayerScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseCtrl;
  int _lastSavedSec = -1;

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
    final audioProv = context.watch<AudioProvider>();
    final bookProv = context.watch<AudiobookProvider>();
    Audiobook? activeBook = widget.book ?? bookProv.activeBook;
    if (activeBook == null &&
        audioProv.currentEpisode != null &&
        audioProv.currentEpisode!.id.startsWith('ab_')) {
      final bookId = audioProv.currentEpisode!.showId;
      activeBook = bookProv.getBook(bookId);
    }

    if (activeBook == null) {
      return Scaffold(
        backgroundColor: AuraColors.darkBg,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.keyboard_arrow_down, color: Colors.white),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
        body: const Center(
          child: Text('No audiobook selected', style: TextStyle(color: Colors.white70)),
        ),
      );
    }

    int currentChapterIdx = bookProv.activeChapterIndex;
    if (audioProv.currentEpisode != null &&
        audioProv.currentEpisode!.id.startsWith('ab_${activeBook.id}_ch_')) {
      final chOrderStr = audioProv.currentEpisode!.id.split('_ch_').last;
      final chOrder = int.tryParse(chOrderStr);
      if (chOrder != null && chOrder - 1 >= 0 && chOrder - 1 < activeBook.chapters.length) {
        currentChapterIdx = chOrder - 1;
      }
    } else if (audioProv.queueIndex >= 0 && audioProv.queueIndex < activeBook.chapters.length) {
      currentChapterIdx = audioProv.queueIndex;
    }

    final totalChapters = activeBook.chapters.length;
    final currentChNum = (currentChapterIdx + 1).clamp(1, totalChapters > 0 ? totalChapters : 1);
    final currentCh = (currentChapterIdx >= 0 && currentChapterIdx < activeBook.chapters.length)
        ? activeBook.chapters[currentChapterIdx]
        : (activeBook.chapters.isNotEmpty ? activeBook.chapters.first : null);

    // Schedule animation controller sync safely after current frame build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (audioProv.isPlaying && !_pulseCtrl.isAnimating) {
        _pulseCtrl.repeat();
      } else if (!audioProv.isPlaying && _pulseCtrl.isAnimating) {
        _pulseCtrl.stop();
      }
    });

    // Save position periodically after build completes (every 5s) without notifying listeners
    final currentSec = audioProv.position.inSeconds;
    if (audioProv.isPlaying && currentSec > 0 && currentSec != _lastSavedSec && currentSec % 5 == 0) {
      _lastSavedSec = currentSec;
      final savedPosMs = audioProv.position.inMilliseconds;
      final savedBookId = activeBook.id;
      final savedChIdx = currentChapterIdx;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        context.read<AudiobookProvider>().saveProgress(
          savedBookId,
          savedChIdx,
          savedPosMs,
          notify: false,
        );
      });
    }

    return Scaffold(
      backgroundColor: AuraColors.darkBg,
      body: Stack(
        children: [
          // Soft ambient backdrop glow - zero hard edges
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 440,
            child: IgnorePointer(
              child: Container(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: const Alignment(0.0, -0.35),
                    radius: 1.1,
                    colors: [
                      AuraColors.primaryDark.withValues(alpha: audioProv.isPlaying ? 0.20 : 0.08),
                      AuraColors.primaryDark.withValues(alpha: audioProv.isPlaying ? 0.06 : 0.02),
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
                // Top Bar
                _buildTopBar(context, activeBook, currentChNum, totalChapters, currentChapterIdx),
                Expanded(
                  child: SingleChildScrollView(
                    clipBehavior: Clip.none, // Prevents clipping top ambient glow into a line
                    padding: const EdgeInsets.symmetric(horizontal: 28),
                    child: Column(
                      children: [
                        const SizedBox(height: 20),
                        // High-res Cover Art with Glow
                        _buildArtwork(activeBook, audioProv.isPlaying),
                    const SizedBox(height: 24),
                    // Title & Chapter Info
                    _buildBookInfo(activeBook, currentCh, currentChNum, totalChapters),
                    const SizedBox(height: 24),
                    // Moving Waveform Visualizer
                    _buildWaveform(audioProv),
                    const SizedBox(height: 10),
                    // Chapter Progress Bar & Time
                    _buildProgressBar(audioProv),
                    const SizedBox(height: 24),
                    // Controls: -15s, Previous Chapter, Play/Pause, Next Chapter, +15s
                    _buildPlaybackControls(audioProv, bookProv, activeBook, currentChapterIdx),
                    const SizedBox(height: 28),
                    // Utility row: Speed (0.75x-2.5x), End-of-Chapter Sleep, Quote Bookmark
                    _buildAudiobookUtilities(context, audioProv, bookProv, activeBook, currentCh),
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
}

  Widget _buildTopBar(
    BuildContext context,
    Audiobook book,
    int currentChNum,
    int totalChapters,
    int currentChapterIdx,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: const Icon(Icons.keyboard_arrow_down, color: Colors.white, size: 28),
            onPressed: () => Navigator.of(context).pop(),
          ),
          Column(
            children: [
              Text(
                'AUDIOBOOK CHAPTER',
                style: GoogleFonts.dmSans(
                  fontSize: 10,
                  letterSpacing: 1.5,
                  fontWeight: FontWeight.bold,
                  color: AuraColors.creamMuted,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Chapter $currentChNum of $totalChapters',
                style: GoogleFonts.dmSans(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.white70,
                ),
              ),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.format_list_bulleted, color: Colors.white, size: 24),
            tooltip: 'Table of Contents',
            onPressed: () => _showChapterDrawer(context, book, currentChapterIdx),
          ),
        ],
      ),
    );
  }

  Widget _buildArtwork(Audiobook book, bool isPlaying) {
    return Center(
      child: AnimatedScale(
        scale: isPlaying ? 1.0 : 0.94,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOutCubic,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeOutCubic,
          width: 220,
          height: 310,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: AuraColors.rust.withValues(alpha: isPlaying ? 0.25 : 0.10),
                blurRadius: isPlaying ? 48 : 28,
                spreadRadius: isPlaying ? 3 : 0,
                offset: Offset.zero, // Symmetric diffusion on all 4 sides - removes top cut line
              ),
              if (isPlaying)
                BoxShadow(
                  color: const Color(0xFFFFC107).withValues(alpha: 0.10),
                  blurRadius: 70,
                  spreadRadius: 8,
                  offset: Offset.zero,
                ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: book.hasValidCover
                ? CachedNetworkImage(
                    imageUrl: book.coverUrl,
                    fit: BoxFit.cover,
                    errorWidget: (_, _, _) => BookJacketCover(book: book, isLarge: true),
                  )
                : BookJacketCover(book: book, isLarge: true),
          ),
        ),
      ),
    );
  }

  Widget _buildBookInfo(
    Audiobook book,
    AudiobookChapter? chapter,
    int currentChNum,
    int totalChapters,
  ) {
    return Column(
      children: [
        Text(
          chapter?.title ?? book.title,
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.dmSans(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: AuraColors.cream,
            height: 1.2,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          '${book.title} • ${book.authorName}',
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.dmSans(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: AuraColors.creamMuted,
          ),
        ),
      ],
    );
  }

  Widget _buildWaveform(AudioProvider audio) {
    final isPlaying = audio.isPlaying;
    final speedFactor = audio.speed.clamp(0.5, 2.5);

    return SizedBox(
      height: 48,
      child: AnimatedBuilder(
        animation: _pulseCtrl,
        builder: (context, child) {
          final phase = _pulseCtrl.value * 2 * math.pi * speedFactor;

          return Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: List.generate(32, (i) {
              final progressFraction = i / 32.0;
              final isActive = progressFraction <= audio.progress;

              // Playhead acoustic energy sync
              final distFromPlayhead = (progressFraction - audio.progress).abs();
              final playheadEnergy = math.exp(-distFromPlayhead * 5.0);

              // Ultra-smooth continuous multi-harmonic ribbon
              final w1 = math.sin(phase + (i * 0.32));
              final w2 = math.cos((phase * 1.4) + (i * 0.18));
              final w3 = math.sin((phase * 0.7) + (i * 0.45));
              final wave = (w1 * 0.5 + w2 * 0.35 + w3 * 0.15);

              final dynamicHeight = isPlaying
                  ? (12.0 + (wave * 14.0) + (playheadEnergy * 14.0) + (math.sin(i * 0.45) * 4.0)).abs().clamp(6.0, 44.0)
                  : (8.0 + (math.sin(i * 0.35) * 5.0)).abs().clamp(4.0, 20.0);

              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 1.8),
                width: 3.5,
                height: dynamicHeight,
                decoration: BoxDecoration(
                  gradient: isActive
                      ? const LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Color(0xFFFFC107), // Golden Amber
                            AuraColors.primaryDark, // Warm Tangerine
                          ],
                        )
                      : null,
                  color: isActive ? null : Colors.white.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(3),
                  boxShadow: isActive && isPlaying
                      ? [
                          BoxShadow(
                            color: AuraColors.primaryDark.withValues(alpha: 0.35 + (playheadEnergy * 0.25)),
                            blurRadius: 5 + (playheadEnergy * 3),
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
    final pos = audio.position;
    final dur = audio.duration;
    final remaining = dur > pos ? dur - pos : Duration.zero;

    return Column(
      children: [
        SliderTheme(
          data: SliderThemeData(
            trackHeight: 4,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
            activeTrackColor: AuraColors.primaryDark,
            inactiveTrackColor: Colors.white24,
            thumbColor: Colors.white,
            overlayColor: AuraColors.primaryDark.withValues(alpha: 0.2),
          ),
          child: Slider(
            value: audio.progress,
            onChanged: (val) {
              final newPos = Duration(milliseconds: (val * dur.inMilliseconds).round());
              audio.seekTo(newPos);
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _formatDuration(pos),
                style: GoogleFonts.dmSans(fontSize: 11, color: Colors.white60),
              ),
              Text(
                '-${_formatDuration(remaining)} left in chapter',
                style: GoogleFonts.dmSans(fontSize: 11, color: Colors.white60),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPlaybackControls(
    AudioProvider audio,
    AudiobookProvider bookProv,
    Audiobook book,
    int currentChapterIdx,
  ) {
    final hasPrev = currentChapterIdx > 0;
    final hasNext = currentChapterIdx < book.chapters.length - 1;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        // Skip Chapter Back
        IconButton(
          icon: Icon(
            Icons.skip_previous,
            color: hasPrev ? Colors.white : Colors.white30,
            size: 28,
          ),
          onPressed: hasPrev
              ? () => bookProv.playChapter(book, currentChapterIdx - 1, context)
              : null,
          tooltip: 'Previous Chapter',
        ),
        // Rewind 10s
        IconButton(
          icon: const Icon(Icons.replay_10, color: Colors.white, size: 30),
          onPressed: audio.skipBackward,
          tooltip: 'Rewind 10s',
        ),
        // Play / Pause FAB
        Container(
          width: 68,
          height: 68,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AuraColors.primaryDark,
            boxShadow: [
              BoxShadow(
                color: AuraColors.primaryDark.withValues(alpha: 0.4),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: IconButton(
            icon: Icon(
              audio.isPlaying ? Icons.pause : Icons.play_arrow,
              color: Colors.white,
              size: 36,
            ),
            onPressed: () {
              if (audio.isPlaying) {
                audio.pause();
              } else {
                audio.resume();
              }
            },
          ),
        ),
        // Forward 30s
        IconButton(
          icon: const Icon(Icons.forward_30, color: Colors.white, size: 30),
          onPressed: audio.skipForward,
          tooltip: 'Forward 30s',
        ),
        // Skip Chapter Next
        IconButton(
          icon: Icon(
            Icons.skip_next,
            color: hasNext ? Colors.white : Colors.white30,
            size: 28,
          ),
          onPressed: hasNext
              ? () => bookProv.playChapter(book, currentChapterIdx + 1, context)
              : null,
          tooltip: 'Next Chapter',
        ),
      ],
    );
  }

  Widget _buildAudiobookUtilities(
    BuildContext context,
    AudioProvider audio,
    AudiobookProvider bookProv,
    Audiobook book,
    AudiobookChapter? chapter,
  ) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        // Speed Selector (0.75x to 2.5x)
        GestureDetector(
          onTap: () => _showSpeedDialog(context, audio),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: AuraColors.surfaceDark,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white12),
            ),
            child: Row(
              children: [
                const Icon(Icons.speed, color: Colors.white70, size: 16),
                const SizedBox(width: 6),
                Text(
                  '${audio.speed}x',
                  style: GoogleFonts.dmSans(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ),

        // End-of-Chapter Sleep Timer
        GestureDetector(
          onTap: () => _showSleepTimerDialog(context, audio),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: AuraColors.surfaceDark,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white12),
            ),
            child: Row(
              children: [
                const Icon(Icons.bedtime_outlined, color: Colors.white70, size: 16),
                const SizedBox(width: 6),
                Text(
                  'Sleep Timer',
                  style: GoogleFonts.dmSans(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ),

        // Bookmark Quote
        GestureDetector(
          onTap: () => _showBookmarkDialog(context, audio, bookProv, book, chapter),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: AuraColors.surfaceDark,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white12),
            ),
            child: Row(
              children: [
                const Icon(Icons.format_quote, color: Colors.white70, size: 16),
                const SizedBox(width: 6),
                Text(
                  'Quote',
                  style: GoogleFonts.dmSans(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ─── Chapter Drawer (Modal Bottom Sheet) ─────────────────────────────────

  void _showChapterDrawer(BuildContext context, Audiobook book, int currentChapterIdx) {
    final bookProv = context.read<AudiobookProvider>();
    showModalBottomSheet(
      context: context,
      backgroundColor: AuraColors.darkBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Table of Contents',
                style: GoogleFonts.dmSans(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${book.chapters.length} Chapters • ${book.title}',
                style: GoogleFonts.dmSans(
                  fontSize: 12,
                  color: Colors.white60,
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: ListView.builder(
                  itemCount: book.chapters.length,
                  itemBuilder: (context, index) {
                    final ch = book.chapters[index];
                    final isCurrent = currentChapterIdx == index;
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      onTap: () {
                        Navigator.of(ctx).pop();
                        bookProv.playChapter(book, index, context);
                      },
                      leading: Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isCurrent ? AuraColors.primaryDark : Colors.white12,
                        ),
                        child: Center(
                          child: Text(
                            '${ch.order}',
                            style: GoogleFonts.dmSans(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: isCurrent ? Colors.white : Colors.white70,
                            ),
                          ),
                        ),
                      ),
                      title: Text(
                        ch.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.dmSans(
                          fontSize: 14,
                          fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                          color: isCurrent ? AuraColors.primaryDark : Colors.white,
                        ),
                      ),
                      trailing: Text(
                        ch.durationFormatted,
                        style: GoogleFonts.dmSans(fontSize: 12, color: Colors.white54),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ─── Speed Dialog ────────────────────────────────────────────────────────

  void _showSpeedDialog(BuildContext context, AudioProvider audio) {
    const speeds = [0.75, 1.0, 1.25, 1.5, 1.75, 2.0, 2.5];
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: AuraColors.card(context),
          title: Text(
            'Narration Speed',
            style: GoogleFonts.dmSans(fontWeight: FontWeight.bold, color: AuraColors.text(context)),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: speeds.map((s) {
              final isSelected = audio.speed == s;
              return ListTile(
                title: Text(
                  '${s}x',
                  style: GoogleFonts.dmSans(
                    color: isSelected ? AuraColors.primary(context) : AuraColors.text(context),
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
                trailing: isSelected ? Icon(Icons.check, color: AuraColors.primary(context)) : null,
                onTap: () {
                  audio.setSpeed(s);
                  Navigator.of(ctx).pop();
                },
              );
            }).toList(),
          ),
        );
      },
    );
  }

  // ─── Sleep Timer Dialog ──────────────────────────────────────────────────

  void _showSleepTimerDialog(BuildContext context, AudioProvider audio) {
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: AuraColors.card(context),
          title: Text(
            'Sleep Timer',
            style: GoogleFonts.dmSans(fontWeight: FontWeight.bold, color: AuraColors.text(context)),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.timer_10),
                title: const Text('15 minutes'),
                onTap: () {
                  audio.setSleepTimer(const Duration(minutes: 15));
                  Navigator.of(ctx).pop();
                },
              ),
              ListTile(
                leading: const Icon(Icons.timer_3),
                title: const Text('30 minutes'),
                onTap: () {
                  audio.setSleepTimer(const Duration(minutes: 30));
                  Navigator.of(ctx).pop();
                },
              ),
              ListTile(
                leading: const Icon(Icons.timer_outlined),
                title: const Text('45 minutes'),
                onTap: () {
                  audio.setSleepTimer(const Duration(minutes: 45));
                  Navigator.of(ctx).pop();
                },
              ),
              ListTile(
                leading: const Icon(Icons.bookmark_outline),
                title: const Text('End of current chapter'),
                onTap: () {
                  final remainingSecs = (audio.duration - audio.position).inSeconds;
                  audio.setSleepTimer(
                    Duration(seconds: remainingSecs > 0 ? remainingSecs : 10),
                  );
                  Navigator.of(ctx).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Audio will pause at end of this chapter')),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  // ─── Quote Bookmark Dialog ───────────────────────────────────────────────

  void _showBookmarkDialog(
    BuildContext context,
    AudioProvider audio,
    AudiobookProvider bookProv,
    Audiobook book,
    AudiobookChapter? chapter,
  ) {
    final noteCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: AuraColors.card(context),
          title: Text(
            'Save Passage / Quote',
            style: GoogleFonts.dmSans(fontWeight: FontWeight.bold, color: AuraColors.text(context)),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Bookmark at ${_formatDuration(audio.position)} in "${chapter?.title ?? 'Chapter'}"',
                style: GoogleFonts.dmSans(fontSize: 12, color: AuraColors.subtext(context)),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: noteCtrl,
                maxLines: 3,
                style: GoogleFonts.dmSans(color: AuraColors.text(context), fontSize: 13),
                decoration: InputDecoration(
                  hintText: 'Enter your note or the memorable quote...',
                  hintStyle: GoogleFonts.dmSans(color: AuraColors.subtext(context), fontSize: 13),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: AuraColors.border(context)),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                bookProv.addBookmark(
                  book: book,
                  chapterIndex: bookProv.activeChapterIndex,
                  chapterTitle: chapter?.title ?? 'Chapter',
                  timestampMs: audio.position.inMilliseconds,
                  note: noteCtrl.text.trim(),
                );
                Navigator.of(ctx).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Passage saved to your Bookshelf!')),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AuraColors.primary(context),
                foregroundColor: Colors.white,
              ),
              child: const Text('Save Quote'),
            ),
          ],
        );
      },
    );
  }

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    if (d.inHours > 0) {
      return '${d.inHours}:$minutes:$seconds';
    }
    return '$minutes:$seconds';
  }
}
