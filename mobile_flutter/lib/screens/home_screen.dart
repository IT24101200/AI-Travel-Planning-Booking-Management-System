import 'package:flutter/material.dart';
import '../app_constants.dart';
import '../services/api_service.dart';
import '../widgets/common_widgets.dart';
import 'profile/trip_history_screen.dart';
import 'profile/notifications_screen.dart';
import 'profile/profile_preferences_screen.dart';

/// Main home screen with bottom navigation bar and rich Explore dashboard.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;
  String _userName = '';

  @override
  void initState() {
    super.initState();
    _verifyAccess();
    _loadUserInfo();
  }

  /// Ensure visitor is authenticated before granting access to inside data
  Future<void> _verifyAccess() async {
    final loggedIn = await ApiService.isLoggedIn();
    if (!loggedIn && mounted) {
      Navigator.pushNamedAndRemoveUntil(context, '/landing', (route) => false);
    }
  }

  Future<void> _loadUserInfo() async {
    final name = await ApiService.getUserName();
    if (mounted && name != null && name.isNotEmpty) {
      setState(() {
        _userName = name;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // 4 Primary tabs
    final List<Widget> screens = [
      _ExploreTab(userName: _userName),
      const TripHistoryScreen(),
      const NotificationsScreen(),
      const ProfilePreferencesScreen(),
    ];

    return Scaffold(
      body: screens[_currentIndex],
      floatingActionButton: _currentIndex == 0
          ? FloatingActionButton.extended(
              onPressed: () => Navigator.pushNamed(context, '/trip-request'),
              backgroundColor: AppColors.jungle600,
              elevation: 4,
              icon: const Icon(Icons.auto_awesome, color: AppColors.sand400),
              label: const Text(
                'AI Plan Trip',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
              ),
            )
          : null,
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: AppColors.line, width: 1)),
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (index) => setState(() => _currentIndex = index),
          type: BottomNavigationBarType.fixed,
          backgroundColor: Colors.white,
          selectedItemColor: AppColors.jungle600,
          unselectedItemColor: AppColors.ink3,
          selectedFontSize: 12,
          unselectedFontSize: 12,
          elevation: 0,
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.explore_outlined),
              activeIcon: Icon(Icons.explore),
              label: 'Explore',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.card_travel_outlined),
              activeIcon: Icon(Icons.card_travel),
              label: 'My Trips',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.notifications_outlined),
              activeIcon: Icon(Icons.notifications),
              label: 'Alerts',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.person_outline),
              activeIcon: Icon(Icons.person),
              label: 'Profile',
            ),
          ],
        ),
      ),
    );
  }
}

/// Rich Explore Dashboard Tab
class _ExploreTab extends StatefulWidget {
  final String userName;
  const _ExploreTab({required this.userName});

  @override
  State<_ExploreTab> createState() => _ExploreTabState();
}

class _ExploreTabState extends State<_ExploreTab> {
  List<dynamic> _tours = [];
  bool _loadingTours = true;

  @override
  void initState() {
    super.initState();
    _fetchTours();
  }

  Future<void> _fetchTours() async {
    try {
      final tours = await ApiService.getTours();
      if (mounted) {
        setState(() {
          _tours = tours;
          _loadingTours = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingTours = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Hero Header with Sri Lanka Scenic Photo ──
          Stack(
            children: [
              Container(
                height: 250,
                width: double.infinity,
                decoration: const BoxDecoration(
                  image: DecorationImage(
                    image: AssetImage(AppDestinations.heroSigiriya),
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              // Gradient Overlay
              Container(
                height: 250,
                width: double.infinity,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      AppColors.jungle900.withOpacity(0.4),
                      AppColors.jungle900.withOpacity(0.85),
                    ],
                  ),
                ),
              ),
              // Header Content
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.userName.isNotEmpty
                                    ? 'Hello, ${widget.userName.split(' ').first}'
                                    : 'Ayubowan!',
                                style: const TextStyle(
                                  color: AppColors.sand400,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 0.5,
                                ),
                              ),
                              const Text(
                                'Explore Serendib',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 24,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -0.5,
                                ),
                              ),
                            ],
                          ),
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              shape: BoxShape.circle,
                            ),
                            child: IconButton(
                              icon: const Icon(Icons.search, color: Colors.white),
                              onPressed: () => Navigator.pushNamed(context, '/tour-search'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      // Search Trigger Bar
                      InkWell(
                        onTap: () => Navigator.pushNamed(context, '/tour-search'),
                        borderRadius: BorderRadius.circular(14),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.15),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: const Row(
                            children: [
                              Icon(Icons.search, color: AppColors.jungle600, size: 20),
                              SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  'Find tours, waterfalls, tea trails...',
                                  style: TextStyle(
                                    color: AppColors.ink3,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                              Icon(Icons.tune, color: AppColors.ink3, size: 18),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // ── Quick Navigation Services Grid ──
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                _buildQuickAction(
                  context,
                  icon: Icons.auto_awesome,
                  label: 'AI Plan',
                  color: AppColors.jungle600,
                  onTap: () => Navigator.pushNamed(context, '/trip-request'),
                ),
                _buildQuickAction(
                  context,
                  icon: Icons.tour_outlined,
                  label: 'Tours',
                  color: AppColors.ocean500,
                  onTap: () => Navigator.pushNamed(context, '/tour-search'),
                ),
                _buildQuickAction(
                  context,
                  icon: Icons.hotel_outlined,
                  label: 'Hotels',
                  color: AppColors.sand600,
                  onTap: () => Navigator.pushNamed(context, '/accommodation'),
                ),
                _buildQuickAction(
                  context,
                  icon: Icons.directions_bus_outlined,
                  label: 'Transit',
                  color: AppColors.coral500,
                  onTap: () => Navigator.pushNamed(context, '/transport'),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // ── Popular Destinations Carousel ──
          SectionHeader(
            title: 'Top Destinations',
            subtitle: 'Iconic wonders across the pearl of the Indian Ocean',
            actionLabel: 'See All',
            onAction: () => Navigator.pushNamed(context, '/tour-search'),
          ),
          SizedBox(
            height: 210,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemCount: AppDestinations.featured.length,
              itemBuilder: (context, index) {
                final dest = AppDestinations.featured[index];
                return DestinationCardWidget(
                  name: dest.name,
                  region: dest.region,
                  tagline: dest.tagline,
                  imageUrl: dest.imageUrl,
                  rating: dest.rating,
                  onTap: () => Navigator.pushNamed(
                    context,
                    '/tour-search',
                    arguments: dest.name,
                  ),
                );
              },
            ),
          ),

          const SizedBox(height: 20),

          // ── AI Planner Banner Card ──
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppColors.jungle700, AppColors.jungle800],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.jungle900.withOpacity(0.15),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.psychology, color: AppColors.sand400, size: 36),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Multi-Agent Trip Planner',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Let 4 autonomous agents build, schedule & validate your dream vacation.',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.85),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () => Navigator.pushNamed(context, '/trip-request'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.sand500,
                      foregroundColor: AppColors.jungle900,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: const Text('Start', style: TextStyle(fontWeight: FontWeight.w700)),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 20),

          // ── Featured Tours Section ──
          SectionHeader(
            title: 'Curated Experiences',
            subtitle: 'Hand-picked guided tours and heritage walks',
            actionLabel: 'Browse All',
            onAction: () => Navigator.pushNamed(context, '/tour-search'),
          ),

          if (_loadingTours)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: LoadingIndicator(message: 'Loading tours...'),
            )
          else if (_tours.isEmpty)
            // Fallback preview cards if database is freshly seeded
            _buildSampleTourList(context)
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.only(bottom: 90),
              itemCount: _tours.length > 5 ? 5 : _tours.length,
              itemBuilder: (context, index) {
                final tour = _tours[index];
                return _buildTourCard(context, tour);
              },
            ),
        ],
      ),
    );
  }

  Widget _buildQuickAction(
    BuildContext context, {
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(height: 6),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.ink2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTourCard(BuildContext context, Map<String, dynamic> tour) {
    final tourName = tour['name'] ?? 'Tour';
    final uploadedImage = ApiService.resolveMediaUrl(tour['imageUrl']?.toString());
    final imageUrl = uploadedImage.isNotEmpty
        ? uploadedImage
        : AppDestinations.getImageForDestination(tourName);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
        border: Border.all(color: AppColors.line),
      ),
      child: InkWell(
        onTap: () => Navigator.pushNamed(context, '/tour-details', arguments: tour['id']),
        borderRadius: BorderRadius.circular(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image with Price Tag Overlay
            Stack(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                  child: AppNetworkImage(
                    imageUrl: imageUrl,
                    height: 140,
                    width: double.infinity,
                    fit: BoxFit.cover,
                  ),
                ),
                Positioned(
                  top: 10,
                  right: 10,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: AppColors.jungle800.withOpacity(0.9),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '\$${(tour['price'] ?? 0).toStringAsFixed(0)} ${tour['currency'] ?? 'USD'}',
                      style: const TextStyle(
                        color: AppColors.sand400,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),
                Positioned(
                  bottom: 10,
                  left: 10,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.6),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.schedule, size: 12, color: Colors.white),
                        const SizedBox(width: 4),
                        Text(
                          '${tour['durationHours'] ?? 2} Hours',
                          style: const TextStyle(color: Colors.white, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            // Content
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    tourName,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppColors.ink,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    tour['category'] ?? 'Sightseeing Tour',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.jungle600,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSampleTourList(BuildContext context) {
    final sampleTours = [
      {'name': 'Sigiriya Lion Rock Sunrise Climb', 'price': 185, 'category': 'UNESCO Heritage', 'durationHours': 4},
      {'name': 'Ella Nine Arches Bridge & Tea Walk', 'price': 145, 'category': 'Hiking & Train', 'durationHours': 3},
      {'name': 'Mirissa Whale Watching Cruise', 'price': 168, 'category': 'Marine Wildlife', 'durationHours': 5},
    ];

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.only(bottom: 90),
      itemCount: sampleTours.length,
      itemBuilder: (context, index) {
        final tour = sampleTours[index];
        return _buildTourCard(context, tour);
      },
    );
  }
}
