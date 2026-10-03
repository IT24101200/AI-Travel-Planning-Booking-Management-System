import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../app_constants.dart';
import '../../services/api_service.dart';

/// Trip history screen matching Figma frame 16 · Trip History / My Trips (node 7:11390)
class TripHistoryScreen extends StatefulWidget {
  const TripHistoryScreen({super.key});

  @override
  State<TripHistoryScreen> createState() => _TripHistoryScreenState();
}

class _TripHistoryScreenState extends State<TripHistoryScreen> {
  List<dynamic> _bookings = [];
  bool _loading = true;
  String _activeTab = 'Upcoming'; // 'Upcoming', 'Completed', 'Cancelled'
  String _selectedYear = 'All years';

  final List<Map<String, dynamic>> _sampleUpcoming = [
    {
      'id': 101,
      'bookingReference': 'ST-284619',
      'title': 'Sigiriya & Cultural Triangle Discovery',
      'destination': 'Sigiriya & Cultural Triangle Discovery',
      'dates': '12–18 Oct 2026 · 7 days',
      'stops': 'Sigiriya · Dambulla · Polonnaruwa · Kandy',
      'price': 1712,
      'totalCost': 1712.0,
      'status': 'CONFIRMED',
      'statusColor': const Color(0xFF267A55),
      'image': 'assets/photos/sigiriya-1280.jpg',
    },
    {
      'id': 102,
      'bookingReference': 'ST-319502',
      'title': 'Southern Coast & Whale Safari',
      'destination': 'Southern Coast & Whale Safari',
      'dates': '24–28 Nov 2026 · 5 days',
      'stops': 'Galle Fort · Mirissa Beach · Weligama Bay',
      'price': 890,
      'totalCost': 890.0,
      'status': 'PROCESSING',
      'statusColor': const Color(0xFFB36A16),
      'image': 'assets/photos/mirissa-1280.jpg',
    },
  ];

  final List<Map<String, dynamic>> _sampleCompleted = [
    {
      'id': 98,
      'bookingReference': 'ST-194820',
      'title': 'Ella Mountain & Nine Arch Tea Trails',
      'destination': 'Ella Mountain & Nine Arch Tea Trails',
      'dates': '15–20 Mar 2026 · 6 days',
      'stops': 'Kandy · Nuwara Eliya · Ella · Nine Arches',
      'price': 1240,
      'totalCost': 1240.0,
      'status': 'COMPLETED',
      'statusColor': const Color(0xFF267A55),
      'image': 'assets/photos/ella-1280.jpg',
    },
    {
      'id': 95,
      'bookingReference': 'ST-182390',
      'title': 'Yala Safari & Wildlife Expedition',
      'destination': 'Yala Safari & Wildlife Expedition',
      'dates': '02–06 Jan 2026 · 4 days',
      'stops': 'Tissamaharama · Yala National Park · Bundala',
      'price': 920,
      'totalCost': 920.0,
      'status': 'COMPLETED',
      'statusColor': const Color(0xFF267A55),
      'image': 'assets/photos/yala-1280.jpg',
    },
  ];

  final List<Map<String, dynamic>> _sampleCancelled = [
    {
      'id': 88,
      'bookingReference': 'ST-147321',
      'title': 'Trincomalee & Pigeon Island Snorkel',
      'destination': 'Trincomalee & Pigeon Island Snorkel',
      'dates': '05–09 Aug 2026 · 5 days',
      'stops': 'Trincomalee · Pigeon Island · Nilaveli',
      'price': 640,
      'totalCost': 640.0,
      'status': 'CANCELLED',
      'statusColor': const Color(0xFFDC2626),
      'image': 'assets/photos/trincomalee-1280.jpg',
    },
  ];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      final bookings = await ApiService.getMyBookings();
      if (mounted) {
        setState(() {
          _bookings = bookings;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Widget _buildTripImage(String imagePath) {
    if (imagePath.startsWith('assets/')) {
      return Image.asset(
        imagePath,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => Container(
          color: const Color(0xFF1E3A2F),
          alignment: Alignment.center,
          child: const Icon(Icons.landscape, color: Colors.white54),
        ),
      );
    }
    return Image.network(
      imagePath,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) => Container(
        color: const Color(0xFF1E3A2F),
        alignment: Alignment.center,
        child: const Icon(Icons.landscape, color: Colors.white54),
      ),
    );
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

    final List<Map<String, dynamic>> currentList;
    if (_activeTab == 'Upcoming') {
      currentList = _bookings.isNotEmpty
          ? _bookings.map((b) {
              final destination = b['destination'] ??
                  (b['bookingItems'] is List && (b['bookingItems'] as List).isNotEmpty
                      ? b['bookingItems'][0]['tourName']
                      : null) ??
                  'Sigiriya & Cultural Triangle Discovery';
              final image = b['imageUrl'] ?? AppDestinations.getImageForDestination(destination.toString());
              final status = (b['status']?.toString() ?? 'CONFIRMED').toUpperCase();
              Color statusColor = const Color(0xFF267A55);
              if (status.contains('PROCESS')) statusColor = const Color(0xFFB36A16);
              if (status.contains('CANCEL')) statusColor = const Color(0xFFDC2626);

              return {
                'id': b['id'],
                'bookingReference': b['bookingReference'] ?? 'ST-${b['id']}',
                'title': destination,
                'destination': destination,
                'dates': b['dates'] ?? '12–18 Oct 2026 · 7 days',
                'stops': b['stops'] ?? 'Sigiriya · Kandy · Ella',
                'price': (b['totalCost'] ?? 1712).toInt(),
                'totalCost': (b['totalCost'] ?? 1712).toDouble(),
                'status': status,
                'statusColor': statusColor,
                'image': image,
              };
            }).toList()
          : _sampleUpcoming;
    } else if (_activeTab == 'Completed') {
      currentList = _sampleCompleted;
    } else {
      currentList = _sampleCancelled;
    }

    final filteredList = _selectedYear == 'All years'
        ? currentList
        : currentList
            .where((t) => (t['dates'] as String? ?? '').contains(_selectedYear))
            .toList();

    final upcomingCount = _bookings.isNotEmpty ? _bookings.length : _sampleUpcoming.length;
    final completedCount = _sampleCompleted.length;

    return Scaffold(
      backgroundColor: AppColors.figmaSurface,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── App Bar ──
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'My Trips',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF17211D),
                        ),
                      ),
                      Text(
                        'Your journeys, past and future',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 10,
                          color: const Color(0xFF6E7772),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.06),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: IconButton(
                      icon: const Icon(
                        Icons.add,
                        color: AppColors.figmaDarkGreen,
                        size: 20,
                      ),
                      onPressed: () {
                        Navigator.pushNamed(context, '/trip-request');
                      },
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 14),

              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => Navigator.pushNamed(context, '/itinerary'),
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFE4E7E2)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: const Color(0xFFEAF2EC),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.calendar_month_outlined,
                            color: AppColors.figmaDarkGreen,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'My Itineraries',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFF17211D),
                            ),
                          ),
                        ),
                        const Icon(
                          Icons.arrow_forward_ios,
                          size: 16,
                          color: AppColors.figmaDarkGreen,
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 14),

              // ── Segmented Tabs Pill ──
              Container(
                height: 38,
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: const Color(0xFFE4E7E2)),
                ),
                child: Row(
                  children: [
                    _buildTabItem('Upcoming'),
                    _buildTabItem('Completed'),
                    _buildTabItem('Cancelled'),
                  ],
                ),
              ),

              const SizedBox(height: 14),

              // ── Trips Summary Row ──
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '$upcomingCount upcoming · $completedCount completed',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF17211D),
                    ),
                  ),
                  PopupMenuButton<String>(
                    initialValue: _selectedYear,
                    onSelected: (val) => setState(() => _selectedYear = val),
                    child: Row(
                      children: [
                        Text(
                          _selectedYear,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 9,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF2F7057),
                          ),
                        ),
                        const SizedBox(width: 2),
                        const Icon(
                          Icons.keyboard_arrow_down,
                          size: 14,
                          color: Color(0xFF2F7057),
                        ),
                      ],
                    ),
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: 'All years',
                        child: Text('All years'),
                      ),
                      const PopupMenuItem(
                        value: '2026',
                        child: Text('2026'),
                      ),
                      const PopupMenuItem(
                        value: '2025',
                        child: Text('2025'),
                      ),
                    ],
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // ── Trip Cards ──
              if (filteredList.isEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 36),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFE4E7E2)),
                  ),
                  child: Column(
                    children: [
                      Container(
                        width: 56,
                        height: 56,
                        decoration: const BoxDecoration(
                          color: Color(0xFFF1F5F3),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.luggage_outlined,
                          size: 28,
                          color: Color(0xFF6E7772),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'No ${_activeTab.toLowerCase()} trips found',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF17211D),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Browse our handpicked tours across Sri Lanka to start planning.',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 11,
                          color: const Color(0xFF6E7772),
                        ),
                      ),
                      const SizedBox(height: 14),
                      ElevatedButton(
                        onPressed: () =>
                            Navigator.pushNamed(context, '/tour-search'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF123F32),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(999),
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 18,
                            vertical: 8,
                          ),
                          elevation: 0,
                        ),
                        child: Text(
                          'Explore Tours',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                )
              else
                ...filteredList.map((trip) {
                  return Container(
                    margin: const EdgeInsets.only(bottom: 14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(17),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF10291F).withValues(alpha: 0.08),
                          blurRadius: 20,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Column(
                      children: [
                        // Image Top Half
                        Stack(
                          children: [
                            SizedBox(
                              height: 100,
                              width: double.infinity,
                              child: _buildTripImage(trip['image'] as String),
                            ),
                            // Tint overlay
                            Positioned.fill(
                              child: Container(
                                color: const Color(0xFF08271E)
                                    .withValues(alpha: 0.18),
                              ),
                            ),
                            // Status Badge
                            Positioned(
                              top: 10,
                              left: 10,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Text(
                                  trip['status'] as String,
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 8,
                                    fontWeight: FontWeight.w800,
                                    color: trip['statusColor'] as Color,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),

                        // Details Bottom Half
                        Padding(
                          padding: const EdgeInsets.fromLTRB(11, 9, 11, 11),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        trip['title'] as String,
                                        style: GoogleFonts.plusJakartaSans(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w800,
                                          color: const Color(0xFF17211D),
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        trip['dates'] as String,
                                        style: GoogleFonts.plusJakartaSans(
                                          fontSize: 9,
                                          color: const Color(0xFF6E7772),
                                        ),
                                      ),
                                    ],
                                  ),
                                  Text(
                                    '\$${trip['price']}',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w800,
                                      color: const Color(0xFF123F32),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              Row(
                                children: [
                                  // View Itinerary Button
                                  Expanded(
                                    child: SizedBox(
                                      height: 38,
                                      child: ElevatedButton(
                                        onPressed: () {
                                          Navigator.pushNamed(
                                            context,
                                            '/itinerary',
                                            arguments: trip,
                                          );
                                        },
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor:
                                              const Color(0xFF123F32),
                                          foregroundColor: Colors.white,
                                          shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(999),
                                          ),
                                          elevation: 0,
                                        ),
                                        child: Text(
                                          'View Itinerary',
                                          style: GoogleFonts.plusJakartaSans(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  // Manage Details Button
                                  Expanded(
                                    child: SizedBox(
                                      height: 38,
                                      child: OutlinedButton(
                                        onPressed: () {
                                          Navigator.pushNamed(
                                            context,
                                            '/booking-status',
                                            arguments: trip,
                                          );
                                        },
                                        style: OutlinedButton.styleFrom(
                                          backgroundColor: Colors.white,
                                          side: const BorderSide(
                                            color: Color(0xFFE4E7E2),
                                          ),
                                          shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(999),
                                          ),
                                          elevation: 0,
                                        ),
                                        child: Text(
                                          'Manage Pass',
                                          style: GoogleFonts.plusJakartaSans(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w700,
                                            color: const Color(0xFF123F32),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                }),

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTabItem(String tab) {
    final isSelected = _activeTab == tab;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _activeTab = tab),
        child: Container(
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF123F32) : Colors.transparent,
            borderRadius: BorderRadius.circular(999),
          ),
          alignment: Alignment.center,
          child: Text(
            tab,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: isSelected ? Colors.white : const Color(0xFF6E7772),
            ),
          ),
        ),
      ),
    );
  }
}
