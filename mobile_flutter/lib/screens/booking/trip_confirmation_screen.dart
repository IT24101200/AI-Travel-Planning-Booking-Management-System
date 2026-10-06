import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../app_constants.dart';

/// Trip confirmation screen matching Figma Dev Mode (13 · Trip Confirmation).
class TripConfirmationScreen extends StatelessWidget {
  const TripConfirmationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final booking =
        ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    final bookingRef = booking?['bookingReference'] ?? 'ST-284619';
    final title = booking?['title'] ?? 'Sri Lanka Discovery';
    final dates = booking?['dates'] ?? '12–18 October 2026 · 7 days / 6 nights';
    final destinations = booking?['destinations'] ?? 'Sigiriya · Kandy · Ella · Mirissa';
    final hotel = booking?['hotel'] ?? 'Heritance Kandalama + 2 stays';
    final transport = booking?['transport'] ?? 'Private car + reserved train';
    final travelers = booking?['travelers'] ?? 'Maya Fernando + 1 guest';

    return Scaffold(
      backgroundColor: const Color(0xFFFBF9F4),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 10),

              // Double Concentric Circle Success Checkmark
              Container(
                width: 80,
                height: 80,
                decoration: const BoxDecoration(
                  color: Color(0xFFD4EFE4),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Container(
                    width: 58,
                    height: 58,
                    decoration: const BoxDecoration(
                      color: Color(0xFF13684B),
                      shape: BoxShape.circle,
                    ),
                    child: const Center(
                      child: Icon(Icons.check, color: Colors.white, size: 32),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 18),

              Text(
                'Booking Confirmed!',
                style: GoogleFonts.poppins(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF08201A),
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Your Sri Lankan journey is secured. Tickets and partner contacts are now available offline.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12.5,
                  color: Color(0xFF6B7280),
                  height: 1.4,
                ),
              ),

              const SizedBox(height: 16),

              // Booking Reference Soft Gold Pill
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFFF6EED8),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'BOOKING REFERENCE  ',
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF8A9E96),
                        letterSpacing: 0.5,
                      ),
                    ),
                    Text(
                      bookingRef,
                      style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF08201A),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 22),

              // Journey Card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: const Color(0xFFEDECE4)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.03),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Top Landscape Image
                    ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Image.asset(
                        AppDestinations.heroSigiriya,
                        height: 150,
                        width: double.infinity,
                        fit: BoxFit.cover,
                      ),
                    ),
                    const SizedBox(height: 16),

                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF08201A),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      dates,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF8A9E96),
                        fontWeight: FontWeight.w500,
                      ),
                    ),

                    const SizedBox(height: 14),
                    Container(height: 1, color: const Color(0xFFEDECE4)),
                    const SizedBox(height: 14),

                    // Detail Row 1: Destinations
                    _buildPassDetailRow(
                      icon: Icons.location_on_outlined,
                      label: 'Destinations',
                      value: destinations,
                    ),
                    const SizedBox(height: 12),

                    // Detail Row 2: Hotel
                    _buildPassDetailRow(
                      icon: Icons.apartment_outlined,
                      label: 'Hotel',
                      value: hotel,
                    ),
                    const SizedBox(height: 12),

                    // Detail Row 3: Transport
                    _buildPassDetailRow(
                      icon: Icons.directions_car_outlined,
                      label: 'Transport',
                      value: transport,
                    ),
                    const SizedBox(height: 12),

                    // Detail Row 4: Travelers
                    _buildPassDetailRow(
                      icon: Icons.people_outline,
                      label: 'Travelers',
                      value: travelers,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 18),

              // Two Actions: Share Trip & Download
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 50,
                      child: OutlinedButton.icon(
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Sharing trip link...')),
                          );
                        },
                        icon: const Icon(Icons.share_outlined, size: 18, color: Color(0xFF08201A)),
                        label: const Text(
                          'Share Trip',
                          style: TextStyle(
                            color: Color(0xFF08201A),
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          backgroundColor: Colors.white,
                          side: const BorderSide(color: Color(0xFFEDECE4)),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(25),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: SizedBox(
                      height: 50,
                      child: OutlinedButton.icon(
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Saving offline pass to phone...')),
                          );
                        },
                        icon: const Icon(Icons.download_outlined, size: 18, color: Color(0xFF08201A)),
                        label: const Text(
                          'Download',
                          style: TextStyle(
                            color: Color(0xFF08201A),
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          backgroundColor: Colors.white,
                          side: const BorderSide(color: Color(0xFFEDECE4)),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(25),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 14),

              // Reminder Banner
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF6EED8),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.notifications_none_outlined, color: Color(0xFFB27D26), size: 20),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'We\'ll remind you about visa, weather and packing details 7 days before departure.',
                        style: TextStyle(
                          fontSize: 11,
                          color: Color(0xFF08201A),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Back to Explore Button
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pushNamedAndRemoveUntil(context, '/home', (route) => false);
                  },
                  icon: const Icon(Icons.explore_outlined, color: Colors.white, size: 20),
                  label: const Text(
                    'Back to Explore',
                    style: TextStyle(
                      fontSize: 15.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0E382C),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(26),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPassDetailRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: const Color(0xFFEEFAF4),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Center(
            child: Icon(icon, color: const Color(0xFF13684B), size: 18),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 10.5,
                  color: Color(0xFF8A9E96),
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 1),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF08201A),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
