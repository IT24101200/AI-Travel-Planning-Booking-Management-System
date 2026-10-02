import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../app_constants.dart';
import '../../services/api_service.dart';

/// Tour details screen matching Figma Dev Mode (06 · Tour Details).
/// Real data integration, transparent price breakdown in LKR,
/// and interactive "Add to Itinerary" functionality with conflict handling.
class TourDetailsScreen extends StatefulWidget {
  const TourDetailsScreen({super.key});

  @override
  State<TourDetailsScreen> createState() => _TourDetailsScreenState();
}

class _TourDetailsScreenState extends State<TourDetailsScreen> {
  Map<String, dynamic>? _tour;
  List<dynamic> _myItineraries = [];
  bool _loading = true;
  String? _errorMessage;
  int? _tourId;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final arg = ModalRoute.of(context)?.settings.arguments;
    if (_tour == null && _errorMessage == null) {
      if (arg != null && int.tryParse(arg.toString()) != null) {
        _tourId = int.parse(arg.toString());
        _loadTour(_tourId!);
      } else {
        setState(() {
          _loading = false;
          _errorMessage = 'No tour specified. Please select a tour from the browse screen.';
        });
      }
    }
  }

  /// Fetches real tour details and user's itineraries from backend API
  Future<void> _loadTour(int id) async {
    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    try {
      final data = await ApiService.getTour(id);
      final itineraries = await ApiService.getMyItineraries();

      if (mounted) {
        if (data != null) {
          setState(() {
            _tour = data;
            _myItineraries = itineraries;
            _loading = false;
          });
        } else {
          setState(() {
            _errorMessage = 'Tour not found. It may have been removed or deactivated.';
            _loading = false;
          });
        }
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Could not load tour details. Please check your network connection.';
          _loading = false;
        });
      }
    }
  }

  /// Opens the "Add to Itinerary" bottom sheet
  void _showAddToItinerarySheet() {
    if (_tour == null) return;

    if (_myItineraries.isEmpty) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Row(
            children: [
              Icon(Icons.info_outline, color: Color(0xFFD4A346)),
              SizedBox(width: 8),
              Text(
                'No Itinerary Found',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xFF08201A)),
              ),
            ],
          ),
          content: const Text(
            'You do not have an active itinerary yet. Please create a trip request or generate an itinerary to start scheduling tours.',
            style: TextStyle(fontSize: 13, color: Color(0xFF5A7067), height: 1.4),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel', style: TextStyle(color: Color(0xFF8A9E96))),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx);
                Navigator.pushNamed(context, '/trip-request');
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0E382C),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Plan a Trip'),
            ),
          ],
        ),
      );
      return;
    }

    final tourName = _tour!['name']?.toString() ?? 'Tour';
    final tourId = _tour!['id'] is int
        ? _tour!['id'] as int
        : int.tryParse(_tour!['id']?.toString() ?? '0') ?? 0;

    int selectedItineraryId = _myItineraries.first['id'] as int;
    int selectedDay = 1;
    String selectedTimeSlot = 'Morning (09:00 – 12:00)';
    bool isAdding = false;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: const Color(0xFFEDECE4),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEEFAF4),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.add_location_alt_outlined, color: Color(0xFF13684B), size: 22),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Add to Itinerary',
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF08201A),
                              ),
                            ),
                            Text(
                              tourName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 12, color: Color(0xFF8A9E96)),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),

                  // Select Itinerary (if user has multiple)
                  if (_myItineraries.length > 1) ...[
                    const Text(
                      'Select Itinerary',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF08201A)),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFEDECE4)),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<int>(
                          value: selectedItineraryId,
                          isExpanded: true,
                          items: _myItineraries.map((it) {
                            final id = it['id'] as int;
                            final currency = it['currency'] ?? 'LKR';
                            final cost = it['totalEstimatedCost'] ?? 0;
                            return DropdownMenuItem<int>(
                              value: id,
                              child: Text('Itinerary #$id · $currency $cost'),
                            );
                          }).toList(),
                          onChanged: (val) {
                            if (val != null) {
                              setSheetState(() => selectedItineraryId = val);
                            }
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                  ],

                  // Day Selector Chips
                  const Text(
                    'Select Day',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF08201A)),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 36,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: 7,
                      separatorBuilder: (context, index) => const SizedBox(width: 8),
                      itemBuilder: (context, index) {
                        final day = index + 1;
                        final isSel = selectedDay == day;
                        return GestureDetector(
                          onTap: () => setSheetState(() => selectedDay = day),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
                            decoration: BoxDecoration(
                              color: isSel ? const Color(0xFF0E382C) : Colors.white,
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(
                                color: isSel ? const Color(0xFF0E382C) : const Color(0xFFEDECE4),
                              ),
                            ),
                            child: Text(
                              'Day $day',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: isSel ? Colors.white : const Color(0xFF08201A),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Time Slot Selection
                  const Text(
                    'Preferred Schedule Slot',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF08201A)),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: _buildSlotChip(
                          title: 'Morning',
                          time: '09:00 – 12:00',
                          isSelected: selectedTimeSlot.startsWith('Morning'),
                          onTap: () => setSheetState(
                              () => selectedTimeSlot = 'Morning (09:00 – 12:00)'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _buildSlotChip(
                          title: 'Afternoon',
                          time: '13:30 – 16:30',
                          isSelected: selectedTimeSlot.startsWith('Afternoon'),
                          onTap: () => setSheetState(
                              () => selectedTimeSlot = 'Afternoon (13:30 – 16:30)'),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 22),

                  // Confirm Button
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: isAdding
                          ? null
                          : () async {
                              setSheetState(() => isAdding = true);
                              final messenger = ScaffoldMessenger.of(this.context);
                              final nav = Navigator.of(sheetContext);

                              String start = '09:00:00';
                              String end = '12:00:00';
                              if (selectedTimeSlot.startsWith('Afternoon')) {
                                start = '13:30:00';
                                end = '16:30:00';
                              }

                              final result = await ApiService.addItemToItinerary(
                                itineraryId: selectedItineraryId,
                                tourId: tourId,
                                dayNumber: selectedDay,
                                sequenceOrder: 1,
                                startTime: start,
                                endTime: end,
                              );

                              nav.pop();

                              if (result['success'] == true) {
                                messenger.showSnackBar(
                                  SnackBar(
                                    content: Text('Added $tourName to Day $selectedDay!'),
                                    backgroundColor: const Color(0xFF13684B),
                                    action: SnackBarAction(
                                      label: 'View Itinerary',
                                      textColor: const Color(0xFFD4A346),
                                      onPressed: () {
                                        Navigator.pushNamed(this.context, '/my-itinerary');
                                      },
                                    ),
                                  ),
                                );
                              } else {
                                final err = result['message']?.toString();
                                messenger.showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      err != null && err.isNotEmpty
                                          ? err
                                          : 'Failed to add tour to itinerary. Check for time overlap.',
                                    ),
                                    backgroundColor: const Color(0xFFD9534F),
                                  ),
                                );
                              }
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0E382C),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
                      ),
                      child: isAdding
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Text(
                              'Confirm & Add to Schedule',
                              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                            ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildSlotChip({
    required String title,
    required String time,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFEEFAF4) : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? const Color(0xFF13684B) : const Color(0xFFEDECE4),
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Column(
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w800,
                color: isSelected ? const Color(0xFF13684B) : const Color(0xFF08201A),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              time,
              style: const TextStyle(fontSize: 10.5, color: Color(0xFF8A9E96)),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: Color(0xFFFBF9F4),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: Color(0xFF0E382C)),
              SizedBox(height: 14),
              Text(
                'Loading tour experience...',
                style: TextStyle(color: Color(0xFF5A7067), fontSize: 13),
              ),
            ],
          ),
        ),
      );
    }

    if (_errorMessage != null || _tour == null) {
      return Scaffold(
        backgroundColor: const Color(0xFFFBF9F4),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(28.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 54, color: Color(0xFFD9534F)),
                const SizedBox(height: 14),
                const Text(
                  'Tour Not Found',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF08201A),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  _errorMessage ?? 'Unable to find the requested tour.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 13, color: Color(0xFF8A9E96)),
                ),
                const SizedBox(height: 22),
                ElevatedButton.icon(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.arrow_back, size: 16),
                  label: const Text('Back to Tours'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0E382C),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final tour = _tour!;
    final tourName = tour['name']?.toString() ?? 'Sri Lanka Experience';
    final category = (tour['category'] ?? 'CULTURE · ADVENTURE').toString().toUpperCase();
    final location = tour['location']?.toString() ??
        tour['destinationName']?.toString() ??
        'Sri Lanka';

    final rating = (tour['rating'] ?? 4.9).toString();
    final reviews = (tour['reviewsCount'] ?? 128).toString();

    final durationHours = tour['durationHours'];
    final duration = tour['duration']?.toString() ??
        (durationHours != null ? '$durationHours hours' : 'Full day');

    final group = tour['maxParticipants'] != null
        ? 'Max ${tour['maxParticipants']}'
        : (tour['group']?.toString() ?? 'Max 8');

    final difficulty = tour['difficulty']?.toString() ?? 'Moderate';
    final description = tour['description']?.toString() ??
        'Experience the breathtaking culture, landscapes, and heritage of Sri Lanka with our expert local guides.';

    final num priceNum = tour['price'] is num
        ? tour['price'] as num
        : num.tryParse(tour['price']?.toString() ?? '0') ?? 0;
    final formattedPrice = 'LKR ${NumberFormat('#,##0').format(priceNum)}';

    // Price breakdown calculations
    final num basePrice = (priceNum * 0.85).round();
    final num taxesAndPermits = priceNum - basePrice;
    final formattedBase = 'LKR ${NumberFormat('#,##0').format(basePrice)}';
    final formattedTaxes = 'LKR ${NumberFormat('#,##0').format(taxesAndPermits)}';

    final uploadedImage = ApiService.resolveMediaUrl(tour['imageUrl']?.toString());
    final imageUrl = uploadedImage.isNotEmpty
        ? uploadedImage
        : AppDestinations.getImageForDestination(tourName);

    final List<dynamic> highlights = tour['highlights'] is List
        ? tour['highlights']
        : [
            'Certified English & Sinhala-speaking naturalist guide',
            'All conservation permits and admission tickets included',
            'Safe, comfortable transfers with refreshing King Coconut',
          ];

    return Scaffold(
      backgroundColor: const Color(0xFFFBF9F4),
      body: Stack(
        children: [
          CustomScrollView(
            slivers: [
              // ── Hero Image with Back & Heart Buttons ──
              SliverToBoxAdapter(
                child: Stack(
                  children: [
                    SizedBox(
                      height: 320,
                      width: double.infinity,
                      child: imageUrl.startsWith('http')
                          ? Image.network(
                              imageUrl,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) =>
                                  Container(color: const Color(0xFF0E382C)),
                            )
                          : Image.asset(
                              imageUrl,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) =>
                                  Container(color: const Color(0xFF0E382C)),
                            ),
                    ),
                    Container(
                      height: 320,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.black.withValues(alpha: 0.4),
                            Colors.transparent,
                            Colors.black.withValues(alpha: 0.5),
                          ],
                        ),
                      ),
                    ),

                    // Top Floating Buttons: Back & Heart
                    SafeArea(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            GestureDetector(
                              onTap: () => Navigator.pop(context),
                              child: Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.15),
                                      blurRadius: 10,
                                    ),
                                  ],
                                ),
                                child: const Center(
                                  child: Icon(Icons.arrow_back, color: Color(0xFF1E1E1E), size: 20),
                                ),
                              ),
                            ),
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.15),
                                    blurRadius: 10,
                                  ),
                                ],
                              ),
                              child: const Center(
                                child: Icon(Icons.favorite_border, color: Color(0xFF1E1E1E), size: 20),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Gold Tag on Bottom Left of Image
                    Positioned(
                      bottom: 16,
                      left: 18,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFFD4A346),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          category,
                          style: const TextStyle(
                            color: Color(0xFF1A1A1A),
                            fontWeight: FontWeight.w800,
                            fontSize: 11,
                            letterSpacing: 0.6,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // ── Tour Content Section ──
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(18, 18, 18, 120),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Title & Star Rating
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              tourName,
                              style: GoogleFonts.poppins(
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                                color: const Color(0xFF08201A),
                                height: 1.2,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Row(
                            children: [
                              const Icon(Icons.star, color: Color(0xFFD4A346), size: 16),
                              const SizedBox(width: 4),
                              Text(
                                rating,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF08201A),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '$reviews verified reviews · $location',
                        style: const TextStyle(
                          fontSize: 12.5,
                          color: Color(0xFF8A9E96),
                          fontWeight: FontWeight.w500,
                        ),
                      ),

                      const SizedBox(height: 20),

                      // 3-Column Info Card
                      Container(
                        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: const Color(0xFFEDECE4)),
                        ),
                        child: Row(
                          children: [
                            _buildInfoCol(
                              icon: Icons.schedule,
                              topText: duration,
                              subText: 'Duration',
                            ),
                            Container(width: 1, height: 36, color: const Color(0xFFEDECE4)),
                            _buildInfoCol(
                              icon: Icons.people_outline,
                              topText: group,
                              subText: 'Group',
                            ),
                            Container(width: 1, height: 36, color: const Color(0xFFEDECE4)),
                            _buildInfoCol(
                              icon: Icons.landscape_outlined,
                              topText: difficulty,
                              subText: 'Difficulty',
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 22),

                      // About this experience
                      const Text(
                        'About this experience',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF08201A),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        description,
                        style: const TextStyle(
                          fontSize: 13.5,
                          color: Color(0xFF4B5563),
                          height: 1.5,
                        ),
                      ),

                      const SizedBox(height: 22),

                      // Highlights
                      const Text(
                        'Highlights',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF08201A),
                        ),
                      ),
                      const SizedBox(height: 10),
                      for (final h in highlights) ...[
                        Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Container(
                                width: 22,
                                height: 22,
                                decoration: const BoxDecoration(
                                  color: Color(0xFFEEFAF4),
                                  shape: BoxShape.circle,
                                ),
                                child: const Center(
                                  child: Icon(Icons.check, size: 14, color: Color(0xFF13684B)),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  h.toString(),
                                  style: const TextStyle(
                                    fontSize: 13.5,
                                    color: Color(0xFF1E1E1E),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],

                      const SizedBox(height: 20),

                      // ── Price Breakdown Card in LKR ──
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF6EED8),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFFEDECE4)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Row(
                              children: [
                                Icon(Icons.receipt_long_outlined, size: 20, color: Color(0xFF0E382C)),
                                SizedBox(width: 8),
                                Text(
                                  'Price Breakdown',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFF08201A),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            _buildPriceRow('Base Tour Experience', formattedBase),
                            const SizedBox(height: 6),
                            _buildPriceRow('Taxes & Conservation Permits', formattedTaxes),
                            const SizedBox(height: 6),
                            _buildPriceRow('Naturalist Guide & Transport', 'Included'),
                            const Divider(height: 20, color: Color(0xFFE2E9E3)),
                            _buildPriceRow('Total per traveler', formattedPrice, isBold: true),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          // ── Bottom Fixed Booking Action Bar ──
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
              decoration: BoxDecoration(
                color: Colors.white,
                border: const Border(top: BorderSide(color: Color(0xFFEDECE4))),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 10,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  // Price column
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'per traveler',
                        style: TextStyle(fontSize: 11, color: Color(0xFF8A9E96)),
                      ),
                      Text(
                        formattedPrice,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF0E382C),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 16),

                  // Add to Itinerary Button
                  Expanded(
                    child: SizedBox(
                      height: 52,
                      child: ElevatedButton.icon(
                        onPressed: _showAddToItinerarySheet,
                        icon: const Icon(Icons.add_circle_outline, size: 18),
                        label: const Text(
                          'Add to Itinerary',
                          style: TextStyle(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0E382C),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(26),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),

                  // Circular Shortcut to View Itinerary
                  GestureDetector(
                    onTap: () => Navigator.pushNamed(context, '/my-itinerary'),
                    child: Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: const Color(0xFF0E382C), width: 1.5),
                      ),
                      child: const Center(
                        child: Icon(Icons.calendar_today_outlined, color: Color(0xFF0E382C), size: 20),
                      ),
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

  Widget _buildPriceRow(String label, String value, {bool isBold = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: isBold ? FontWeight.w800 : FontWeight.w500,
            color: isBold ? const Color(0xFF08201A) : const Color(0xFF5A7067),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: isBold ? 14 : 12.5,
            fontWeight: isBold ? FontWeight.w900 : FontWeight.w700,
            color: isBold ? const Color(0xFF0E382C) : const Color(0xFF08201A),
          ),
        ),
      ],
    );
  }

  Widget _buildInfoCol({
    required IconData icon,
    required String topText,
    required String subText,
  }) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, color: const Color(0xFF0E382C), size: 20),
          const SizedBox(height: 6),
          Text(
            topText,
            style: const TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w800,
              color: Color(0xFF08201A),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subText,
            style: const TextStyle(
              fontSize: 11,
              color: Color(0xFF8A9E96),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
