import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../app_constants.dart';
import '../../services/api_service.dart';
import '../../widgets/common_widgets.dart';

/// My Itinerary screen matching Figma frame 07 · My Itinerary (node 7:10655)
class MyItineraryScreen extends StatefulWidget {
  const MyItineraryScreen({super.key});

  @override
  State<MyItineraryScreen> createState() => _MyItineraryScreenState();
}

class _MyItineraryScreenState extends State<MyItineraryScreen> {
  List<dynamic> _itineraries = [];
  Map<String, dynamic>? _selectedItinerary;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadItineraries();
  }

  /// Fetch customer itineraries from backend
  Future<void> _loadItineraries() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final list = await ApiService.getMyItineraries();
      if (mounted) {
        setState(() {
          _itineraries = list;
          if (_itineraries.isNotEmpty && _selectedItinerary == null) {
            _selectedItinerary = _itineraries.first;
          }
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Failed to load itineraries';
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

    if (_error != null && _itineraries.isEmpty) {
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
            'My Itinerary',
            style: GoogleFonts.plusJakartaSans(
              color: AppColors.figmaDarkGreen,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        body: ErrorMessage(
          message: _error!,
          onRetry: _loadItineraries,
        ),
      );
    }

    // Default sample stops if no items returned from backend
    final defaultStops = [
      {
        'day': 'DAY 1',
        'date': '12 OCT',
        'time': '08:00',
        'title': 'Sigiriya Rock Fortress',
        'description': 'Meet guide at hotel lobby · tickets included',
        'icon': Icons.account_balance_outlined,
      },
      {
        'day': 'DAY 2',
        'date': '13 OCT',
        'time': '09:30',
        'title': 'Kandy & Temple of the Tooth',
        'description': 'Scenic transfer via spice garden',
        'icon': Icons.location_city_outlined,
      },
      {
        'day': 'DAY 3',
        'date': '14 OCT',
        'time': '07:15',
        'title': 'Ella Tea Country Train',
        'description': 'Reserved observation seats · bring light jacket',
        'icon': Icons.train_outlined,
      },
    ];

    final backendItems = (_selectedItinerary?['items'] as List<dynamic>?) ?? [];
    final List<Map<String, dynamic>> displayStops = backendItems.isNotEmpty
        ? backendItems.map((item) {
            final dayNum = item['dayNumber'] ?? 1;
            return {
              'day': 'DAY $dayNum',
              'date': '${11 + dayNum} OCT',
              'time': item['time'] ?? '09:00',
              'title': item['title'] ?? item['activityName'] ?? 'Scenic Excursion',
              'description': item['description'] ?? 'Guided travel activity',
              'icon': Icons.place_outlined,
            };
          }).toList()
        : defaultStops;

    final durationDays = _selectedItinerary?['durationDays'] ?? 7;
    final totalCost = (_selectedItinerary?['totalEstimatedCost'] ?? 1846).toDouble();
    final routeText = _selectedItinerary?['routeSummary'] ??
        'Sigiriya → Kandy → Ella → Mirissa';

    return Scaffold(
      backgroundColor: AppColors.figmaSurface,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Header Bar ──
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Back button
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
                  // Title
                  Column(
                    children: [
                      Text(
                        'My Itinerary',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: AppColors.figmaDarkGreen,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Sri Lanka Discovery · 12–18 Oct',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          color: const Color(0xFF6B7280),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  // More options button
                  GestureDetector(
                    onTap: () {
                      _showOptionsBottomSheet();
                    },
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.more_horiz,
                        color: AppColors.figmaDarkGreen,
                        size: 20,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 18),

              // ── Deep Green Summary Banner ──
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.figmaDarkGreen,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    // Gold Days Badge
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: AppColors.figmaGold,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            '$durationDays',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: Colors.black,
                              height: 1.1,
                            ),
                          ),
                          Text(
                            'DAYS',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              color: Colors.black,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 14),
                    // Route & Travelers
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            routeText,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 3),
                          Text(
                            '2 travelers · 4 stops · AI optimized',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 11,
                              color: Colors.white.withValues(alpha: 0.75),
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Gold Sparkle Icon
                    const Icon(
                      Icons.auto_awesome,
                      color: AppColors.figmaGold,
                      size: 20,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // ── Route Map Preview Banner ──
              GestureDetector(
                onTap: () {
                  Navigator.pushNamed(
                    context,
                    '/trip-map',
                    arguments: _selectedItinerary,
                  );
                },
                child: Container(
                  height: 120,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.figmaCardBorder),
                    image: const DecorationImage(
                      image: NetworkImage(
                        'https://images.unsplash.com/photo-1524661135-423995f22d0b?w=900&auto=format&fit=crop&q=80',
                      ),
                      fit: BoxFit.cover,
                    ),
                  ),
                  child: Stack(
                    children: [
                      // White badge: VIEW FULL ROUTE
                      Positioned(
                        top: 12,
                        left: 12,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.08),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.alt_route,
                                size: 14,
                                color: AppColors.figmaDarkGreen,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'VIEW FULL ROUTE',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.figmaDarkGreen,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 22),

              // ── "Your journey" Section Header ──
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Your journey',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: AppColors.figmaDarkGreen,
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      Navigator.pushNamed(context, '/trip-request');
                    },
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: Text(
                      'Edit',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.figmaDarkGreen,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // ── Timeline List ──
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: displayStops.length,
                itemBuilder: (context, index) {
                  final stop = displayStops[index];
                  final isFirst = index == 0;
                  final isLast = index == displayStops.length - 1;

                  return IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Left Timeline Column
                        SizedBox(
                          width: 58,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                stop['day'] as String,
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.figmaDarkGreen,
                                ),
                              ),
                              Text(
                                stop['date'] as String,
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 10,
                                  color: const Color(0xFF6B7280),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  Container(
                                    width: 8,
                                    height: 8,
                                    decoration: BoxDecoration(
                                      color: isFirst
                                          ? AppColors.figmaGold
                                          : AppColors.figmaDarkGreen,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                ],
                              ),
                              if (!isLast)
                                Expanded(
                                  child: Container(
                                    margin: const EdgeInsets.only(left: 3.5),
                                    width: 1,
                                    color: const Color(0xFFD1D5DB),
                                  ),
                                ),
                            ],
                          ),
                        ),

                        // Right Stop Card
                        Expanded(
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 14),
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: AppColors.figmaCardBorder,
                              ),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Icon Box
                                Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFEAF2EC),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Icon(
                                    stop['icon'] as IconData? ?? Icons.place,
                                    color: AppColors.figmaDarkGreen,
                                    size: 20,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                // Texts
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        stop['time'] as String,
                                        style: GoogleFonts.plusJakartaSans(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700,
                                          color: AppColors.figmaGold,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        stop['title'] as String,
                                        style: GoogleFonts.plusJakartaSans(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w800,
                                          color: AppColors.figmaDarkGreen,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        stop['description'] as String,
                                        style: GoogleFonts.plusJakartaSans(
                                          fontSize: 11,
                                          color: const Color(0xFF6B7280),
                                          height: 1.3,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),

              const SizedBox(height: 10),

              // ── Estimated Total & Duration Card ──
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFF3ECE0),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'DURATION',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFF6B7280),
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '$durationDays days / ${durationDays - 1} nights',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: AppColors.figmaDarkGreen,
                          ),
                        ),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          'ESTIMATED TOTAL',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFF6B7280),
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '\$${totalCost.toStringAsFixed(0)}',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: AppColors.figmaDarkGreen,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // ── Continue to Checkout Button ──
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pushNamed(
                      context,
                      '/checkout',
                      arguments: _selectedItinerary,
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
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.arrow_forward, size: 18),
                      const SizedBox(width: 8),
                      Text(
                        'Continue to Checkout',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  void _showOptionsBottomSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Itinerary Options',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: AppColors.figmaDarkGreen,
              ),
            ),
            const SizedBox(height: 14),
            ListTile(
              leading: const Icon(Icons.map_outlined, color: AppColors.figmaDarkGreen),
              title: const Text('View Interactive Map'),
              onTap: () {
                Navigator.pop(ctx);
                Navigator.pushNamed(context, '/trip-map', arguments: _selectedItinerary);
              },
            ),
            ListTile(
              leading: const Icon(Icons.edit_calendar_outlined, color: AppColors.figmaDarkGreen),
              title: const Text('Customize Trip Prompt'),
              onTap: () {
                Navigator.pop(ctx);
                Navigator.pushNamed(context, '/trip-request');
              },
            ),
          ],
        ),
      ),
    );
  }
}
