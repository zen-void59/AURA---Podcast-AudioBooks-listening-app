import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:aura/core/theme.dart';
import 'package:aura/core/routes.dart';
import 'package:aura/models/audiobook.dart';
import 'package:aura/providers/audiobook_provider.dart';
import 'package:aura/providers/audio_provider.dart';
import 'package:aura/widgets/book_jacket_cover.dart';

class AudiobookDetailScreen extends StatefulWidget {
  final Audiobook book;
  const AudiobookDetailScreen({super.key, required this.book});

  @override
  State<AudiobookDetailScreen> createState() => _AudiobookDetailScreenState();
}

class _AudiobookDetailScreenState extends State<AudiobookDetailScreen> {
  bool _isDescriptionExpanded = false;
  late Audiobook _currentBook;

  @override
  void initState() {
    super.initState();
    _currentBook = widget.book;
    // Load full chapters if not already populated
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AudiobookProvider>().loadBookDetails(widget.book).then((fullBook) {
        if (mounted) {
          setState(() {
            _currentBook = fullBook;
          });
        }
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final bookProv = context.watch<AudiobookProvider>();
    final audioProv = context.watch<AudioProvider>();
    final progress = bookProv.getProgress(_currentBook.id);
    final isSaved = bookProv.isBookSaved(_currentBook.id);
    final pct = progress != null ? progress.calculatePercentage(_currentBook) : 0.0;
    final currentChIdx = progress?.currentChapterIndex ?? 0;

    return Scaffold(
      backgroundColor: AuraColors.bg(context),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new, color: AuraColors.text(context), size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          IconButton(
            icon: Icon(
              isSaved ? Icons.bookmark : Icons.bookmark_border,
              color: isSaved ? AuraColors.primary(context) : AuraColors.text(context),
            ),
            onPressed: () => bookProv.toggleSaveBook(_currentBook),
            tooltip: isSaved ? 'Remove from Bookshelf' : 'Save to Bookshelf',
          ),
          IconButton(
            icon: Icon(Icons.share_outlined, color: AuraColors.text(context)),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Sharing "${_currentBook.title}"'),
                  duration: const Duration(seconds: 2),
                ),
              );
            },
          ),
        ],
      ),
      body: CustomScrollView(
        slivers: [
          // 1. Book Header & Cover Art
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              child: Column(
                children: [
                  // High-res Cover Art with soft drop shadow
                  Container(
                    width: 170,
                    height: 240,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.22),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(18),
                      child: _currentBook.hasValidCover
                          ? CachedNetworkImage(
                              imageUrl: _currentBook.coverUrl,
                              fit: BoxFit.cover,
                              errorWidget: (_, _, _) => BookJacketCover(
                                book: _currentBook,
                                isLarge: true,
                              ),
                            )
                          : BookJacketCover(
                              book: _currentBook,
                              isLarge: true,
                            ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  // Title
                  Text(
                    _currentBook.title,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.dmSans(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: AuraColors.text(context),
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 6),
                  // Author & Narrator
                  Text(
                    'by ${_currentBook.authorName}',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.dmSans(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AuraColors.primary(context),
                    ),
                  ),
                  if (_currentBook.narrators.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      'Narrated by ${_currentBook.narrators.join(", ")}',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.dmSans(
                        fontSize: 12,
                        color: AuraColors.subtext(context),
                      ),
                    ),
                  ],
                  const SizedBox(height: 14),

                  // Metadata Pills
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _buildPill(
                        context,
                        icon: Icons.access_time,
                        label: _currentBook.durationFormatted,
                      ),
                      _buildPill(
                        context,
                        icon: Icons.format_list_numbered,
                        label: '${_currentBook.chapters.length} Chapters',
                      ),
                      _buildPill(
                        context,
                        icon: Icons.language,
                        label: _currentBook.language.toUpperCase(),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: AuraColors.primary(context).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          _currentBook.sourceBadge,
                          style: GoogleFonts.dmSans(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: AuraColors.primary(context),
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  // Primary CTA Play/Resume Button
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        if (progress != null && progress.positionMs > 0) {
                          bookProv.resumeBook(_currentBook, context);
                        } else {
                          bookProv.playChapter(_currentBook, 0, context);
                        }
                        Navigator.of(context).pushNamed(AppRoutes.audiobookPlayer, arguments: _currentBook);
                      },
                      icon: Icon(
                        (progress != null && progress.positionMs > 0)
                            ? Icons.play_arrow
                            : Icons.headphones,
                        color: Colors.white,
                      ),
                      label: Text(
                        (progress != null && progress.positionMs > 0)
                            ? 'Resume Chapter ${currentChIdx + 1} (${(pct * 100).toInt()}%)'
                            : 'Start Listening (Chapter 1)',
                        style: GoogleFonts.dmSans(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AuraColors.primary(context),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        elevation: 0,
                      ),
                    ),
                  ),

                  if (pct > 0) ...[
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: pct,
                        minHeight: 4,
                        backgroundColor: AuraColors.border(context),
                        valueColor: AlwaysStoppedAnimation<Color>(AuraColors.primary(context)),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),

          // 2. Synopsis / Description
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'About this Book',
                    style: GoogleFonts.dmSans(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: AuraColors.text(context),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _currentBook.description,
                    maxLines: _isDescriptionExpanded ? 100 : 4,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.dmSans(
                      fontSize: 13,
                      height: 1.5,
                      color: AuraColors.subtext(context),
                    ),
                  ),
                  if (_currentBook.description.length > 180)
                    GestureDetector(
                      onTap: () => setState(() => _isDescriptionExpanded = !_isDescriptionExpanded),
                      child: Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          _isDescriptionExpanded ? 'Read Less' : 'Read More',
                          style: GoogleFonts.dmSans(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: AuraColors.primary(context),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),

          // 3. Table of Contents / Chapter List Header
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Chapters (${_currentBook.chapters.length})',
                    style: GoogleFonts.dmSans(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: AuraColors.text(context),
                    ),
                  ),
                  if (bookProv.isLoadingDetails)
                    const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                ],
              ),
            ),
          ),

          // 4. Chapter List Tiles
          if (_currentBook.chapters.isEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Center(
                  child: bookProv.isLoadingDetails
                      ? const CircularProgressIndicator()
                      : Text(
                          'No chapters available.',
                          style: GoogleFonts.dmSans(color: AuraColors.subtext(context)),
                        ),
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final chapter = _currentBook.chapters[index];
                    final isCurrentChapter =
                        audioProv.currentEpisode?.id == 'ab_${_currentBook.id}_ch_${chapter.order}';
                    final isPlaying = isCurrentChapter && audioProv.isPlaying;

                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      decoration: BoxDecoration(
                        color: isCurrentChapter
                            ? AuraColors.primary(context).withValues(alpha: 0.08)
                            : AuraColors.card(context),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: isCurrentChapter
                              ? AuraColors.primary(context).withValues(alpha: 0.4)
                              : AuraColors.border(context),
                        ),
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: ListTile(
                          onTap: () {
                            bookProv.playChapter(_currentBook, index, context);
                            Navigator.of(context).pushNamed(AppRoutes.audiobookPlayer, arguments: _currentBook);
                          },
                          leading: Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: isCurrentChapter
                                  ? AuraColors.primary(context)
                                  : AuraColors.border(context).withValues(alpha: 0.5),
                            ),
                            child: Center(
                              child: isPlaying
                                  ? const Icon(Icons.volume_up, color: Colors.white, size: 18)
                                  : Text(
                                      '${chapter.order}',
                                      style: GoogleFonts.dmSans(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: isCurrentChapter
                                            ? Colors.white
                                            : AuraColors.text(context),
                                      ),
                                    ),
                            ),
                          ),
                          title: Text(
                            chapter.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.dmSans(
                              fontSize: 14,
                              fontWeight: isCurrentChapter ? FontWeight.bold : FontWeight.w600,
                              color: isCurrentChapter
                                  ? AuraColors.primary(context)
                                  : AuraColors.text(context),
                            ),
                          ),
                          subtitle: Text(
                            chapter.durationFormatted,
                            style: GoogleFonts.dmSans(
                              fontSize: 11,
                              color: AuraColors.subtext(context),
                            ),
                          ),
                          trailing: IconButton(
                            icon: Icon(
                              isPlaying ? Icons.pause_circle_filled : Icons.play_circle_fill,
                              color: isCurrentChapter
                                  ? AuraColors.primary(context)
                                  : AuraColors.subtext(context),
                              size: 28,
                            ),
                            onPressed: () {
                              if (isPlaying) {
                                audioProv.pause();
                              } else {
                                bookProv.playChapter(_currentBook, index, context);
                              }
                            },
                          ),
                        ),
                      ),
                    );
                  },
                  childCount: _currentBook.chapters.length,
                ),
              ),
            ),

          const SliverToBoxAdapter(
            child: SizedBox(height: 100),
          ),
        ],
      ),
    );
  }

  Widget _buildPill(BuildContext context, {required IconData icon, required String label}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: AuraColors.card(context),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AuraColors.border(context)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: AuraColors.subtext(context)),
          const SizedBox(width: 4),
          Text(
            label,
            style: GoogleFonts.dmSans(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: AuraColors.text(context),
            ),
          ),
        ],
      ),
    );
  }
}
