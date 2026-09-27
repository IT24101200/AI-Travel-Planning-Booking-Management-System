import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../app_constants.dart';
import '../services/api_service.dart';
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
      backgroundColor: const Color(0xFFF7F5EF),
      body: screens[_currentIndex],
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: Color(0xFFE5E7EB), width: 1)),
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (index) => setState(() => _currentIndex = index),
          type: BottomNavigationBarType.fixed,
          backgroundColor: Colors.white,
          selectedItemColor: AppColors.figmaDarkGreen,
          unselectedItemColor: const Color(0xFF9CA3AF),
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

  String _getUserInitials() {
    if (widget.userName.isEmpty) return 'MF';
    final parts = widget.userName.trim().split(RegExp(r'\s+'));
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return parts[0].substring(0, parts[0].length >= 2 ? 2 : 1).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final greetingName = widget.userName.isNotEmpty
        ? widget.userName.split(' ').first.toUpperCase()
        : 'MAYA';

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
                      Colors.black.withValues(alpha: 0.65),
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
                                  color: Colors.white.withValues(alpha: 0.8),
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
                            onTap: () => Navigator.pushNamed(context, '/profile-preferences'),
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
                      color: Colors.white,
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
                              color: const Color(0xFF6B7280),
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

          const SizedBox(height: 36),

          // ── 4 Quick Actions Row ──
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
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
          ),

          const SizedBox(height: 26),

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
                    color: const Color(0xFF111827),
                  ),
                ),
                GestureDetector(
                  onTap: () => Navigator.pushNamed(context, '/tour-search'),
                  child: Text(
                    'See all',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF166B4F),
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
              ],
            ),
          ),

          const SizedBox(height: 22),

          // ── Four Agents One Seamless Trip Banner ──
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: GestureDetector(
              onTap: () => Navigator.pushNamed(context, '/trip-request'),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.figmaDarkGreen,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Row(
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
                              color: Colors.white.withValues(alpha: 0.75),
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
                    color: const Color(0xFF111827),
                  ),
                ),
                GestureDetector(
                  onTap: () => Navigator.pushNamed(context, '/tour-search'),
                  child: Text(
                    'Browse',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF166B4F),
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
                ? const Center(child: Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator(strokeWidth: 2)))
                : _buildFigmaFeaturedTourCard(),
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
                  backgroundColor: AppColors.figmaDarkGreen,
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
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE5E7EB)),
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
              Icon(icon, color: AppColors.figmaDarkGreen, size: 22),
              const SizedBox(height: 6),
              Text(
                label,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF111827),
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
                    Colors.black.withValues(alpha: 0.6),
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
                      fontSize: 18,
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

  Widget _buildFigmaFeaturedTourCard() {
    final tour = _tours.isNotEmpty ? _tours.first : null;
    final tourName = tour != null ? (tour['name'] ?? 'Kandy Heritage & Lake Walk') : 'Kandy Heritage & Lake Walk';
    final tourPrice = tour != null ? (tour['price'] ?? 42) : 42;
    final tourDuration = tour != null ? (tour['durationHours'] ?? 6) : 6;
    final tourCategory = tour != null ? (tour['category'] ?? 'CULTURE').toString().toUpperCase() : 'CULTURE';

    return GestureDetector(
      onTap: () {
        if (tour != null && tour['id'] != null) {
          Navigator.pushNamed(context, '/tour-details', arguments: tour['id']);
        } else {
          Navigator.pushNamed(context, '/tour-search');
        }
      },
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE5E7EB)),
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.asset(
                'assets/photos/kandy-1280.jpg',
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
                      color: const Color(0xFF111827),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.star_border, color: AppColors.figmaGold, size: 14),
                      const SizedBox(width: 3),
                      Text(
                        '4.8',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF374151),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '· $tourDuration hours · from \$$tourPrice',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          color: const Color(0xFF6B7280),
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
