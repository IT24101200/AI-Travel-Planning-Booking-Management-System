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

  final List<Map<String, dynamic>> _sampleUpcoming = [
    {
      'id': 101,
      'title': 'Sri Lanka Discovery',
      'dates': '12–18 Oct 2026 · 7 days',
      'price': 1712,
      'status': 'CONFIRMED',
      'statusColor': Color(0xFF267A55),
      'image':
          'https://images.unsplash.com/photo-1586861635167-e5223aadc9fe?w=600&auto=format&fit=crop&q=80',
    },
    {
      'id': 102,
      'title': 'Southern Coast & Whales',
      'dates': '24–28 Nov 2026 · 5 days',
      'price': 890,
      'status': 'PROCESSING',
      'statusColor': Color(0xFFB36A16),
      'image':
          'https://images.unsplash.com/photo-1552465011-b4e21bf6e79a?w=600&auto=format&fit=crop&q=80',
    },
  ];

  final List<Map<String, dynamic>> _sampleCompleted = [
    {
      'id': 98,
      'title': 'Ella Mountain & Tea Trails',
      'dates': '15–20 Mar 2026 · 6 days',
      'price': 1240,
      'status': 'COMPLETED',
      'statusColor': Color(0xFF267A55),
      'image':
          'https://images.unsplash.com/photo-1588598198321-9735fd52455b?w=600&auto=format&fit=crop&q=80',
    },
    {
      'id': 95,
      'title': 'Yala Safari & Wildlife',
      'dates': '02–06 Jan 2026 · 4 days',
      'price': 920,
      'status': 'COMPLETED',
      'statusColor': Color(0xFF267A55),
      'image':
          'https://images.unsplash.com/photo-1546708973-b339540b5162?w=600&auto=format&fit=crop&q=80',
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
              return {
                'id': b['id'],
                'title': b['destination'] ?? 'Sri Lanka Discovery',
                'dates': b['dates'] ?? '12–18 Oct 2026 · 7 days',
                'price': (b['totalCost'] ?? 1712).toInt(),
                'status': 'CONFIRMED',
                'statusColor': const Color(0xFF267A55),
                'image':
                    'https://images.unsplash.com/photo-1586861635167-e5223aadc9fe?w=600&auto=format&fit=crop&q=80',
              };
            }).toList()
          : _sampleUpcoming;
    } else if (_activeTab == 'Completed') {
      currentList = _sampleCompleted;
    } else {
      currentList = [];
    }

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
                    '${_sampleUpcoming.length} upcoming · ${_sampleCompleted.length} completed',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF17211D),
                    ),
                  ),
                  Row(
                    children: [
                      Text(
                        'All years',
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
                ],
              ),

              const SizedBox(height: 12),

              // ── Trip Cards ──
              if (currentList.isEmpty)
                Container(
                  padding: const EdgeInsets.all(32),
                  alignment: Alignment.center,
                  child: Column(
                    children: [
                      const Icon(
                        Icons.luggage_outlined,
                        size: 48,
                        color: Color(0xFF9CA3AF),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'No ${_activeTab.toLowerCase()} trips found',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF6E7772),
                        ),
                      ),
                    ],
                  ),
                )
              else
                ...currentList.map((trip) {
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
                              height: 82,
                              width: double.infinity,
                              child: Image.network(
                                trip['image'] as String,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) =>
                                    Container(
                                  color: const Color(0xFF374151),
                                  child: const Icon(
                                    Icons.landscape,
                                    color: Colors.white54,
                                  ),
                                ),
                              ),
                            ),
                            // Tint overlay
                            Positioned.fill(
                              child: Container(
                                color: const Color(0xFF08271E)
                                    .withValues(alpha: 0.25),
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

      // ── Bottom Navigation Bar ──
      bottomNavigationBar: Container(
        height: 68,
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: Color(0xFFE4E7E2))),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildNavItem(
              icon: Icons.explore_outlined,
              label: 'Explore',
              isActive: false,
              onTap: () => Navigator.pushReplacementNamed(context, '/home'),
            ),
            _buildNavItem(
              icon: Icons.luggage_outlined,
              label: 'My Trips',
              isActive: true,
              onTap: () {},
            ),
            _buildNavItem(
              icon: Icons.notifications_none_outlined,
              label: 'Alerts',
              isActive: false,
              onTap: () => Navigator.pushNamed(context, '/notifications'),
            ),
            _buildNavItem(
              icon: Icons.person_outline,
              label: 'Profile',
              isActive: false,
              onTap: () =>
                  Navigator.pushReplacementNamed(context, '/profile'),
            ),
          ],
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

  Widget _buildNavItem({
    required IconData icon,
    required String label,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 3),
            decoration: BoxDecoration(
              color: isActive ? const Color(0xFFE5F1EA) : Colors.transparent,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              icon,
              size: 20,
              color:
                  isActive ? const Color(0xFF123F32) : const Color(0xFF6E7772),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 10,
              fontWeight: isActive ? FontWeight.w800 : FontWeight.w500,
              color:
                  isActive ? const Color(0xFF123F32) : const Color(0xFF6E7772),
            ),
          ),
        ],
      ),
    );
  }
}
