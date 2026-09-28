import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:aura/models/audiobook.dart';

/// A stylized luxury hardcover book jacket rendered when cover images are missing,
/// loading, or offline. Ensures an authentic, premium aesthetic is always visible.
class BookJacketCover extends StatelessWidget {
  final Audiobook book;
  final bool isLarge;

  const BookJacketCover({
    super.key,
    required this.book,
    this.isLarge = false,
  });

  static const List<List<Color>> _palette = [
    [Color(0xFF0F1E36), Color(0xFF070E1A)], // Midnight Royal Navy
    [Color(0xFF38101C), Color(0xFF1C060D)], // Vintage Bordeaux Leather
    [Color(0xFF0F2B20), Color(0xFF06140E)], // Antique Emerald
    [Color(0xFF3B2314), Color(0xFF1A0E07)], // Saddle Mahogany
    [Color(0xFF2B1238), Color(0xFF13071A)], // Imperial Damson
    [Color(0xFF1C252E), Color(0xFF0C1014)], // Obsidian Charcoal
  ];

  @override
  Widget build(BuildContext context) {
    final colorPair = _palette[book.title.hashCode.abs() % _palette.length];

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: colorPair,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Stack(
        children: [
          // Left Book Spine shadow
          Positioned(
            left: 0,
            top: 0,
            bottom: 0,
            width: isLarge ? 14 : 8,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.black.withValues(alpha: 0.65),
                    Colors.black.withValues(alpha: 0.15),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          // Inner spine highlight crease
          Positioned(
            left: isLarge ? 14 : 8,
            top: 0,
            bottom: 0,
            width: 1,
            child: Container(
              color: Colors.white.withValues(alpha: 0.08),
            ),
          ),
          // Luxury Gold-Tooled Inner Border
          Positioned.fill(
            left: isLarge ? 16 : 9,
            top: isLarge ? 8 : 5,
            right: isLarge ? 8 : 5,
            bottom: isLarge ? 8 : 5,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(isLarge ? 8 : 5),
                border: Border.all(
                  color: const Color(0xFFD4AF37).withValues(alpha: 0.22), // Soft gold foil
                  width: 0.8,
                ),
              ),
            ),
          ),
          // Book Jacket Content
          Padding(
            padding: EdgeInsets.fromLTRB(
              isLarge ? 24 : 14,
              isLarge ? 18 : 10,
              isLarge ? 16 : 10,
              isLarge ? 16 : 10,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Top header: Audiobook Indicator Pill
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: isLarge ? 8 : 5, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.08),
                          width: 0.5,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.headphones, size: isLarge ? 12 : 8, color: const Color(0xFFE5C07B)),
                          const SizedBox(width: 4),
                          Text(
                            'AUDIOBOOK',
                            style: GoogleFonts.dmSans(
                              fontSize: isLarge ? 9 : 6.5,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.9,
                              color: const Color(0xFFE5C07B),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                // Center: Book Title & Golden Rule
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: isLarge ? 36 : 20,
                        height: 2,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFFF3E5AB), Color(0xFFD4AF37)],
                          ),
                          borderRadius: BorderRadius.circular(1),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        book.title,
                        maxLines: isLarge ? 4 : 3,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.dmSans(
                          fontSize: isLarge ? 18 : 11,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          height: 1.2,
                          letterSpacing: -0.2,
                        ),
                      ),
                    ],
                  ),
                ),

                // Bottom: Author Name
                Text(
                  book.authorName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.dmSans(
                    fontSize: isLarge ? 12 : 8.5,
                    fontWeight: FontWeight.w600,
                    color: Colors.white.withValues(alpha: 0.75),
                    letterSpacing: 0.3,
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
