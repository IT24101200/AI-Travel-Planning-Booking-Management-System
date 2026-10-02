import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../app_constants.dart';
import '../services/api_service.dart';
import 'profile/trip_history_screen.dart';
import 'profile/notifications_screen.dart';
import 'profile/profile_preferences_screen.dart';

/// Main home screen with bottom navigation bar and rich Explore dashboard.
/// Fully matches Figma Dev Mode (04 · Home / Explore).
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

  /// Ensure visitor is authenticated before granting access
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

  String _getInitials(String name) {
    if (name.trim().isEmpty) return 'MF';
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return parts[0].substring(0, parts[0].length >= 2 ? 2 : 1).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> screens = [
      _ExploreTab(userName: _userName, userInitials: _getInitials(_userName)),
      const TripHistoryScreen(),
      const NotificationsScreen(),
      const ProfilePreferencesScreen(),
    ];

    return Scaffold(
      backgroundColor: const Color(0xFFFBF9F4),
      body: screens[_currentIndex],
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: Color(0xFFEDECE4), width: 1)),
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (index) => setState(() => _currentIndex = index),
          type: BottomNavigationBarType.fixed,
          backgroundColor: Colors.white,
          selectedItemColor: const Color(0xFF0E382C),
          unselectedItemColor: const Color(0xFF8A9E96),
          selectedFontSize: 11.5,
          unselectedFontSize: 11.5,
          selectedLabelStyle: const TextStyle(fontWeight: FontWeight.w700),
          unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500),
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

/// Rich Explore Dashboard Tab (04 · Home / Explore)
class _ExploreTab extends StatefulWidget {
  final String userName;
  final String userInitials;
  const _ExploreTab({required this.userName, required this.userInitials});

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
    final firstName = widget.userName.isNotEmpty
        ? widget.userName.split(' ').first.toUpperCase()
        : 'MAYA';

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Top Hero Header with Tea Hill Country & Floating Search ──
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                height: 250,
                width: double.infinity,
                decoration: BoxDecoration(
                  image: DecorationImage(
                    image: AssetImage(AppDestinations.featured[1].imageUrl), // Ella tea country
                    fit: BoxFit.cover,
                  ),
                ),
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        const Color(0xFF0E382C).withValues(alpha: 0.5),
                        const Color(0xFF0E382C).withValues(alpha: 0.85),
                      ],
                    ),
                  ),
                ),
              ),

              // Header Greeting & Avatar
              SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'AYUBOWAN, $firstName',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.8),
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.1,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            'Explore Serendib',
                            style: GoogleFonts.poppins(
                              color: Colors.white,
                              fontSize: 26,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.5,
                            ),
                          ),
                        ],
                      ),
                      // Circular Initials Avatar
                      GestureDetector(
                        onTap: () => Navigator.pushNamed(context, '/profile-preferences'),
                        child: Container(
                          width: 44,
                          height: 44,
                          decoration: const BoxDecoration(
                            color: Color(0xFFE0A63F),
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: Text(
                              widget.userInitials,
                              style: const TextStyle(
                                color: Color(0xFF1E1E1E),
                                fontWeight: FontWeight.w800,
                                fontSize: 15,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Floating Search Bar Pill (overlapping bottom of hero)
              Positioned(
                left: 18,
                right: 18,
                bottom: -24,
                child: GestureDetector(
                  onTap: () => Navigator.pushNamed(context, '/tour-search'),
                  child: Container(
                    height: 50,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(25),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.08),
                          blurRadius: 14,
                          offset: const Offset(0, 4),
                        ),
                      ],
                      border: Border.all(color: const Color(0xFFEDECE4)),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.search, color: Color(0xFF0E382C), size: 22),
                        SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Search places, tours & stays',
                            style: TextStyle(
                              color: Color(0xFF8A9E96),
                              fontSize: 13.5,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        Icon(Icons.tune, color: Color(0xFF6B7280), size: 20),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 38),

          // ── Quick Category Action Cards (4 in a row) ──
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18),
            child: Row(
              children: [
                _buildFigmaCategoryCard(
                  icon: Icons.auto_awesome,
                  label: 'AI Plan',
                  onTap: () => Navigator.pushNamed(context, '/trip-request'),
                ),
                const SizedBox(width: 10),
                _buildFigmaCategoryCard(
                  icon: Icons.map_outlined,
                  label: 'Tours',
                  onTap: () => Navigator.pushNamed(context, '/tour-search'),
                ),
                const SizedBox(width: 10),
                _buildFigmaCategoryCard(
                  icon: Icons.apartment_outlined,
                  label: 'Hotels',
                  onTap: () => Navigator.pushNamed(context, '/accommodation'),
                ),
                const SizedBox(width: 10),
                _buildFigmaCategoryCard(
                  icon: Icons.directions_bus_outlined,
                  label: 'Transit',
                  onTap: () => Navigator.pushNamed(context, '/transport'),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // ── Section: Dream destinations ──
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Dream destinations',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF08201A),
                  ),
                ),
                GestureDetector(
                  onTap: () => Navigator.pushNamed(context, '/tour-search'),
                  child: const Text(
                    'See all',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF0E382C),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 140,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 18),
              children: [
                _buildDestinationCard(
                  name: 'Ella',
                  region: 'Tea country',
                  imageUrl: AppDestinations.featured[1].imageUrl,
                  onTap: () => Navigator.pushNamed(context, '/tour-search', arguments: 'Ella'),
                ),
                const SizedBox(width: 12),
                _buildDestinationCard(
                  name: 'Mirissa',
                  region: 'South coast',
                  imageUrl: AppDestinations.featured[2].imageUrl,
                  onTap: () => Navigator.pushNamed(context, '/tour-search', arguments: 'Mirissa'),
                ),
                const SizedBox(width: 12),
                _buildDestinationCard(
                  name: 'Yala',
                  region: 'Wild frontier',
                  imageUrl: AppDestinations.featured[3].imageUrl,
                  onTap: () => Navigator.pushNamed(context, '/tour-search', arguments: 'Yala'),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // ── Section: AI Planner Banner (Dark Green) ──
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18),
            child: GestureDetector(
              onTap: () => Navigator.pushNamed(context, '/trip-request'),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF134035),
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF134035).withValues(alpha: 0.2),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    // Circular Gold Icon Badge
                    Container(
                      width: 44,
                      height: 44,
                      decoration: const BoxDecoration(
                        color: Color(0xFFD4A346),
                        shape: BoxShape.circle,
                      ),
                      child: const Center(
                        child: Icon(Icons.auto_awesome, color: Colors.white, size: 22),
                      ),
                    ),
                    const SizedBox(width: 14),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Four agents. One seamless trip.',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 14.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          SizedBox(height: 3),
                          Text(
                            'Routes, rooms, transport and review — coordinated in minutes.',
                            style: TextStyle(
                              color: Color(0xFFD0E1DA),
                              fontSize: 11,
                              height: 1.3,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Icon(Icons.arrow_forward, color: Colors.white, size: 20),
                  ],
                ),
              ),
            ),
          ),

          const SizedBox(height: 24),

          // ── Section: Featured tours ──
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Featured tours',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF08201A),
                  ),
                ),
                GestureDetector(
                  onTap: () => Navigator.pushNamed(context, '/tour-search'),
                  child: const Text(
                    'Browse',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF0E382C),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Tour Card (Figma featured tour: Kandy Heritage & Lake Walk)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18),
            child: _buildFeaturedTourCard(
              context,
              category: 'CULTURE',
              title: 'Kandy Heritage & Lake Walk',
              rating: '4.8',
              duration: '6 hours',
              price: '42',
              imageUrl: AppDestinations.featured[0].imageUrl,
              onTap: () => Navigator.pushNamed(context, '/tour-details', arguments: '1'),
            ),
          ),

          // If backend has additional tours, render them in this format
          if (!_loadingTours && _tours.isNotEmpty) ...[
            for (final tour in _tours.take(3)) ...[
              if (tour['name'] != 'Kandy Heritage & Lake Walk') ...[
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                  child: _buildFeaturedTourCard(
                    context,
                    category: (tour['category'] ?? 'EXPERIENCE').toString().toUpperCase(),
                    title: tour['name'] ?? 'Serendib Experience',
                    rating: (tour['rating'] ?? 4.8).toString(),
                    duration: '${tour['durationDays'] ?? 1} days',
                    price: (tour['price'] ?? 68).toStringAsFixed(0),
                    imageUrl: tour['imageUrl'] ?? AppDestinations.heroSigiriya,
                    onTap: () => Navigator.pushNamed(context, '/tour-details', arguments: tour['id'].toString()),
                  ),
                ),
              ],
            ],
          ],

          const SizedBox(height: 24),

          // ── Centered Bottom Pill: AI Plan My Trip ──
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18),
            child: SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                onPressed: () => Navigator.pushNamed(context, '/trip-request'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0E382C),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(26),
                  ),
                ),
                icon: const Icon(Icons.auto_awesome, color: Color(0xFFD4A346), size: 20),
                label: const Text(
                  'AI Plan My Trip',
                  style: TextStyle(
                    fontSize: 15.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ),

          const SizedBox(height: 30),
        ],
      ),
    );
  }

  Widget _buildFigmaCategoryCard({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          height: 78,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFEDECE4)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: const Color(0xFF0E382C), size: 22),
              const SizedBox(height: 6),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1E1E1E),
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
    required String region,
    required String imageUrl,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 124,
        height: 140,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          image: DecorationImage(
            image: AssetImage(imageUrl),
            fit: BoxFit.cover,
          ),
        ),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.black.withValues(alpha: 0.25),
                Colors.black.withValues(alpha: 0.7),
              ],
            ),
          ),
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                region,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.85),
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                name,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFeaturedTourCard(
    BuildContext context, {
    required String category,
    required String title,
    required String rating,
    required String duration,
    required String price,
    required String imageUrl,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFEDECE4)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            // Left Image Thumbnail
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: SizedBox(
                width: 90,
                height: 74,
                child: imageUrl.startsWith('http')
                    ? Image.network(imageUrl, fit: BoxFit.cover, errorBuilder: (context, error, stackTrace) => Container(color: const Color(0xFF0E382C)))
                    : Image.asset(imageUrl, fit: BoxFit.cover, errorBuilder: (context, error, stackTrace) => Container(color: const Color(0xFF0E382C))),
              ),
            ),
            const SizedBox(width: 14),
            // Right Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    category,
                    style: const TextStyle(
                      color: Color(0xFFD4A346),
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF08201A),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(Icons.star, color: Color(0xFFD4A346), size: 14),
                      const SizedBox(width: 4),
                      Text(
                        rating,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF08201A),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '$duration · from \$$price',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF6B7280),
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
