import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../app_constants.dart';
import '../services/api_service.dart';
import '../services/currency_notifier.dart';
import 'profile/trip_history_screen.dart';
import 'profile/notifications_screen.dart';
import 'profile/profile_preferences_screen.dart';
import '../main.dart' show currencyNotifier;

/// Main home screen with bottom navigation bar and rich Explore dashboard.
class HomeScreen extends StatefulWidget {
  final int initialIndex;
  const HomeScreen({super.key, this.initialIndex = 0});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late int _currentIndex;
  String _userName = '';

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _verifyAccess();
    _loadUserInfo();
  }

  /// Ensure visitor is authenticated before granting access to inside data
  Future<void> _verifyAccess() async {
    final loggedIn = await ApiService.isLoggedIn();
    if (!loggedIn && mounted) {
      Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
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

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: screens[_currentIndex],
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          border: Border(top: BorderSide(color: isDark ? const Color(0xFF2E3D36) : const Color(0xFFE5E7EB), width: 1)),
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (index) => setState(() => _currentIndex = index),
          type: BottomNavigationBarType.fixed,
          backgroundColor: theme.colorScheme.surface,
          selectedItemColor: theme.colorScheme.primary,
          unselectedItemColor: isDark ? const Color(0xFF7FA393) : const Color(0xFF9CA3AF),
          selectedLabelStyle: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.w700),
          unselectedLabelStyle: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.w500),
          elevation: 0,
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.explore_outlined),
              activeIcon: Icon(Icons.explore),
              label: 'Explore',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.luggage_outlined),
              activeIcon: Icon(Icons.luggage),
              label: 'My Trips',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.notifications_none_outlined),
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

/// Rich Explore Dashboard Tab matching Figma Frame 04
/// Integrates all 4 student components:
/// - Student A: AI Intake & Coordinator, User Profile, Trip History
/// - Student B: Tour Catalog, Destination Discovery, Day-by-Day Itineraries
/// - Student C: Hotel Stays, Transport Fleet, Interactive Route Map (Device Feature 1)
/// - Student D: Booking Pass & Digital QR Ticket (Device Feature 2)
class _ExploreTab extends StatefulWidget {
  final String userName;
  const _ExploreTab({required this.userName});

  @override
  State<_ExploreTab> createState() => _ExploreTabState();
}

class _ExploreTabState extends State<_ExploreTab> {
  List<dynamic> _tours = [];
  bool _loadingTours = true;
  String _selectedCategory = 'All';

  // Category filter chips matching the project travel themes
  final List<String> _categories = [
    'All',
    'Heritage',
    'Hiking',
    'Wildlife',
    'Beach',
    'Rail Journeys',
    'Culture',
  ];

  @override
  void initState() {
    super.initState();
    _fetchTours();
  }

  Future<void> _fetchTours() async {
    try {
      final tours = await ApiService.getTours(currency: currencyNotifier.value);
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

  String _getUserInitials() {
    if (widget.userName.isEmpty) return 'US';
    final parts = widget.userName.trim().split(RegExp(r'\s+'));
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return parts[0].substring(0, parts[0].length >= 2 ? 2 : 1).toUpperCase();
  }

  /// Curated fallback tours for rich visual demonstration if API has no tours
  List<Map<String, dynamic>> _getSampleTours() {
    return [
      {
        'id': 1,
        'name': 'Kandy Heritage & Sacred Lake Walk',
        'category': 'CULTURE',
        'durationHours': 6,
        'price': 42,
        'rating': '4.8',
        'image': 'assets/photos/kandy-1280.jpg',
      },
      {
        'id': 2,
        'name': 'Sigiriya Lion Rock Fortress Sunrise Climb',
        'category': 'HERITAGE',
        'durationHours': 4,
        'price': 55,
        'rating': '4.9',
        'image': 'assets/photos/sigiriya-1280.jpg',
      },
      {
        'id': 3,
        'name': 'Ella Nine Arches Bridge & Tea Trail',
        'category': 'HIKING',
        'durationHours': 3,
        'price': 38,
        'rating': '4.9',
        'image': 'assets/photos/ella-1280.jpg',
      },
    ];
  }

  @override
  Widget build(BuildContext context) {
    final greetingName = widget.userName.isNotEmpty
        ? widget.userName.split(' ').first.toUpperCase()
        : 'USER';

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Top Hero with Scenic Backdrop, Avatar & Search Pill ──
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                height: 230,
                width: double.infinity,
                decoration: const BoxDecoration(
                  image: DecorationImage(
                    image: AssetImage('assets/photos/ella-1280.jpg'),
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              Container(
                height: 230,
                width: double.infinity,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.35),
                      Colors.black.withValues(alpha: 0.70),
                    ],
                  ),
                ),
              ),
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
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
                                'AYUBOWAN, $greetingName',
                                style: GoogleFonts.plusJakartaSans(
                                  color: Colors.white.withValues(alpha: 0.85),
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 1.1,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Explore Serendib',
                                style: GoogleFonts.plusJakartaSans(
                                  color: Colors.white,
                                  fontSize: 26,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                          GestureDetector(
                            onTap: () => Navigator.pushNamed(context, '/profile'),
                            child: Container(
                              width: 38,
                              height: 38,
                              decoration: const BoxDecoration(
                                color: AppColors.figmaGold,
                                shape: BoxShape.circle,
                              ),
                              child: Center(
                                child: Text(
                                  _getUserInitials(),
                                  style: GoogleFonts.plusJakartaSans(
                                    color: AppColors.figmaDarkGreen,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w800,
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
              ),
              // Search Pill overlapping hero bottom
              Positioned(
                bottom: -22,
                left: 20,
                right: 20,
                child: GestureDetector(
                  onTap: () => Navigator.pushNamed(context, '/tour-search'),
                  child: Container(
                    height: 48,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surface,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.08),
                          blurRadius: 16,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.search, color: Color(0xFF6B7280), size: 20),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Search places, tours & stays',
                            style: GoogleFonts.plusJakartaSans(
                              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        const Icon(Icons.tune, color: Color(0xFF6B7280), size: 18),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 34),

          // ── Core Services & Travel Tools Grid (Balanced 2x4 Layout covering all 4 components) ──
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              children: [
                // Row 1: Primary Services (AI Plan, Tours, Hotels, Transit)
                Row(
                  children: [
                    _buildQuickAction(
                      icon: Icons.auto_awesome,
                      label: 'AI Plan',
                      onTap: () => Navigator.pushNamed(context, '/trip-request'),
                    ),
                    const SizedBox(width: 10),
                    _buildQuickAction(
                      icon: Icons.map_outlined,
                      label: 'Tours',
                      onTap: () => Navigator.pushNamed(context, '/tour-search'),
                    ),
                    const SizedBox(width: 10),
                    _buildQuickAction(
                      icon: Icons.apartment_outlined,
                      label: 'Hotels',
                      onTap: () => Navigator.pushNamed(context, '/accommodation'),
                    ),
                    const SizedBox(width: 10),
                    _buildQuickAction(
                      icon: Icons.directions_subway_outlined,
                      label: 'Transit',
                      onTap: () => Navigator.pushNamed(context, '/transport'),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // Row 2: Planning & Tracking Tools (Itinerary, Route Map, My Trips, QR Pass)
                Row(
                  children: [
                    _buildQuickAction(
                      icon: Icons.calendar_month_outlined,
                      label: 'Itinerary',
                      onTap: () => Navigator.pushNamed(context, '/itinerary'),
                    ),
                    const SizedBox(width: 10),
                    _buildQuickAction(
                      icon: Icons.explore_outlined,
                      label: 'Route Map',
                      onTap: () => Navigator.pushNamed(context, '/trip-map'),
                    ),
                    const SizedBox(width: 10),
                    _buildQuickAction(
                      icon: Icons.luggage_outlined,
                      label: 'My Trips',
                      onTap: () => Navigator.pushNamed(context, '/trip-history'),
                    ),
                    const SizedBox(width: 10),
                    _buildQuickAction(
                      icon: Icons.qr_code_2_outlined,
                      label: 'QR Pass',
                      onTap: () => Navigator.pushNamed(context, '/booking-status'),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 22),

          // ── Category Filter Chips ──
          SizedBox(
            height: 36,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemCount: _categories.length,
              separatorBuilder: (context, index) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final cat = _categories[index];
                final isSelected = _selectedCategory == cat;
                return GestureDetector(
                  onTap: () {
                    setState(() => _selectedCategory = cat);
                    if (cat != 'All') {
                      Navigator.pushNamed(context, '/tour-search', arguments: cat);
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
                    decoration: BoxDecoration(
                      color: isSelected ? theme.colorScheme.primary : theme.colorScheme.surface,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: isSelected ? theme.colorScheme.primary : (isDark ? const Color(0xFF2E3D36) : const Color(0xFFE5E7EB)),
                      ),
                    ),
                    child: Center(
                      child: Text(
                        cat,
                        style: GoogleFonts.plusJakartaSans(
                          color: isSelected ? Colors.white : theme.colorScheme.onSurface,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          const SizedBox(height: 22),

          // ── Dream Destinations Section ──
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Dream destinations',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                GestureDetector(
                  onTap: () => Navigator.pushNamed(context, '/tour-search'),
                  child: Text(
                    'See all',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          SizedBox(
            height: 145,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              children: [
                _buildDestinationCard(
                  name: 'Ella',
                  category: 'Tea country',
                  imagePath: 'assets/photos/ella-1280.jpg',
                  onTap: () => Navigator.pushNamed(context, '/tour-search', arguments: 'Ella'),
                ),
                const SizedBox(width: 12),
                _buildDestinationCard(
                  name: 'Mirissa',
                  category: 'South coast',
                  imagePath: 'assets/photos/mirissa-1280.jpg',
                  onTap: () => Navigator.pushNamed(context, '/tour-search', arguments: 'Mirissa'),
                ),
                const SizedBox(width: 12),
                _buildDestinationCard(
                  name: 'Yala',
                  category: 'Wild frontier',
                  imagePath: 'assets/photos/yala-1280.jpg',
                  onTap: () => Navigator.pushNamed(context, '/tour-search', arguments: 'Yala'),
                ),
                const SizedBox(width: 12),
                _buildDestinationCard(
                  name: 'Sigiriya',
                  category: 'Ancient kingdom',
                  imagePath: 'assets/photos/sigiriya-1280.jpg',
                  onTap: () => Navigator.pushNamed(context, '/tour-search', arguments: 'Sigiriya'),
                ),
                const SizedBox(width: 12),
                _buildDestinationCard(
                  name: 'Kandy',
                  category: 'Hill capital',
                  imagePath: 'assets/photos/kandy-1280.jpg',
                  onTap: () => Navigator.pushNamed(context, '/tour-search', arguments: 'Kandy'),
                ),
                const SizedBox(width: 12),
                _buildDestinationCard(
                  name: 'Nuwara Eliya',
                  category: 'Little England',
                  imagePath: 'assets/photos/nuwara-eliya-1280.jpg',
                  onTap: () => Navigator.pushNamed(context, '/tour-search', arguments: 'Nuwara Eliya'),
                ),
              ],
            ),
          ),

          const SizedBox(height: 22),

          // ── Four Agents One Seamless Trip Multi-Agent Banner ──
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: GestureDetector(
              onTap: () => Navigator.pushNamed(context, '/trip-request'),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.figmaDarkGreen,
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.figmaDarkGreen.withValues(alpha: 0.2),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: const BoxDecoration(
                            color: AppColors.figmaGold,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.auto_awesome,
                            color: AppColors.figmaDarkGreen,
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Four agents. One seamless trip.',
                                style: GoogleFonts.plusJakartaSans(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Routes, rooms, transport and review — coordinated in minutes.',
                                style: GoogleFonts.plusJakartaSans(
                                  color: Colors.white.withValues(alpha: 0.8),
                                  fontSize: 11,
                                  height: 1.25,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Icon(
                          Icons.arrow_forward,
                          color: AppColors.figmaGold,
                          size: 20,
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    // Micro-badges representing the 4 agents
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        _buildAgentMicroBadge('1. Coordinator'),
                        _buildAgentMicroBadge('2. Itinerary'),
                        _buildAgentMicroBadge('3. Booking'),
                        _buildAgentMicroBadge('4. Verification'),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),

          const SizedBox(height: 24),

          // ── Featured Tours Section ──
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Featured tours',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                GestureDetector(
                  onTap: () => Navigator.pushNamed(context, '/tour-search'),
                  child: Text(
                    'Browse',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: _loadingTours
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: CircularProgressIndicator(color: theme.colorScheme.primary, strokeWidth: 2),
                    ),
                  )
                : _buildFeaturedToursList(),
          ),

          const SizedBox(height: 20),

          // ── Sticky AI Plan My Trip Pill Button ──
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: () => Navigator.pushNamed(context, '/trip-request'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.colorScheme.primary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(26),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.auto_awesome, color: Colors.white, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'AI Plan My Trip',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          const SizedBox(height: 30),
        ],
      ),
    );
  }

  Widget _buildAgentMicroBadge(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        label,
        style: GoogleFonts.plusJakartaSans(
          color: Colors.white.withValues(alpha: 0.9),
          fontSize: 10,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildQuickAction({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF2E3D36) : const Color(0xFFE5E7EB)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.02),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: Theme.of(context).colorScheme.primary, size: 22),
              const SizedBox(height: 6),
              Text(
                label,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDestinationCard({
    required String name,
    required String category,
    required String imagePath,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 115,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          image: DecorationImage(
            image: AssetImage(imagePath),
            fit: BoxFit.cover,
          ),
        ),
        child: Stack(
          children: [
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.3),
                    Colors.black.withValues(alpha: 0.65),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    category,
                    style: GoogleFonts.plusJakartaSans(
                      color: Colors.white.withValues(alpha: 0.9),
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    name,
                    style: GoogleFonts.plusJakartaSans(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
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

  Widget _buildFeaturedToursList() {
    final list = _tours.isNotEmpty ? _tours.take(3).toList() : _getSampleTours();

    return Column(
      children: list.map<Widget>((item) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: _buildTourItemCard(item),
        );
      }).toList(),
    );
  }

  Widget _buildTourItemCard(dynamic tour) {
    final Map<String, dynamic> tourMap = tour is Map<String, dynamic>
        ? tour
        : {'name': 'Sri Lanka Discovery Tour', 'price': 45};

    final tourName = tourMap['name']?.toString() ?? 'Sri Lanka Tour';
    final dynamic priceRaw = tourMap['price'];
    final num tourPriceNum = priceRaw is num ? priceRaw : num.tryParse(priceRaw?.toString() ?? '42') ?? 42;
    final int tourDuration = tourMap['durationHours'] is int ? tourMap['durationHours'] : 5;
    final String tourCategory = (tourMap['category'] ?? 'TOUR').toString().toUpperCase();
    final String tourRating = tourMap['rating']?.toString() ?? '4.8';
    final int tourId = tourMap['id'] is int ? tourMap['id'] : int.tryParse(tourMap['id']?.toString() ?? '0') ?? 0;

    // Pick a local photo asset based on category or default
    String photoAsset = 'assets/photos/kandy-1280.jpg';
    if (tourCategory.contains('HERITAGE') || tourName.contains('Sigiriya')) {
      photoAsset = 'assets/photos/sigiriya-1280.jpg';
    } else if (tourCategory.contains('HIKING') || tourName.contains('Ella')) {
      photoAsset = 'assets/photos/ella-1280.jpg';
    } else if (tourCategory.contains('WILD') || tourName.contains('Yala')) {
      photoAsset = 'assets/photos/yala-1280.jpg';
    } else if (tourCategory.contains('BEACH') || tourName.contains('Mirissa')) {
      photoAsset = 'assets/photos/mirissa-1280.jpg';
    }

    final tourCurrency = tourMap['currency']?.toString() ?? currencyNotifier.value;

    return GestureDetector(
      onTap: () {
        if (tourId > 0) {
          Navigator.pushNamed(context, '/tour-details', arguments: tourId);
        } else {
          Navigator.pushNamed(context, '/tour-search');
        }
      },
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF2E3D36) : const Color(0xFFE5E7EB)),
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.asset(
                photoAsset,
                width: 76,
                height: 64,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => Container(
                  width: 76,
                  height: 64,
                  color: AppColors.figmaDarkGreen,
                  child: const Icon(Icons.landscape, color: Colors.white),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    tourCategory,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: AppColors.figmaGold,
                      letterSpacing: 0.8,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    tourName,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.star, color: AppColors.figmaGold, size: 14),
                      const SizedBox(width: 3),
                      Text(
                        tourRating,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '· $tourDuration hours · from ${formatMoney(tourPriceNum, tourCurrency)}',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
