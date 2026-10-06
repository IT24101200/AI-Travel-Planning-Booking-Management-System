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

          // ── Foreground Content (Responsive with Safe Scroll) ──
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  physics: const ClampingScrollPhysics(),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minHeight: constraints.maxHeight),
                    child: IntrinsicHeight(
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

                  // Destination Region Pill Tag (Figma style)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.35),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
                      ),
                      child: Text(
                        currentDest.region.toUpperCase(),
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.95),
                          fontWeight: FontWeight.w700,
                          fontSize: 10.5,
                          letterSpacing: 1.1,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 10),

                  // Destination Title (Animated Switcher)
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 400),
                    child: Text(
                      currentDest.name,
                      key: ValueKey(currentDest.name),
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontSize: 42,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                        height: 1.05,
                      ),
                    ),
                  ),

                  const SizedBox(height: 8),

                  // Subtitle matching Figma 01 Landing
                  Text(
                    'Go beyond the guidebook. Let intelligent agents compose your island story.',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.9),
                      fontSize: 14,
                      height: 1.4,
                      fontWeight: FontWeight.w400,
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Destination Dots Switcher (Figma style)
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
                            width: isActive ? 28 : 6,
                            height: 6,
                            decoration: BoxDecoration(
                              color: isActive ? const Color(0xFFD4A346) : Colors.white.withValues(alpha: 0.45),
                              borderRadius: BorderRadius.circular(3),
                            ),
                          ),
                        );
                      }),
                    ],
                  ),

                  const Spacer(flex: 2),

                  // Primary Action: Start Your Journey (Gold Pill Button)
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: () => Navigator.pushNamed(context, '/home'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFD4A346),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(26),
                        ),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.arrow_forward, size: 18, color: Colors.white),
                          SizedBox(width: 8),
                          Text(
                            'Start Your Journey',
                            style: TextStyle(
                              fontSize: 15.5,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 12),

                  // Secondary Row: Sign In & How AI Agents Work (White Pill Buttons)
                  Row(
                    children: [
                      Expanded(
                        child: SizedBox(
                          height: 48,
                          child: ElevatedButton(
                            onPressed: () => Navigator.pushNamed(context, '/login').then((_) => _checkAuthStatus()),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: const Color(0xFF0E382C),
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(24),
                              ),
                            ),
                            child: Text(
                              _isLoggedIn ? 'Account' : 'Sign In',
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF0E382C),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: SizedBox(
                          height: 48,
                          child: ElevatedButton.icon(
                            onPressed: () => _showAgentWorkflowDialog(context),
                            icon: const Icon(Icons.auto_awesome, size: 16, color: Color(0xFF0E382C)),
                            label: const Text(
                              'How AI Agents Work',
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF0E382C),
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(24),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 14),

                  // Footer Caption
                  Center(
                    child: Text(
                      'Curated routes · Verified partners · 24/7 trip support',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.7),
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),

                  const SizedBox(height: 6),
                ],
              ),
            ),
          ),
        ),
      );
    },
  ),
),
        ],
      ),
    );
  }
}

