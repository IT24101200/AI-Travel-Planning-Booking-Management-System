import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../app_constants.dart';
import '../services/api_service.dart';
import '../widgets/common_widgets.dart';

/// Stunning, full-screen non-scrolling Landing Page for Serendib Trails.
/// Displays dynamic Sri Lanka destination slideshow, live agent workflow info,
/// and enforces sign-in before allowing access to inside data.
class LandingScreen extends StatefulWidget {
  const LandingScreen({super.key});

  @override
  State<LandingScreen> createState() => _LandingScreenState();
}

class _LandingScreenState extends State<LandingScreen> {
  late final PageController _pageController;
  int _currentPage = 0;
  Timer? _timer;
  bool _isLoggedIn = false;
  String _userName = '';

  // Curated showcase destinations using verified local photographic assets
  final List<DestinationItem> _showcase = [
    AppDestinations.featured[0], // Sigiriya
    AppDestinations.featured[1], // Ella
    AppDestinations.featured[2], // Mirissa
    AppDestinations.featured[3], // Nuwara Eliya
    AppDestinations.featured[4], // Yala
  ];

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _checkAuthStatus();
    _startAutoSlide();
  }

  /// Check whether traveler is currently logged in
  Future<void> _checkAuthStatus() async {
    final logged = await ApiService.isLoggedIn();
    final name = await ApiService.getUserName();
    if (!mounted) return;
    setState(() {
      _isLoggedIn = logged;
      _userName = name ?? '';
    });
  }

  /// Auto-cycling slideshow every 4 seconds
  void _startAutoSlide() {
    _timer = Timer.periodic(const Duration(seconds: 4), (timer) {
      if (!mounted) return;
      if (_currentPage < _showcase.length - 1) {
        _currentPage++;
      } else {
        _currentPage = 0;
      }
      if (_pageController.hasClients) {
        _pageController.animateToPage(
          _currentPage,
          duration: const Duration(milliseconds: 700),
          curve: Curves.easeInOutCubic,
        );
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  /// Displays a clean modal explaining the 4 AI agents in Serendib Trails
  void _showAgentWorkflowDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => Container(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.lineStrong,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.leaf50,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.auto_awesome, color: AppColors.jungle600, size: 22),
                ),
                const SizedBox(width: 12),
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Multi-Agent Architecture',
                      style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: AppColors.ink),
                    ),
                    Text(
                      '4 Autonomous AI agents orchestrate your trip',
                      style: TextStyle(fontSize: 12, color: AppColors.ink3),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildAgentTile(
              num: '1',
              title: 'Coordinator Agent',
              desc: 'Extracts your preferences, travel dates and budget ceiling.',
              color: AppColors.jungle600,
              icon: Icons.psychology_outlined,
            ),
            _buildAgentTile(
              num: '2',
              title: 'Itinerary Agent',
              desc: 'Generates conflict-free day schedules with real travel times.',
              color: AppColors.ocean500,
              icon: Icons.alt_route,
            ),
            _buildAgentTile(
              num: '3',
              title: 'Booking & Inventory Agent',
              desc: 'Checks live room counts and transit fleet with concurrency locks.',
              color: AppColors.sand600,
              icon: Icons.hotel_outlined,
            ),
            _buildAgentTile(
              num: '4',
              title: 'Validation & Approval Agent',
              desc: 'Validates budget rules and requests agent sign-off before payment.',
              color: AppColors.coral500,
              icon: Icons.verified_user_outlined,
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  if (_isLoggedIn) {
                    Navigator.pushNamed(context, '/trip-request');
                  } else {
                    Navigator.pushNamed(context, '/login').then((_) => _checkAuthStatus());
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.jungle600,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: Text(
                  _isLoggedIn ? 'Start Planning Trip' : 'Sign In to Plan Trip',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAgentTile({
    required String num,
    required String title,
    required String desc,
    required Color color,
    required IconData icon,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Agent $num: $title',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: color),
                ),
                Text(
                  desc,
                  style: const TextStyle(fontSize: 11, color: AppColors.ink3, height: 1.3),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentDest = _showcase[_currentPage];

    return Scaffold(
      backgroundColor: AppColors.jungle900,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // ── Full-Screen Dynamic Background Slideshow ──
          PageView.builder(
            controller: _pageController,
            onPageChanged: (index) {
              setState(() => _currentPage = index);
            },
            itemCount: _showcase.length,
            itemBuilder: (context, index) {
              final item = _showcase[index];
              return AppNetworkImage(
                imageUrl: item.imageUrl,
                fit: BoxFit.cover,
              );
            },
          ),

          // ── Cinematic Multi-layered Contrast Overlay ──
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  AppColors.jungle900.withValues(alpha: 0.65),
                  AppColors.jungle900.withValues(alpha: 0.25),
                  AppColors.jungle900.withValues(alpha: 0.75),
                  AppColors.jungle900.withValues(alpha: 0.96),
                ],
                stops: const [0.0, 0.35, 0.65, 1.0],
              ),
            ),
          ),

          // ── Single-Screen Foreground Content (No Scrolling) ──
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Top Navigation Bar
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Brand Logo & Title
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.2),
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white.withValues(alpha: 0.4)),
                            ),
                            child: const Icon(Icons.travel_explore, color: AppColors.sand400, size: 20),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            'SERENDIB TRAILS',
                            style: GoogleFonts.poppins(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.8,
                            ),
                          ),
                        ],
                      ),

                      // Sign In / Dashboard Quick Pill
                      InkWell(
                        onTap: () {
                          if (_isLoggedIn) {
                            Navigator.pushNamed(context, '/home');
                          } else {
                            Navigator.pushNamed(context, '/login').then((_) => _checkAuthStatus());
                          }
                        },
                        borderRadius: BorderRadius.circular(20),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.22),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: Colors.white.withValues(alpha: 0.5)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                _isLoggedIn ? Icons.dashboard_outlined : Icons.lock_outline,
                                size: 13,
                                color: Colors.white,
                              ),
                              const SizedBox(width: 5),
                              Text(
                                _isLoggedIn
                                    ? (_userName.isNotEmpty ? _userName.split(' ').first : 'Dashboard')
                                    : 'Sign In',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),

                  const Spacer(flex: 3),

                  // Destination Region Pill Tag
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                      decoration: BoxDecoration(
                        color: AppColors.sand500,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.2),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Text(
                        currentDest.region.toUpperCase(),
                        style: const TextStyle(
                          color: AppColors.jungle900,
                          fontWeight: FontWeight.w800,
                          fontSize: 10.5,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 8),

                  // Destination Title (Animated Switcher)
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 400),
                    child: Text(
                      currentDest.name,
                      key: ValueKey(currentDest.name),
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontSize: 34,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.5,
                        height: 1.1,
                      ),
                    ),
                  ),

                  const SizedBox(height: 4),

                  // Destination Tagline (Animated Switcher)
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 400),
                    child: Text(
                      currentDest.tagline,
                      key: ValueKey(currentDest.tagline),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.9),
                        fontSize: 13.5,
                        height: 1.35,
                      ),
                    ),
                  ),

                  const SizedBox(height: 14),

                  // Destination Dots Switcher
                  Row(
                    children: [
                      ...List.generate(_showcase.length, (i) {
                        final isActive = i == _currentPage;
                        return GestureDetector(
                          onTap: () {
                            _pageController.animateToPage(
                              i,
                              duration: const Duration(milliseconds: 400),
                              curve: Curves.easeInOut,
                            );
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            margin: const EdgeInsets.only(right: 6),
                            width: isActive ? 26 : 7,
                            height: 7,
                            decoration: BoxDecoration(
                              color: isActive ? AppColors.sand400 : Colors.white.withValues(alpha: 0.4),
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        );
                      }),
                      const Spacer(),
                      Text(
                        '${_currentPage + 1} / ${_showcase.length}',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.8),
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),

                  const Spacer(flex: 2),

                  // Floating Glass Highlights Strip
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildMiniStat('8+', 'UNESCO Sites'),
                        Container(width: 1, height: 20, color: Colors.white.withValues(alpha: 0.25)),
                        _buildMiniStat('4', 'AI Agents'),
                        Container(width: 1, height: 20, color: Colors.white.withValues(alpha: 0.25)),
                        _buildMiniStat('100%', 'Inventory Lock'),
                      ],
                    ),
                  ),

                  const SizedBox(height: 10),

                  // Quick Action to View 4 Agents Architecture
                  InkWell(
                    onTap: () => _showAgentWorkflowDialog(context),
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 12),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.25),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.auto_awesome, size: 14, color: AppColors.sand400),
                          SizedBox(width: 6),
                          Text(
                            'How 4 Autonomous AI Agents Plan Your Journey',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          SizedBox(width: 4),
                          Icon(Icons.arrow_forward_ios, size: 10, color: AppColors.sand400),
                        ],
                      ),
                    ),
                  ),

                  const Spacer(flex: 2),

                  // Sign In Required Notice Badge (if not logged in)
                  if (!_isLoggedIn)
                    Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                      decoration: BoxDecoration(
                        color: AppColors.sand100,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.sand200),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.lock_outline, size: 13, color: AppColors.jungle800),
                          SizedBox(width: 6),
                          Text(
                            'Sign in required to view tours & real-time bookings',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: AppColors.jungle900,
                            ),
                          ),
                        ],
                      ),
                    ),

                  // Primary Action Buttons
                  if (!_isLoggedIn)
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () => Navigator.pushNamed(context, '/login').then((_) => _checkAuthStatus()),
                            icon: const Icon(Icons.login, size: 17),
                            label: const Text('Sign In'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.jungle600,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              elevation: 4,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () => Navigator.pushNamed(context, '/register').then((_) => _checkAuthStatus()),
                            icon: const Icon(Icons.person_add_outlined, size: 17, color: AppColors.jungle900),
                            label: const Text(
                              'Create Account',
                              style: TextStyle(color: AppColors.jungle900, fontWeight: FontWeight.w800),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.sand400,
                              foregroundColor: AppColors.jungle900,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              elevation: 4,
                            ),
                          ),
                        ),
                      ],
                    )
                  else
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () => Navigator.pushNamed(context, '/home'),
                            icon: const Icon(Icons.explore, size: 17),
                            label: const Text('Open Dashboard'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.jungle600,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              elevation: 4,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () => Navigator.pushNamed(context, '/trip-request'),
                            icon: const Icon(Icons.auto_awesome, size: 17, color: AppColors.jungle900),
                            label: const Text(
                              'AI Plan Trip',
                              style: TextStyle(color: AppColors.jungle900, fontWeight: FontWeight.w800),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.sand400,
                              foregroundColor: AppColors.jungle900,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              elevation: 4,
                            ),
                          ),
                        ),
                      ],
                    ),

                  const SizedBox(height: 8),

                  // Brand Subtitle
                  Center(
                    child: Text(
                      'SERENDIB TRAILS • SRI LANKA TRAVEL PLATFORM',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.55),
                        fontSize: 9.5,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1.0,
                      ),
                    ),
                  ),

                  const SizedBox(height: 4),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMiniStat(String value, String label) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 15,
            fontWeight: FontWeight.w900,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.75),
            fontSize: 10,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
