import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../app_constants.dart';

/// Trip map screen matching Figma frame 10 · Trip Map (node 7:10901)
class TripMapScreen extends StatefulWidget {
  const TripMapScreen({super.key});

  @override
  State<TripMapScreen> createState() => _TripMapScreenState();
}

class _TripMapScreenState extends State<TripMapScreen> {
  int _activeStopIndex = 1; // Default to Stop 2: Temple of the Tooth

  final List<Map<String, dynamic>> _stops = [
    {
      'stopNum': 1,
      'location': 'SIGIRIYA',
      'title': 'Sigiriya Lion Rock Fortress',
      'rating': 4.9,
      'time': '12 Oct · 07:00–10:30',
      'distance': 'From airport · 148 km',
      'transit': '3.5 hrs private transfer',
      'image':
          'https://images.unsplash.com/photo-1586861635167-e5223aadc9fe?w=600&auto=format&fit=crop&q=80',
    },
    {
      'stopNum': 2,
      'location': 'KANDY',
      'title': 'Temple of the Tooth',
      'rating': 4.8,
      'time': '13 Oct · 10:30–12:00',
      'distance': 'From hotel · 1.8 km',
      'transit': '8 min by tuk-tuk',
      'image':
          'https://images.unsplash.com/photo-1546708973-b339540b5162?w=600&auto=format&fit=crop&q=80',
    },
    {
      'stopNum': 3,
      'location': 'DAMBULLA',
      'title': 'Heritance Kandalama Stay',
      'rating': 4.9,
      'time': '14 Oct · Check-in 14:00',
      'distance': 'From Sigiriya · 11 km',
      'transit': '20 min private car',
      'image':
          'https://images.unsplash.com/photo-1566073771259-6a8506099945?w=600&auto=format&fit=crop&q=80',
    },
    {
      'stopNum': 4,
      'location': 'ELLA',
      'title': 'Nine Arches Bridge & Train',
      'rating': 4.9,
      'time': '16 Oct · 08:30–11:00',
      'distance': 'From Kandy · 135 km',
      'transit': 'Scenic observation train',
      'image':
          'https://images.unsplash.com/photo-1588598198321-9735fd52455b?w=600&auto=format&fit=crop&q=80',
    },
  ];

  @override
  Widget build(BuildContext context) {
    final activeStop = _stops[_activeStopIndex];

    return Scaffold(
      backgroundColor: AppColors.figmaSurface,
      body: Stack(
        children: [
          // ── Map Canvas Background ──
          Positioned.fill(
            child: Container(
              color: const Color(0xFFE8EFE9),
              child: Stack(
                children: [
                  // High quality topographic map texture
                  Positioned.fill(
                    child: Image.network(
                      'https://images.unsplash.com/photo-1524661135-423995f22d0b?w=1200&auto=format&fit=crop&q=80',
                      fit: BoxFit.cover,
                      color: Colors.white.withValues(alpha: 0.65),
                      colorBlendMode: BlendMode.screen,
                    ),
                  ),
                  // Stylized SVG / Custom Painted Route
                  CustomPaint(
                    size: Size.infinite,
                    painter: _MapRoutePainter(),
                  ),
                  // 1. Sigiriya Pin (Gold)
                  Positioned(
                    top: 170,
                    left: 140,
                    child: GestureDetector(
                      onTap: () => setState(() => _activeStopIndex = 0),
                      child: _buildMapPin(
                        icon: Icons.castle_outlined,
                        color: AppColors.figmaGold,
                        isSelected: _activeStopIndex == 0,
                      ),
                    ),
                  ),
                  // 2. Dambulla Hotel Pin (Dark Green)
                  Positioned(
                    top: 280,
                    left: 200,
                    child: GestureDetector(
                      onTap: () => setState(() => _activeStopIndex = 2),
                      child: _buildMapPin(
                        icon: Icons.hotel_outlined,
                        color: AppColors.figmaDarkGreen,
                        isSelected: _activeStopIndex == 2,
                      ),
                    ),
                  ),
                  // 3. Kandy Temple Pin (Blue)
                  Positioned(
                    top: 380,
                    left: 145,
                    child: GestureDetector(
                      onTap: () => setState(() => _activeStopIndex = 1),
                      child: _buildMapPin(
                        icon: Icons.account_balance_outlined,
                        color: const Color(0xFF2563EB),
                        isSelected: _activeStopIndex == 1,
                      ),
                    ),
                  ),
                  // 4. Ella Transport Pin (Amber)
                  Positioned(
                    top: 480,
                    left: 220,
                    child: GestureDetector(
                      onTap: () => setState(() => _activeStopIndex = 3),
                      child: _buildMapPin(
                        icon: Icons.directions_car_outlined,
                        color: const Color(0xFFD97706),
                        isSelected: _activeStopIndex == 3,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── Top Floating App Bar Capsule ──
          Positioned(
            top: MediaQuery.of(context).padding.top + 10,
            left: 16,
            right: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(30),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: const BoxDecoration(
                        color: AppColors.figmaSurface,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.arrow_back,
                        color: AppColors.figmaDarkGreen,
                        size: 18,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Sri Lanka Discovery',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: AppColors.figmaDarkGreen,
                          ),
                        ),
                        Text(
                          '4 stops · 612 km',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 11,
                            color: const Color(0xFF6B7280),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    width: 36,
                    height: 36,
                    decoration: const BoxDecoration(
                      color: AppColors.figmaSurface,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.layers_outlined,
                      color: AppColors.figmaDarkGreen,
                      size: 18,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── Top Right Floating Legend Card ──
          Positioned(
            top: MediaQuery.of(context).padding.top + 76,
            right: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildLegendItem(Icons.castle_outlined, 'Destination'),
                  const SizedBox(height: 6),
                  _buildLegendItem(Icons.hotel_outlined, 'Hotel'),
                  const SizedBox(height: 6),
                  _buildLegendItem(Icons.account_balance_outlined, 'Attraction'),
                  const SizedBox(height: 6),
                  _buildLegendItem(Icons.directions_car_outlined, 'Transport'),
                ],
              ),
            ),
          ),

          // ── Bottom Floating Stop Preview Card ──
          Positioned(
            left: 12,
            right: 12,
            bottom: 12,
            child: Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.12),
                    blurRadius: 16,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Center grab handle
                  Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: const Color(0xFFD1D5DB),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Stop Details Row
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Thumbnail
                      ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: Image.network(
                          activeStop['image'] as String,
                          width: 80,
                          height: 80,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) => Container(
                            width: 80,
                            height: 80,
                            color: const Color(0xFFE5E7EB),
                            child: const Icon(
                              Icons.landscape,
                              color: Color(0xFF9CA3AF),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      // Details Column
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'STOP ${activeStop['stopNum']} OF 4 · ${activeStop['location']}',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                color: AppColors.figmaGold,
                                letterSpacing: 0.5,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              activeStop['title'] as String,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                color: AppColors.figmaDarkGreen,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 3),
                            Row(
                              children: [
                                const Icon(
                                  Icons.star_rounded,
                                  color: AppColors.figmaGold,
                                  size: 16,
                                ),
                                const SizedBox(width: 2),
                                Text(
                                  '${activeStop['rating']}',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.figmaDarkGreen,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              activeStop['time'] as String,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 11,
                                color: const Color(0xFF6B7280),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  // Distance & Transit Bar
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEAF2EC),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          activeStop['distance'] as String,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 11,
                            color: const Color(0xFF374151),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Text(
                          activeStop['transit'] as String,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF064E3B),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 14),

                  // CTA Button
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pushNamed(
                          context,
                          '/tours',
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.figmaDarkGreen,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(25),
                        ),
                        elevation: 0,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.arrow_forward, size: 18),
                          const SizedBox(width: 8),
                          Text(
                            'View Stop Details',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
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
        ],
      ),
    );
  }

  Widget _buildMapPin({
    required IconData icon,
    required Color color,
    required bool isSelected,
  }) {
    return Container(
      width: isSelected ? 44 : 38,
      height: isSelected ? 44 : 38,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Icon(
        icon,
        color: Colors.white,
        size: isSelected ? 22 : 18,
      ),
    );
  }

  Widget _buildLegendItem(IconData icon, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: AppColors.figmaDarkGreen),
        const SizedBox(width: 6),
        Text(
          label,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: AppColors.figmaDarkGreen,
          ),
        ),
      ],
    );
  }
}

/// Custom painter to draw the interconnected route path on the map
class _MapRoutePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF0F4735).withValues(alpha: 0.85)
      ..strokeWidth = 3.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final path = Path();
    path.moveTo(159, 190);
    path.cubicTo(130, 240, 219, 240, 219, 300);
    path.cubicTo(219, 340, 164, 340, 164, 400);
    path.cubicTo(164, 440, 239, 440, 239, 500);

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
