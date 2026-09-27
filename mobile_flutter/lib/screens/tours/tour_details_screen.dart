import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../app_constants.dart';
import '../../services/api_service.dart';
import '../../widgets/common_widgets.dart';

/// Tour details screen matching Figma frame 06 · Tour Details (node 7:10595)
class TourDetailsScreen extends StatefulWidget {
  const TourDetailsScreen({super.key});

  @override
  State<TourDetailsScreen> createState() => _TourDetailsScreenState();
}

class _TourDetailsScreenState extends State<TourDetailsScreen> {
  Map<String, dynamic>? _tour;
  bool _loading = true;
  String? _error;
  bool _isFavorite = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final tourId = ModalRoute.of(context)?.settings.arguments as int?;
    if (tourId != null && _tour == null) {
      _loadTour(tourId);
    }
  }

  /// Fetch tour details from backend
  Future<void> _loadTour(int id) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await ApiService.getTour(id);
      if (mounted) {
        setState(() {
          _tour = data;
          if (_tour == null) _error = 'Tour details not found';
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Failed to load tour details';
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: AppColors.figmaSurface,
        body: Center(
          child: CircularProgressIndicator(color: AppColors.figmaDarkGreen),
        ),
      );
    }

    if (_error != null || _tour == null) {
      return Scaffold(
        backgroundColor: AppColors.figmaSurface,
        appBar: AppBar(
          backgroundColor: AppColors.figmaSurface,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: AppColors.figmaDarkGreen),
            onPressed: () => Navigator.pop(context),
          ),
          title: Text(
            'Tour Details',
            style: GoogleFonts.plusJakartaSans(
              color: AppColors.figmaDarkGreen,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        body: ErrorMessage(
          message: _error ?? 'Tour not found',
          onRetry: () {
            final tourId = ModalRoute.of(context)?.settings.arguments as int?;
            if (tourId != null) _loadTour(tourId);
          },
        ),
      );
    }

    final tourName = _tour!['name'] ?? 'Sigiriya Sunrise & Village Life';
    final uploadedImage = ApiService.resolveMediaUrl(
      _tour!['imageUrl']?.toString(),
    );
    final imageUrl = uploadedImage.isNotEmpty
        ? uploadedImage
        : AppDestinations.getImageForDestination(tourName);
    final price = (_tour!['price'] ?? 68).toDouble();
    final duration = _tour!['durationHours'] ?? 8;
    final location = _tour!['location'] ?? 'Sigiriya, Matale';
    final category = (_tour!['category'] ?? 'Culture · Adventure').toString();
    final description = _tour!['description'] ??
        'Climb the ancient rock fortress before the crowds, then share a garden breakfast and traditional lunch with a nearby village family.';

    final highlights = [
      'Early-access fortress climb',
      'Local naturalist guide',
      'Village cycle & home-cooked lunch',
    ];

    return Scaffold(
      backgroundColor: AppColors.figmaSurface,
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Hero Image with Back, Wishlist & Category Badge ──
            Stack(
              children: [
                SizedBox(
                  height: 320,
                  width: double.infinity,
                  child: Image.network(
                    imageUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Container(
                      color: const Color(0xFF374151),
                      alignment: Alignment.center,
                      child: const Icon(
                        Icons.landscape,
                        color: Colors.white54,
                        size: 64,
                      ),
                    ),
                  ),
                ),
                // Top gradient for button visibility
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  height: 100,
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withValues(alpha: 0.45),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ),
                // Top Action Buttons
                Positioned(
                  top: MediaQuery.of(context).padding.top + 8,
                  left: 16,
                  right: 16,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Back Button
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: Container(
                          width: 44,
                          height: 44,
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.arrow_back,
                            color: AppColors.figmaDarkGreen,
                            size: 20,
                          ),
                        ),
                      ),
                      // Wishlist Heart Button
                      GestureDetector(
                        onTap: () {
                          setState(() {
                            _isFavorite = !_isFavorite;
                          });
                        },
                        child: Container(
                          width: 44,
                          height: 44,
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            _isFavorite
                                ? Icons.favorite
                                : Icons.favorite_border,
                            color: _isFavorite
                                ? Colors.red
                                : AppColors.figmaDarkGreen,
                            size: 20,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                // Category Pill on Image Bottom
                Positioned(
                  left: 16,
                  bottom: 16,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.figmaGold,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      category.toUpperCase(),
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: Colors.black,
                        letterSpacing: 0.4,
                      ),
                    ),
                  ),
                ),
              ],
            ),

            // ── Main Content Body ──
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title & Rating
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          tourName,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: AppColors.figmaDarkGreen,
                            height: 1.25,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Row(
                        children: [
                          const Icon(
                            Icons.star_rounded,
                            color: AppColors.figmaGold,
                            size: 20,
                          ),
                          const SizedBox(width: 2),
                          Text(
                            '4.9',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: AppColors.figmaDarkGreen,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${_tour!['reviewCount'] ?? 326} verified reviews · $location',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 13,
                      color: const Color(0xFF6B7280),
                      fontWeight: FontWeight.w500,
                    ),
                  ),

                  const SizedBox(height: 18),

                  // ── 3-Column Quick Stats Card ──
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.figmaCardBorder),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: _buildStatColumn(
                            icon: Icons.access_time,
                            value: '$duration hours',
                            label: 'Duration',
                          ),
                        ),
                        Container(
                          width: 1,
                          height: 36,
                          color: AppColors.figmaCardBorder,
                        ),
                        Expanded(
                          child: _buildStatColumn(
                            icon: Icons.people_outline,
                            value: 'Max ${_tour!['maxGroupSize'] ?? 8}',
                            label: 'Group',
                          ),
                        ),
                        Container(
                          width: 1,
                          height: 36,
                          color: AppColors.figmaCardBorder,
                        ),
                        Expanded(
                          child: _buildStatColumn(
                            icon: Icons.terrain_outlined,
                            value: _tour!['difficulty'] ?? 'Moderate',
                            label: 'Difficulty',
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // ── About Section ──
                  Text(
                    'About this experience',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: AppColors.figmaDarkGreen,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    description,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 13,
                      color: const Color(0xFF6B7280),
                      height: 1.5,
                    ),
                  ),

                  const SizedBox(height: 24),

                  // ── Highlights Section ──
                  Text(
                    'Highlights',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: AppColors.figmaDarkGreen,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ...highlights.map(
                    (h) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.check_circle_outline,
                            color: AppColors.figmaDarkGreen,
                            size: 20,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              h,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: AppColors.figmaDarkGreen,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),

      // ── Sticky Bottom Reservation Bar ──
      bottomNavigationBar: Container(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        decoration: BoxDecoration(
          color: AppColors.figmaSurface,
          border: const Border(top: BorderSide(color: AppColors.figmaCardBorder)),
        ),
        child: Row(
          children: [
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'per traveler',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11,
                    color: const Color(0xFF6B7280),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  '\$${price.toStringAsFixed(0)}',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: AppColors.figmaDarkGreen,
                  ),
                ),
              ],
            ),
            const SizedBox(width: 18),
            // Book This Tour Button
            Expanded(
              child: SizedBox(
                height: 52,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pushNamed(
                      context,
                      '/trip-request',
                      arguments: _tour,
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.figmaDarkGreen,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(26),
                    ),
                    elevation: 0,
                  ),
                  child: Text(
                    'Book This Tour',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            // Add to Itinerary Button
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: AppColors.figmaDarkGreen,
                      width: 1.5,
                    ),
                  ),
                  child: IconButton(
                    icon: const Icon(
                      Icons.calendar_month_outlined,
                      color: AppColors.figmaDarkGreen,
                      size: 22,
                    ),
                    onPressed: () {
                      Navigator.pushNamed(context, '/itinerary');
                    },
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Add to Itinerary',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 9,
                    color: const Color(0xFF6B7280),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatColumn({
    required IconData icon,
    required String value,
    required String label,
  }) {
    return Column(
      children: [
        Icon(icon, color: AppColors.figmaDarkGreen, size: 22),
        const SizedBox(height: 6),
        Text(
          value,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 13,
            fontWeight: FontWeight.w800,
            color: AppColors.figmaDarkGreen,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 11,
            color: const Color(0xFF6B7280),
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
